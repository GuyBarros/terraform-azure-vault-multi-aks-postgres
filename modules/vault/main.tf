###############################################################################
# modules/vault/main.tf
# Deploys HashiCorp Vault ENTERPRISE via Helm onto AKS
#
# This module contains ONLY helm + kubernetes resources.
# Azure resources (Key Vault, keys, RBAC, Public IP) live in the root module
# and are passed in as variables — this keeps the module free of any azurerm
# provider usage and avoids the "legacy module" restriction entirely.
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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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

  force_update  = true
  recreate_pods = true

  values = [
    templatefile("${path.module}/vault-values.yaml.tpl", {
      replica_count          = var.replica_count
      region_label           = var.region_label
      vault_version          = var.vault_enterprise_version
      akv_tenant_id          = var.akv_tenant_id
      akv_vault_name         = var.akv_vault_name
      akv_key_name           = var.akv_key_name
      akv_client_id          = var.akv_client_id
      license_secret_name    = kubernetes_secret.vault_license.metadata[0].name
      image_pull_secret_name = kubernetes_secret.vault_image_pull.metadata[0].name
      tls_secret_name        = kubernetes_secret.vault_tls.metadata[0].name
      replication_enabled    = var.replication_enabled
      lb_ip                  = var.lb_ip
      cluster_lb_ip          = var.cluster_lb_ip
    })
  ]

  set {
    name  = "server.annotations.terraform-values-checksum"
    value = sha256(join(",", concat(
      [
        var.akv_tenant_id,
        var.akv_client_id,
        var.akv_vault_name,
        var.akv_key_name,
        var.vault_enterprise_version,
        var.region_label,
        var.lb_ip,
        var.cluster_lb_ip,
      ],
      var.additional_ip_sans
    )))
  }

  timeout = 600
  wait    = true

  depends_on = [
    kubernetes_namespace.vault,
    kubernetes_secret.vault_license,
    kubernetes_secret.vault_tls,
  ]
}

###############################################################################
# Vault Cluster Port LoadBalancer Service (port 8201)
# The vault-ui service only exposes 8200. Replication needs 8201 exposed
# publicly. A separate LoadBalancer service on a dedicated IP handles this.
###############################################################################

resource "kubernetes_service" "vault_cluster" {
  metadata {
    name      = "${var.vault_release_name}-cluster"
    namespace = kubernetes_namespace.vault.metadata[0].name
    labels = {
      "app.kubernetes.io/name"     = "vault"
      "app.kubernetes.io/instance" = var.vault_release_name
    }
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-internal" = "false"
      "service.beta.kubernetes.io/azure-pip-name"               = var.cluster_pip_name
    }
  }

  spec {
    type             = "LoadBalancer"
    load_balancer_ip = var.cluster_lb_ip

    selector = {
      "app.kubernetes.io/name"     = "vault"
      "app.kubernetes.io/instance" = var.vault_release_name
      "component"                  = "server"
    }

    port {
      name        = "cluster"
      port        = 8201
      target_port = 8201
      protocol    = "TCP"
    }

    publish_not_ready_addresses = true
  }

  depends_on = [helm_release.vault]
}
