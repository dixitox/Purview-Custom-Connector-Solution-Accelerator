# Post-provision hook for Purview Custom Connector Solution Accelerator

Write-Host "Running post-provision configuration..." -ForegroundColor Green

# Load azd environment variables
$envVars = azd env get-values | ConvertFrom-StringData

$AZURE_CLIENT_NAME = $envVars.AZURE_CLIENT_NAME
$AZURE_SUBSCRIPTION_ID = $envVars.AZURE_SUBSCRIPTION_ID
$AZURE_RESOURCE_GROUP = $envVars.AZURE_RESOURCE_GROUP
$PURVIEW_ACCOUNT_NAME = $envVars.PURVIEW_ACCOUNT_NAME
$AZURE_LOCATION = $envVars.AZURE_LOCATION

# Get service principal object ID
Write-Host "Retrieving service principal object ID..." -ForegroundColor Yellow
$APP_OBJECT_ID = az ad sp list --display-name $AZURE_CLIENT_NAME --query "[0].id" -o tsv

if ([string]::IsNullOrEmpty($APP_OBJECT_ID)) {
    Write-Host "Error: Could not find service principal with name $AZURE_CLIENT_NAME" -ForegroundColor Red
    exit 1
}

Write-Host "Service Principal Object ID: $APP_OBJECT_ID" -ForegroundColor Cyan

# Get resource IDs
$PURVIEW_RESOURCE_ID = "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Purview/accounts/$PURVIEW_ACCOUNT_NAME"

# Purview Data Curator role
$PURVIEW_DATA_CURATOR_ROLE = "8a3c2885-9b38-4fd2-9d99-91af537c1347"
# Purview Data Reader role
$PURVIEW_DATA_READER_ROLE = "4465f953-8eca-43a9-b5b2-17be51ca8e01"

Write-Host "Assigning Purview Data Curator role..." -ForegroundColor Yellow
try {
    az role assignment create `
        --assignee $APP_OBJECT_ID `
        --role $PURVIEW_DATA_CURATOR_ROLE `
        --scope $PURVIEW_RESOURCE_ID `
        --output none 2>$null
} catch {
    Write-Host "Role assignment already exists or failed" -ForegroundColor Gray
}

Write-Host "Assigning Purview Data Reader role..." -ForegroundColor Yellow
try {
    az role assignment create `
        --assignee $APP_OBJECT_ID `
        --role $PURVIEW_DATA_READER_ROLE `
        --scope $PURVIEW_RESOURCE_ID `
        --output none 2>$null
} catch {
    Write-Host "Role assignment already exists or failed" -ForegroundColor Gray
}

# Create folder structure in ADLS
Write-Host "Creating folder structure in ADLS..." -ForegroundColor Yellow
$STORAGE_ACCOUNT_NAME = az deployment group show `
    --resource-group $AZURE_RESOURCE_GROUP `
    --name "core-resources-deployment" `
    --query "properties.outputs.storageAccountName.value" -o tsv

# Create directories using Azure CLI
try {
    az storage fs directory create `
        --name "incoming" `
        --file-system "pccsa" `
        --account-name $STORAGE_ACCOUNT_NAME `
        --auth-mode login `
        --output none 2>$null
} catch {
    Write-Host "Directory 'incoming' already exists" -ForegroundColor Gray
}

try {
    az storage fs directory create `
        --name "processed" `
        --file-system "pccsa" `
        --account-name $STORAGE_ACCOUNT_NAME `
        --auth-mode login `
        --output none 2>$null
} catch {
    Write-Host "Directory 'processed' already exists" -ForegroundColor Gray
}

Write-Host "`nPost-provision configuration completed successfully!" -ForegroundColor Green
Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "Resource Group: $AZURE_RESOURCE_GROUP"
Write-Host "Purview Account: $PURVIEW_ACCOUNT_NAME"
Write-Host "Storage Account: $STORAGE_ACCOUNT_NAME"
Write-Host "Location: $AZURE_LOCATION"
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Configure Microsoft Fabric workspace manually via the Fabric portal"
Write-Host "2. Import notebooks from purview_connector_services/Fabric/notebook/"
Write-Host "3. Import pipelines from purview_connector_services/Fabric/pipeline/"
Write-Host "4. Configure Purview root collection role assignments in Purview Studio"
