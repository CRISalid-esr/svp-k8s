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

kubectl get namespace $INST > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating namespace $INST"
    kubectl create namespace $INST
else
    echo "Namespace $INST already exists"
fi