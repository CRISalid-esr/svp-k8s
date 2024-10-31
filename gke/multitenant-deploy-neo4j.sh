#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env
get_project_id
get_gsa_email

kubectl config set-context --current --namespace=$INST

#copy neo4j values from HELM_CONFIG_DIRECTORY/neo4j-values.yaml to INST_DIRECTORY/neo4j-values.yaml
# replace ${NEO4J_INSTANCE_NAME} and ${NEO4J_PASSWORD} with $NEO4J_INSTANCE_NAME and $NEO4J_PASSWORD
NEO4J_CONFIG_TEMPLATE=$HELM_CONFIG_DIRECTORY/neo4j-values.yaml
NEO4J_INST_VALUES_FILE=$INST_DIRECTORY/neo4j-values.yaml

cp $NEO4J_CONFIG_TEMPLATE $NEO4J_INST_VALUES_FILE
sed -i "s/\${NEO4J_INSTANCE_NAME}/$NEO4J_INSTANCE_NAME/g" $NEO4J_INST_VALUES_FILE
sed -i "s/\${NEO4J_PASSWORD}/$NEO4J_PASSWORD/g" $NEO4J_INST_VALUES_FILE

helm upgrade --install $NEO4J_INSTANCE_NAME neo4j/neo4j --namespace $INST -f $NEO4J_INST_VALUES_FILE
