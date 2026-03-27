
postgres.v0326.internal

kubectl run nettest --image=busybox:1.28 --restart=Never -- sleep 3600
kubectl exec nettest -- nc -zv -w 5 postgres.v0326.internal 5432


kubectl run dnsutils --image=busybox:1.28 --restart=Never -- sleep 3600
kubectl exec dnsutils -- nslookup postgres.v0326.internal
kubectl delete pod dnsutils


kubectl exec dnsutils -- nslookup v0326-psql-primary.postgres.database.azure.com
kubectl exec dnsutils -- nslookup c03948c4d5e5.v0326.private.postgres.database.azure.com
kubectl exec dnsutils -- nslookup e0f87acb3a42.v0326.private.postgres.database.azure.com

c03948c4d5e5
e0f87acb3a42

kubectl exec dnsutils -- nslookup postgres.postgres.v0326.internal

