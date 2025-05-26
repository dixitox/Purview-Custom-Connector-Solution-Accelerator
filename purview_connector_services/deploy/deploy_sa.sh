#!/bin/bash
set -euo pipefail

# This script can take over 1 hour to complete
# This script requires contributor and user access administrator permissions to run
source ./settings.sh

# Check required secrets are set
if [ -z "${client_secret:-}" ]; then
  echo "ERROR: client_secret is not set. Please set it in settings.sh or export it before running this script."
  exit 1
fi

# Ensure sql_admin_password is set
if [ -z "${sql_admin_password:-}" ]; then
  echo "ERROR: sql_admin_password is not set. Please set it in settings.sh or export it before running this script."
  exit 1
fi

# To run in Azure Cloud CLI, comment this section out
# az login --output none
# az account set --subscription "Early Access Engineering Subscription" --output none

# dynamically load missing az dependancies without prompting
az config set extension.use_dynamic_install=yes_without_prompt --output none

# Parameters
base="pccsa" # must be < 7 chars, all letters

# Names
synapse_name=$base"synapse"
storage_name=$base"storage"
resource_group=$base"_rg"
key_vault_name=$base"keyvault"

# Retrieve account info
tenant_id=$(az account show --query "homeTenantId" -o tsv)
subscription_id=$(az account show --query "id" -o tsv)

echo "tenant_id is $tenant_id"
echo "subscription_id is $subscription_id"

# Ensure subscription_id is set and set the Azure CLI context
if [ -z "${subscription_id:-}" ]; then
  echo "ERROR: subscription_id is not set. Please check your settings.sh or Azure CLI context."
  exit 1
fi
az account set --subscription "$subscription_id"

#################################################################################

echo "Checking if resource group $resource_group exists..."
if az group show --name $resource_group --output none 2>/dev/null; then
  echo "Resource group $resource_group already exists. Skipping creation."
else
  echo "Creating resource group $resource_group"
  az group create --name $resource_group --location $location --output none >> log_connector_services_deploy.txt
fi

#################################################################################

echo "Checking if Key Vault $key_vault_name exists..."
if az keyvault show --name $key_vault_name --resource-group $resource_group --output none 2>/dev/null; then
  echo "Key Vault $key_vault_name already exists. Skipping creation."
else
  echo "Creating Key Vault $key_vault_name"
  az keyvault create \
    --name $key_vault_name \
    --resource-group $resource_group \
    --location $location \
    --enabled-for-template-deployment true \
    --output none
fi

# Assign Key Vault Secrets Officer role to the signed-in user (az login account)
user_upn=$(az account show --query user.name -o tsv)

role_assignment_exists=$(az role assignment list --assignee $user_upn --all --query "[?roleDefinitionName=='Key Vault Secrets Officer' && scope=='/subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.KeyVault/vaults/$key_vault_name'] | [0]" -o tsv)
if [ -z "$role_assignment_exists" ]; then
  echo "Assigning Key Vault Secrets Officer role to signed-in user ($user_upn)."
  az role assignment create \
    --assignee $user_upn \
    --role "Key Vault Secrets Officer" \
    --scope "subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.KeyVault/vaults/$key_vault_name" \
    --output none
  echo "Waiting 60 seconds for role assignment to propagate..."
  sleep 60
else
  echo "Key Vault Secrets Officer role already assigned to signed-in user. Skipping."
fi

# Now set the secret only if it does not exist or value is different
existing_secret_value=$(az keyvault secret show --vault-name $key_vault_name --name client-secret --query value -o tsv 2>/dev/null || true)
if [ "$existing_secret_value" != "$client_secret" ]; then
  echo "Setting client-secret in Key Vault."
  az keyvault secret set --vault-name $key_vault_name --name client-secret --value $client_secret --output none >> log_connector_services_deploy.txt
else
  echo "client-secret already set with the same value. Skipping."
fi

echo "Retrieving client secret uri"
# Get secret URI to fill in pipeline templates later
client_secret_uri=$(az keyvault secret show --name client-secret --vault-name $key_vault_name --query 'value' -o tsv)

# Store/retrieve Synapse SQL admin password in Key Vault
existing_sql_admin_secret=$(az keyvault secret show --vault-name $key_vault_name --name synapse-sql-admin-password --query value -o tsv 2>/dev/null || true)
if [ "$existing_sql_admin_secret" != "$sql_admin_password" ]; then
  echo "Setting synapse-sql-admin-password in Key Vault."
  az keyvault secret set --vault-name $key_vault_name --name synapse-sql-admin-password --value "$sql_admin_password" --output none >> log_connector_services_deploy.txt
