# Check if nodes are running on the primary cluster
kubectl -n vault get pods --context v0326-aks-uksouth

# Initialize the Vault cluster and save the unseal keys and root token to a file
kubectl exec -n vault vault-0 --context v0326-aks-uksouth -- vault operator init \
    -recovery-shares=7 \
    -recovery-threshold=4 \
    -format=json > ./primary-cluster-keys.json 

#Get the Vault UI LoadBalancer address:
echo https://$(kubectl get svc vault-ui -n vault -o json --context v0326-aks-uksouth | jq -r ".status.loadBalancer.ingress[0].ip"):8200

#Get the Cluster LB for cluster address LoadBalancer address:
echo https://$(kubectl get svc vault-cluster -n vault -o json --context v0326-aks-uksouth | jq -r ".status.loadBalancer.ingress[0].ip"):8201


##do the same for the secondary cluster

# Check if nodes are running
kubectl -n vault get pods --context v0326-aks-brazilsouth

# Initialize the Vault cluster and save the unseal keys and root token to a file
kubectl exec -n vault vault-0 --context v0326-aks-brazilsouth -- vault operator init \
    -recovery-shares=7 \
    -recovery-threshold=4 \
    -format=json > ./secondary-cluster-keys.json 

#Get the Vault UI LoadBalancer address:
echo https://$(kubectl get svc vault-ui -n vault -o json --context v0326-aks-brazilsouth | jq -r ".status.loadBalancer.ingress[0].ip"):8200


#### Check CAs
kubectl get secret vault-tls -n vault \
  --context v0326-aks-uksouth \
  -o jsonpath='{.data.ca\.crt}' | base64 -d | openssl x509 -noout -subject -issuer


kubectl get secret vault-tls -n vault \
  --context v0326-aks-brazilsouth \
  -o jsonpath='{.data.ca\.crt}' | base64 -d | openssl x509 -noout -subject -issuer