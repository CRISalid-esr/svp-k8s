#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env

SVPH_DOCKER_IMAGE_TAG="v0.17-dev"
SVPH_DOCKER_IMAGE_NAME="crisalidesr/svp-harvester"
IKG_DOCKER_IMAGE_TAG="v0.9-dev"
IKG_DOCKER_IMAGE_NAME="crisalidesr/crisalid-ikg"
SVP_DOCKER_IMAGE_TAG="v0.18-dev"
SVP_DOCKER_IMAGE_NAME="crisalidesr/sovisuplus"
CTD_DOCKER_IMAGE_TAG="v0.12-dev"
CTD_DOCKER_IMAGE_NAME="crisalidesr/crisalid-training-data"
APOLLO_DOCKER_IMAGE_TAG="v0.2-dev"
APOLLO_DOCKER_IMAGE_NAME="crisalidesr/crisalid-apollo"

REGISTRY="index.docker.io"
SVPH_REPOSITORY_NAME="crisalidesr/svp-harvester"
IKG_REPOSITORY_NAME="crisalidesr/crisalid-ikg"
SVP_REPOSITORY_NAME="crisalidesr/sovisuplus"
APOLLO_REPOSITORY_NAME="crisalidesr/crisalid-apollo"

SVPH_TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$SVPH_REPOSITORY_NAME:pull" | jq -r .token)
IKG_TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$IKG_REPOSITORY_NAME:pull" | jq -r .token)
SVP_TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$SVP_REPOSITORY_NAME:pull" | jq -r .token)
APOLLO_TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$APOLLO_REPOSITORY_NAME:pull" | jq -r .token)


# Get the image digest using Docker Registry HTTP API v2
SVPH_MANIFESTS=$(curl -s -H "Authorization: Bearer $SVPH_TOKEN" "https://${REGISTRY}/v2/$SVPH_REPOSITORY_NAME/manifests/$SVPH_DOCKER_IMAGE_TAG")
SVPH_DOCKER_IMAGE_DIGEST=$(curl -sI -H "Authorization: Bearer $SVPH_TOKEN" "https://${REGISTRY}/v2/$SVPH_REPOSITORY_NAME/manifests/$SVPH_DOCKER_IMAGE_TAG" | awk '/docker-content-digest/ {print $2}' | tr -d '\r')
IKG_MANIFESTS=$(curl -s -H "Authorization: Bearer $IKG_TOKEN" "https://${REGISTRY}/v2/$IKG_REPOSITORY_NAME/manifests/$IKG_DOCKER_IMAGE_TAG")
IKG_DOCKER_IMAGE_DIGEST=$(curl -sI -H "Authorization: Bearer $IKG_TOKEN" "https://${REGISTRY}/v2/$IKG_REPOSITORY_NAME/manifests/$IKG_DOCKER_IMAGE_TAG" | awk '/docker-content-digest/ {print $2}' | tr -d '\r')
SVP_MANIFESTS=$(curl -s -H "Authorization: Bearer $SVP_TOKEN" "https://${REGISTRY}/v2/$SVP_REPOSITORY_NAME/manifests/$SVP_DOCKER_IMAGE_TAG")
SVP_DOCKER_IMAGE_DIGEST=$(curl -sI -H "Authorization: Bearer $SVP_TOKEN" "https://${REGISTRY}/v2/$SVP_REPOSITORY_NAME/manifests/$SVP_DOCKER_IMAGE_TAG" | awk '/docker-content-digest/ {print $2}' | tr -d '\r')
APOLO_MANIFEST=$(curl -s -H "Authorization: Bearer $APOLLO_TOKEN" "https://${REGISTRY}/v2/$APOLLO_REPOSITORY_NAME/manifests/$APOLLO_DOCKER_IMAGE_TAG")
APOLLO_DOCKER_IMAGE_DIGEST=$(curl -sI -H "Authorization: Bearer $APOLLO_TOKEN" "https://${REGISTRY}/v2/$APOLLO_REPOSITORY_NAME/manifests/$APOLLO_DOCKER_IMAGE_TAG" | awk '/docker-content-digest/ {print $2}' | tr -d '\r')

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

