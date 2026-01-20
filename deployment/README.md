# Deployment Overview

This solution now supports **Azure Developer CLI (azd)** for a modern, idempotent deployment experience.

## 🚀 Quick Start

```bash
# 1. Install azd
winget install microsoft.azd  # Windows
brew install azd              # macOS

# 2. Create service principal
az ad sp create-for-rbac --name "PurviewCustomConnectorSP" --role Contributor

# 3. Initialize and configure
azd init
azd env set AZURE_CLIENT_ID "<your-appId>"
azd env set AZURE_CLIENT_SECRET "<your-password>"

# 4. Deploy
azd up
```

See [Quick Start Guide](./docs/QUICKSTART_AZD.md) for details.

## 📚 Documentation

- **[Quick Start (azd)](./docs/QUICKSTART_AZD.md)** - Get started in 5 minutes
- **[Full Deployment Guide (azd)](./docs/DEPLOYMENT_AZD.md)** - Complete documentation
- **[Migration Guide](./docs/MIGRATION_GUIDE.md)** - Migrate from legacy deployment
- **[Legacy Deployment](./purview_connector_services/deploy/deploy_sa.md)** - Original bash script approach

## ✨ Key Features

### Idempotent Deployment
Run `azd up` multiple times safely - it won't recreate existing resources.

### Custom Resource Group Names
```bash
azd env set AZURE_RESOURCE_GROUP "my-custom-rg"
```

### Reuse Existing Purview Account
Since you can only have **one Purview account per tenant**:

```bash
# Check for existing Purview accounts
./scripts/check-purview-accounts.ps1

# Use existing account
azd env set PURVIEW_ACCOUNT_NAME "<existing-purview-name>"
azd up
```

### Multi-Environment Support
```bash
azd env new dev
azd env new test  
azd env new prod
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                 Azure Subscription                   │
│                                                       │
│  ┌─────────────────────────────────────────────┐   │
│  │         Resource Group (customizable)        │   │
│  │                                               │   │
│  │  ┌──────────────┐  ┌──────────────┐         │   │
│  │  │   Purview    │  │  Storage     │         │   │
│  │  │   Account    │  │  Account     │         │   │
│  │  │ (new/exist)  │  │  (ADLS Gen2) │         │   │
│  │  └──────────────┘  └──────────────┘         │   │
│  │                                               │   │
│  │  ┌──────────────┐  ┌──────────────┐         │   │
│  │  │  Key Vault   │  │   Fabric     │         │   │
│  │  │  (secrets)   │  │  Workspace*  │         │   │
│  │  └──────────────┘  └──────────────┘         │   │
│  │                                               │   │
│  └───────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘

* Fabric Workspace requires manual configuration
```

## 📦 What Gets Deployed

| Resource | Status | Notes |
|----------|--------|-------|
| Resource Group | ✅ Auto | Created if doesn't exist |
| Purview Account | ✅ Auto | Reuses existing or creates new |
| Storage Account (ADLS Gen2) | ✅ Auto | With hierarchical namespace |
| Key Vault | ✅ Auto | Stores service principal secret |
| Storage Containers | ✅ Auto | `incoming/` and `processed/` folders |
| Role Assignments | ✅ Auto | Purview Data Curator & Reader |
| Fabric Workspace | ⚠️ Manual | Configure via Fabric portal |

## 🔧 Configuration Options

All configuration via environment variables:

```bash
# Required
azd env set AZURE_CLIENT_ID "<service-principal-id>"
azd env set AZURE_CLIENT_SECRET "<service-principal-secret>"

# Optional (with defaults)
azd env set AZURE_RESOURCE_GROUP "pccsa-rg"          # Default: pccsa-rg
azd env set AZURE_LOCATION "eastus"                   # Default: eastus
azd env set BASE_NAME "pccsa"                         # Default: pccsa
azd env set PURVIEW_ACCOUNT_NAME "<existing-name>"    # Default: auto-generated

# Service principal display name
azd env set AZURE_CLIENT_NAME "PurviewCustomConnectorSP"
```

## 🛠️ Common Commands

```bash
# Deploy everything
azd up

# Update infrastructure only
azd provision

# View environment variables
azd env get-values

# Switch environments
azd env select <env-name>

# Delete all resources
azd down
```

## 🔍 Checking Deployment

```bash
# View deployed resources
az resource list --resource-group <your-rg> --output table

# View azd environment
azd env get-values

# Check Purview account
az purview account show --name <purview-name> --resource-group <rg>
```

## ⚠️ Important Notes

### One Purview Account Per Tenant
You can only have **one Microsoft Purview account per Azure tenant**. If you already have one:

1. Check existing accounts: `./scripts/check-purview-accounts.ps1`
2. Use existing account: `azd env set PURVIEW_ACCOUNT_NAME "<name>"`

### Fabric Workspace Configuration
Microsoft Fabric workspace must be configured **manually** after deployment:

1. Create workspace in Fabric portal
2. Import notebooks from `purview_connector_services/Fabric/notebook/`
3. Import pipelines from `purview_connector_services/Fabric/pipeline/`
4. Configure connections

See [Post-Deployment Configuration](./docs/POST_DEPLOYMENT.md).

## 🆚 Comparison: Legacy vs azd

| Feature | Legacy (`deploy_sa.sh`) | New (azd) |
|---------|------------------------|-----------|
| **Idempotent** | ❌ No | ✅ Yes |
| **Custom RG Name** | ❌ No | ✅ Yes |
| **Reuse Purview** | ❌ No | ✅ Yes |
| **Environment Mgmt** | ❌ No | ✅ Yes |
| **IaC Format** | ARM Templates | Bicep |
| **Parameter Validation** | Limited | Full |
| **Deployment Command** | `./deploy_sa.sh` | `azd up` |

## 🔄 Migration from Legacy

Already using the bash script deployment? See [Migration Guide](./docs/MIGRATION_GUIDE.md).

## 📖 Additional Resources

- [Azure Developer CLI Docs](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Microsoft Purview Docs](https://learn.microsoft.com/azure/purview/)
- [Microsoft Fabric Docs](https://learn.microsoft.com/fabric/)

## 🤝 Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines.

## 📄 License

See [LICENSE](../LICENSE) for license information.
