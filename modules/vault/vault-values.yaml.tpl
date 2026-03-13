# vault-values.yaml.tpl
# HashiCorp Vault ENTERPRISE — HA Raft + Azure Key Vault Auto-Unseal
# + Performance Replication + Audit Logging

global:
  enabled: true
  tlsDisable: false
  imagePullSecrets:
    - name: "${image_pull_secret_name}"

injector:
  enabled: true
  replicas: 2
  image:
    repository: "hashicorp/vault-k8s"
    tag: "1.4.0"
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app.kubernetes.io/name: vault-agent-injector
          topologyKey: kubernetes.io/hostname

server:
  # -------------------------------------------------------------------------
  # Enterprise Image
  # -------------------------------------------------------------------------
  image:
    repository: "hashicorp/vault-enterprise"
    tag: "${vault_version}"
    pullPolicy: IfNotPresent

  # -------------------------------------------------------------------------
  # Enterprise License
  # -------------------------------------------------------------------------
  enterpriseLicense:
    secretName: "${license_secret_name}"
    secretKey: "license"

  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"

  readinessProbe:
    enabled: true
    path: "/v1/sys/health?standbyok=true&perfstandbyok=true"

  livenessProbe:
    enabled: true
    path: "/v1/sys/health?standbyok=true&perfstandbyok=true"
    initialDelaySeconds: 60

  tolerations:
    - key: "workload"
      operator: "Equal"
      value: "vault"
      effect: "NoSchedule"

  nodeSelector:
    workload: vault

  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app.kubernetes.io/name: vault
              component: server
          topologyKey: kubernetes.io/hostname

  extraLabels:
    region: "${region_label}"
    vault-edition: "enterprise"

  extraEnvironmentVars:
    VAULT_CACERT: /vault/userconfig/vault-tls/ca.crt
    VAULT_TLSCERT: /vault/userconfig/vault-tls/tls.crt
    VAULT_TLSKEY: /vault/userconfig/vault-tls/tls.key

  # -------------------------------------------------------------------------
  # HA + Raft + Azure Key Vault Auto-Unseal + Replication
  # -------------------------------------------------------------------------
  ha:
    enabled: true
    replicas: ${replica_count}
    raft:
      enabled: true
      setNodeId: true
      config: |
        ui = true

        listener "tcp" {
          address         = "[::]:8200"
          cluster_address = "[::]:8201"
          tls_cert_file   = "/vault/userconfig/vault-tls/tls.crt"
          tls_key_file    = "/vault/userconfig/vault-tls/tls.key"
          tls_client_ca_file = "/vault/userconfig/vault-tls/ca.crt"
          telemetry {
            unauthenticated_metrics_access = "true"
          }
        }

        storage "raft" {
          path    = "/vault/data"

          retry_join {
            leader_api_addr         = "https://vault-0.vault-internal:8200"
            leader_ca_cert_file     = "/vault/userconfig/vault-tls/ca.crt"
            leader_client_cert_file = "/vault/userconfig/vault-tls/tls.crt"
            leader_client_key_file  = "/vault/userconfig/vault-tls/tls.key"
          }
          retry_join {
            leader_api_addr         = "https://vault-1.vault-internal:8200"
            leader_ca_cert_file     = "/vault/userconfig/vault-tls/ca.crt"
            leader_client_cert_file = "/vault/userconfig/vault-tls/tls.crt"
            leader_client_key_file  = "/vault/userconfig/vault-tls/tls.key"
          }
          retry_join {
            leader_api_addr         = "https://vault-2.vault-internal:8200"
            leader_ca_cert_file     = "/vault/userconfig/vault-tls/ca.crt"
            leader_client_cert_file = "/vault/userconfig/vault-tls/tls.crt"
            leader_client_key_file  = "/vault/userconfig/vault-tls/tls.key"
          }

          autopilot {
            cleanup_dead_servers               = "true"
            last_contact_threshold             = "200ms"
            last_contact_failure_threshold     = "10m"
            max_trailing_logs                  = 250000
            min_quorum                         = 3
            server_stabilization_time          = "10s"
          }
        }

        # -----------------------------------------------------------------------
        # Azure Key Vault Auto-Unseal
        # -----------------------------------------------------------------------
        seal "azurekeyvault" {
          tenant_id  = "${akv_tenant_id}"
          vault_name = "${akv_vault_name}"
          key_name   = "${akv_key_name}"
        }

        # -----------------------------------------------------------------------
        # Telemetry (Prometheus)
        # -----------------------------------------------------------------------
        telemetry {
          prometheus_retention_time = "30s"
          disable_hostname          = true
        }

        service_registration "kubernetes" {}

        # -----------------------------------------------------------------------
        # Vault Enterprise — Performance Replication
        # (Activate via CLI post-init; config enables the feature set)
        # -----------------------------------------------------------------------
        %{ if replication_enabled ~}
        replication {
          resolver_discover_servers = true
        }
        %{ endif ~}

  auditStorage:
    enabled: true
    size: 10Gi
    storageClass: managed-premium
    accessMode: ReadWriteOnce

  dataStorage:
    enabled: true
    size: 50Gi
    storageClass: managed-premium
    accessMode: ReadWriteOnce

  serviceAccount:
    create: true
    annotations: {}

  serviceMonitor:
    enabled: true
    interval: "30s"
    scrapeTimeout: "10s"

ui:
  enabled: true
  serviceType: "LoadBalancer"
  serviceNodePort: null
  externalPort: 8200
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "false"
