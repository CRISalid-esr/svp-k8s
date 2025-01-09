#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env

SECRETS_DIR="core/secrets"

if [ ! -d "$SECRETS_DIR" ]; then
  echo "Error: SECRETS_DIR '$SECRETS_DIR' does not exist."
  exit 1
fi

base64_encode() {
  echo -n "$1" | base64
}

for file in "$SECRETS_DIR"/*-secret.yaml; do

  echo "Copying $file to $INST_DIRECTORY"
  cp "$file" "$INST_DIRECTORY"

  for var in SCANR_ES_HOST \
    SCANR_ES_USER \
    SCANR_ES_PASSWORD \
    AMQP_USER \
    AMQP_PASSWORD \
    SVPH_DB_NAME \
    SVPH_DB_USER \
    SVPH_DB_PASSWORD \
    SVP_DB_HOST \
    SVP_DB_PORT \
    SVP_DB_NAME \
    SVP_DB_USER \
    SVP_DB_PASSWORD \
    SCOPUS_INST_TOKEN \
    SCOPUS_API_KEY \
    NEO4J_USER \
    NEO4J_PASSWORD\
    CTD_ES_USER \
    CTD_ES_PASSWORD \
    NEXTAUTH_SECRET \
    KEYCLOAK_CLIENT_SECRET\
    SVP_GRAPHQL_API_KEY\
    APOLLO_API_KEYS; do
    value=$(eval "echo \$$var")
    encoded_value=$(base64_encode "$value")
    sed -i -e "s/\${$var}/$encoded_value/g" "$INST_DIRECTORY/$(basename "$file")"
  done
done
