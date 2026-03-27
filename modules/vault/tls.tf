###############################################################################
# modules/vault/tls.tf
#
# Generates a Vault server certificate signed by the SHARED root CA.
#
# IP SANs — all known at plan time to avoid dependency cycles:
#   1. 127.0.0.1          always — local health checks
#   2. var.lb_ip          pre-created Azure Public IP — known before cert generation
#   3. additional_ip_sans any extras passed in from root
#
# Vault replication uses cluster_addr / api_addr set to the LB IP in the
# HCL config (vault-values.yaml.tpl), so the cert covers all IPs Vault
# will use for cross-cluster communication.
###############################################################################

resource "tls_private_key" "vault" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "vault" {
  private_key_pem = tls_private_key.vault.private_key_pem

  subject {
    common_name  = "vault.${var.vault_namespace}.svc (${var.region_label})"
    organization = "HashiCorp Vault"
  }

  dns_names = concat(
    [
      "vault-0.vault-internal",
      "vault-1.vault-internal",
      "vault-2.vault-internal",
      "*.vault-internal",
      "${var.vault_release_name}.${var.vault_namespace}.svc",
      "${var.vault_release_name}.${var.vault_namespace}.svc.cluster.local",
      "${var.vault_release_name}-internal.${var.vault_namespace}.svc",
      "${var.vault_release_name}-internal.${var.vault_namespace}.svc.cluster.local",
      "localhost",
      "vault",
      "vault-internal",
    ],
    var.additional_dns_sans
  )

  # IP SANs — all known at plan time, no data source lookups needed:
  # - 127.0.0.1        local health checks inside the pod
  # - var.lb_ip        pre-created Azure Public IP for cross-cluster replication
  # - additional_ip_sans  any extras passed in from root
  #
  # The internal ClusterIPs are NOT included here because looking them up
  # via data sources creates a dependency cycle (cert → Helm → cert).
  # Instead, Vault replication is configured to use DNS names (which ARE
  # in the cert SANs) rather than internal IPs, avoiding the issue entirely.
  ip_addresses = compact(concat(
    ["127.0.0.1"],
    [var.lb_ip],
    [var.cluster_lb_ip],
    var.additional_ip_sans
  ))
}

resource "tls_locally_signed_cert" "vault" {
  cert_request_pem   = tls_cert_request.vault.cert_request_pem
  ca_private_key_pem = var.shared_ca_private_key_pem
  ca_cert_pem        = var.shared_ca_cert_pem

  validity_period_hours = 8760 # 1 year
  set_subject_key_id    = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

###############################################################################
# Kubernetes TLS Secret
# Annotated with a checksum of the IP SANs — when ClusterIPs are discovered
# on the second apply the checksum changes, Terraform updates the secret with
# the regenerated cert, and the Helm checksum annotation triggers a pod rollout.
###############################################################################

resource "kubernetes_secret" "vault_tls" {
  metadata {
    name      = "vault-tls"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }

  type = "Opaque"

  data = {
    "tls.crt" = tls_locally_signed_cert.vault.cert_pem
    "tls.key" = tls_private_key.vault.private_key_pem
    "ca.crt"  = var.shared_ca_cert_pem
  }
}
