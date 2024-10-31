#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env

CONFIG_DIR="core/config"

if [ ! -d "$CONFIG_DIR" ]; then
  echo "Error: CONFIG_DIR '$CONFIG_DIR' does not exist."
  exit 1
fi

for file in "$CONFIG_DIR"/*-config.yaml; do

  echo "Copying $file to $INST_DIRECTORY"
  cp "$file" "$INST_DIRECTORY"

  for var in API_HOST INSTITUTION_NAME AMQP_HOST AMQP_PORT APP_ENV NEO4J_INSTANCE_NAME NEO4J_PORT; do
    value=$(eval "echo \$$var")
    echo "Replacing $var with $value in $INST_DIRECTORY/$(basename "$file")"
    sed -i -e "s#\${$var}#$value#g" "$INST_DIRECTORY/$(basename "$file")"
  done
done
