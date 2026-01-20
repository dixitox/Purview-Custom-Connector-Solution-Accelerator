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

# Generate a unique suffix for the service names
let svc_suffix=$RANDOM*$RANDOM

# Names
fabric_workspace_name=$base"fabric"$svc_suffix
purview_name=$base"purview"$svc_suffix
storage_name=$base"storage"$svc_suffix
resource_group=$base"_rg_"$svc_suffix
key_vault_name=$base"keyvault"$svc_suffix

# Retrieve account info
tenant_id=$(az account show --query "homeTenantId" -o tsv)
subscription_id=$(az account show --query "id" -o tsv)

#################################################################################

echo "Creating resource group $resource_group"
az group create --name $resource_group --location $location --output none >> log_connector_services_deploy.txt


#################################################################################

echo "Adding keyvault and client secret"
# Create KeyVault and generate secrets
az keyvault create \
  --name $key_vault_name \
  --resource-group $resource_group \
  --location $location \
  --enabled-for-template-deployment true\
  --output none
az keyvault secret set --vault-name $key_vault_name --name client-secret --value $client_secret --output none >> log_connector_services_deploy.txt

echo "Retrieving client secret uri"
# Get secret URI to fill in pipeline templates later
client_secret_uri=$(az keyvault secret show --name client-secret --vault-name $key_vault_name --query 'id' -o tsv)

##################################################################################

echo "Starting Purview template deployment"
# Use template for deployment
params="{\"purviewName\":{\"value\":\"$purview_name\"}}"
az deployment group create --resource-group $resource_group --parameters $params --template-file ./arm/deploy_purview.json --output none >> log_connector_services_deploy.txt

echo "Adding app sp $app_object_id to Purview curator and reader roles"
app_object_id=$(az ad sp list --display-name $client_name --query "[0].objectId" -o tsv)
echo "App object id: $app_object_id"
purview_resource="/subscriptions/$subscription_id/resourcegroups/$resource_group/providers/Microsoft.Purview/accounts/$purview_name"
purview_data_curator_id=$(az role definition list --name "Purview Data Curator" --query "[].{name:name}" -o tsv)
purview_data_reader_id=$(az role definition list --name "Purview Data Reader" --query "[].{name:name}" -o tsv)
echo "purview_data_curator_id is $purview_data_curator_id" >> log_connector_services_deploy.txt
echo "purview_data_reader_id is $purview_data_reader_id" >> log_connector_services_deploy.txt
# Add client app id to purview data curator and reader roles
# https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-cli
az role assignment create --assignee $app_object_id --role $purview_data_curator_id --scope $purview_resource --output none >> log_connector_services_deploy.txt
az role assignment create --assignee $app_object_id --role $purview_data_reader_id --scope $purview_resource --output none >> log_connector_services_deploy.txt

###############################################################################
echo "Deploying Microsoft Fabric Workspace"
# NOTE: Microsoft Fabric workspace deployment requires Power BI REST API or Fabric API
# Use template for deployment - THIS WILL NEED TO BE UPDATED FOR FABRIC
params="{\"prefixName\":{\"value\":\"$base\"},"\
"\"suffixName\":{\"value\":\"$svc_suffix\"},"\
"\"fabricWorkspaceName\":{\"value\":\"$fabric_workspace_name\"}}"
# az deployment group create --resource-group $resource_group --parameters $params --template-file ./arm/deploy_fabric.json --output none >> log_connector_services_deploy.txt

echo "Setting KeyVault secret policy for Fabric Workspace"
# Allow Fabric workspace to retrieve keyvault secrets
# NOTE: This will need to be updated for Fabric workspace identity
# fabric_sp_id=$(az ... --query 'identity.principalId' -o tsv)
# az keyvault set-policy -n $key_vault_name --secret-permissions get list --object-id $fabric_sp_id --output none >> log_connector_services_deploy.txt

echo "Creating linked services in Fabric Workspace"
# Configure Fabric Notebooks and Pipelines
# NOTE: Fabric uses different approach for linked services via Lakehouse or other connections
# Add storage account name to linked service json
sed "s/<tag_storage_account>/$storage_name/g" ../fabric/linked_service/purviewaccws-WorkspaceDefaultStorage.json > ../fabric/linked_service/purviewaccws-WorkspaceDefaultStorage-tmp.json
# Create linked service in Fabric - THIS WILL NEED TO BE UPDATED FOR FABRIC API
# Fabric uses lakehouse connections or other connection types
# az ... create linked service using Fabric API
rm ../fabric/linked_service/purviewaccws-WorkspaceDefaultStorage-tmp.json

