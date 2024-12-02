#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
get_project_id
load_inst_env

if [ -d $INST_DIRECTORY ]; then
  read -p "Wipe instance directory $INST_DIRECTORY ? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Wiping instance directory $INST_DIRECTORY"
    rm -rf $INST_DIRECTORY
  else
    echo "Instance directory $INST_DIRECTORY already exists and will not be wiped."
  fi
fi

echo "Creating directory $INST_DIRECTORY for instance $INST"

mkdir -p $INST_DIRECTORY

kubectl get namespace $INST >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Creating namespace $INST"
  kubectl create namespace $INST
else
  echo "Namespace $INST already exists"
fi

gcloud iam service-accounts list --filter="name:$INST_SERVICE_ACCOUNT" --format="value(email)" | grep $INST_SERVICE_ACCOUNT
if [ $? -ne 0 ]; then
  echo "Creating service account $INST_SERVICE_ACCOUNT"
  gcloud iam service-accounts create $INST_SERVICE_ACCOUNT --display-name="$INST_SERVICE_ACCOUNT service account" \
    --description="Service account used by $INST apps" \
    --display-name="SVPH Service account for $INST"
else
  echo "Service account $INST_SERVICE_ACCOUNT already exists"
fi

get_gsa_email

kubectl get serviceaccount $K8S_SERVICE_ACCOUNT -n $INST >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Creating k8s service account $K8S_SERVICE_ACCOUNT"
  kubectl apply -f auth/$K8S_SERVICE_ACCOUNT.yaml -n $INST
  gcloud iam service-accounts add-iam-policy-binding \
    --role roles/iam.workloadIdentityUser \
    --member="serviceAccount:$PROJECT_ID.svc.id.goog[$INST/$K8S_SERVICE_ACCOUNT]" \
    $GSA_EMAIL

  kubectl annotate serviceaccount \
    $K8S_SERVICE_ACCOUNT \
    iam.gke.io/gcp-service-account=$GSA_EMAIL \
    -n $INST
else
  echo "Service account $K8S_SERVICE_ACCOUNT already exists with email $GSA_EMAIL"
fi

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$GSA_EMAIL" \
  --role="roles/cloudsql.client" \
  --role="roles/logging.logWriter" \
  --role="roles/composer.admin" \
  --role="roles/composer.worker" \
  --role="roles/container.admin" \
  --role="roles/container.clusterAdmin" \
  --role="roles/container.nodeAdmin" \
  --role="roles/cloudsql.admin" \
  --role="roles/compute.admin" \
  --role="roles/compute.networkAdmin" \
  --role="roles/storage.admin" \
  --role="roles/iam.serviceAccountAdmin" \
  --role="roles/iam.serviceAccountUser" \
  --role="roles/monitoring.viewer" \
  --role="roles/monitoring.metricWriter" \
  --role="roles/redis.viewer" \
  --role="roles/redis.editor"

gsutil ls -p $PROJECT_ID | grep -q gs://$DATA_BUCKET_NAME
if [ $? -ne 0 ]; then
  echo "Creating bucket $DATA_BUCKET_NAME"
  gsutil mb -p $PROJECT_ID -c regional -l $LOCATION gs://$DATA_BUCKET_NAME
  # allow svph service account to read data from the bucket
  gsutil iam ch serviceAccount:$GSA_EMAIL:objectViewer gs://$DATA_BUCKET_NAME
else
  echo "Bucket $DATA_BUCKET_NAME already exists"
fi

# If ENABLE_TRAINING_DATA_PIPELINE is set to true, create bucket for training data
if [ "$ENABLE_TRAINING_DATA_PIPELINE" = "1" ]; then
  gsutil ls -p $PROJECT_ID | grep -q gs://$TRAINING_DATA_BUCKET_NAME
  if [ $? -ne 0 ]; then
    echo "Creating bucket $TRAINING_DATA_BUCKET_NAME"
    gsutil mb -p $PROJECT_ID -c regional -l $LOCATION gs://$TRAINING_DATA_BUCKET_NAME
    # allow svph service account to read data from the bucket
    gsutil iam ch serviceAccount:$GSA_EMAIL:objectCreator gs://$TRAINING_DATA_BUCKET_NAME
  else
    echo "Bucket $TRAINING_DATA_BUCKET_NAME already exists"
  fi
  else
    echo "Training data pipeline is disabled"
