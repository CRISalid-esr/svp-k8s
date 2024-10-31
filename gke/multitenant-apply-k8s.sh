#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env

SVPH_DOCKER_IMAGE_TAG="v0.16-dev"
SVPH_DOCKER_IMAGE_NAME="crisalidesr/svp-harvester"
IKG_DOCKER_IMAGE_TAG="v0.2-dev"
IKG_DOCKER_IMAGE_NAME="crisalidesr/crisalid-ikg"

REGISTRY="index.docker.io"
SVPH_REPOSITORY_NAME="crisalidesr/svp-harvester"
IKG_REPOSITORY_NAME="crisalidesr/crisalid-ikg"

SVPH_TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$SVPH_REPOSITORY_NAME:pull" | jq -r .token)
IKG_TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$IKG_REPOSITORY_NAME:pull" | jq -r .token)

# Get the image digest using Docker Registry HTTP API v2
SVPH_MANIFESTS=$(curl -s -H "Authorization: Bearer $SVPH_TOKEN" "https://${REGISTRY}/v2/$SVPH_REPOSITORY_NAME/manifests/$SVPH_DOCKER_IMAGE_TAG")
SVPH_DOCKER_IMAGE_DIGEST=$(curl -sI -H "Authorization: Bearer $SVPH_TOKEN" "https://${REGISTRY}/v2/$SVPH_REPOSITORY_NAME/manifests/$SVPH_DOCKER_IMAGE_TAG" | awk '/docker-content-digest/ {print $2}' | tr -d '\r')
IKG_MANIFESTS=$(curl -s -H "Authorization: Bearer $IKG_TOKEN" "https://${REGISTRY}/v2/$IKG_REPOSITORY_NAME/manifests/$IKG_DOCKER_IMAGE_TAG")
IKG_DOCKER_IMAGE_DIGEST=$(curl -sI -H "Authorization: Bearer $IKG_TOKEN" "https://${REGISTRY}/v2/$IKG_REPOSITORY_NAME/manifests/$IKG_DOCKER_IMAGE_TAG" | awk '/docker-content-digest/ {print $2}' | tr -d '\r')

echo "SVP Harvester docker image name: $SVPH_DOCKER_IMAGE_NAME"
echo "SVP Harvester docker image tag: $SVPH_DOCKER_IMAGE_TAG"
echo "SVP Harvester docker image digest: $SVPH_DOCKER_IMAGE_DIGEST"

if [ -z "$SVPH_DOCKER_IMAGE_DIGEST" ]; then
  echo "Failed to retrieve SVP Harvester docker image digest for $SVPH_DOCKER_IMAGE_NAME"
  exit 1
fi

echo "Crisalid IKG docker image name: $IKG_DOCKER_IMAGE_NAME"
echo "Crisalid IKG docker image tag: $IKG_DOCKER_IMAGE_TAG"
echo "Crisalid IKG docker image digest: $IKG_DOCKER_IMAGE_DIGEST"

if [ -z "$IKG_DOCKER_IMAGE_DIGEST" ]; then
  echo "Failed to retrieve Crisalid IKG docker image digest for $IKG_DOCKER_IMAGE_NAME"
  exit 1
fi

export SVPH_DOCKER_IMAGE_NAME
export SVPH_DOCKER_IMAGE_TAG
export SVPH_DOCKER_IMAGE_DIGEST
export IKG_DOCKER_IMAGE_NAME
export IKG_DOCKER_IMAGE_TAG
export IKG_DOCKER_IMAGE_DIGEST

folders=(
  "$INST_DIRECTORY"
  "$RABBIT_DIRECTORY"
  "$REDIS_DIRECTORY"
  "$VOC_PROXIES_DIRECTORY"
  "$ACCESS_DIRECTORY"
)

for folder in "${folders[@]}"; do
  find "$folder" \( -name '*.yaml' -o -name '*.yml' \) \
    -not -path '*/dags/*' \
    -not -name '*-values.yml' \
    -not -name '*-values.yaml' | while read file; do
      # Use envsubst to replace the placeholder with the actual digest
      # and pipe it to kubectl apply
      echo "Applying $file"
      envsubst <"$file" | kubectl apply --namespace="$INST" -f -
  done
done
