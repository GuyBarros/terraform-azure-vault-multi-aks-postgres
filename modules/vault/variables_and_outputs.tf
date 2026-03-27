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
variable "region_label"       {
  type = string
}

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
variable "akv_client_id" {
  description = "Client ID of the AKS kubelet managed identity — disambiguates which identity to use when multiple are present on the node"
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

variable "lb_ip" {
  description = "Pre-created Azure Public IP for the Vault UI/API LoadBalancer (port 8200)"
  type        = string
}

variable "cluster_lb_ip" {
  description = "Pre-created Azure Public IP for the Vault cluster port LoadBalancer (port 8201) used for Performance Replication"
  type        = string
}

variable "cluster_pip_name" {
  description = "Name of the pre-created Azure Public IP resource for port 8201 — used in the azure-pip-name annotation so AKS binds the correct IP"
  type        = string
}

variable "additional_ip_sans" {
  description = "Any extra IP addresses to add to the Vault TLS cert SANs beyond lb_ip and 127.0.0.1"
  type        = list(string)
  default     = []
}

variable "additional_dns_sans" {
  description = "Extra DNS names to add to the Vault TLS cert SANs"
  type        = list(string)
  default     = []
}

# Shared CA — generated once in the root module and passed to both vault
# module instances so both clusters trust each other's certificates.
variable "shared_ca_cert_pem" {
  description = "PEM-encoded shared root CA certificate that signs all Vault server certs"
  type        = string
  sensitive   = true
}

variable "shared_ca_private_key_pem" {
  description = "PEM-encoded private key of the shared root CA"
  type        = string
  sensitive   = true
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

output "tls_secret_name" {
  description = "Name of the Kubernetes secret containing the Vault TLS cert, key, and CA"
  value       = kubernetes_secret.vault_tls.metadata[0].name
}

output "ca_cert_pem" {
  description = "PEM-encoded shared CA certificate — same across all clusters, so no ca_file needed for replication"
  value       = var.shared_ca_cert_pem
  sensitive   = true
}

output "lb_ip" {
  description = "Public IP address of the Vault UI LoadBalancer service"
  value       = var.lb_ip
}
