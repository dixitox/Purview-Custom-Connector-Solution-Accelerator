# Deployment Changes Summary

## Overview

The Purview Custom Connector Solution Accelerator deployment has been modernized using **Azure Developer CLI (azd)** to address your requirements:

✅ **Idempotent deployments** - Run multiple times without issues  
✅ **Custom resource group names** - Full control over RG naming  
✅ **Reuse existing Purview accounts** - Handle the one-per-tenant limitation  
✅ **Better tooling** - Evaluated and implemented azd for deployment

## What's New

### 📁 New Files Created

#### Infrastructure (Bicep)
- `infra/main.bicep` - Main infrastructure template
- `infra/modules/core-resources.bicep` - Core resource definitions
- `infra/main.parameters.json` - Parameter mappings
- `infra/hooks/postprovision.sh` - Post-deployment automation (bash)
- `infra/hooks/postprovision.ps1` - Post-deployment automation (PowerShell)

#### Configuration
- `azure.yaml` - azd project configuration
- `.azure/config.json` - azd settings
- `.azure/env.template` - Environment variable template
- `.gitignore` - Ignore azd environment files

#### Scripts
- `scripts/check-purview-accounts.sh` - Check for existing Purview (bash)
- `scripts/check-purview-accounts.ps1` - Check for existing Purview (PowerShell)

#### Documentation
- `docs/QUICKSTART_AZD.md` - 5-minute quick start guide
- `docs/DEPLOYMENT_AZD.md` - Comprehensive deployment guide
- `docs/MIGRATION_GUIDE.md` - Migration from legacy deployment
- `deployment/README.md` - Deployment overview

## Key Features

### 1. Idempotent Deployment

**Before (Legacy):**
```bash
./deploy_sa.sh  # Creates resources
./deploy_sa.sh  # ❌ ERROR: Resources already exist
```

**After (azd):**
```bash
azd up  # Creates resources
azd up  # ✅ Updates/validates existing resources
```

### 2. Custom Resource Group Names

**Before (Legacy):**
```bash
# Resource group name was hardcoded as: pccsa_rg_<random>
# No way to customize
```

**After (azd):**
```bash
# Full control over resource group name
azd env set AZURE_RESOURCE_GROUP "my-custom-rg"
azd up
```

### 3. Reuse Existing Purview Account

**Before (Legacy):**
```bash
# Always tried to create new Purview account
# Failed if you already had one (1 per tenant limit)
```

**After (azd):**
```bash
# Check for existing accounts
./scripts/check-purview-accounts.ps1

# Reuse existing account
azd env set PURVIEW_ACCOUNT_NAME "existing-purview"
azd up  # ✅ Uses existing account
```

### 4. Modern Infrastructure as Code

**Before (Legacy):**
- ARM Templates (JSON)
- Manual parameter substitution with `sed`
- Hardcoded values

**After (azd):**
- Bicep (modern, readable)
- Type-safe parameters
- Environment-based configuration
- Built-in validation

## Configuration Comparison

### Legacy (`settings.sh`)
```bash
#!/bin/bash
location="eastus"
client_name="PurviewCustomConnectorSP"
client_id="<hardcoded>"
client_secret="<hardcoded>"
# Resource group: NOT CONFIGURABLE
# Purview account: NOT CONFIGURABLE
```

### azd (Environment Variables)
```bash
# Required
azd env set AZURE_CLIENT_ID "<value>"
azd env set AZURE_CLIENT_SECRET "<value>"

# Optional (customizable!)
azd env set AZURE_RESOURCE_GROUP "custom-rg"
azd env set PURVIEW_ACCOUNT_NAME "existing-purview"
azd env set AZURE_LOCATION "westus2"
azd env set BASE_NAME "myapp"
```

## Deployment Workflow

### Quick Start (5 minutes)

```bash
# 1. Install azd
winget install microsoft.azd

# 2. Create service principal
az ad sp create-for-rbac --name "PurviewCustomConnectorSP" --role Contributor

# 3. Check for existing Purview (important!)
./scripts/check-purview-accounts.ps1

# 4. Configure
azd init
azd env set AZURE_CLIENT_ID "<appId>"
azd env set AZURE_CLIENT_SECRET "<password>"
azd env set PURVIEW_ACCOUNT_NAME "<existing-name>"  # If you have one

# 5. Deploy
azd up
```

### What Happens During `azd up`

