###############################################################################
# modules/traffic_manager/variables.tf
###############################################################################

variable "project_name" {
  description = "Project prefix — used to build the DNS zone name: postgres.<project>.internal"
  type        = string
}

# Each DNS zone lives in its own region's RG to avoid the Azure constraint
# that prevents two Private DNS zones with the same name in the same RG.
variable "resource_group_name_london" {
  description = "Resource group for the London DNS view (typically the London AKS RG)"
  type        = string
}

variable "resource_group_name_sao_paulo" {
  description = "Resource group for the São Paulo DNS view (typically the São Paulo AKS RG)"
  type        = string
}

variable "primary_fqdn" {
  description = "FQDN of the PostgreSQL primary server (London)"
  type        = string
}

variable "replica_fqdn" {
  description = "FQDN of the PostgreSQL replica server (São Paulo)"
  type        = string
}

variable "vnet_id_london" {
  description = "Resource ID of the London AKS VNet"
  type        = string
}

variable "vnet_id_sao_paulo" {
  description = "Resource ID of the São Paulo AKS VNet"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

###############################################################################
# modules/traffic_manager/outputs.tf
###############################################################################

output "geo_fqdn" {
  description = "Single FQDN for geo-local PostgreSQL routing — use this in your app config"
  value       = "postgres.${var.project_name}.internal"
}

output "primary_fqdn" {
  description = "Always resolves to the London primary — use for all writes"
  value       = "postgres-primary.${var.project_name}.internal"
}

output "replica_fqdn" {
  description = "Always resolves to the São Paulo replica — use for explicit reads"
  value       = "postgres-replica.${var.project_name}.internal"
}

output "london_dns_zone_id" {
  value = azurerm_private_dns_zone.london_view.id
}

output "sao_paulo_dns_zone_id" {
  value = azurerm_private_dns_zone.sao_paulo_view.id
}
