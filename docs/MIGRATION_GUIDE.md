# Migration Guide - Legacy to azd Deployment

This guide helps you migrate from the legacy bash script deployment (`deploy_sa.sh`) to the new Azure Developer CLI (azd) deployment.

## Why Migrate?

The new azd-based deployment offers:

| Feature | Legacy | azd |
|---------|--------|-----|
| Idempotent deployments | ❌ | ✅ |
| Custom resource group names | ❌ | ✅ |
| Reuse existing Purview | ❌ | ✅ |
| Environment management | ❌ | ✅ |
| Modern IaC (Bicep vs ARM) | ❌ | ✅ |
| Parameter validation | Limited | ✅ |
| Post-provision automation | Manual | ✅ |

## Migration Steps

### 1. Install Azure Developer CLI

**Windows:**
```powershell
winget install microsoft.azd
```

**macOS:**
```bash
brew tap azure/azd && brew install azd
```

**Linux:**
```bash
curl -fsSL https://aka.ms/install-azd.sh | bash
```

### 2. Preserve Existing Configuration

If you have an existing deployment, note your current settings:

```bash
# List current resources
az resource list --resource-group <your-rg> --output table

# Note:
# - Resource group name
# - Purview account name  
# - Storage account name
# - Key Vault name
```

### 3. Clean Up Legacy Files (Optional)

The following files are no longer needed with azd:

```bash
# These can be moved to a backup folder or deleted:
purview_connector_services/deploy/deploy_sa.sh
purview_connector_services/deploy/settings.sh
purview_connector_services/deploy/arm/*.json (ARM templates)
```

**Note**: Keep these files if you want to reference the legacy approach or maintain backward compatibility.

### 4. Initialize azd

```bash
cd Purview-Custom-Connector-Solution-Accelerator
azd init
```

### 5. Configure Environment

**If reusing existing resources:**

```bash
# Use existing resource group
azd env set AZURE_RESOURCE_GROUP "<existing-rg-name>"

# Use existing Purview account (IMPORTANT!)
azd env set PURVIEW_ACCOUNT_NAME "<existing-purview-name>"

# Set service principal credentials
azd env set AZURE_CLIENT_ID "<client-id>"
azd env set AZURE_CLIENT_SECRET "<client-secret>"
```

**For new deployment:**

```bash
# Set service principal credentials
azd env set AZURE_CLIENT_ID "<client-id>"
azd env set AZURE_CLIENT_SECRET "<client-secret>"

# Optional customizations
azd env set AZURE_RESOURCE_GROUP "my-custom-rg"
azd env set AZURE_LOCATION "eastus"
```

### 6. Deploy

```bash
azd up
```

This will:
- Use existing resources if specified
- Create missing resources
- Configure everything properly
- Run post-provision scripts

## Mapping Legacy Settings to azd

Legacy `settings.sh` → azd environment variables:

| Legacy (`settings.sh`) | azd Environment Variable | Notes |
|------------------------|-------------------------|-------|
| `location` | `AZURE_LOCATION` | Default: eastus |
| `client_name` | `AZURE_CLIENT_NAME` | Default: PurviewCustomConnectorSP |
| `client_id` | `AZURE_CLIENT_ID` | Required |
| `client_secret` | `AZURE_CLIENT_SECRET` | Required |
| (hardcoded) | `AZURE_RESOURCE_GROUP` | Now configurable! |
| (generated) | `PURVIEW_ACCOUNT_NAME` | Can reuse existing! |

## Key Differences

### Resource Naming

**Legacy:**
- Random suffix: `$RANDOM*$RANDOM`
- Format: `pccsapurview12345`
- Not reproducible

**azd:**
- Deterministic suffix: `uniqueString(subscriptionId, resourceGroup)`
- Format: `pccsapurviewabc123xyz`
- Reproducible for same subscription + RG

### Idempotency

**Legacy:**
```bash
# Running twice creates duplicate resources
./deploy_sa.sh  # Creates resources
./deploy_sa.sh  # ERROR: Resources already exist
```

**azd:**
```bash
# Running multiple times is safe
azd up  # Creates resources
azd up  # Updates/validates existing resources ✅
```

### Purview Account Handling

**Legacy:**
```bash
# Always tries to create new Purview account
# Fails if you already have one (1 per tenant limit)
```

**azd:**
```bash
# Check for existing account first
./scripts/check-purview-accounts.sh

# Reuse existing account
azd env set PURVIEW_ACCOUNT_NAME "<existing-name>"
azd up  # Uses existing account ✅
```

## Rollback Plan

If you need to revert to legacy deployment:

1. Keep legacy files (don't delete `deploy_sa.sh`)
2. Legacy deployment can coexist with azd deployment
3. Each uses separate resource groups if configured differently

## Testing Migration

**Recommended approach:**

1. **Test in new resource group first:**
   ```bash
   azd env set AZURE_RESOURCE_GROUP "pccsa-test-rg"
   azd up
   ```

2. **Verify resources:**
   ```bash
   az resource list --resource-group pccsa-test-rg --output table
   ```

3. **If satisfied, deploy to production RG:**
   ```bash
   azd env set AZURE_RESOURCE_GROUP "pccsa-prod-rg"
   azd env set PURVIEW_ACCOUNT_NAME "<existing-purview>"
   azd up
   ```

## Common Migration Scenarios

### Scenario 1: Existing Deployment, Keep Everything

```bash
azd env set AZURE_RESOURCE_GROUP "<existing-rg>"
azd env set PURVIEW_ACCOUNT_NAME "<existing-purview>"
azd env set AZURE_CLIENT_ID "<client-id>"
azd env set AZURE_CLIENT_SECRET "<client-secret>"
azd up
```

Result: ✅ Reuses everything, adds/updates as needed

### Scenario 2: Existing Purview, New Everything Else

```bash
azd env set PURVIEW_ACCOUNT_NAME "<existing-purview>"
azd env set AZURE_RESOURCE_GROUP "new-rg"
azd env set AZURE_CLIENT_ID "<client-id>"
azd env set AZURE_CLIENT_SECRET "<client-secret>"
azd up
```

Result: ✅ Reuses Purview, creates new Storage/KeyVault

### Scenario 3: Fresh Start

```bash
azd env set AZURE_CLIENT_ID "<client-id>"
azd env set AZURE_CLIENT_SECRET "<client-secret>"
azd up
```

Result: ✅ Creates everything new

## Getting Help

- **azd Documentation**: [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- **Migration Issues**: Open an issue in the GitHub repository
- **Deployment Guide**: See [DEPLOYMENT_AZD.md](./DEPLOYMENT_AZD.md)
