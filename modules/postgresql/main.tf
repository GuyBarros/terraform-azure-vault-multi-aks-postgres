###############################################################################
# modules/postgresql/main.tf
# Azure Database for PostgreSQL Flexible Server
# Primary: London (uksouth) | Read Replica: São Paulo (brazilsouth)
#
# Network access: VNet integration via delegated subnets + Private DNS zone.
# No IP-based firewall rules — avoids the "for_each on unknown values" error
# and is the correct production pattern for AKS → PostgreSQL connectivity.
###############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

###############################################################################
# Private DNS Zone (global — linked to both VNets)
###############################################################################

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.project_name}.private.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sao_paulo" {
  name                  = "psql-dns-link-brazilsouth"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = var.vnet_id_sao_paulo
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "london" {
  name                  = "psql-dns-link-uksouth"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = var.vnet_id_london
  registration_enabled  = false
  tags                  = var.tags
}

###############################################################################
# PostgreSQL Primary — London
# Uses VNet-delegated subnet; public access disabled.
###############################################################################

resource "azurerm_postgresql_flexible_server" "primary" {
  name                          = "${var.project_name}-psql-primary"
  resource_group_name           = var.resource_group_name
  location                      = var.primary.location
  version                       = var.postgres_version
  administrator_login           = var.administrator_login
  administrator_password        = var.administrator_password
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  zone                          = var.primary.zone
  public_network_access_enabled = false
  backup_retention_days         = 35
  geo_redundant_backup_enabled  = true

  # VNet integration — subnet must be delegated to Microsoft.DBforPostgreSQL/flexibleServers
  delegated_subnet_id = var.delegated_subnet_id_primary
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }

  maintenance_window {
    day_of_week  = 0
    start_hour   = 2
    start_minute = 0
  }

  tags = var.tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.london,
    azurerm_private_dns_zone_virtual_network_link.sao_paulo,
  ]
}

###############################################################################
# Read Replica — São Paulo
###############################################################################

resource "azurerm_postgresql_flexible_server" "replica" {
  name                          = "${var.project_name}-psql-replica"
  resource_group_name           = var.resource_group_name
  location                      = var.replica.location
  version                       = var.postgres_version
  administrator_login           = var.administrator_login
  administrator_password        = var.administrator_password
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  zone                          = var.replica.zone
  public_network_access_enabled = false
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  create_mode                   = "Replica"
  source_server_id              = azurerm_postgresql_flexible_server.primary.id

  delegated_subnet_id = var.delegated_subnet_id_replica
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  tags = var.tags

  depends_on = [
    # Wait for primary to be fully idle before creating replica
    # (time_sleep gates on primary already, so this covers both)
    time_sleep.wait_for_primary,
    azurerm_private_dns_zone_virtual_network_link.london,
    azurerm_private_dns_zone_virtual_network_link.sao_paulo,
  ]

  lifecycle {
    # Replica inherits config from primary; ignore drift on these read-only attributes
    ignore_changes = [
      administrator_login,
      administrator_password,
      version,
    ]
  }
}

###############################################################################
# PostgreSQL Configuration
#
# Azure Flexible Server stays "busy" for several minutes after provisioning
# even once Terraform considers the resource complete. A time_sleep after the
# primary gives the server time to reach a fully idle state before we attempt
# any configuration changes, preventing the ServerIsBusy error.
# Configs are also chained sequentially — Azure only allows one config
# operation at a time per server.
###############################################################################

resource "time_sleep" "wait_for_primary" {
  create_duration = "5m"
  depends_on      = [azurerm_postgresql_flexible_server.primary]
}

resource "azurerm_postgresql_flexible_server_configuration" "ssl_on" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.primary.id
  value     = "on"

  depends_on = [time_sleep.wait_for_primary]
}

resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.primary.id
  value     = "500"

  depends_on = [azurerm_postgresql_flexible_server_configuration.ssl_on]
}

resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.primary.id
  value     = "on"

  depends_on = [azurerm_postgresql_flexible_server_configuration.max_connections]
}

###############################################################################
# Vault Database
###############################################################################

resource "azurerm_postgresql_flexible_server_database" "vault" {
  name      = "vault"
  server_id = azurerm_postgresql_flexible_server.primary.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
