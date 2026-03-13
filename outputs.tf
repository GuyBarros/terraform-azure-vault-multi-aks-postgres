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
