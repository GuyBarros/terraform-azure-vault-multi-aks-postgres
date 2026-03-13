###############################################################################
# modules/aks/variables.tf
###############################################################################

variable "resource_group_name"        { type = string }
variable "location"                   { type = string }
variable "cluster_name"               { type = string }
variable "dns_prefix"                 { type = string }
variable "kubernetes_version"         { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "tags"                       { type = map(string) }

variable "node_pool" {
  type = object({
    vm_size    = string
    node_count = number
    # Pass an empty list [] for regions that don't support Availability Zones
    zones      = list(string)
  })
}

variable "vnet_address_space" {
  description = "Address space for the AKS VNet. Must not overlap with service_cidr."
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "Subnet CIDR for AKS nodes — must sit inside vnet_address_space."
  type        = string
  default     = "10.0.0.0/22"
}

variable "postgresql_subnet_cidr" {
  description = "CIDR for the PostgreSQL-delegated subnet — must sit inside vnet_address_space."
  type        = string
  default     = "10.0.8.0/24"
}

variable "service_cidr" {
  description = <<-EOT
    CIDR used for Kubernetes service IPs. Must NOT overlap with vnet_address_space
    or any subnet. Using 172.16.0.0/16 keeps it safely away from the 10.0.0.0/8 VNet space.
  EOT
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "IP for the Kubernetes DNS service — must be within service_cidr."
  type        = string
  default     = "172.16.0.10"
}