fi

# if SVPH_DB_NAME does not exist in $DB_INSTANCE_NAME cloud sql postgres instance, create it
gcloud sql databases list --instance=$DB_INSTANCE_NAME --format="value(name)" | grep -q $SVPH_DB_NAME
if [ $? -ne 0 ]; then
  echo "Creating database $SVPH_DB_NAME in $DB_INSTANCE_NAME cloud sql postgres instance"
  gcloud sql databases create $SVPH_DB_NAME --instance=$DB_INSTANCE_NAME
else
  echo "Database $SVPH_DB_NAME already exists in $DB_INSTANCE_NAME cloud sql postgres instance"
fi
# if $SVPH_DB_USER user does not exist in "$DB_INSTANCE_NAME"" cloud sql postgres instance, create it
gcloud sql users list --instance=$DB_INSTANCE_NAME --format="value(name)" | grep -q $SVPH_DB_USER
if [ $? -ne 0 ]; then
  echo "Creating user $SVPH_DB_USER in $DB_INSTANCE_NAME cloud sql postgres instance"
  gcloud sql users create $SVPH_DB_USER --instance=$DB_INSTANCE_NAME --password=$SVPH_DB_PASSWORD
else
  echo "User $SVPH_DB_USER already exists in $DB_INSTANCE_NAME cloud sql postgres instance"
fi

# if SVP_DB_NAME does not exist in $DB_INSTANCE_NAME cloud sql postgres instance, create it
gcloud sql databases list --instance=$DB_INSTANCE_NAME --format="value(name)" | grep -q $SVP_DB_NAME
if [ $? -ne 0 ]; then
  echo "Creating database $SVP_DB_NAME in $DB_INSTANCE_NAME cloud sql postgres instance"
  gcloud sql databases create $SVP_DB_NAME --instance=$DB_INSTANCE_NAME
else
  echo "Database $SVP_DB_NAME already exists in $DB_INSTANCE_NAME cloud sql postgres instance"
fi
# if $SVP_DB_USER user does not exist in "$DB_INSTANCE_NAME"" cloud sql postgres instance, create it
gcloud sql users list --instance=$DB_INSTANCE_NAME --format="value(name)" | grep -q $SVP_DB_USER
if [ $? -ne 0 ]; then
  echo "Creating user $SVP_DB_USER in $DB_INSTANCE_NAME cloud sql postgres instance"
  gcloud sql users create $SVP_DB_USER --instance=$DB_INSTANCE_NAME --password=$SVP_DB_PASSWORD
else
  echo "User $SVP_DB_USER already exists in $DB_INSTANCE_NAME cloud sql postgres instance"
fi

CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)")

# copy deployment files (*-depl.yaml) from core/svph and core/sovisuplus to inst/$INST
# and replace ${CONNECTION_NAME} with $CONNECTION_NAME for cloud-sql-proxy container
for file in core/svph/*-depl.yaml core/sovisuplus/*-depl.yaml; do
  echo "Copying $file to $INST_DIRECTORY"
  cp "$file" "$INST_DIRECTORY"
  for var in CONNECTION_NAME; do
    value=$(eval "echo \$$var")
    sed -i -e "s/\${$var}/$value/g" "$INST_DIRECTORY/$(basename "$file")"
  done
done

# copy deployment files (*-depl.yaml) from core/ikg to inst/$INST
# and replace ${NEO4J_INSTANCE_NAME} with $NEO4J_INSTANCE_NAME and ${NEO4J_PORT} with $NEO4J_PORT
for file in core/ikg/*-depl.yaml; do
  echo "Copying $file to $INST_DIRECTORY"
  cp "$file" "$INST_DIRECTORY"
  for var in NEO4J_INSTANCE_NAME NEO4J_PORT; do
    value=$(eval "echo \$$var")
    sed -i -e "s/\${$var}/$value/g" "$INST_DIRECTORY/$(basename "$file")"
  done
done

