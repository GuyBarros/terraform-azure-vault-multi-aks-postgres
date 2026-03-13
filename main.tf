###############################################################################
# main.tf - Multi-Region AKS + Vault Enterprise + Azure PostgreSQL
# Regions: Brazil South (São Paulo) | UK South (London)
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

###############################################################################
# Aliased Helm + Kubernetes providers — one per region.
# Passed into vault modules via `providers = {}` so the vault module itself
# contains zero provider blocks and is never treated as a "legacy module".
###############################################################################

provider "helm" {
  alias = "sao_paulo"
  kubernetes {
    host                   = module.aks_sao_paulo.host
    client_certificate     = base64decode(module.aks_sao_paulo.client_certificate)
    client_key             = base64decode(module.aks_sao_paulo.client_key)
    cluster_ca_certificate = base64decode(module.aks_sao_paulo.cluster_ca_certificate)
  }
}

provider "kubernetes" {
  alias                  = "sao_paulo"
  host                   = module.aks_sao_paulo.host
  client_certificate     = base64decode(module.aks_sao_paulo.client_certificate)
  client_key             = base64decode(module.aks_sao_paulo.client_key)
  cluster_ca_certificate = base64decode(module.aks_sao_paulo.cluster_ca_certificate)
}

provider "helm" {
  alias = "london"
  kubernetes {
    host                   = module.aks_london.host
    client_certificate     = base64decode(module.aks_london.client_certificate)
    client_key             = base64decode(module.aks_london.client_key)
    cluster_ca_certificate = base64decode(module.aks_london.cluster_ca_certificate)
  }
}

provider "kubernetes" {
  alias                  = "london"
  host                   = module.aks_london.host
  client_certificate     = base64decode(module.aks_london.client_certificate)
  client_key             = base64decode(module.aks_london.client_key)
  cluster_ca_certificate = base64decode(module.aks_london.cluster_ca_certificate)
}

###############################################################################
# Data
###############################################################################

data "azurerm_client_config" "current" {}

###############################################################################
# Resource Groups
###############################################################################

resource "azurerm_resource_group" "sao_paulo" {
  name     = "${var.project_name}-rg-brazilsouth"
  location = "brazilsouth"
  tags     = merge(var.common_tags, { region = "brazil-south" })
}

resource "azurerm_resource_group" "london" {
  name     = "${var.project_name}-rg-uksouth"
  location = "uksouth"
  tags     = merge(var.common_tags, { region = "uk-south" })
}

resource "azurerm_resource_group" "postgres_primary" {
  name     = "${var.project_name}-rg-postgres"
  location = "uksouth"
  tags     = merge(var.common_tags, { component = "postgresql-global" })
}

###############################################################################
# Log Analytics Workspaces
###############################################################################

module "log_analytics_sao_paulo" {
  source              = "./modules/log_analytics"
  name                = "${var.project_name}-law-brazilsouth"
  resource_group_name = azurerm_resource_group.sao_paulo.name
  location            = azurerm_resource_group.sao_paulo.location
  tags                = var.common_tags
}

module "log_analytics_london" {
  source              = "./modules/log_analytics"
  name                = "${var.project_name}-law-uksouth"
  resource_group_name = azurerm_resource_group.london.name
  location            = azurerm_resource_group.london.location
  tags                = var.common_tags
}

###############################################################################
# AKS Clusters
###############################################################################

module "aks_sao_paulo" {
  source = "./modules/aks"

  resource_group_name        = azurerm_resource_group.sao_paulo.name
  location                   = azurerm_resource_group.sao_paulo.location
  cluster_name               = "${var.project_name}-aks-brazilsouth"
  dns_prefix                 = "${var.project_name}-brazilsouth"
  kubernetes_version         = var.kubernetes_version
  log_analytics_workspace_id = module.log_analytics_sao_paulo.workspace_id
  tags                       = merge(var.common_tags, { region = "brazil-south" })

  # São Paulo VNet space — kept in 10.1.x.x to avoid any cross-region overlap
  vnet_address_space     = "10.1.0.0/16"
  aks_subnet_cidr        = "10.1.0.0/22"
  postgresql_subnet_cidr = "10.1.8.0/24"
  # service_cidr must not overlap with vnet_address_space; 172.16.x.x is safe
  service_cidr           = "172.16.0.0/16"
  dns_service_ip         = "172.16.0.10"

