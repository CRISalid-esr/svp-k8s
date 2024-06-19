#!/bin/bash
INST=$1

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

  for var in SCANR_ES_HOST SCANR_ES_USER SCANR_ES_PASSWORD AMQP_USER AMQP_PASSWORD DB_NAME DB_USER DB_PASSWORD SCOPUS_INST_TOKEN SCOPUS_API_KEY; do
    value=$(eval "echo \$$var")
    encoded_value=$(base64_encode "$value")
    sed -i -e "s/\${$var}/$encoded_value/g" "$INST_DIRECTORY/$(basename "$file")"
  done
done

