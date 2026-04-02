#!/usr/bin/env bash
# =============================================================================
# vault_setup.sh
# Configures HashiCorp Vault with:
#   - Userpass auth method
#   - Admin policy
#   - Three users bound to the admin policy (default password: Welcome123)
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — adjust as needed
# ---------------------------------------------------------------------------
#VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
#VAULT_TOKEN="${VAULT_TOKEN:-}"          # Root / bootstrap token
DEFAULT_PASSWORD="Welcome123"

POLICY_NAME="admin"

USERS=(
  "fabiano"
  "guy"
  "phil"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
die()     { echo "[ERROR] $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "'$1' is required but not found in PATH."
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
require_cmd vault
require_cmd curl

export VAULT_ADDR

[[ -z "${VAULT_TOKEN}" ]] && die "VAULT_TOKEN is not set. Export a root or privileged token before running this script."
export VAULT_TOKEN

info "Checking Vault connectivity at ${VAULT_ADDR} ..."
vault status -format=json > /dev/null 2>&1 || die "Cannot reach Vault at ${VAULT_ADDR}. Is it running and unsealed?"
success "Vault is reachable and unsealed."

# ---------------------------------------------------------------------------
# 1. Enable Userpass auth method (idempotent)
# ---------------------------------------------------------------------------
info "Enabling userpass auth method ..."

if vault auth list -format=json 2>/dev/null | grep -q '"userpass/"'; then
  warn "Userpass auth method is already enabled — skipping."
else
  vault auth enable userpass
  success "Userpass auth method enabled."
fi

# ---------------------------------------------------------------------------
# 2. Create the admin policy
# ---------------------------------------------------------------------------
info "Writing '${POLICY_NAME}' policy ..."

vault policy write "${POLICY_NAME}" - <<'POLICY'
# ===========================================================================
# Admin Policy
# Grants broad administrative access across the Vault cluster.
# Restrict further in production environments.
# ===========================================================================
# Super Admin
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Transform secret engine
path "org/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Full access to all secrets engines
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Auth method management
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

path "sys/auth" {
  capabilities = ["read"]
}

# Policy management
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policy/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policy" {
  capabilities = ["read", "list"]
}

# Mount management
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/mounts" {
  capabilities = ["read"]
}

# Audit log management
path "sys/audit*" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

# Health, leader, and status
path "sys/health" {
  capabilities = ["read", "sudo"]
}

path "sys/leader" {
  capabilities = ["read"]
}

path "sys/capabilities*" {
  capabilities = ["create", "read", "update"]
}

# Token management
path "auth/token/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
POLICY

success "Policy '${POLICY_NAME}' written successfully."

# ---------------------------------------------------------------------------
# 3. Create users
# ---------------------------------------------------------------------------
info "Creating ${#USERS[@]} user(s) with policy '${POLICY_NAME}' ..."

for username in "${USERS[@]}"; do
  info "  → Creating user: ${username}"

  vault write "auth/userpass/users/${username}" \
    password="${DEFAULT_PASSWORD}"              \
    policies="${POLICY_NAME}"

  success "  User '${username}' created (policy: ${POLICY_NAME})."
done

# ---------------------------------------------------------------------------
# 4. Smoke-test — verify each user can log in
# ---------------------------------------------------------------------------
info "Smoke-testing login for each user ..."

for username in "${USERS[@]}"; do
  token=$(vault write -field=token "auth/userpass/login/${username}" \
    password="${DEFAULT_PASSWORD}" 2>/dev/null) || \
    die "Login failed for user '${username}'. Check Vault logs."

  [[ -n "${token}" ]] && success "  Login OK for '${username}' (token: ${token:0:8}…)"
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
cat <<SUMMARY

=============================================================
  Vault Userpass Configuration — Complete
=============================================================
  Vault Address : ${VAULT_ADDR}
  Auth Method   : userpass  (path: auth/userpass/)
  Policy        : ${POLICY_NAME}
  Default Passwd: ${DEFAULT_PASSWORD}

  Users created:
$(for u in "${USERS[@]}"; do echo "    • ${u}"; done)

  IMPORTANT: Rotate the default passwords immediately in
  production environments!
    vault write auth/userpass/users/<username> password=<new>
=============================================================

SUMMARY