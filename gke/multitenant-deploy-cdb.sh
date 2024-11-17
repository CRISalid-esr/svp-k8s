#!/bin/bash
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env
get_project_id
get_gsa_email

PWD=$(pwd)
INST_DIRECTORY=$PWD/inst/$INST

ENV_FILE=$DAGS_DIRECTORY/env.txt

AIRFLOW_VERSION="2.9.3"
COMPOSER_VERSION="3"
GIT_BRANCH="dev-main"
RESTART_TRIGGER="3"

# create bucket for dags if it does not exist
gsutil ls -p $PROJECT_ID | grep -q gs://$DAGS_BUCKET_NAME
if [ $? -ne 0 ]; then
  echo "Creating bucket $DAGS_BUCKET_NAME with standard storage class in $LOCATION"
  gsutil mb -p $PROJECT_ID -c standard -l $LOCATION gs://$DAGS_BUCKET_NAME
else
  echo "Bucket $DAGS_BUCKET_NAME already exists"
fi

# create Redis memory store instance if it does not exist
REDIS_INST_NAME="redis-cdb-$INST"
REDIS_INST_LOCATION=$LOCATION
REDIS_INST_ZONE=$ZONE
REDIS_INST_TIER="BASIC"
REDIS_INST_SIZE="1"
REDIS_INST_REDIS_VERSION="redis_7_0"

# if redis instance does not exist, create it
gcloud redis instances list --region=$REDIS_INST_ZONE --format="value(name)" | grep -q $REDIS_INST_NAME
if [ $? -ne 0 ]; then
  echo "Creating redis instance $REDIS_INST_NAME"
  gcloud redis instances create $REDIS_INST_NAME \
    --region=$REDIS_INST_LOCATION \
    --zone=$REDIS_INST_ZONE \
    --tier=$REDIS_INST_TIER \
    --redis-version=$REDIS_INST_REDIS_VERSION \
    --size=$REDIS_INST_SIZE
else
  echo "Redis instance $REDIS_INST_NAME already exists"
fi

CDB_REDIS_HOST=$(gcloud redis instances describe $REDIS_INST_NAME --region=$LOCATION --format="value(host)")

# if crisalid-directory-bridge directory does no exist, git clone git@github.com:CRISalid-esr/crisalid-directory-bridge.git
# else pull latest changes
cd $INST_DIRECTORY
if [ ! -d dags ]; then
  echo "Cloning crisalid-directory-bridge branch $GIT_BRANCH into $DAGS_DIRECTORY"
  git clone git@github.com:CRISalid-esr/crisalid-directory-bridge.git dags --branch $GIT_BRANCH
else
  echo "Pulling latest changes from crisalid-directory-bridge"
  cd dags
  git reset --hard
  git checkout $GIT_BRANCH
  git pull origin $GIT_BRANCH
  cd ..
fi
cd ..

# push crisalid directory bridge to gs://crisalid-$INST-bucket directory with gsutil
# exclude directories : .github, .git, data, tests, and files : .gitignore
echo "Pushing crisalid-directory-bridge to bucket gs://$DAGS_BUCKET_NAME/dags"
gsutil -m rsync -r -x "(\.gitignore|\.github($|/)|\.git($|/)|data($|/)|tests($|/))" \
  $DAGS_DIRECTORY \
  gs://$DAGS_BUCKET_NAME/dags

# create composer environment if it does not exist
gcloud composer environments describe $COMPOSER_ENV_NAME --location $LOCATION --format="value(name)" | grep -q $COMPOSER_ENV_NAME
if [ $? -ne 0 ]; then
  echo "Creating Composer environment $COMPOSER_ENV_NAME"
  gcloud composer environments create $COMPOSER_ENV_NAME \
    --location $LOCATION \
    --image-version=composer-$COMPOSER_VERSION-airflow-$AIRFLOW_VERSION \
    --service-account=$GSA_EMAIL \
    --network=default \
    --storage-bucket=gs://$DAGS_BUCKET_NAME \
    --tags=cdb
  echo "Composer environment $COMPOSER_ENV_NAME successfully created"
else
  echo "Composer environment $COMPOSER_ENV_NAME already exists"
fi

# remove all apache-airflow-* lines from cloud-composer-requirements.txt file as Composer does not allow to update it
sed -i -e '/apache-airflow/d' $DAGS_DIRECTORY/cloud-composer-requirements.txt

# update composer environment with requirements from cloud-composer-requirements.txt
gcloud composer environments update $COMPOSER_ENV_NAME \
  --location=$LOCATION \
  --update-pypi-packages-from-file=$DAGS_DIRECTORY/cloud-composer-requirements.txt

# spreadsheet identifiers path is in data buckets with DATA_BUCKET_NAME="crisalid-$INST-data"
PEOPLE_SPREADSHEET_PATH="gs://$DATA_BUCKET_NAME/people.csv"
STRUCTURE_SPREADSHEET_PATH="gs://$DATA_BUCKET_NAME/structure.csv"

# Replace variables in .env.template file and copy it to env.txt
cp $DAGS_DIRECTORY/.env.template $ENV_FILE
for var in LDAP_HOST \
  LDAP_BIND_DN \
  LDAP_BIND_PASSWORD \
  PEOPLE_SPREADSHEET_PATH \
  STRUCTURE_SPREADSHEET_PATH \
  RABBITMQ_CONN_ID \
  RABBITMQ_HOST \
  RABBITMQ_PORT \
  AMQP_USER \
  AMQP_PASSWORD \
  CDB_REDIS_CONN_ID \
  CDB_REDIS_HOST \
  CDB_REDIS_PORT \
  CDB_REDIS_PASSWORD \
  RESTART_TRIGGER; do
  value=$(eval "echo \$$var")
  echo "Replacing $var with $value"
  sed -i -e "s|\${$var}|$value|g" $ENV_FILE
done

# create composer environment variables
# Read each line from the env.txt file, format it for gcloud
# and send it to the gcloud composer environments update command

if [ ! -f "$ENV_FILE" ]; then
  echo "Environment file $ENV_FILE does not exist."
  exit 1
fi

# Initialize the ENV_VARS string
ENV_VARS=""

# Read each line from the env.txt file and format it for gcloud with § separator
while IFS= read -r line; do
  # Skip empty lines or lines starting with #
  if [[ ! -z "$line" && ! "$line" =~ ^# ]]; then
    ENV_VARS="${ENV_VARS}${line}§"
  fi
done <"$ENV_FILE"

# Remove the trailing §
ENV_VARS="${ENV_VARS%§}"

rm $ENV_FILE
# Update the Composer environment with the environment variables : force
gcloud composer environments update "$COMPOSER_ENV_NAME" \
  --location="$LOCATION" \
  --update-env-variables="^§^$ENV_VARS"

# Check if the gcloud command was successful
if [ $? -ne 0 ]; then
  echo "Failed to update Composer environment variables."
  exit 1
else
  echo "Composer environment variables updated successfully."
fi
