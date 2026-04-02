vault write sys/replication/performance/primary/enable primary_cluster_addr="https://51.105.30.231:8201"

vault write -format=json sys/replication/performance/primary/secondary-token id="sao-paulo"

# Secondary (São Paulo) — no ca_file needed
vault write sys/replication/performance/secondary/enable token="eyJhbGciOiJFUzUxMiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3NvciI6IiIsImFkZHIiOiJodHRwczovLzEwLjIuMC45ODo4MjAwIiwiZXhwIjoxNzc1MTM5ODQ0LCJpYXQiOjE3NzUxMzgwNDQsImp0aSI6Imh2cy53QXk3dFZCMDA2YU1NekFUV2FVTXdXV24iLCJuYmYiOjE3NzUxMzgwMzksInR5cGUiOiJ3cmFwcGluZyJ9.ATwINx90X-3wsTktoylws9yB74Yj8N4m_aqOMtuPlNjGRPk-dE6uoe0aaqeB5Kpys43fMqxPyp-MxTPRaTOoy2z-ARvOt3SM_ho7nPjHJJBqOBSS4QEfxWMCBMyWTtHAAdmpVmiQ8oJII_d1odf4PQGA8jsvDMetIX-6nLLidJDTiN6d" primary_api_addr="https://51.104.239.58:8200" ca_file=/vault/userconfig/vault-tls/ca.crt


vault write -force sys/replication/performance/primary/disable