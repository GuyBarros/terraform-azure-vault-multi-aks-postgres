###############################################################################
# modules/vault/variables.tf
###############################################################################

variable "vault_release_name" {
   type = string
    default = "vault" 
    }
variable "vault_namespace"    {
   type = string
    default = "vault" 
    }
variable "replica_count"      { 
  type = number
   default = 3 
   }
variable "region_label"       { type = string }

# Azure Key Vault Auto-Unseal values — created in root, passed in here
variable "akv_tenant_id" {
  description = "Azure AD tenant ID for the Key Vault seal config"
  type        = string
}
variable "akv_vault_name" {
  description = "Name of the Azure Key Vault used for auto-unseal"
  type        = string
}
variable "akv_key_name" {
  description = "Name of the RSA-HSM key inside the Azure Key Vault"
  type        = string
}

# Vault Enterprise
variable "vault_enterprise_license" {
  type      = string
  sensitive = true
}
variable "vault_enterprise_version" {
  type    = string
  default = "1.17.0-ent"
}
variable "vault_chart_version" {
  type    = string
  default = "0.28.0"
}
variable "hcp_registry_username" {
  type      = string
  sensitive = true
}
variable "hcp_registry_password" {
  type      = string
  sensitive = true
}
variable "replication_enabled" {
  type    = bool
  default = true
}

###############################################################################
# modules/vault/outputs.tf
###############################################################################

output "namespace" {
  value = kubernetes_namespace.vault.metadata[0].name
}

output "release_name" {
  value = helm_release.vault.name
}
