###############################################################################
# modules/aks/outputs.tf
###############################################################################

output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive = true
}

output "host" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive = true
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].client_certificate
  sensitive = true
}

output "client_key" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "outbound_ip_addresses" {
  description = "Outbound public IPs of the AKS load balancer"
  value = [
    for pip in azurerm_kubernetes_cluster.this.network_profile[0].load_balancer_profile[0].effective_outbound_ips :
    pip
  ]
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

output "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity — used for Azure Key Vault RBAC"
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "vnet_id" {
  description = "Resource ID of the AKS VNet"
  value       = azurerm_virtual_network.this.id
}

output "postgresql_subnet_id" {
  description = "Subnet ID of the PostgreSQL-delegated subnet"
  value       = azurerm_subnet.postgresql.id
}

output "vnet_name" {
  description = "Name of the AKS VNet — needed for VNet peering"
  value       = azurerm_virtual_network.this.name
}
