#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env

CONFIG_DIR="core/config"

TRAINING_DATA_BUCKET_PATH="gs://$TRAINING_DATA_BUCKET_NAME"

if [ ! -d "$CONFIG_DIR" ]; then
  echo "Error: CONFIG_DIR '$CONFIG_DIR' does not exist."
  exit 1
fi

for file in "$CONFIG_DIR"/*-config.yaml; do

  echo "Copying $file to $INST_DIRECTORY"
  cp "$file" "$INST_DIRECTORY"

  for var in SVPH_WEB_HOST \
  SOVISUPLUS_HOST \
  INSTITUTION_NAME \
  AMQP_HOST \
  AMQP_PORT \
  APP_ENV \
  NEO4J_INSTANCE_NAME \
  NEO4J_PORT \
  TRAINING_DATA_BUCKET_PATH \
  KEYCLOAK_CLIENT_ID \
  KEYCLOAK_ADDR \
  KEYCLOAK_REALM \
  CTD_ES_INSTANCE_NAME \
  CTD_ES_PORT\
  SVP_AMQP_QUEUE_NAME; do
    value=$(eval "echo \$$var")
    echo "Replacing $var with $value in $INST_DIRECTORY/$(basename "$file")"
    sed -i -e "s#\${$var}#$value#g" "$INST_DIRECTORY/$(basename "$file")"
  done
done
