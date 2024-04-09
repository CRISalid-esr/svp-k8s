#!/bin/bash
INST=$1

if [ -z $INST ]; then
  echo "Please provide an institution name"
  exit 1
fi

PWD=$(pwd)
CORE_DIRECTORY=$PWD/core
INST_DIRECTORY=$PWD/inst/$INST
RABBIT_DIRECTORY=$CORE_DIRECTORY/rabbitmq
REDIS_DIRECTORY=$CORE_DIRECTORY/redis
VOC_PROXIES_DIRECTORY=$CORE_DIRECTORY/voc-proxies
CLIENT_MOCK_DIRECTORY=$CORE_DIRECTORY/client-mock

kubectl apply -f -n $INST

folders=(
  "$INST_DIRECTORY"
  "$RABBIT_DIRECTORY"
  "$REDIS_DIRECTORY"
  "$VOC_PROXIES_DIRECTORY"
)

for folder in "${folders[@]}"; do
  kubectl delete -f "$folder" --recursive --namespace=$INST
done
