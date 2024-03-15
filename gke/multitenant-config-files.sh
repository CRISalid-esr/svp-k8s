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

CONFIG_DIR="core/config"

if [ ! -d "$CONFIG_DIR" ]; then
  echo "Error: CONFIG_DIR '$CONFIG_DIR' does not exist."
  exit 1
fi


for file in "$CONFIG_DIR"/*-config.yaml; do

  echo "Copying $file to $INST_DIRECTORY"
  cp "$file" "$INST_DIRECTORY"

  for var in API_HOST; do
    value=$(eval "echo \$$var")
    sed -i -e "s/\${$var}/$value/g" "$INST_DIRECTORY/$(basename "$file")"
  done
done