else
  echo "synapse-sql-admin-password already set with the same value. Skipping."
fi

# Retrieve Synapse SQL admin password from Key Vault
sql_admin_password_kv=$(az keyvault secret show --vault-name $key_vault_name --name synapse-sql-admin-password --query value -o tsv)

##################################################################################

# Check if Purview account exists before deploying
if az purview account list --output none 2>/dev/null; then
  purview_name=$(az purview account list --query "[0].name" -o tsv)
  echo "Purview account $purview_name exists. Skipping deployment."
else
  echo "Purview account does not exists. Create a Microsoft Purview account"
fi

# Add app sp to Purview curator and reader roles only if not already assigned
app_object_id=$object_id
echo "App object id: $app_object_id"
purview_resource="/subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.Purview/accounts/$purview_name"

# Check and assign curator role

# Check and assign reader role


###############################################################################
echo "Deploying Synapse ARM Template"
# Use template for deployment
params="{\"prefixName\":{\"value\":\"$base\"},\
\"synapseName\":{\"value\":\"$synapse_name\"},\
\"suffixName\":{\"value\":\"$base\"},\
\"AllowAll\":{\"value\":\"true\"},\
\"sqlAdministratorLoginPassword\":{\"value\":\"$sql_admin_password_kv\"}}"
az deployment group create --resource-group $resource_group --parameters $params --template-file ./arm/deploy_synapse.json --output none >> log_connector_services_deploy.txt

echo "Setting KeyVault secret policy for Synapse"
# For RBAC-enabled Key Vault, assign Key Vault Secrets User role to Synapse managed identity
synapse_sp_id=$(az synapse workspace show --resource-group $resource_group --name $synapse_name --query 'identity.principalId' -o tsv)

synapse_role_assignment_exists=$(az role assignment list --assignee $synapse_sp_id --all --query "[?roleDefinitionName=='Key Vault Secrets User' && scope=='/subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.KeyVault/vaults/$key_vault_name'] | [0]" -o tsv)
if [ -z "$synapse_role_assignment_exists" ]; then
  echo "Assigning Key Vault Secrets User role to Synapse managed identity ($synapse_sp_id)."
  az role assignment create \
    --assignee $synapse_sp_id \
    --role "Key Vault Secrets User" \
    --scope "subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.KeyVault/vaults/$key_vault_name" \
    --output none >> log_connector_services_deploy.txt
else
  echo "Key Vault Secrets User role already assigned to Synapse managed identity. Skipping."
fi

echo "Creating linked services in Synapse"
# Configure Synapse Notebooks and Pipelines
# Synapse linked service
if az synapse linked-service show --workspace-name $synapse_name --name purviewaccws-WorkspaceDefaultStorage --output none 2>/dev/null; then
  echo "Synapse linked service purviewaccws-WorkspaceDefaultStorage already exists. Skipping creation."
else
  # Add storage account name to linked service json
  sed "s/<tag_storage_account>/$storage_name/g" ../synapse/linked_service/purviewaccws-WorkspaceDefaultStorage.json > ../synapse/linked_service/purviewaccws-WorkspaceDefaultStorage-tmp.json
  # Create linked service in Synapse
  az synapse linked-service create --workspace-name $synapse_name --name purviewaccws-WorkspaceDefaultStorage --file @../synapse/linked_service/purviewaccws-WorkspaceDefaultStorage-tmp.json --output none >> log_connector_services_deploy.txt
  # Delete the tmp json with the added storage account name
  rm ../synapse/linked_service/purviewaccws-WorkspaceDefaultStorage-tmp.json
fi

echo "Creating spark pool"
# Create SPARK pool
if az synapse spark pool show --name notebookrun --workspace-name $synapse_name --resource-group $resource_group --output none 2>/dev/null; then
  echo "Synapse spark pool notebookrun already exists. Skipping creation."
else
  az synapse spark pool create --name notebookrun --workspace-name $synapse_name --resource-group $resource_group --spark-version 3.3 --node-count 10 --node-size Medium --delay 10 --enable-auto-pause true --min-executors 3 --max-executors 10 --output none >> log_connector_services_deploy.txt
  # Add packages
  az synapse spark pool update --name notebookrun --workspace-name $synapse_name --resource-group $resource_group --library-requirements ./requirements.txt --output none >> log_connector_services_deploy.txt
