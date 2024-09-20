# Neo4j helm mini-howto

```bash
# Install helm first via asdf or binary download

# Create the neo4j namespace
kubectl create namespace neo4j

# Add the neo4j repository to helm
helm repo add neo4j https://helm.neo4j.com/neo4j

# Create and tune the neo4j-values.yaml file for your project

# Deploy the neo4j chart
helm install neo4j neo4j/neo4j --namespace neo4j -f neo4j-values.yaml

# Check everything is created
watch "kubectl get all,pvc,secrets -n neo4j -o wide"
helm status neo4j --namespace neo4j

# Uninstall neo4j
helm uninstall neo4j -n neo4j --wait

# Delete the neo4j PVC (if needed)
kubectl delete pvc/data-neo4j-0 -n neo4j
```
