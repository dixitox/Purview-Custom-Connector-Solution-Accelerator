#!/bin/bash 

# This script can take over 1 hour to complete
# This script requires contributor and user access administrator permissions to run
source ./settings.sh

# To run in Azure Cloud CLI, comment this section out
# az login --output none
# az account set --subscription "Early Access Engineering Subscription" --output none

# dynamically load missing az dependancies without prompting
az config set extension.use_dynamic_install=yes_without_prompt --output none

# Parameters
base="pccsa" # must be < 7 chars, all letters

# Names
synapse_name=$base"synapse"
purview_name=$base"purview"
storage_name=$base"storage"
resource_group=$base"_rg"
key_vault_name=$base"keyvault"

# Retrieve account info
tenant_id=$(az account show --query "homeTenantId" -o tsv)
subscription_id=$(az account show --query "id" -o tsv)

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

# Assign Key Vault Secrets Officer role to the current user
current_user_object_id=$(az ad signed-in-user show --query objectId -o tsv)
role_assignment_exists=$(az role assignment list --assignee $current_user_object_id --role "Key Vault Secrets Officer" --scope "/subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.KeyVault/vaults/$key_vault_name" --query "[0]" -o tsv)
if [ -z "$role_assignment_exists" ]; then
  echo "Assigning Key Vault Secrets Officer role to current user."
  az role assignment create \
    --assignee $current_user_object_id \
    --role "Key Vault Secrets Officer" \
    --scope "/subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.KeyVault/vaults/$key_vault_name" \
    --output none
else
  echo "Key Vault Secrets Officer role already assigned to current user. Skipping."
fi

# Print the current user and caller info for RBAC troubleshooting
echo "Current user objectId (for role assignment): $current_user_object_id"
caller_object_id=$(az account show --query user.name -o tsv 2>/dev/null)
echo "Caller (az account show --query user.name): $caller_object_id"

# Wait for role assignment propagation
max_wait=300  # max 5 minutes
waited=0
interval=15

echo "Waiting for RBAC propagation (up to $max_wait seconds)..."
while true; do
  # Try a dry-run secret set to check permission
  az keyvault secret set --vault-name $key_vault_name --name __rbac_check__ --value test --output none 2>/dev/null
  if [ $? -eq 0 ]; then
    az keyvault secret delete --vault-name $key_vault_name --name __rbac_check__ --output none 2>/dev/null
    echo "RBAC propagation complete."
    break
  fi
  if [ $waited -ge $max_wait ]; then
    echo "RBAC propagation timed out after $max_wait seconds. Exiting."
    exit 1
  fi
  echo "Waiting $interval seconds for RBAC propagation... ($waited/$max_wait)"
  sleep $interval
  waited=$((waited+interval))
done

# Now set the secret only if it does not exist or value is different
existing_secret_value=$(az keyvault secret show --vault-name $key_vault_name --name client-secret --query value -o tsv 2>/dev/null)
if [ "$existing_secret_value" != "$client_secret" ]; then
  echo "Setting client-secret in Key Vault."
  az keyvault secret set --vault-name $key_vault_name --name client-secret --value $client_secret --output none >> log_connector_services_deploy.txt
else
  echo "client-secret already set with the same value. Skipping."
fi

echo "Retrieving client secret uri"
# Get secret URI to fill in pipeline templates later
client_secret_uri=$(az keyvault secret show --name client-secret --vault-name $key_vault_name --query 'id' -o tsv)

##################################################################################

# Check if Purview account exists before deploying
if az purview account show --name $purview_name --resource-group $resource_group --output none 2>/dev/null; then
  echo "Purview account $purview_name already exists. Skipping deployment."
else
  echo "Starting Purview template deployment"
  # Use template for deployment
  params="{\"purviewName\":{\"value\":\"$purview_name\"}}"
  az deployment group create --resource-group $resource_group --parameters $params --template-file ./arm/deploy_purview.json --output none >> log_connector_services_deploy.txt
fi

