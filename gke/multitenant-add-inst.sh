#!/bin/bash
INST=$1

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
SERVICE_ACCOUNT_EMAIL=$(gcloud iam service-accounts list --filter="name:$INST-svph" --format="value(email)")
echo "Service account email: $SERVICE_ACCOUNT_EMAIL"

# if k8s service account does not exist, create it
kubectl get serviceaccount svph-ksa -n $INST >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Creating k8s service account svph-ksa"
  kubectl apply -f auth/svph-ksa.yaml -n $INST
  gcloud iam service-accounts add-iam-policy-binding \
    --role roles/iam.workloadIdentityUser \
    --member="serviceAccount:$PROJECT_ID.svc.id.goog[$INST/svph-ksa]" \
    $SERVICE_ACCOUNT_EMAIL
else
  echo "Service account svph-ksa already exists"
fi

