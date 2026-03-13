###############################################################################
# variables.tf
###############################################################################

variable "project_name" {
  description = "Short project identifier used as a prefix for all resources"
  type        = string
  default     = "hashi-global"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS clusters"
  type        = string
  default     = "1.29"
}

variable "aks_node_vm_size" {
  description = "VM size for AKS default node pool"
  type        = string
  default     = "Standard_D4as_v7"  # Available in both brazilsouth and uksouth
}

variable "aks_node_count" {
  description = "Number of nodes per AKS node pool"
  type        = number
  default     = 3
}

variable "vault_replica_count" {
  description = "Number of Vault HA replicas per cluster"
  type        = number
  default     = 3
}

# PostgreSQL
variable "postgres_admin_username" {
  description = "PostgreSQL administrator login"
  type        = string
  default     = "pgadmin"
  sensitive   = true
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

variable "postgres_sku_name" {
  description = "PostgreSQL Flexible Server SKU"
  type        = string
  default     = "GP_Standard_D4s_v3"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage size in MB"
  type        = number
  default     = 131072 # 128 GB
}

variable "postgres_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "15"
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    managed_by  = "terraform"
    project     = "hashi-global"
    environment = "production"
  }
}

###############################################################################
# Vault Enterprise
###############################################################################

variable "vault_enterprise_license" {
  description = "Vault Enterprise license string obtained from HashiCorp"
  type        = string
  sensitive   = true
}

variable "vault_enterprise_version" {
  description = "Vault Enterprise Docker image tag"
  type        = string
  default     = "1.17.0-ent"
}

variable "hcp_registry_username" {
  description = "Docker Hub username for pulling the hashicorp/vault-enterprise image"
  type        = string
  sensitive   = true
}

variable "hcp_registry_password" {
  description = "Docker Hub password or PAT for pulling the hashicorp/vault-enterprise image"
  type        = string
  sensitive   = true
}
