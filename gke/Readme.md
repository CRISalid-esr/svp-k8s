GKE instructions

# Authenticate with GCP

```bash
gcloud auth login
gcloud projects list
gcloud config set project my-project-12345
gcloud container clusters get-credentials my-cluster --region=europe-west9
```

# Scale down svp-harvester

No more than one svp-harvester instance should be up at restart time, to avoid dabase model/ code discrepancies.

```bash
 kubectl scale --replicas=1 deployment svph-api-web -n my_namespace
 kubectl scale --replicas=0 deployment svph-api-worker -n my_namespace
```

# Refresh and reapply k8s configuration

This step is necessary to fetch Github commit id and Docker image hash and write it to K8s config.

If you need to update SVP-H docker image tag, edit gke/multitenant-apply-k8s.sh.

```bash
./multitenant-apply-k8s.sh my_namespace
```

# Restart svp-harvester

```bash
kubectl rollout restart deployment svph-api-web -n my_namespace
kubectl scale --replicas=1 deployment svph-api-worker -n my_namespace
kubectl rollout restart deployment svph-api-worker -n demo1
```

# Check the status of the pods

```bash
watch kubectl get pods -o wide -n my_namespace
```