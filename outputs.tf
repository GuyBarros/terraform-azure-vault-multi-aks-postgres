###############################################################################
# outputs.tf
###############################################################################

output "aks_sao_paulo_cluster_name" {
  value = module.aks_sao_paulo.cluster_name
}

output "aks_london_cluster_name" {
  value = module.aks_london.cluster_name
}

output "aks_sao_paulo_kubeconfig_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.sao_paulo.name} --name ${module.aks_sao_paulo.cluster_name}"
}

output "aks_london_kubeconfig_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.london.name} --name ${module.aks_london.cluster_name}"
}

output "postgresql_primary_fqdn" {
  value = module.postgresql.primary_fqdn
}

output "postgresql_replica_fqdn" {
  value = module.postgresql.replica_fqdn
}

output "vault_sao_paulo_namespace" {
  value = module.vault_sao_paulo.namespace
}

output "vault_london_namespace" {
  value = module.vault_london.namespace
}

output "akv_unseal_sao_paulo_name" {
  description = "Azure Key Vault used for Vault auto-unseal in São Paulo"
  value       = azurerm_key_vault.vault_unseal_sao_paulo.name
}

output "akv_unseal_london_name" {
  description = "Azure Key Vault used for Vault auto-unseal in London"
  value       = azurerm_key_vault.vault_unseal_london.name
}

###############################################################################
# Geo-Routing DNS outputs
###############################################################################

output "postgres_geo_fqdn" {
  description = "Use this FQDN in your app — resolves to the nearest PostgreSQL server based on VNet location"
  value       = module.traffic_manager.geo_fqdn
}

output "postgres_primary_dns_fqdn" {
  description = "Always resolves to the London primary — use for writes"
  value       = module.traffic_manager.primary_fqdn
}

output "postgres_replica_dns_fqdn" {
  description = "Always resolves to the São Paulo replica — use for explicit reads"
  value       = module.traffic_manager.replica_fqdn
}

###############################################################################
# Vault TLS outputs
###############################################################################

output "vault_sao_paulo_ca_cert" {
  description = "CA cert for São Paulo Vault cluster — add to your trust store or use with VAULT_CACERT"
  value       = module.vault_sao_paulo.ca_cert_pem
  sensitive   = true
}

output "vault_london_ca_cert" {
  description = "CA cert for London Vault cluster — add to your trust store or use with VAULT_CACERT"
  value       = module.vault_london.ca_cert_pem
  sensitive   = true
}

output "vault_london_lb_ip" {
  description = "Pre-created Public IP for the London Vault UI LoadBalancer — included in TLS cert SANs"
  value       = azurerm_public_ip.vault_ui_london.ip_address
}

output "vault_sao_paulo_lb_ip" {
  description = "Pre-created Public IP for the São Paulo Vault UI LoadBalancer — included in TLS cert SANs"
  value       = azurerm_public_ip.vault_ui_sao_paulo.ip_address
}

output "vault_shared_ca_cert" {
  description = "Shared Vault root CA cert — both clusters trust this. Use with VAULT_CACERT for CLI access to either cluster."
  value       = tls_self_signed_cert.vault_shared_ca.cert_pem
  sensitive   = true
}

output "vault_london_cluster_ip" {
  description = "Public IP for London Vault cluster port 8201 — use as primary_cluster_addr for replication"
  value       = azurerm_public_ip.vault_cluster_london.ip_address
}

output "vault_sao_paulo_cluster_ip" {
  description = "Public IP for São Paulo Vault cluster port 8201"
  value       = azurerm_public_ip.vault_cluster_sao_paulo.ip_address
}

###############################################################################
# pgBouncer connection strings
# Use these in Vault's database secrets engine instead of direct PostgreSQL
###############################################################################

output "pgbouncer_london_connection_host" {
  description = "pgBouncer ClusterIP hostname for London — use in Vault database/config/postgres connection_url"
  value       = module.pgbouncer_london.connection_string_host
}

output "pgbouncer_sao_paulo_connection_host" {
  description = "pgBouncer ClusterIP hostname for São Paulo — use in Vault database/config/postgres connection_url"
  value       = module.pgbouncer_sao_paulo.connection_string_host
}

