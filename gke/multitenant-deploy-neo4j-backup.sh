#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env
get_project_id
get_gsa_email

NEO4J_BACKUP_INSTANCE_NAME="neo4j-backup-$INST"

gsutil ls -p $PROJECT_ID | grep -q gs://$NEO4J_BACKUP_BUCKET_NAME
if [ $? -ne 0 ]; then
  echo "Creating bucket $NEO4J_BACKUP_BUCKET_NAME"
  gsutil mb -p $PROJECT_ID -c regional -l $LOCATION gs://$NEO4J_BACKUP_BUCKET_NAME
  gsutil iam ch serviceAccount:$GSA_EMAIL:objectAdmin gs://$NEO4J_BACKUP_BUCKET_NAME
else
  echo "Bucket $NEO4J_BACKUP_BUCKET_NAME already exists"
fi

kubectl config set-context --current --namespace=$INST

NEO4J_CONFIG_TEMPLATE=$HELM_CONFIG_DIRECTORY/neo4j-backup-values.yaml
NEO4J_INST_VALUES_FILE=$INST_DIRECTORY/neo4j-backup-values.yaml

cp $NEO4J_CONFIG_TEMPLATE $NEO4J_INST_VALUES_FILE
sed -i "s/\${NEO4J_BACKUP_BUCKET_NAME}/$NEO4J_BACKUP_BUCKET_NAME/g" $NEO4J_INST_VALUES_FILE
sed -i "s/\${INST}/$INST/g" $NEO4J_INST_VALUES_FILE

helm upgrade --install $NEO4J_BACKUP_INSTANCE_NAME neo4j/neo4j-admin --namespace $INST -f $NEO4J_INST_VALUES_FILE
