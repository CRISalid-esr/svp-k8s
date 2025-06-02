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
cp inst_env/definitions-example.json inst_env/definitions-myinst.json
# Edit inst_env/definitions-myinst.json with custom crisalid-bus (RabbitMQ) architecture if any
```

**Fully managed database**:
Create your fully managed database instance on Google Cloud SQL (PostgreSQL) and note the connection details.
Name : crisalid-myinst-db
Apply database flag : temp_file_limit 5242880

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

If you want to access to neo4j from the web :

```bash
kubectl patch service neo4j-{myinst} \
  -n myinst \
  -p '{"spec": {"type": "LoadBalancer"}}'
 ```

Then get the external IP:

```bash
kubectl get service neo4j-{myinst} -n myinst
```

### Get a neo4j backup

#### With enterprise edition (live backup enabled)

Deploy the Neo4j backup Helm chart:

```bash
 ./multitenant-deploy-neo4j-backup.sh nu
```

If you want to run a job to backup the Neo4j database, you can use the following command:

```bash
kubectl create job --from=cronjob/neo4j-backup-nu neo4j-backup-test -n myinst
```

#### With community edition (live backup not enabled)

As live backup is not available in the community edition, you need to scale down the Neo4j deployment to 1 replica
to ensure data consistency before taking a backup.

```bash
kubectl scale deployment ikg --replicas=0 -n myinst
```

Then download the data from the Neo4j pod:

```bash
kubectl cp nu/neo4j-nu-0:/data ./neo4j-backup-nu-data
```

Scale back up ikg deployment:

```bash
kubectl scale deployment ikg --replicas=1 -n myinst
```

Create a myinst-neo4j directory and move the neo4j-backup-nu-data directory content into its data subdirectory:

```bash
mkdir -p myinst-neo4j/data
mv neo4j-backup-nu-data/* myinst-neo4j/data/
```

Ensure 7474 will be the owner of the myinst-neo4j directory, with write permissions:

```bash
sudo chown -R 7474:7474 myinst-neo4j
sudo chmod -R 755 myinst-neo4j
```

Check the neo4j version you are deploying through the Helm chart:

```bash
helm list -n myinst
```

Start a new Neo4j pod with the backup data, ensuring the version matches the one you backed up (here 5.26) :

```bash
docker run --publish=7474:7474 --publish=7687:7687 \
          --env=NEO4J_AUTH=none -e NEO4J_apoc_export_file_enabled=true \
          -e NEO4J_server_memory_heap_initial__size=4G -e NEO4J_server_memory_heap_max__size=8G \
          -e NEO4J_server_memory_pagecache_size=6G -e NEO4J_apoc_import_file_enabled=true \
          -e NEO4J_apoc_import_file_use__neo4j__config=true -e NEO4JLABS_PLUGINS=\[\"apoc\"\] \
          -v ./myinst-neo4j/data:/data -v ./myinst-neo4j/logs:/logs -v ./myinst-neo4j/import:/import -v ./myinst-neo4j/backups:/backups -v ./myinst-neo4j/plugins:/plugins   neo4j:5.26-community
```

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

If you are feeding data into SoVisu+ using CSV, upload your peole.csv ad structure.csv files to the Google Cloud Storage
bucket `crisalid-myinst-data` (replace `myinst` with your institution code).
The bucket has been automatically created by the "multitenant-add-inst.sh" script.

Creates a GCP Cloud Composer (managed Airflow) environment for the institution.

```bash
./multitenant-deploy-cdb.sh myinst
```

## Refresh & Apply Kubernetes Configuration

This fetches GitHub commit info and Docker image hash to update the K8s config.

> To update the Docker tags, edit `gke/multitenant-apply-k8s.sh`.

```bash
./multitenant-apply-k8s.sh myinst
```

---

## Allow Airflow to access crisalid-bus (RabbitMQ)

> **Important**: Airflow needs to access the crisalid-bus (RabbitMQ) service, which is part of the GKE cluster.

To expose the necessary ports, apply extras/crisalid-bus-external-access.yaml after editing the namespace :

```bash
kubectl apply -f extras/crisalid-bus-external-access.yaml -n myinst
```

After Airflow has started, it won't be aware of crisalid-bus (RabbitMQ) IP address as it does not belong the the GKE
cluster.
Navigate to the Airflow UI and manually add the connection to crisalid-bus (RabbitMQ) with the following parameters:

- **Connection Id**: `crisalid-bus`
- **Connection Type**: `RabbitMQ`
- **Host**: `12.34.56.78` (replace with your crisalid-bus LoadBalancer IP from the previous step)
- **vhost**: `/`
- **Login**: `your_rabbitmq_login`
- **Password**: `your_rabbitmq_password`
- **Port**: `5672`

---

## Scale Down SVP-Harvester if Running

> Only **one** harvester instance should be running at restart to avoid inconsistencies.

```bash
kubectl scale --replicas=1 deployment svph-api-web -n myinst
kubectl scale --replicas=0 deployment svph-api-worker -n myinst
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