# Add app sp to Purview curator and reader roles only if not already assigned
app_object_id=$(az ad sp list --display-name $client_name --query "[0].objectId" -o tsv)
echo "App object id: $app_object_id"
purview_resource="/subscriptions/$subscription_id/resourcegroups/$resource_group/providers/Microsoft.Purview/accounts/$purview_name"
purview_data_curator_id=$(az role definition list --name "Purview Data Curator" --query "[].{name:name}" -o tsv)
purview_data_reader_id=$(az role definition list --name "Purview Data Reader" --query "[].{name:name}" -o tsv)
echo "purview_data_curator_id is $purview_data_curator_id" >> log_connector_services_deploy.txt
echo "purview_data_reader_id is $purview_data_reader_id" >> log_connector_services_deploy.txt
# Check and assign curator role
curator_assignment=$(az role assignment list --assignee $app_object_id --role "$purview_data_curator_id" --scope "$purview_resource" --query "[0]" -o tsv)
if [ -z "$curator_assignment" ]; then
  echo "Assigning Purview Data Curator role to app sp."
  az role assignment create --assignee $app_object_id --role $purview_data_curator_id --scope $purview_resource --output none >> log_connector_services_deploy.txt
else
  echo "Purview Data Curator role already assigned to app sp. Skipping."
fi
# Check and assign reader role
reader_assignment=$(az role assignment list --assignee $app_object_id --role "$purview_data_reader_id" --scope "$purview_resource" --query "[0]" -o tsv)
if [ -z "$reader_assignment" ]; then
  echo "Assigning Purview Data Reader role to app sp."
  az role assignment create --assignee $app_object_id --role $purview_data_reader_id --scope $purview_resource --output none >> log_connector_services_deploy.txt
else
  echo "Purview Data Reader role already assigned to app sp. Skipping."
fi

###############################################################################
echo "Deploying Synapse ARM Template"
# Use template for deployment
params="{\"prefixName\":{\"value\":\"$base\"},"\
"\"suffixName\":{\"value\":\"$svc_suffix\"},"\
"\"synapseName\":{\"value\":\"$synapse_name\"}}"
az deployment group create --resource-group $resource_group --parameters $params --template-file ./arm/deploy_synapse.json --output none >> log_connector_services_deploy.txt

echo "Setting KeyVault secret policy for Synapse"
# Allow synapse pipelines (MIP) to retrieve keyvault secrets
synapse_sp_id=$(az synapse workspace show --resource-group $resource_group --name $synapse_name --query 'identity.principalId' -o tsv)
az keyvault set-policy -n $key_vault_name --secret-permissions get list --object-id $synapse_sp_id --output none >> log_connector_services_deploy.txt

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
  az synapse spark pool create --name notebookrun --workspace-name $synapse_name --resource-group $resource_group --spark-version 2.4 --node-count 10 --node-size Medium --delay 10 --enable-auto-pause true --output none >> log_connector_services_deploy.txt
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
# Use template for deployment
params="{\"synapseName\":{\"value\":\"$synapse_name\"},"\
"\"storageName\":{\"value\":\"$storage_name\"}}"
az deployment group create --resource-group $resource_group --parameters $params --template-file ./arm/deploy_storage.json --output none >> log_connector_services_deploy.txt

echo "Creating folder structure in ADLS"
# Create storage dir structure
if az storage fs directory exists -f pccsa --account-name $storage_name -p incoming --output tsv | grep -q true; then
  echo "ADLS directory structure already exists. Skipping creation."
else
  mkdir pccsa_main; cd pccsa_main; mkdir incoming; touch ./incoming/tmp; mkdir processed; touch ./processed/tmp; cd ..
  # Upload dir structure to storage
  az storage fs directory upload -f pccsa --account-name $storage_name -s ./pccsa_main -d . --recursive --output none >> log_connector_services_deploy.txt
  # Remove tmp directory structure
  rm -r pccsa_main
fi

# Get storage account key and add to keyvault secrets
storage_account_key=$(az storage account keys list --resource-group $resource_group --account-name $storage_name --query [0].value -o tsv)
# Storage account key secret
existing_storage_key_secret=$(az keyvault secret show --vault-name $key_vault_name --name storage-account-key --query value -o tsv 2>/dev/null)
if [ "$existing_storage_key_secret" != "$storage_account_key" ]; then
  echo "Setting storage-account-key in Key Vault."
  az keyvault secret set --vault-name $key_vault_name --name storage-account-key --value $storage_account_key --output none >> log_connector_services_deploy.txt
else
  echo "storage-account-key already set with the same value. Skipping."
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
echo "suffix=$svc_suffix" >> ./export_names.sh

