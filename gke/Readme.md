# ☁️ SoVisu+ Deployment on Google Kubernetes Engine (GKE)

This guide provides step-by-step instructions to deploy an institution on GKE using Kubernetes namespaces.

---

## Authenticate with Google Cloud

```bash
gcloud auth login
gcloud projects list
gcloud config set project my-project-12345
gcloud container clusters get-credentials my-cluster --region=europe-west9
```

---

## Add a New Institution (Namespace)

Each institution is identified by a unique code, used across:
- Kubernetes namespaces
- Database names
- Configuration files
- Repository prefixes

> Example: use `myinst` as your institution code.

**Preparation**:
```bash
cp inst_env/example.env inst_env/myinst.env
# Edit inst_env/myinst.env with institution-specific values
```

**Create the institution**:
```bash
./multitenant-add-inst.sh myinst
```

---

## Deploy Neo4j

If this is your first Neo4j deployment, add the Helm chart repo:

```bash
helm repo add neo4j https://neo4j.github.io/helm
helm repo update
```

Deploy Neo4j for the institution:
```bash
./multitenant-deploy-neo4j.sh myinst
```

---

## Generate Secret Files

Used to store credentials and sensitive data (e.g., passwords, API keys).

```bash
./multitenant-secrets-files.sh myinst
```

Idempotent – safe to run multiple times.

---

## Generate Config Files

Creates Kubernetes config maps and other files from the `.env` values.

```bash
./multitenant-config-files.sh myinst
```

Also idempotent.

---

## Deploy Cloud Composer (Airflow)

Creates a GCP Cloud Composer (managed Airflow) environment for the institution.

```bash
./multitenant-deploy-cdb.sh myinst
```

---

## Scale Down SVP-Harvester if Running

> Only **one** harvester instance should be running at restart to avoid inconsistencies.

```bash
kubectl scale --replicas=1 deployment svph-api-web -n myinst
kubectl scale --replicas=0 deployment svph-api-worker -n myinst
```

---

## Refresh & Apply Kubernetes Configuration

This fetches GitHub commit info and Docker image hash to update the K8s config.

> To update the Docker tags, edit `gke/multitenant-apply-k8s.sh`.

```bash
./multitenant-apply-k8s.sh myinst
```

---

## Restart SVP-Harvester

```bash
kubectl rollout restart deployment svph-api-web -n myinst
kubectl scale --replicas=1 deployment svph-api-worker -n myinst
kubectl rollout restart deployment svph-api-worker -n myinst
```

---

## Monitor Pod Status

```bash
watch kubectl get pods -o wide -n myinst
```

---

🎉 Your institution is now up and running on GKE!

