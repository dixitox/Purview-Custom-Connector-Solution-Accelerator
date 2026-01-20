# Deployment Guide - Azure Developer CLI (azd)

This guide describes how to deploy the Purview Custom Connector Solution Accelerator using Azure Developer CLI (azd). The deployment is fully idempotent and supports custom resource group names and reusing existing Purview accounts.

## Why Azure Developer CLI (azd)?

We've migrated to `azd` for the following benefits:

- **Idempotent Deployments**: Run deployment multiple times without issues
- **Environment Management**: Easy management of multiple environments (dev, test, prod)
- **Modern Infrastructure as Code**: Uses Bicep instead of ARM templates
- **Simplified Workflow**: Single command to provision and configure all resources
- **Better Parameter Management**: Environment-based configuration with validation

## Prerequisites

1. **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
2. **Azure Developer CLI (azd)** - [Install azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
3. **Azure Subscription** - With Contributor and User Access Administrator permissions
4. **Service Principal** - Created in advance (see below)

## Step 1: Create Service Principal

Before deployment, create a service principal that will be used for Purview access:

```bash
# Login to Azure
az login

# Create service principal
az ad sp create-for-rbac --name "PurviewCustomConnectorSP" --role Contributor

# Save the output values:
# - appId (will be AZURE_CLIENT_ID)
# - password (will be AZURE_CLIENT_SECRET)
# - tenant (will be AZURE_TENANT_ID)
```

## Step 2: Check for Existing Purview Accounts

Since you can only have **one Purview account per Azure tenant**, check if one already exists:

**PowerShell:**
```powershell
.\scripts\check-purview-accounts.ps1
```

**Bash:**
```bash
./scripts/check-purview-accounts.sh
```

This script will list any existing Purview accounts and show you how to configure the deployment to use them.

## Step 3: Initialize azd Environment

```bash
# Navigate to the project root
cd Purview-Custom-Connector-Solution-Accelerator

# Initialize a new azd environment
azd init
```

When prompted, provide:
- **Environment Name**: `dev` (or your preferred name)
- **Subscription**: Select your Azure subscription

## Step 4: Configure Environment Variables

Set the required environment variables:

```bash
# Required: Service Principal credentials
azd env set AZURE_CLIENT_ID "<your-service-principal-appId>"
azd env set AZURE_CLIENT_SECRET "<your-service-principal-password>"
azd env set AZURE_CLIENT_NAME "PurviewCustomConnectorSP"

# Optional: Custom resource group name (default: pccsa-rg)
azd env set AZURE_RESOURCE_GROUP "my-custom-rg"

# Optional: Azure region (default: eastus)
azd env set AZURE_LOCATION "eastus"

# Optional: Base name for resources (default: pccsa, max 7 chars)
azd env set BASE_NAME "pccsa"

# Optional: Use existing Purview account (if you have one)
azd env set PURVIEW_ACCOUNT_NAME "<existing-purview-account-name>"
```

### Environment Variable Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AZURE_CLIENT_ID` | ✅ Yes | - | Service principal application ID |
| `AZURE_CLIENT_SECRET` | ✅ Yes | - | Service principal password |
| `AZURE_CLIENT_NAME` | No | PurviewCustomConnectorSP | Service principal display name |
| `AZURE_RESOURCE_GROUP` | No | pccsa-rg | Resource group name |
| `AZURE_LOCATION` | No | eastus | Azure region |
| `BASE_NAME` | No | pccsa | Base name for resources (max 7 chars) |
| `PURVIEW_ACCOUNT_NAME` | No | (auto-generated) | Existing or new Purview account name |

## Step 5: Deploy

Run a single command to provision all resources:

```bash
azd up
```

This command will:
1. Provision Azure infrastructure (Bicep templates)
2. Create resource group (if it doesn't exist)
3. Deploy or reference existing Purview account
4. Create Storage account with ADLS Gen2
5. Create Key Vault and store secrets
6. Run post-provision scripts to:
   - Assign Purview roles to service principal
   - Create storage directory structure
   - Display deployment summary

The deployment is **idempotent** - you can run it multiple times safely.

## Step 6: Verify Deployment

After deployment completes, verify the resources:

```bash
# List all resources in the resource group
az resource list --resource-group <your-resource-group> --output table

# Or using azd
azd env get-values
```

## Reusing Existing Purview Account

If you already have a Purview account and want to use it:

```bash
# Set the existing Purview account name
azd env set PURVIEW_ACCOUNT_NAME "<existing-purview-account-name>"

# Deploy (will use existing account instead of creating new one)
azd up
```

The deployment will:
- ✅ Use the existing Purview account
- ✅ Not attempt to create a new one
- ✅ Configure role assignments on the existing account
- ✅ Create other resources (Storage, Key Vault) as needed

## Custom Resource Group Name

To use a custom resource group name:

```bash
# Set custom resource group name
azd env set AZURE_RESOURCE_GROUP "my-purview-rg"

# Deploy
azd up
```

If the resource group doesn't exist, it will be created. If it exists, resources will be deployed into it (idempotent).

## Managing Multiple Environments

azd supports multiple environments (dev, test, prod):

```bash
# Create a new environment
azd env new test

# Configure test environment
azd env set AZURE_CLIENT_ID "<test-sp-id>"
azd env set AZURE_CLIENT_SECRET "<test-sp-secret>"
azd env set AZURE_RESOURCE_GROUP "purview-test-rg"

# Deploy to test environment
azd up

# Switch between environments
azd env select dev
azd env select test
```

## Updating Deployment

To update resources after changing Bicep templates:

```bash
# Re-provision infrastructure
azd provision
```

## Cleaning Up

To delete all resources:

```bash
# Delete all resources in the environment
azd down

# Delete with confirmation prompt
azd down --purge
```

⚠️ **Note**: This will delete the resource group and all contained resources. Use with caution.

## Troubleshooting

### Issue: "Purview account already exists"

This means you already have a Purview account in your tenant. You can only have one per tenant.

**Solution**: Use the existing account:
```bash
azd env set PURVIEW_ACCOUNT_NAME "<existing-account-name>"
azd up
```

### Issue: "Service principal not found"

Ensure the service principal exists and the name matches:
```bash
az ad sp list --display-name "PurviewCustomConnectorSP"
```

### Issue: "Insufficient permissions"

Ensure you have:
- Contributor role on the subscription
- User Access Administrator role (for role assignments)

### Viewing Deployment Logs

```bash
# View azd logs
azd monitor

# View Azure deployment logs
az deployment group show \
  --resource-group <your-rg> \
  --name core-resources-deployment
```

## Next Steps

After successful deployment:

1. **Configure Fabric Workspace** - Manually create and configure via Fabric portal
2. **Import Notebooks** - Upload notebooks from `purview_connector_services/Fabric/notebook/`
3. **Import Pipelines** - Upload pipelines from `purview_connector_services/Fabric/pipeline/`
4. **Configure Purview** - Set up root collection role assignments in Purview Studio

See [Post-Deployment Configuration](./POST_DEPLOYMENT.md) for detailed steps.

## Comparison with Legacy Deployment

| Feature | Legacy (deploy_sa.sh) | New (azd) |
|---------|----------------------|-----------|
| Idempotent | ❌ No | ✅ Yes |
| Custom RG Name | ❌ No | ✅ Yes |
| Reuse Purview | ❌ No | ✅ Yes |
| Environment Management | ❌ No | ✅ Yes |
| Parameter Validation | ❌ Limited | ✅ Yes |
| Modern IaC | ❌ ARM Templates | ✅ Bicep |
| Single Command | ❌ No | ✅ Yes |

## Additional Resources

- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Microsoft Purview Documentation](https://learn.microsoft.com/azure/purview/)
