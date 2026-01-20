# Deployment Summary

> **👉 START HERE**: Follow the step-by-step guide in [README.md](./README.md)

## What Changed

The deployment has been modernized with Azure Developer CLI (azd) for a better experience.

### ✅ Your Requirements Met

1. **Idempotent Deployment** - Run `azd up` multiple times safely
2. **Custom Resource Group Names** - Use `azd env set AZURE_RESOURCE_GROUP "your-name"`
3. **Reuse Existing Purview** - Detects and reuses existing Purview accounts (handles 1-per-tenant limit)
4. **Better Tooling** - Modern azd instead of bash scripts

## How to Deploy

### Option 1: Interactive Setup (Recommended)

**Windows:**
```powershell
.\scripts\setup.ps1
```

**Mac/Linux:**
```bash
./scripts/setup.sh
```

The script will guide you through all configuration and deploy automatically.

### Option 2: Manual Setup

```bash
# 1. Create service principal
az ad sp create-for-rbac --name "PurviewCustomConnectorSP" --role Contributor

# 2. Configure azd
azd init
azd env set AZURE_CLIENT_ID "<appId-from-step-1>"
azd env set AZURE_CLIENT_SECRET "<password-from-step-1>"

# 3. (Optional) Use existing Purview
azd env set PURVIEW_ACCOUNT_NAME "<existing-purview-name>"

# 4. (Optional) Custom resource group
azd env set AZURE_RESOURCE_GROUP "my-custom-rg"

# 5. Deploy
azd up
```

## What Gets Deployed

✅ Resource Group (your custom name or default)  
✅ Purview Account (reused if exists, created if not)  
✅ Storage Account with ADLS Gen2  
✅ Key Vault with secrets  
✅ Role assignments for service principal  
✅ Storage folder structure

## Key Commands

```bash
azd up              # Deploy everything
azd provision       # Update infrastructure only
azd env get-values  # View configuration
azd down            # Delete all resources
```

## Documentation

- **Main Guide**: [README.md](./README.md) - Step-by-step instructions
- **Advanced**: [docs/DEPLOYMENT_AZD.md](./docs/DEPLOYMENT_AZD.md) - Advanced configuration

## Important Notes

⚠️ **One Purview Per Tenant**: You can only have ONE Purview account per Azure tenant. Check for existing accounts:
```bash
.\scripts\check-purview-accounts.ps1  # Windows
./scripts/check-purview-accounts.sh   # Mac/Linux
```

✅ **Idempotent**: Safe to run multiple times - won't duplicate resources

✅ **Customizable**: Control resource group name, location, and all settings via environment variables