echo "Creating Fabric Spark pool"
# NOTE: Fabric Spark pools are created differently than Synapse
# In Fabric, you create a Spark compute in the workspace settings or via API
# This will need to be updated to use Fabric REST API or PowerShell cmdlets
# Create Fabric SPARK pool - PLACEHOLDER
# Add packages - In Fabric, packages are managed via environment or notebook settings
echo "Package management in Fabric is done via Spark environment or library management"

echo "Creating Fabric notebooks"
# NOTE: Fabric notebooks are imported via the Fabric UI or REST API
# The Azure CLI does not have native Fabric notebook commands
# Notebooks should be imported manually or via Fabric REST API
# az ... fabric notebook create - PLACEHOLDER FOR FABRIC API
echo "Notebooks need to be imported via Fabric workspace UI or REST API"

echo "Creating Fabric Data Pipelines"
# Build multiple substitutions for pipeline json - note sed can use any delimeter so url changed to avoid conflict with slash char
pipeline_sub="s/<tag_storage_account>/$storage_name/;"\
"s/<tag_purview_account>/$purview_name/;"\
"s/<tag_tenant_id>/$tenant_id/;"\
"s/<tag_client_id>/$client_id/;"\
"s@<tag_secret_uri>@$client_secret_uri?api-version=7.0@"
sed $pipeline_sub '../fabric/pipeline/Purview Load Custom Types.json' > '../fabric/pipeline/Purview Load Custom Types-tmp.json'
# Create pipeline in Fabric - THIS WILL NEED TO BE UPDATED FOR FABRIC API
# Fabric Data Pipelines use different API than Synapse
echo "Pipelines need to be imported via Fabric workspace UI or REST API"
# Delete the tmp json
rm '../fabric/pipeline/Purview Load Custom Types-tmp.json'

echo "Creating Fabric pipeline trigger"
# Build multiple substitutions for trigger json
pipeline_sub="s/<tag_subscription_id>/$subscription_id/;"\
"s/<tag_resource_group>/$resource_group/;"\
"s/<tag_storage_account>/$storage_name/"
sed $pipeline_sub '../fabric/trigger/Trigger Load Custom Type.json' > '../fabric/trigger/Trigger Load Custom Type-tmp.json'
# Create trigger in Fabric - THIS WILL NEED TO BE UPDATED FOR FABRIC API
echo "Triggers need to be created via Fabric workspace UI or REST API"
# Delete the tmp json
rm '../fabric/trigger/Trigger Load Custom Type-tmp.json'

##################################################################################

echo "Deploying Storage ARM Template"
# Use template for deployment
params="{\"fabricWorkspaceName\":{\"value\":\"$fabric_workspace_name\"},"\
"\"storageName\":{\"value\":\"$storage_name\"}}"
az deployment group create --resource-group $resource_group --parameters $params --template-file ./arm/deploy_storage.json --output none >> log_connector_services_deploy.txt

echo "Creating folder structure in ADLS"
# Create storage dir structure
mkdir pccsa_main; cd pccsa_main; mkdir incoming; touch ./incoming/tmp; mkdir processed; touch ./processed/tmp; cd ..
# Upload dir structure to storage
az storage fs directory upload -f pccsa --account-name $storage_name -s ./pccsa_main -d . --recursive --output none >> log_connector_services_deploy.txt
# Remove tmp directory structure
rm -r pccsa_main
# Get storage account key and add to keyvault secrets
storage_account_key=$(az storage account keys list --resource-group $resource_group --account-name $storage_name --query [0].value -o tsv)
az keyvault secret set --vault-name $key_vault_name --name storage-account-key --value $storage_account_key --output none >> log_connector_services_deploy.txt

##################################################################################
echo "Writing name output"
# Write names into bash script so they can be sourced into example deploy scripts
echo '#!/bin/bash' > ./export_names.sh
echo >> ./export_names.sh
echo "key_vault_name=$key_vault_name" >> ./export_names.sh
echo "fabric_workspace_name=$fabric_workspace_name" >> ./export_names.sh
echo "purview_name=$purview_name" >> ./export_names.sh
echo "storage_name=$storage_name" >> ./export_names.sh
echo "tenant_id=$tenant_id" >> ./export_names.sh
echo "subscription_id=$subscription_id" >> ./export_names.sh
echo "resource_group=$resource_group" >> ./export_names.sh
echo "prefix=$base" >> ./export_names.sh
echo "suffix=$svc_suffix" >> ./export_names.sh

