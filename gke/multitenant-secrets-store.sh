#!/bin/bash
INST=$1

# get project id $PROJECT_ID
PROJECT_ID=$(gcloud config get-value project)
PWD=$(pwd)
INST_DIRECTORY=$PWD/inst/$INST

SERVICE_ACCOUNT_EMAIL=$(gcloud iam service-accounts list --filter="name:$INST-svph" --format="value(email)")
echo "Service account email: $SERVICE_ACCOUNT_EMAIL"

SECRET_VERSION="0.1"

for var in SCANR_ES_HOST SCANR_ES_USER SCANR_ES_PASSWORD; do
  gcloud secrets add-iam-policy-binding $var \
    --member=serviceAccount:$SERVICE_ACCOUNT_EMAIL \
    --role=roles/secretmanager.secretAccessor
done

cp auth/svph-secrets.yaml $INST_DIRECTORY
sed -i -e "s/\${PROJECT_ID}/$PROJECT_ID/g" $INST_DIRECTORY/svph-secrets.yaml
sed -i -e "s/\${SECRET_VERSION}/$SECRET_VERSION/g" $INST_DIRECTORY/svph-secrets.yaml
# apply it
kubectl apply -f $INST_DIRECTORY/svph-secrets.yaml -n $INST