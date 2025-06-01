#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env

kubectl config set-context --current --namespace=$INST

# This will uninstall Keycloak but leave PVCs and other data intact
helm uninstall $KEYCLOAK_INSTANCE_NAME --namespace $INST

echo "Keycloak instance '$KEYCLOAK_INSTANCE_NAME' has been stopped (Helm release deleted, data preserved)."
