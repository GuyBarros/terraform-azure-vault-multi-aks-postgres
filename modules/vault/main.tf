###############################################################################
# modules/vault/main.tf
# Deploys HashiCorp Vault ENTERPRISE via Helm onto AKS
#
# This module contains ONLY helm + kubernetes resources.
# Azure resources (Key Vault, keys, RBAC) live in the root module and are
# passed in as variables — this keeps the module free of any azurerm provider
# usage and avoids the "legacy module" restriction entirely.
###############################################################################

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

###############################################################################
# Namespace
###############################################################################

resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "region"                       = var.region_label
      "vault.hashicorp.com/edition"  = "enterprise"
    }
  }
}

###############################################################################
# Vault Enterprise License Secret
###############################################################################

resource "kubernetes_secret" "vault_license" {
  metadata {
    name      = "vault-ent-license"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
  data = {
    license = var.vault_enterprise_license
  }
  type = "Opaque"
}

###############################################################################
# Vault Enterprise Image Pull Secret
###############################################################################

resource "kubernetes_secret" "vault_image_pull" {
  metadata {
    name      = "vault-image-pull"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "docker.io" = {
          username = var.hcp_registry_username
          password = var.hcp_registry_password
          auth     = base64encode("${var.hcp_registry_username}:${var.hcp_registry_password}")
        }
      }
    })
  }
}

###############################################################################
# Helm Release - HashiCorp Vault Enterprise
###############################################################################

resource "helm_release" "vault" {
  name       = var.vault_release_name
  namespace  = kubernetes_namespace.vault.metadata[0].name
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_chart_version

  values = [
    templatefile("${path.module}/vault-values.yaml.tpl", {
      replica_count          = var.replica_count
      region_label           = var.region_label
      vault_version          = var.vault_enterprise_version
      akv_tenant_id          = var.akv_tenant_id
      akv_vault_name         = var.akv_vault_name
      akv_key_name           = var.akv_key_name
      license_secret_name    = kubernetes_secret.vault_license.metadata[0].name
      image_pull_secret_name = kubernetes_secret.vault_image_pull.metadata[0].name
      replication_enabled    = var.replication_enabled
    })
  ]

  timeout = 600
  wait    = true

  depends_on = [
    kubernetes_namespace.vault,
    kubernetes_secret.vault_license,
  ]
}
