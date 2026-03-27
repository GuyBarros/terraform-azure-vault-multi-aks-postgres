###############################################################################
# modules/aks/main.tf
###############################################################################

resource "azurerm_virtual_network" "this" {
  name                = "${var.cluster_name}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_cidr]
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name           = "system"
    vm_size        = var.node_pool.vm_size
    node_count     = var.node_pool.node_count
    # zones is null when the region doesn't support availability zones (e.g. uksouth)
    zones          = length(var.node_pool.zones) > 0 ? var.node_pool.zones : null
    vnet_subnet_id = azurerm_subnet.aks.id
    os_disk_size_gb = 128
    os_disk_type    = "Managed"
    type            = "VirtualMachineScaleSets"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    # service_cidr and dns_service_ip must NOT overlap with vnet_address_space
    # or any subnet within. We carve them out of a separate 172.16.x.x range.
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  azure_policy_enabled             = true
  http_application_routing_enabled = false

  # OIDC issuer — once enabled on a cluster Azure will not allow it to be
  # disabled. Set it explicitly here so Terraform's state matches reality
  # and never attempts to send a disable request (which causes a 400 error).
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = var.tags
}

###############################################################################
# Vault node pool (dedicated, tainted)
###############################################################################

resource "azurerm_kubernetes_cluster_node_pool" "vault" {
  name                  = "vault"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.node_pool.vm_size
  node_count            = 3
  zones                 = length(var.node_pool.zones) > 0 ? var.node_pool.zones : null
  vnet_subnet_id        = azurerm_subnet.aks.id
  os_disk_size_gb       = 128
  mode                  = "User"

  node_labels = { "workload" = "vault" }
  node_taints = ["workload=vault:NoSchedule"]

  tags = var.tags

  lifecycle {
    # Prevent Terraform from failing when the node pool already exists in Azure
    # but isn't in state (e.g. after a partial apply). Also ignore autoscaler-
    # driven node count changes so Terraform doesn't fight the cluster autoscaler.
    ignore_changes = [
      node_count,
      tags,
    ]
  }
}

###############################################################################
# PostgreSQL-delegated subnet (for VNet integration)
###############################################################################

resource "azurerm_subnet" "postgresql" {
  name                 = "postgresql-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.postgresql_subnet_cidr]

  delegation {
    name = "postgresql-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

###############################################################################
# Network Security Group — Vault replication port (8201)
#
# Port 8201 is Vault's cluster port, used for:
#   - Raft peer-to-peer replication within a cluster
#   - Performance Replication between clusters across regions
#
# We create an NSG, allow 8201 inbound from the remote region's AKS subnet,
# and associate it with the AKS subnet. Port 8200 (API) is handled by the
# Azure Load Balancer and is already open publicly.
###############################################################################

resource "azurerm_network_security_group" "aks" {
  name                = "${var.cluster_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "vault_cluster_port_inbound" {
  count = length(var.vault_replication_source_cidrs) > 0 ? 1 : 0

  name                        = "allow-vault-cluster-port-inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8201"
  # Allow from Internet — cross-region replication uses public IPs across regions
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
  description                 = "Allow Vault cluster port 8201 inbound for Performance Replication"
}

resource "azurerm_network_security_rule" "vault_cluster_port_outbound" {
  count = length(var.vault_replication_source_cidrs) > 0 ? 1 : 0

  name                        = "allow-vault-cluster-port-outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8201"
  destination_address_prefix  = "Internet"
  source_address_prefix       = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
  description                 = "Allow Vault cluster port 8201 outbound for Performance Replication"
}

resource "azurerm_network_security_rule" "vault_api_port_inbound" {
  name                        = "allow-vault-api-port-inbound"
  priority                    = 210
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8200"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
  description                 = "Allow Vault API port 8200 inbound from internet (fronted by Azure Load Balancer)"
}

resource "azurerm_network_security_rule" "postgresql_outbound" {
  name                        = "allow-postgresql-outbound"
  priority                    = 220
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "*"
  destination_address_prefix  = var.postgresql_subnet_cidr
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
  description                 = "Allow PostgreSQL port 5432 outbound from AKS pods to the delegated PostgreSQL subnet"
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}
