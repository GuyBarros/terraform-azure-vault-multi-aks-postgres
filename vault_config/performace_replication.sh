vault write sys/replication/performance/primary/enable \
  primary_cluster_addr="https://20.50.127.21:8201"

vault write -format=json sys/replication/performance/primary/secondary-token id="sao-paulo"

# Secondary (São Paulo) — no ca_file needed
vault write sys/replication/performance/secondary/enable token="eyJhbGciOiJFUzUxMiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3NvciI6IiIsImFkZHIiOiJodHRwczovLzEwLjIuMC4xNTM6ODIwMCIsImV4cCI6MTc3NDYzNTc1OCwiaWF0IjoxNzc0NjMzOTU4LCJqdGkiOiJodnMuMTdhUGxoT2t4YmZFdkdTTGVEajRSUzhIIiwibmJmIjoxNzc0NjMzOTUzLCJ0eXBlIjoid3JhcHBpbmcifQ.ANnJRwFLzexU_FwZsfkLBGFpuqaC4yarrLnfCAGQmM11Bo0tDUoDkOjuNdAiW2LPowHwGLiUru_23pXWl45nr83cANsgQQKSUUClLyrrD-mbz04B3aKm-JolV_K27SiNJOrWl-GWBhyjZCb-7rkqcv1_RhlckI0XostnUA54FsBY8Jhm" primary_api_addr="https://20.50.118.1:8200" ca_file=/vault/userconfig/vault-tls/ca.crt


vault write sys/replication/performance/primary/disable