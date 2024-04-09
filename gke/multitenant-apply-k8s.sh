#!/bin/bash
INST=$1

if [ -z $INST ]; then
  echo "Please provide an institution name"
  exit 1
fi

PWD=$(pwd)
CORE_DIRECTORY=$PWD/core
ACCESS_DIRECTORY=$PWD/access
INST_DIRECTORY=$PWD/inst/$INST
RABBIT_DIRECTORY=$CORE_DIRECTORY/rabbitmq
REDIS_DIRECTORY=$CORE_DIRECTORY/redis
VOC_PROXIES_DIRECTORY=$CORE_DIRECTORY/voc-proxies
CLIENT_MOCK_DIRECTORY=$CORE_DIRECTORY/client-mock

SVPH_DOCKER_IMAGE_TAG="v0.10-dev"
SVPH_DOCKER_IMAGE_NAME="crisalidesr/svp-harvester"
docker pull $SVPH_DOCKER_IMAGE_NAME:$SVPH_DOCKER_IMAGE_TAG
SVPH_DOCKER_IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $SVPH_DOCKER_IMAGE_NAME:$SVPH_DOCKER_IMAGE_TAG)

echo "Docker image name: $SVPH_DOCKER_IMAGE_NAME"
echo "Docker image tag: $SVPH_DOCKER_IMAGE_TAG"
echo "Docker image digest: $SVPH_DOCKER_IMAGE_DIGEST"

if [ -z "$SVPH_DOCKER_IMAGE_DIGEST" ]; then
  echo "Failed to retrieve Docker image digest for $IMAGE_NAME"
  exit 1
fi

export SVPH_DOCKER_IMAGE_NAME
export SVPH_DOCKER_IMAGE_TAG
export SVPH_DOCKER_IMAGE_DIGEST

folders=(
  "$INST_DIRECTORY"
  "$RABBIT_DIRECTORY"
  "$REDIS_DIRECTORY"
  "$VOC_PROXIES_DIRECTORY"
  "$ACCESS_DIRECTORY"
)

for folder in "${folders[@]}"; do
  find "$folder" -name '*.yaml' -o -name '*.yml' | while read file; do
    # Use envsubst to replace the placeholder with the actual digest
    # and pipe it to kubectl apply
    envsubst <"$file" | kubectl apply --namespace="$INST" -f -
  done
done
