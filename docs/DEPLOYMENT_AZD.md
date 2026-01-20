# Advanced Deployment Reference

> **Quick Start**: See the [main README](../README.md) for step-by-step deployment instructions.

This document provides advanced configuration options and troubleshooting for the Azure Developer CLI (azd) deployment.

## Environment Variables Reference

All configuration via `azd env set`:

### Required
```bash
azd env set AZURE_CLIENT_ID "<service-principal-app-id>"
azd env set AZURE_CLIENT_SECRET "<service-principal-password>"
```

### Optional
```bash
azd env set AZURE_RESOURCE_GROUP "custom-rg-name"     # Default: pccsa-rg
azd env set AZURE_LOCATION "westus2"                  # Default: eastus
azd env set PURVIEW_ACCOUNT_NAME "existing-purview"   # Default: auto-generated
azd env set BASE_NAME "myapp"                         # Default: pccsa (max 7 chars)
azd env set AZURE_CLIENT_NAME "MySP"                  # Default: PurviewCustomConnectorSP
```

## Multiple Environments

```bash
# Create environments
azd env new dev
azd env new test
azd env new prod

# Configure each
azd env select dev
azd env set AZURE_RESOURCE_GROUP "pccsa-dev-rg"
azd env set AZURE_CLIENT_ID "..."
azd up

azd env select test
azd env set AZURE_RESOURCE_GROUP "pccsa-test-rg"
azd env set AZURE_CLIENT_ID "..."
azd up
```

## Reusing Existing Resources

### Existing Purview Account
```bash
# Find existing accounts
az purview account list --query "[].name" -o table

# Use existing account
azd env set PURVIEW_ACCOUNT_NAME "<existing-account-name>"
azd up
```

### Existing Resource Group
```bash
azd env set AZURE_RESOURCE_GROUP "<existing-rg-name>"
azd up
```

The deployment is idempotent - it will reuse existing resources.

## Manual Deployment (Without Interactive Script)

```bash
# 1. Initialize
azd init

# 2. Set required variables
azd env set AZURE_CLIENT_ID "<your-client-id>"
azd env set AZURE_CLIENT_SECRET "<your-client-secret>"

# 3. Set optional variables
azd env set AZURE_RESOURCE_GROUP "my-custom-rg"
azd env set PURVIEW_ACCOUNT_NAME "existing-purview"

# 4. Deploy
azd up
```

## Deployment Workflow

`azd up` performs:

1. **Provision** - Deploys Bicep templates
   - Resource group (created if doesn't exist)
   - Purview account (reused if exists)
   - Storage account with ADLS Gen2
   - Key Vault with secrets

2. **Post-Provision** - Runs hooks
   - Assigns Purview roles to service principal
   - Creates storage directory structure
   - Displays summary

## Troubleshooting

### View Deployment Logs
```bash
# azd logs
azd monitor

# Azure deployment logs
az deployment group show \
  --resource-group <your-rg> \
  --name core-resources-deployment
```

### Re-run Post-Provision Only
```bash
# Bash
./infra/hooks/postprovision.sh

# PowerShell
.\infra\hooks\postprovision.ps1
```

### Update Infrastructure Only
```bash
azd provision  # Skip post-provision hooks
```

### Delete Everything
```bash
azd down        # Deletes resource group and all resources
azd down --purge  # Also purges Key Vault
```

## Advanced Scenarios

### Custom Bicep Parameters

Edit [infra/main.parameters.json](../infra/main.parameters.json) to add custom parameters.

### Different Subscription

```bash
az account set --subscription "<subscription-id>"
azd up
```

### CI/CD Pipeline

```bash
# Use service principal for auth
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# Deploy
azd up --no-prompt
```

## File Structure

```
infra/
├── main.bicep                      # Main infrastructure template
├── main.parameters.json            # Parameter mappings
├── modules/
│   └── core-resources.bicep        # Resource definitions
└── hooks/
    ├── postprovision.sh           # Post-deployment (bash)
    └── postprovision.ps1          # Post-deployment (PowerShell)
```

## Why azd?

Benefits over legacy bash script:
- ✅ Idempotent deployments
- ✅ Custom resource group names
- ✅ Reuse existing Purview
- ✅ Environment management
- ✅ Modern IaC (Bicep vs ARM)
- ✅ Parameter validation

## Additional Resources

- [Azure Developer CLI Docs](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Microsoft Purview Docs](https://learn.microsoft.com/azure/purview/)
