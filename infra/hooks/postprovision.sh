#!/bin/bash
# Post-provision hook for Purview Custom Connector Solution Accelerator

set -e

echo "Running post-provision configuration..."

# Load azd environment variables
source <(azd env get-values)

# Get service principal object ID
echo "Retrieving service principal object ID..."
APP_OBJECT_ID=$(az ad sp list --display-name "$AZURE_CLIENT_NAME" --query "[0].id" -o tsv)

if [ -z "$APP_OBJECT_ID" ]; then
    echo "Error: Could not find service principal with name $AZURE_CLIENT_NAME"
    exit 1
fi

echo "Service Principal Object ID: $APP_OBJECT_ID"

# Get resource IDs
PURVIEW_RESOURCE_ID="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Purview/accounts/${PURVIEW_ACCOUNT_NAME}"

# Purview Data Curator role
PURVIEW_DATA_CURATOR_ROLE="8a3c2885-9b38-4fd2-9d99-91af537c1347"
# Purview Data Reader role
PURVIEW_DATA_READER_ROLE="4465f953-8eca-43a9-b5b2-17be51ca8e01"

echo "Assigning Purview Data Curator role..."
az role assignment create \
  --assignee "$APP_OBJECT_ID" \
  --role "$PURVIEW_DATA_CURATOR_ROLE" \
  --scope "$PURVIEW_RESOURCE_ID" \
  --output none 2>/dev/null || echo "Role assignment already exists or failed"

echo "Assigning Purview Data Reader role..."
az role assignment create \
  --assignee "$APP_OBJECT_ID" \
  --role "$PURVIEW_DATA_READER_ROLE" \
  --scope "$PURVIEW_RESOURCE_ID" \
  --output none 2>/dev/null || echo "Role assignment already exists or failed"

# Create folder structure in ADLS
echo "Creating folder structure in ADLS..."
STORAGE_ACCOUNT_NAME=$(az deployment group show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "core-resources-deployment" \
  --query "properties.outputs.storageAccountName.value" -o tsv)

# Create directories using Azure CLI
az storage fs directory create \
  --name "incoming" \
  --file-system "pccsa" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode login \
  --output none 2>/dev/null || echo "Directory already exists"

az storage fs directory create \
  --name "processed" \
  --file-system "pccsa" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode login \
  --output none 2>/dev/null || echo "Directory already exists"

echo "Post-provision configuration completed successfully!"
echo ""
echo "=== Deployment Summary ==="
echo "Resource Group: $AZURE_RESOURCE_GROUP"
echo "Purview Account: $PURVIEW_ACCOUNT_NAME"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Location: $AZURE_LOCATION"
echo ""
echo "Next Steps:"
echo "1. Configure Microsoft Fabric workspace manually via the Fabric portal"
echo "2. Import notebooks from purview_connector_services/Fabric/notebook/"
echo "3. Import pipelines from purview_connector_services/Fabric/pipeline/"
echo "4. Configure Purview root collection role assignments in Purview Studio"