  node_pool = {
    #vm_size    = var.aks_node_vm_size
    vm_size    = "standard_d16s_v6"
    node_count = var.aks_node_count
    zones      = [ "2"]   # brazilsouth supports AZs
  }
}

module "aks_london" {
  source = "./modules/aks"

  resource_group_name        = azurerm_resource_group.london.name
  location                   = azurerm_resource_group.london.location
  cluster_name               = "${var.project_name}-aks-uksouth"
  dns_prefix                 = "${var.project_name}-uksouth"
  kubernetes_version         = var.kubernetes_version
  log_analytics_workspace_id = module.log_analytics_london.workspace_id
  tags                       = merge(var.common_tags, { region = "uk-south" })

  # London VNet space — kept in 10.2.x.x to avoid any cross-region overlap
  vnet_address_space     = "10.2.0.0/16"
  aks_subnet_cidr        = "10.2.0.0/22"
  postgresql_subnet_cidr = "10.2.8.0/24"
  service_cidr           = "172.17.0.0/16"
  dns_service_ip         = "172.17.0.10"

  node_pool = {
    vm_size    = var.aks_node_vm_size
    node_count = var.aks_node_count
    zones      = []   # uksouth does not support Availability Zones — pass empty list
  }
}

###############################################################################
# VNet Peering — London <-> São Paulo
# Must exist BEFORE PostgreSQL module so the replica can reach the primary.
###############################################################################