if [ "$ENABLE_TRAINING_DATA_PIPELINE" = "1" ]; then
  echo "Training Data Pipeline is enabled"
  echo "Crisalid Training Data docker image name: $CTD_DOCKER_IMAGE_NAME"
  echo "Crisalid Training Data docker image tag: $CTD_DOCKER_IMAGE_TAG"
else
  echo "Training Data Pipeline is disabled"
fi

if [ -z "$IKG_DOCKER_IMAGE_DIGEST" ]; then
  echo "Failed to retrieve Crisalid IKG docker image digest for $IKG_DOCKER_IMAGE_NAME"
  exit 1
fi

echo "SoVisuPlus docker image name: $SVP_DOCKER_IMAGE_NAME"
echo "SoVisuPlus docker image tag: $SVP_DOCKER_IMAGE_TAG"
echo "SoVisuPlus docker image digest: $SVP_DOCKER_IMAGE_DIGEST"

if [ -z "$SVP_DOCKER_IMAGE_DIGEST" ]; then
  echo "Failed to retrieve SoVisuPlus docker image digest for $SVP_DOCKER_IMAGE_NAME"
  exit 1
fi

echo "Apollo docker image name: $APOLLO_DOCKER_IMAGE_NAME"
echo "Apollo docker image tag: $APOLLO_DOCKER_IMAGE_TAG"
echo "Apollo docker image digest: $APOLLO_DOCKER_IMAGE_DIGEST"
if [ -z "$APOLLO_DOCKER_IMAGE_DIGEST" ]; then
  echo "Failed to retrieve Apollo docker image digest for $APOLLO_DOCKER_IMAGE_NAME"
  exit 1
fi

export SVPH_DOCKER_IMAGE_NAME
export SVPH_DOCKER_IMAGE_TAG
export SVPH_DOCKER_IMAGE_DIGEST
export IKG_DOCKER_IMAGE_NAME
export IKG_DOCKER_IMAGE_TAG
export IKG_DOCKER_IMAGE_DIGEST
export SVP_DOCKER_IMAGE_NAME
export SVP_DOCKER_IMAGE_TAG
export SVP_DOCKER_IMAGE_DIGEST
export CTD_DOCKER_IMAGE_NAME
export CTD_DOCKER_IMAGE_TAG
export CTD_DOCKER_IMAGE_DIGEST
export APOLLO_DOCKER_IMAGE_NAME
export APOLLO_DOCKER_IMAGE_TAG
export APOLLO_DOCKER_IMAGE_DIGEST

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

if [ "$ENABLE_TRAINING_DATA_PIPELINE" != "1" ]; then
  echo "Training Data Pipeline is disabled"
  exit 0
fi

CTD_ES_CONFIG_TEMPLATE=$HELM_CONFIG_DIRECTORY/ctd-es-values.yaml
CTD_ES_INST_VALUES_FILE=$INST_DIRECTORY/ctd-es-values.yaml

cp $CTD_ES_CONFIG_TEMPLATE $CTD_ES_INST_VALUES_FILE
sed -i "s/\${CTD_ES_INSTANCE_NAME}/$CTD_ES_INSTANCE_NAME/g" $CTD_ES_INST_VALUES_FILE
sed -i "s/\${CTD_ES_PASSWORD}/$CTD_ES_PASSWORD/g" $CTD_ES_INST_VALUES_FILE
sed -i "s/\${CTD_ES_PORT}/$CTD_ES_PORT/g" $CTD_ES_INST_VALUES_FILE
helm repo add elastic https://helm.elastic.co
helm upgrade --install $CTD_ES_INSTANCE_NAME elastic/elasticsearch --namespace $INST -f $CTD_ES_INST_VALUES_FILE
CTD_DEPL_FILE="$CORE_DIRECTORY/crisalid-training-data/crisalid-training-data-depl.yaml"
echo "Applying $CTD_DEPL_FILE"
export CTD_DOCKER_IMAGE_NAME
export CTD_DOCKER_IMAGE_TAG
envsubst <"$CTD_DEPL_FILE" | kubectl apply --namespace="$INST" -f -

