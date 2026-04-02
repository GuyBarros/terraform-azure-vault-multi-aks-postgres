###############################################################################
# modules/pgbouncer/main.tf
#
# Deploys pgBouncer as a Kubernetes Deployment + Service via the Bitnami Helm
# chart. pgBouncer sits between Vault/app pods and PostgreSQL, pooling
# connections so the ~500 max_connections limit isn't exhausted by Vault's
# dynamic credential holders.
#
# Connection flow:
#   Vault pods → pgBouncer:5432 (ClusterIP) → PostgreSQL private DNS :5432
#
# The PostgreSQL password is stored in a Kubernetes Secret and referenced by
# the Helm chart — never passed as a plain Helm value.
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

resource "kubernetes_namespace" "pgbouncer" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = "pgbouncer"
    }
  }
}

###############################################################################
# Secret — PostgreSQL admin credentials for pgBouncer userlist
###############################################################################

resource "kubernetes_secret" "pgbouncer_auth" {
  metadata {
    name      = "pgbouncer-auth"
    namespace = kubernetes_namespace.pgbouncer.metadata[0].name
  }

  type = "Opaque"

  data = {
    # pgBouncer userlist.txt format: "username" "password"
    "userlist.txt"         = "\"${var.postgres_username}\" \"${var.postgres_password}\""
    "postgresql-password"  = var.postgres_password
  }
}

###############################################################################
# Helm Release — pgBouncer (Bitnami chart)
###############################################################################

resource "helm_release" "pgbouncer" {
  name       = "pgbouncer"
  namespace  = kubernetes_namespace.pgbouncer.metadata[0].name
  repository = "https://icoretech.github.io/helm"
  chart      = "pgbouncer"
  version    = var.pgbouncer_chart_version

  values = [
    yamlencode({
      replicaCount = var.replica_count

      # PostgreSQL backend connection
      config = {
        adminPassword = var.postgres_password
        databases = {
          "${var.postgres_database}" = {
            host     = var.postgres_host
            port     = 5432
            dbname   = var.postgres_database
            # Embed credentials so pgBouncer can authenticate to PostgreSQL
            # using its own connection — required because pgBouncer in
            # transaction mode cannot proxy scram-sha-256 exchanges
            user     = var.postgres_username
            password = var.postgres_password
          }
        }
        pgbouncer = {
          pool_mode                 = var.pool_mode
          max_client_conn           = var.max_client_conn
          default_pool_size         = var.default_pool_size
          min_pool_size             = var.min_pool_size
          reserve_pool_size         = var.reserve_pool_size
          # md5 for client→pgBouncer auth — scram-sha-256 cannot be proxied
          # in transaction mode (the exchange is stateful, transaction mode
          # is not). pgBouncer authenticates to PostgreSQL independently
          # using the credentials embedded in the databases block above.
          auth_type                 = "md5"
          server_tls_sslmode        = "require"
          ignore_startup_parameters = "extra_float_digits"
          auth_file                 = "/etc/pgbouncer/userlist.txt"
          listen_port               = 5432
          listen_addr               = "*"
          server_login_retry        = 3
        }
        userlist = {
          "${var.postgres_username}" = var.postgres_password
        }
      }

      # Mount the auth secret as a file
      existingSecretName = kubernetes_secret.pgbouncer_auth.metadata[0].name

      service = {
        type = "ClusterIP"
        port = 5432
      }

      resources = {
        requests = { memory = "64Mi",  cpu = "50m"  }
        limits   = { memory = "128Mi", cpu = "200m" }
      }
    })
  ]

  depends_on = [kubernetes_namespace.pgbouncer, kubernetes_secret.pgbouncer_auth]
}
