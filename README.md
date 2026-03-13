# HashiCorp Global Infrastructure — Terraform
#### this code was generated with the help of AI

Multi-region Azure deployment: **AKS + HashiCorp Vault + PostgreSQL Flexible Server**

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Azure Global                         │
│                                                         │
│  ┌──────────────────────┐  ┌──────────────────────┐    │
│  │   Brazil South       │  │   UK South           │    │
│  │   (São Paulo)        │  │   (London)           │    │
│  │                      │  │                      │    │
│  │  ┌────────────────┐  │  │  ┌────────────────┐  │    │
│  │  │  AKS Cluster   │  │  │  │  AKS Cluster   │  │    │
│  │  │  3x D4s_v5     │  │  │  │  3x D4s_v5     │  │    │
│  │  │                │  │  │  │                │  │    │
│  │  │  ┌──────────┐  │  │  │  │  ┌──────────┐  │  │    │
│  │  │  │  Vault   │  │  │  │  │  │  Vault   │  │  │    │
│  │  │  │  3 HA    │  │  │  │  │  │  3 HA    │  │  │    │
│  │  │  │  Replicas│  │  │  │  │  │  Replicas│  │  │    │
│  │  │  └──────────┘  │  │  │  │  └──────────┘  │  │    │
│  │  └────────────────┘  │  │  └────────────────┘  │    │
│  └──────────────────────┘  └──────────────────────┘    │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │         PostgreSQL Flexible Server (Global)       │  │
│  │  Primary: uksouth  ←→  Replica: brazilsouth      │  │
│  │  Zone-Redundant HA │ Geo-redundant backups        │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Module Structure

```
.
├── main.tf                        # Root module — wires everything together
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example       # Copy → terraform.tfvars
└── modules/
    ├── aks/                       # AKS cluster + dedicated Vault node pool
    ├── vault/                     # Vault Helm release (HA Raft)
    ├── postgresql/                # PostgreSQL Flexible Server + replica
    └── log_analytics/             # Log Analytics workspace
```

## Prerequisites

- Terraform >= 1.5.0
- Azure CLI authenticated (`az login`)
- Helm >= 3.x (for local operations)
- Sufficient Azure quota in both regions

## Quick Start

```bash
# 1. Authenticate
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

# 2. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Init & plan
terraform init
terraform plan -out=tfplan

# 4. Apply
terraform apply tfplan
```

## Post-Deploy: Initialize Vault Enterprise

After apply, initialize each Vault cluster:

```bash
# São Paulo
az aks get-credentials --resource-group hashi-global-rg-brazilsouth --name hashi-global-aks-brazilsouth
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=1 -key-threshold=1 \   # Auto-Unseal = only 1 recovery key needed
  -format=json > vault-init-sao-paulo.json   # Store securely in a secrets manager!

# London — same process
az aks get-credentials --resource-group hashi-global-rg-uksouth --name hashi-global-aks-uksouth
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=1 -key-threshold=1 \
  -format=json > vault-init-london.json
```

> **Auto-Unseal is handled by Azure Key Vault** — pods unseal automatically on restart. No manual `vault operator unseal` needed.

## Post-Deploy: Enable Performance Replication

Performance Replication makes London the **primary** and São Paulo the **secondary**.

```bash
# 1. On London (Primary) — enable replication and create a token
VAULT_TOKEN=<london_root_token>
VAULT_ADDR=https://<london-vault-lb-ip>:8200

vault login $VAULT_TOKEN
vault write -f sys/replication/performance/primary/enable
vault write sys/replication/performance/primary/secondary-token \
  id="sao-paulo-secondary" \
  ttl="30m"
# Copy the token from the output

# 2. On São Paulo (Secondary) — activate with the token
VAULT_ADDR=https://<sao-paulo-vault-lb-ip>:8200
vault login <sao_paulo_root_token>
vault write sys/replication/performance/secondary/enable \
  token="<replication_token_from_step_1>"
```

## Connecting to PostgreSQL from Vault

```bash
vault secrets enable database

vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="*" \
  connection_url="postgresql://{{username}}:{{password}}@<PRIMARY_FQDN>:5432/vault?sslmode=require" \
  username="pgadmin" \
  password="<PASSWORD>"
```

Applications in São Paulo should point to the **replica FQDN** for read queries.

## Key Design Decisions

| Decision | Rationale |
|---|---|
| `hashicorp/vault-enterprise` image | Enterprise feature set: replication, namespaces, HSM |
| Azure Key Vault Auto-Unseal (RSA-HSM) | Zero-touch unseal; no manual key distribution |
| Performance Replication (not DR) | São Paulo actively serves reads; London is primary |
| Raft Autopilot enabled | Automatic dead-server cleanup and quorum management |
| Dedicated tainted `vault` node pool | Isolates Vault from noisy-neighbour workloads |
| Zone-Redundant HA on PostgreSQL primary | 99.99% SLA within London region |
| TLS enabled end-to-end | `tls_disable = 0` on all listeners; probes updated accordingly |
| `perfstandbyok=true` in health probes | Performance standbys correctly reported as healthy |
