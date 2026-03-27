###############################################################################
# modules/postgresql/variables.tf
###############################################################################

variable "resource_group_name"    {
  type = string
}
variable "project_name"           {
  type = string
}
variable "administrator_login"    {
  type = string
  sensitive = true
}
variable "administrator_password" {
  type = string
  sensitive = true
}
variable "sku_name"               {
  type = string
}
variable "storage_mb"             {
  type = number
}
variable "postgres_version"       {
  type = string
}
variable "tags"                   {
  type = map(string)
}

variable "primary" {
  type = object({
    location = string
    zone     = string
  })
}

variable "replica" {
  type = object({
    location = string
    zone     = string
  })
}

# VNet integration — replaces IP-based firewall rules
variable "vnet_id_london" {
  description = "Resource ID of the London VNet (for Private DNS zone link)"
  type        = string
}

variable "vnet_id_sao_paulo" {
  description = "Resource ID of the São Paulo VNet (for Private DNS zone link)"
  type        = string
}

variable "delegated_subnet_id_primary" {
  description = "Subnet ID delegated to Microsoft.DBforPostgreSQL/flexibleServers in London"
  type        = string
}

variable "delegated_subnet_id_replica" {
  description = "Subnet ID delegated to Microsoft.DBforPostgreSQL/flexibleServers in São Paulo"
  type        = string
}

variable "vnet_peering_ids" {
  description = "Resource IDs of VNet peerings to wait for before creating the replica (prevents ReadReplicaToSourceServerNetworkBlocked)"
  type        = list(string)
  default     = []
}

variable "aks_subnet_cidrs" {
  description = "AKS subnet CIDRs from both regions — allowed to connect to PostgreSQL on port 5432"
  type        = list(string)
  default     = []
}

###############################################################################
# modules/postgresql/outputs.tf
###############################################################################

output "primary_fqdn" {
  value = azurerm_postgresql_flexible_server.primary.fqdn
}

output "replica_fqdn" {
  value = azurerm_postgresql_flexible_server.replica.fqdn
}

output "primary_server_name" {
  value = azurerm_postgresql_flexible_server.primary.name
}

output "vault_database_name" {
  value = azurerm_postgresql_flexible_server_database.vault.name
}

output "private_dns_zone_id" {
  value = azurerm_private_dns_zone.postgres.id
}