resource "azurerm_virtual_network_peering" "london_to_sao_paulo" {
  name                      = "london-to-sao-paulo"
  resource_group_name       = azurerm_resource_group.london.name
  virtual_network_name      = module.aks_london.vnet_name
  remote_virtual_network_id = module.aks_sao_paulo.vnet_id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

resource "azurerm_virtual_network_peering" "sao_paulo_to_london" {
  name                      = "sao-paulo-to-london"
  resource_group_name       = azurerm_resource_group.sao_paulo.name
  virtual_network_name      = module.aks_sao_paulo.vnet_name
  remote_virtual_network_id = module.aks_london.vnet_id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

###############################################################################
# PostgreSQL Flexible Server
# Declared after VNet peering so the replica can reach the primary on port 5432
###############################################################################

module "postgresql" {
  source = "./modules/postgresql"

  resource_group_name    = azurerm_resource_group.postgres_primary.name
  project_name           = var.project_name
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password
  sku_name               = var.postgres_sku_name
  storage_mb             = var.postgres_storage_mb
  postgres_version       = var.postgres_version

  primary = { location = "uksouth",     zone = "1" }
  replica = { location = "brazilsouth", zone = "1" }

  vnet_id_london              = module.aks_london.vnet_id
  vnet_id_sao_paulo           = module.aks_sao_paulo.vnet_id
  delegated_subnet_id_primary = module.aks_london.postgresql_subnet_id
  delegated_subnet_id_replica = module.aks_sao_paulo.postgresql_subnet_id

  # Pass peering IDs so Terraform knows to wait for peering before PostgreSQL
  vnet_peering_ids = [
    azurerm_virtual_network_peering.london_to_sao_paulo.id,
    azurerm_virtual_network_peering.sao_paulo_to_london.id,
  ]

  tags = merge(var.common_tags, { component = "postgresql-global" })
}

###############################################################################
# Azure Key Vault — Auto-Unseal (São Paulo)
# Keeping AKV resources in root avoids any azurerm usage inside the vault
# module, which is what triggers the "legacy module" error.
###############################################################################

resource "azurerm_key_vault" "vault_unseal_sao_paulo" {
  name                       = "${var.project_name}-akv-brs"
  location                   = azurerm_resource_group.sao_paulo.location
  resource_group_name        = azurerm_resource_group.sao_paulo.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  enable_rbac_authorization  = true
  tags                       = merge(var.common_tags, { region = "brazil-south" })
}

# AKS kubelet identity — needs Crypto Officer to wrap/unwrap the unseal key at runtime
resource "azurerm_role_assignment" "vault_unseal_crypto_sao_paulo" {
  scope                = azurerm_key_vault.vault_unseal_sao_paulo.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = module.aks_sao_paulo.kubelet_identity_object_id
}

# Terraform service principal — needs Crypto Officer to CREATE the key during apply
resource "azurerm_role_assignment" "terraform_akv_sao_paulo" {
  scope                = azurerm_key_vault.vault_unseal_sao_paulo.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_key" "vault_unseal_sao_paulo" {
  name         = "vault-unseal-key"
  key_vault_id = azurerm_key_vault.vault_unseal_sao_paulo.id
  key_type     = "RSA-HSM"
  key_size     = 2048
  key_opts     = ["wrapKey", "unwrapKey"]
  depends_on   = [
    azurerm_role_assignment.vault_unseal_crypto_sao_paulo,
    azurerm_role_assignment.terraform_akv_sao_paulo,
  ]
}

###############################################################################
# Azure Key Vault — Auto-Unseal (London)
###############################################################################

resource "azurerm_key_vault" "vault_unseal_london" {
  name                       = "${var.project_name}-akv-uks"
  location                   = azurerm_resource_group.london.location
  resource_group_name        = azurerm_resource_group.london.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  enable_rbac_authorization  = true
  tags                       = merge(var.common_tags, { region = "uk-south" })
}

# AKS kubelet identity — needs Crypto Officer to wrap/unwrap the unseal key at runtime
resource "azurerm_role_assignment" "vault_unseal_crypto_london" {
  scope                = azurerm_key_vault.vault_unseal_london.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = module.aks_london.kubelet_identity_object_id
}

# Terraform service principal — needs Crypto Officer to CREATE the key during apply
resource "azurerm_role_assignment" "terraform_akv_london" {
  scope                = azurerm_key_vault.vault_unseal_london.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_key" "vault_unseal_london" {
  name         = "vault-unseal-key"
  key_vault_id = azurerm_key_vault.vault_unseal_london.id
  key_type     = "RSA-HSM"
  key_size     = 2048
  key_opts     = ["wrapKey", "unwrapKey"]
  depends_on   = [
    azurerm_role_assignment.vault_unseal_crypto_london,
    azurerm_role_assignment.terraform_akv_london,
  ]
}


###############################################################################
# Vault Enterprise - São Paulo
###############################################################################

module "vault_sao_paulo" {
  source = "./modules/vault"

  providers = {
    helm       = helm.sao_paulo
    kubernetes = kubernetes.sao_paulo
  }

  vault_release_name = "vault"
  vault_namespace    = "vault"
  replica_count      = var.vault_replica_count
  region_label       = "brazil-south"

  # AKV auto-unseal values resolved in root, passed in as plain strings
  akv_tenant_id  = data.azurerm_client_config.current.tenant_id
  akv_vault_name = azurerm_key_vault.vault_unseal_sao_paulo.name
  akv_key_name   = azurerm_key_vault_key.vault_unseal_sao_paulo.name

  vault_enterprise_license = var.vault_enterprise_license
  vault_enterprise_version = var.vault_enterprise_version
  hcp_registry_username    = var.hcp_registry_username
  hcp_registry_password    = var.hcp_registry_password
  replication_enabled      = true
}

###############################################################################
# Vault Enterprise - London
###############################################################################

module "vault_london" {
  source = "./modules/vault"

  providers = {
    helm       = helm.london
    kubernetes = kubernetes.london
  }

  vault_release_name = "vault"
  vault_namespace    = "vault"
  replica_count      = var.vault_replica_count
  region_label       = "uk-south"

  akv_tenant_id  = data.azurerm_client_config.current.tenant_id
  akv_vault_name = azurerm_key_vault.vault_unseal_london.name
  akv_key_name   = azurerm_key_vault_key.vault_unseal_london.name

  vault_enterprise_license = var.vault_enterprise_license
  vault_enterprise_version = var.vault_enterprise_version
  hcp_registry_username    = var.hcp_registry_username
  hcp_registry_password    = var.hcp_registry_password
  replication_enabled      = true
}
