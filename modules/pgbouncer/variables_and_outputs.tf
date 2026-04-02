###############################################################################
# modules/pgbouncer/variables.tf
###############################################################################

variable "namespace" {
  description = "Kubernetes namespace to deploy pgBouncer into"
  type        = string
  default     = "pgbouncer"
}

variable "postgres_host" {
  description = "PostgreSQL hostname — use the split-horizon DNS name so each region hits its local server"
  type        = string
}

variable "postgres_database" {
  description = "PostgreSQL database name pgBouncer proxies"
  type        = string
  default     = "vault"
}

variable "postgres_username" {
  description = "PostgreSQL admin username for pgBouncer userlist"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL admin password for pgBouncer userlist"
  type        = string
  sensitive   = true
}

variable "pgbouncer_chart_version" {
  description = "icoretech pgBouncer Helm chart version"
  type        = string
  default     = "4.1.5"
}

variable "pool_mode" {
  description = <<-EOT
    pgBouncer pool mode:
      transaction — recommended for Vault dynamic credentials (short-lived, high churn)
      session     — one server connection per client session
      statement   — one server connection per statement
  EOT
  type        = string
  default     = "transaction"
}

variable "max_client_conn" {
  description = "Maximum number of client connections pgBouncer will accept"
  type        = number
  default     = 1000
}

variable "default_pool_size" {
  description = "How many server connections to allow per user/database pair"
  type        = number
  default     = 20
}

variable "min_pool_size" {
  description = "Minimum server connections kept open per pool"
  type        = number
  default     = 5
}

variable "reserve_pool_size" {
  description = "Extra connections available when pool is exhausted"
  type        = number
  default     = 5
}

variable "replica_count" {
  description = "Number of pgBouncer pod replicas"
  type        = number
  default     = 2
}

###############################################################################
# modules/pgbouncer/outputs.tf
###############################################################################

output "service_name" {
  description = "Kubernetes Service name — use as hostname in Vault's database connection string"
  value       = "pgbouncer.${var.namespace}.svc.cluster.local"
}

output "service_port" {
  description = "Port pgBouncer listens on"
  value       = 5432
}

output "connection_string_host" {
  description = "Host to use in Vault database/config/postgres connection_url"
  value       = "pgbouncer.${var.namespace}.svc.cluster.local"
}
