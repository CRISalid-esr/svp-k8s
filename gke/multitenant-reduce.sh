#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env

kubectl config set-context --current --namespace="$INST"

kubectl scale --replicas=0 statefulset svph-redis
kubectl scale --replicas=0 deployment svp-jel-proxy
kubectl scale --replicas=0 deployment crisalid-training-data
kubectl scale --replicas=0 deployment crisalid-bus
kubectl scale --replicas=0 statefulset ctd-es-cluster-master

gcloud composer environments describe $COMPOSER_ENV_NAME --location $LOCATION --format="value(name)" | grep -q $COMPOSER_ENV_NAME
if [ $? -ne 0 ]; then
  echo "Composer environment $COMPOSER_ENV_NAME does not exist"
  exit 1
else
  echo "Composer environment $COMPOSER_ENV_NAME exists"
fi

gcloud composer environments update "$COMPOSER_ENV_NAME" \
    --location="$LOCATION" \
    --update-airflow-configs=scheduler-max_threads=0