fi

echo "Creating Synapse notebooks"
# Note: add notebooks and attach to sparkpool
if az synapse notebook show --workspace-name $synapse_name --name Purview_Load_Entity --output none 2>/dev/null; then
  echo "Synapse notebook Purview_Load_Entity already exists. Skipping creation."
else
  az synapse notebook create --workspace-name $synapse_name --spark-pool-name notebookrun --name Purview_Load_Entity --file @../synapse/notebook/Purview_Load_Entity.ipynb --output none
fi

echo "Creating Synapse pipelines"
# Build multiple substitutions for pipeline json - note sed can use any delimeter so url changed to avoid conflict with slash char
if az synapse pipeline show --workspace-name $synapse_name --name 'Purview Load Custom Types' --output none 2>/dev/null; then
  echo "Synapse pipeline 'Purview Load Custom Types' already exists. Skipping creation."
else
  pipeline_sub="s/<tag_storage_account>/$storage_name/;s/<tag_purview_account>/$purview_name/;s/<tag_tenant_id>/$tenant_id/;s/<tag_client_id>/$client_id/;s@<tag_secret_uri>@$client_secret_uri?api-version=7.0@"
  sed $pipeline_sub '../synapse/pipeline/Purview Load Custom Types.json' > '../synapse/pipeline/Purview Load Custom Types-tmp.json'
  # Create pipeline in Synapse
  az synapse pipeline create --workspace-name $synapse_name --name 'Purview Load Custom Types' --file '@../synapse/pipeline/Purview Load Custom Types-tmp.json' --output none >> log_connector_services_deploy.txt
  # Delete the tmp json
  rm '../synapse/pipeline/Purview Load Custom Types-tmp.json'
fi

echo "Creating Synapse pipeline trigger"
# Build multiple substitutions for trigger json
if az synapse trigger show --workspace-name $synapse_name --name 'Trigger Load Custom Type' --output none 2>/dev/null; then
  echo "Synapse trigger 'Trigger Load Custom Type' already exists. Skipping creation."
else
  pipeline_sub="s/<tag_subscription_id>/$subscription_id/;s/<tag_resource_group>/$resource_group/;s/<tag_storage_account>/$storage_name/"
  sed $pipeline_sub '../synapse/trigger/Trigger Load Custom Type.json' > '../synapse/trigger/Trigger Load Custom Type-tmp.json'
  # Create trigger in Synapse
  az synapse trigger create --workspace-name $synapse_name --name 'Trigger Load Custom Type' --file '@../synapse/trigger/Trigger Load Custom Type-tmp.json' --output none >> log_connector_services_deploy.txt
  # Delete the tmp json
  rm '../synapse/trigger/Trigger Load Custom Type-tmp.json'
fi

##################################################################################

echo "Deploying Storage ARM Template"
# Use template for deployment - ensure all parameters match exactly what the template expects
params="{\"synapseName\":{\"value\":\"$synapse_name\"},\"storageName\":{\"value\":\"$storage_name\"}}"
az deployment group create --resource-group $resource_group --parameters $params --template-file ./arm/deploy_storage.json --output none --no-prompt >> log_connector_services_deploy.txt 2>&1

# Get storage account key and add to keyvault secrets
echo "Getting storage account key..."
if ! storage_account_key=$(az storage account keys list --resource-group $resource_group --account-name $storage_name --query [0].value -o tsv 2>> log_connector_services_deploy.txt); then
  echo "ERROR: Failed to retrieve storage account key. Check if storage account '$storage_name' exists in resource group '$resource_group'."
  echo "Trying to proceed with other steps..."
else
  echo "Successfully retrieved storage account key."
  
  # Storage account key secret
  echo "Checking if storage account key already exists in Key Vault..."
  existing_storage_key_secret=$(az keyvault secret show --vault-name $key_vault_name --name storage-account-key --query value -o tsv 2>/dev/null || echo "")
  
  if [ -z "$storage_account_key" ]; then
    echo "WARNING: Retrieved storage account key is empty. Skipping Key Vault update."
  elif [ "$existing_storage_key_secret" != "$storage_account_key" ]; then
    echo "Setting storage-account-key in Key Vault '$key_vault_name'..."
    az keyvault secret set --vault-name $key_vault_name --name storage-account-key --value "$storage_account_key" --output none >> log_connector_services_deploy.txt 2>&1
    echo "Storage account key successfully saved to Key Vault."
  else
    echo "Storage account key already set with the same value. Skipping."
  fi
