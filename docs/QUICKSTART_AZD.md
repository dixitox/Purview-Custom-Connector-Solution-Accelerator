# Quick Start - Azure Developer CLI (azd)

Deploy the Purview Custom Connector Solution Accelerator in minutes using Azure Developer CLI.

## 1. Prerequisites (2 minutes)

Install required tools:

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)

## 2. Create Service Principal (2 minutes)

```bash
az login
az ad sp create-for-rbac --name "PurviewCustomConnectorSP" --role Contributor
```

**Save the output** - you'll need `appId`, `password`, and `tenant`

## 3. Check for Existing Purview (1 minute)

**PowerShell:**
```powershell
.\scripts\check-purview-accounts.ps1
```

**Bash:**
```bash
./scripts/check-purview-accounts.sh
```

## 4. Configure & Deploy (3 minutes)

```bash
# Initialize azd
azd init

# Set required variables
azd env set AZURE_CLIENT_ID "<your-appId>"
azd env set AZURE_CLIENT_SECRET "<your-password>"

# Optional: Use existing Purview account
azd env set PURVIEW_ACCOUNT_NAME "<existing-purview-name>"

# Optional: Custom resource group name
azd env set AZURE_RESOURCE_GROUP "my-custom-rg"

# Deploy everything
azd up
```

## 5. Post-Deployment (Manual)

After deployment:

1. **Create Fabric Workspace** in Fabric portal
2. **Import Notebooks** from `purview_connector_services/Fabric/notebook/`
3. **Import Pipelines** from `purview_connector_services/Fabric/pipeline/`
4. **Configure Purview** root collection in Purview Studio

## What Gets Deployed?

- ✅ Resource Group (custom name supported)
- ✅ Purview Account (new or existing)
- ✅ Storage Account with ADLS Gen2
- ✅ Key Vault with secrets
- ✅ Role assignments for service principal
- ✅ Storage directory structure

## Key Features

- **Idempotent**: Run multiple times safely
- **Custom RG**: Use your own resource group name
- **Reuse Purview**: Use existing Purview account (required - only 1 per tenant)
- **Environment Management**: Support dev/test/prod environments

## Update Deployment

```bash
azd provision  # Re-deploy infrastructure only
```

## Clean Up

```bash
azd down  # Delete all resources
```

## Need Help?

See [Full Deployment Guide](./DEPLOYMENT_AZD.md) for detailed instructions.