1. **Provision Phase**
   - Creates/validates resource group
   - Deploys/references Purview account (idempotent)
   - Creates Storage account with ADLS Gen2
   - Creates Key Vault and stores secrets
   - All operations are idempotent

2. **Post-Provision Phase** (automated hooks)
   - Assigns Purview Data Curator role to service principal
   - Assigns Purview Data Reader role to service principal
   - Creates storage directory structure (`incoming/`, `processed/`)
   - Displays deployment summary

3. **Manual Steps** (Fabric workspace)
   - Create Fabric workspace in portal
   - Import notebooks
   - Import pipelines
   - Configure connections

## Environment Management

azd supports multiple environments:

```bash
# Create environments
azd env new dev
azd env new test
azd env new prod

# Configure dev environment
azd env select dev
azd env set AZURE_RESOURCE_GROUP "pccsa-dev-rg"
azd env set AZURE_CLIENT_ID "..."
azd up

# Configure test environment
azd env select test
azd env set AZURE_RESOURCE_GROUP "pccsa-test-rg"
azd env set AZURE_CLIENT_ID "..."
azd up

# Switch between environments
azd env select dev
azd env select test
```

## Migration from Legacy

For existing deployments using `deploy_sa.sh`:

1. **Keep existing resources** - azd can manage them
2. **Note existing names** - Resource group, Purview account
3. **Configure azd** with existing names
4. **Run `azd up`** - Will validate/update existing resources

See [MIGRATION_GUIDE.md](./docs/MIGRATION_GUIDE.md) for details.

## Benefits Summary

| Benefit | Description |
|---------|-------------|
| **Idempotency** | Safe to run multiple times, no duplicates |
| **Customization** | Control resource group name, location, etc. |
| **Reusability** | Reuse existing Purview account (1 per tenant) |
| **Environment Mgmt** | Separate dev/test/prod configurations |
| **Modern IaC** | Bicep instead of ARM templates |
| **Validation** | Parameter validation before deployment |
| **Automation** | Post-provision hooks for role assignments |
| **Documentation** | Comprehensive guides and examples |

## File Structure

```
Purview-Custom-Connector-Solution-Accelerator/
├── azure.yaml                          # azd project config
├── .azure/
│   ├── config.json                     # azd settings
│   └── env.template                    # Environment template
├── .gitignore                          # Ignore azd files
├── infra/
│   ├── main.bicep                      # Main infrastructure
│   ├── main.parameters.json            # Parameter mappings
│   ├── modules/
│   │   └── core-resources.bicep        # Core resources
│   └── hooks/
│       ├── postprovision.sh            # Post-deployment (bash)
│       └── postprovision.ps1           # Post-deployment (PowerShell)
├── scripts/
│   ├── check-purview-accounts.sh       # Check Purview (bash)
│   └── check-purview-accounts.ps1      # Check Purview (PowerShell)
├── docs/
│   ├── QUICKSTART_AZD.md              # Quick start guide
│   ├── DEPLOYMENT_AZD.md              # Full deployment guide
│   └── MIGRATION_GUIDE.md             # Migration guide
└── deployment/
    └── README.md                       # Deployment overview
```

## Next Steps

1. **Review Documentation**
   - [Quick Start](./docs/QUICKSTART_AZD.md) - Get started quickly
   - [Full Guide](./docs/DEPLOYMENT_AZD.md) - Comprehensive details
   - [Migration](./docs/MIGRATION_GUIDE.md) - Migrate from legacy

2. **Test Deployment**
   ```bash
   # Test in new resource group first
   azd env set AZURE_RESOURCE_GROUP "pccsa-test-rg"
   azd up
   ```

3. **Check Existing Purview**
   ```bash
   # Very important - only one per tenant!
   ./scripts/check-purview-accounts.ps1
   ```

4. **Deploy**
   ```bash
   azd up
   ```

## Support

- **Documentation**: See `docs/` folder
- **Issues**: Open GitHub issue
- **Migration**: See [MIGRATION_GUIDE.md](./docs/MIGRATION_GUIDE.md)

## Conclusion

The new azd-based deployment provides:
- ✅ Idempotent deployments
- ✅ Custom resource group names  
- ✅ Reuse existing Purview accounts
- ✅ Better tooling (azd > bash scripts)
- ✅ Modern IaC (Bicep > ARM)
- ✅ Comprehensive documentation

All requirements have been met! 🎉