fi

echo "Creating folder structure in ADLS"
# Create storage dir structure
# First, ensure we have the right storage account permissions
echo "Getting Synapse managed identity"
synapse_id=$(az synapse workspace show --resource-group $resource_group --name $synapse_name --query identity.principalId -o tsv)

echo "Ensuring Storage Blob Data Contributor role is assigned to current user and Synapse"
current_user_id=$(az ad signed-in-user show --query id -o tsv)
# Assign Storage Blob Data Contributor role to current user
az role assignment create --assignee $current_user_id --role "Storage Blob Data Contributor" --scope "/subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.Storage/storageAccounts/$storage_name" --output none 2>/dev/null || true
# Assign Storage Blob Data Contributor role to Synapse managed identity
az role assignment create --assignee $synapse_id --role "Storage Blob Data Contributor" --scope "/subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.Storage/storageAccounts/$storage_name" --output none 2>/dev/null || true

echo "Waiting for role assignments to propagate (30 seconds)..."
sleep 30

# Try with OAuth authentication first
if az storage fs directory exists -f pccsa --account-name $storage_name --name incoming --auth-mode login --output tsv 2>/dev/null | grep -q true; then
  echo "ADLS directory structure already exists. Skipping creation."
else
  echo "Creating local directory structure"
  [ -d pccsa_main ] && rm -rf pccsa_main
  mkdir pccsa_main; cd pccsa_main; mkdir incoming; touch ./incoming/tmp; mkdir processed; touch ./processed/tmp; cd ..
  
  echo "Uploading directory structure to storage with OAuth"
  # Try with OAuth first
  az storage fs directory create -f pccsa --account-name $storage_name --name incoming --auth-mode login --output none 2>> log_connector_services_deploy.txt || \
  az storage fs directory create -f pccsa --account-name $storage_name --name incoming --auth-mode key --account-key "$storage_account_key" --output none 2>> log_connector_services_deploy.txt
  
  az storage fs directory create -f pccsa --account-name $storage_name --name processed --auth-mode login --output none 2>> log_connector_services_deploy.txt || \
  az storage fs directory create -f pccsa --account-name $storage_name --name processed --auth-mode key --account-key "$storage_account_key" --output none 2>> log_connector_services_deploy.txt
  
  # Create placeholder files
  echo "Creating placeholder files"
  touch pccsa_main/incoming/placeholder.txt
  touch pccsa_main/processed/placeholder.txt
  
  # Upload placeholder files
  echo "Uploading placeholder files"
  az storage fs file upload -f pccsa --path incoming/placeholder.txt --source pccsa_main/incoming/placeholder.txt --account-name $storage_name --auth-mode login --output none 2>> log_connector_services_deploy.txt || \
  az storage fs file upload -f pccsa --path incoming/placeholder.txt --source pccsa_main/incoming/placeholder.txt --account-name $storage_name --auth-mode key --account-key "$storage_account_key" --output none 2>> log_connector_services_deploy.txt
  
  az storage fs file upload -f pccsa --path processed/placeholder.txt --source pccsa_main/processed/placeholder.txt --account-name $storage_name --auth-mode login --output none 2>> log_connector_services_deploy.txt || \
  az storage fs file upload -f pccsa --path processed/placeholder.txt --source pccsa_main/processed/placeholder.txt --account-name $storage_name --auth-mode key --account-key "$storage_account_key" --output none 2>> log_connector_services_deploy.txt
  
  # Remove tmp directory structure
  echo "Cleaning up local directory"
  rm -r pccsa_main
fi

##################################################################################
echo "Writing name output"
# Write names into bash script so they can be sourced into example deploy scripts
echo '#!/bin/bash' > ./export_names.sh
echo >> ./export_names.sh
echo "key_vault_name=$key_vault_name" >> ./export_names.sh
echo "synapse_name=$synapse_name" >> ./export_names.sh
echo "purview_name=$purview_name" >> ./export_names.sh
echo "storage_name=$storage_name" >> ./export_names.sh
echo "tenant_id=$tenant_id" >> ./export_names.sh
echo "subscription_id=$subscription_id" >> ./export_names.sh
echo "resource_group=$resource_group" >> ./export_names.sh
echo "prefix=$base" >> ./export_names.sh
