#!/bin/bash
INST=$1

if [ -z $INST ]; then
    echo "Please provide an institution name"
    exit 1
fi

PWD=`pwd`

INST_DIRECTORY=$PWD/$INST
INST_ENV_FILE=$PWD/inst_env/$INST.env

# check if inst env file exists
if [ ! -f $INST_ENV_FILE ]; then
    echo "Institution environment file not found"
    exit 1
fi
echo "Institution environment file found: $INST_ENV_FILE"
source $INST_ENV_FILE
echo "Institution environment variables loaded"
echo "$SCANR_ES_HOST"

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

YAML_DIR="svp"

if [ ! -d "$YAML_DIR" ]; then
    echo "Error: YAML_DIR '$YAML_DIR' does not exist."
    exit 1
fi

base64_encode() {
    echo -n "$1" | base64
}

for file in "$YAML_DIR"/*-secret.yaml; do

    echo "Copying $file to $INST_DIRECTORY"
    cp "$file" "$INST_DIRECTORY"

    for var in SCANR_ES_HOST SCANR_ES_USER SCANR_ES_PASSWORD; do
        value=$(eval "echo \$$var")
        encoded_value=$(base64_encode "$value")
        sed -i -e "s/\${$var}/$encoded_value/g" "$INST_DIRECTORY/$(basename "$file")"
    done
done


# create namespace if it does not exist

kubectl get namespace $INST > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating namespace $INST"
    kubectl create namespace $INST
else
    echo "Namespace $INST already exists"
fi