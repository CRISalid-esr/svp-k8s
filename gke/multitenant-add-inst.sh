#!/bin/bash
INST=$1
DB_INSTANCE_NAME=svph-db
LOCATION=europe-west9

# get project id $PROJECT_ID
PROJECT_ID=$(gcloud config get-value project)
if [ -z $PROJECT_ID ]; then
  echo "Could not get project id"
  exit 1
else
  echo "Project id: $PROJECT_ID"
fi

if [ -z $INST ]; then
  echo "Please provide an institution name"
  exit 1
fi

PWD=$(pwd)
INST_DIRECTORY=$PWD/inst/$INST
INST_ENV_FILE=$PWD/inst_env/$INST.env

# check if inst env file exists
if [ ! -f $INST_ENV_FILE ]; then
  echo "Institution environment file not found"
  exit 1
fi
echo "Institution environment file found: $INST_ENV_FILE"
source $INST_ENV_FILE
echo "Institution environment variables loaded"

if [ -d $INST_DIRECTORY ]; then
  read -p "Wipe instance directory $INST_DIRECTORY ? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Wiping instance directory $INST_DIRECTORY"
    rm -rf $INST_DIRECTORY
  else
    echo "Exiting"
    exit 1
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

gcloud iam service-accounts list --filter="name:$INST-svph" --format="value(email)" | grep $INST-svph
if [ $? -ne 0 ]; then
  echo "Creating service account $INST-svph"
  gcloud iam service-accounts create $INST-svph --display-name="$INST-svph service account" \
    --description="Service account used by $INST SVP harvester" \
    --display-name="SVPH Service accounct for $INST"
else
  echo "Service account $INST-svph already exists"
fi
GSA_EMAIL=$(gcloud iam service-accounts list --filter="name:$INST-svph" --format="value(email)")
echo "Service account email: $GSA_EMAIL"

# if k8s service account does not exist, create it
kubectl get serviceaccount svph-ksa -n $INST >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Creating k8s service account svph-ksa"
  kubectl apply -f auth/svph-ksa.yaml -n $INST
  gcloud iam service-accounts add-iam-policy-binding \
    --role roles/iam.workloadIdentityUser \
    --member="serviceAccount:$PROJECT_ID.svc.id.goog[$INST/svph-ksa]" \
    $GSA_EMAIL
  gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$GSA_EMAIL" \
  --role="roles/cloudsql.client"
  gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$GSA_EMAIL" \
  --role="roles/logging.logWriter"
  kubectl annotate serviceaccount \
    svph-ksa \
    iam.gke.io/gcp-service-account=$GSA_EMAIL \
    -n $INST
else
  echo "Service account svph-ksa already exists"
fi

# if crisalid-$INST-bucket does not exist, create it
gsutil ls -p $PROJECT_ID | grep -q gs://crisalid-$INST-bucket
if [ $? -ne 0 ]; then
  echo "Creating bucket crisalid-$INST-bucket"
  gsutil mb -p $PROJECT_ID -c regional -l $LOCATION gs://crisalid-$INST-bucket
else
  echo "Bucket crisalid-$INST-bucket already exists"
fi

# if svph-$INST-db does not exist in $DB_INSTANCE_NAME cloud sql postgres instance, create it
gcloud sql databases list --instance=$DB_INSTANCE_NAME --format="value(name)" | grep -q $DB_NAME
if [ $? -ne 0 ]; then
  echo "Creating database svph-$INST-db in $DB_INSTANCE_NAME cloud sql postgres instance"
  gcloud sql databases create $DB_NAME --instance=$DB_INSTANCE_NAME
else
  echo "Database $DB_NAME already exists in $DB_INSTANCE_NAME cloud sql postgres instance"
fi
# if $DB_USER user does not exist in "$DB_INSTANCE_NAME"" cloud sql postgres instance, create it
# with password from $DB_PASSWORD
gcloud sql users list --instance=$DB_INSTANCE_NAME --format="value(name)" | grep -q $DB_USER
if [ $? -ne 0 ]; then
  echo "Creating user $DB_USER in $DB_INSTANCE_NAME cloud sql postgres instance"
  gcloud sql users create $DB_USER --instance=$DB_INSTANCE_NAME --password=$DB_PASSWORD
else
  echo "User $DB_USER already exists in $DB_INSTANCE_NAME cloud sql postgres instance"
fi

CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)")

# copy deployment files (*-depl.yaml) from core/svph to inst/$INST
# and replace ${CONNECTION_NAME} and ${PROJECT_ID} with $CONNECTION_NAME and $PROJECT_ID
for file in core/svph/*-depl.yaml; do
  echo "Copying $file to $INST_DIRECTORY"
  cp "$file" "$INST_DIRECTORY"
  for var in CONNECTION_NAME LOCATION; do
    value=$(eval "echo \$$var")
    sed -i -e "s/\${$var}/$value/g" "$INST_DIRECTORY/$(basename "$file")"
  done
done
