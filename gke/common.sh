#!/bin/bash

# Function to check if the institution name is provided
check_inst_arg() {
  if [ -z $INST ]; then
    echo "Please provide an institution name"
    exit 1
  fi
}

# Function to get the project ID
get_project_id() {
  PROJECT_ID=$(gcloud config get-value project)
  if [ -z "$PROJECT_ID" ]; then
    echo "Could not get project id"
    exit 1
  else
    echo "Project id: $PROJECT_ID"
  fi
}

load_inst_env() {
  INST_ENV_FILE=$(pwd)/inst_env/$INST.env
  if [ ! -f "$INST_ENV_FILE" ]; then
    echo "Institution environment file not found"
    exit 1
  fi
  echo "Institution environment file found: $INST_ENV_FILE"
  source "$INST_ENV_FILE"
  echo "Institution environment variables loaded"
}

get_gsa_email() {
  GSA_EMAIL=$(gcloud iam service-accounts list --filter="name:$INST_SERVICE_ACCOUNT" --format="value(email)")
  if [ -z "$GSA_EMAIL" ]; then
    echo "Could not get service account email"
    exit 1
  else
    echo "Service account email: $GSA_EMAIL"
  fi
}
