# Deployment Workflow

## Visual Flow

```
START
  │
  ├─> Install Prerequisites (5 min)
  │   ├─ Azure CLI
  │   └─ Azure Developer CLI (azd)
  │
  ├─> Create Service Principal (2 min)
  │   └─ az ad sp create-for-rbac --name "PurviewCustomConnectorSP"
  │       ├─ Save: appId (CLIENT_ID)
  │       ├─ Save: password (CLIENT_SECRET)
  │       └─ Save: tenant (TENANT_ID)
  │
  ├─> Check for Existing Purview (1 min)
  │   ├─ Run: .\scripts\check-purview-accounts.ps1
  │   └─ Note existing account name (if any)
  │
  ├─> Deploy via Interactive Script (5 min)
  │   ├─ Run: .\scripts\setup.ps1
  │   │   ├─ Prompts for environment name
  │   │   ├─ Prompts for service principal details
  │   │   ├─ Prompts for Purview account (reuse/create)
  │   │   ├─ Prompts for resource group name
  │   │   └─ Prompts for Azure region
  │   │
  │   └─> azd up (automated)
  │       ├─ Creates/validates resource group
  │       ├─ Deploys/reuses Purview account
  │       ├─ Creates Storage account (ADLS Gen2)
  │       ├─ Creates Key Vault + secrets
  │       └─ Runs post-provision hooks
  │           ├─ Assigns Purview roles
  │           └─ Creates storage folders
  │
  ├─> Configure Fabric Workspace (15 min) [MANUAL]
  │   ├─ Create workspace in Fabric portal
  │   ├─ Import notebooks from purview_connector_services/Fabric/notebook/
  │   ├─ Import pipelines from purview_connector_services/Fabric/pipeline/
  │   └─ Configure connections
  │
  ├─> Configure Purview (5 min) [MANUAL]
  │   ├─ Open Purview Studio
  │   ├─ Navigate to Data Map → Collections → Root
  │   └─ Add service principal to Data Curators & Data Readers roles
  │
  └─> Install Custom Types Tool (10 min)
      ├─ Visit: github.com/microsoft/Purview-Custom-Types-Tool-Solution-Accelerator
      ├─ Follow installation instructions
      └─ Create base entity type
```

## Decision Tree

```
Do you have an existing Purview account?
│
├─ YES ──> Set PURVIEW_ACCOUNT_NAME
│          azd env set PURVIEW_ACCOUNT_NAME "existing-name"
│          azd up
│
└─ NO ──> Leave PURVIEW_ACCOUNT_NAME empty
          azd up (creates new account)


Do you want a custom resource group name?
│
├─ YES ──> Set AZURE_RESOURCE_GROUP
│          azd env set AZURE_RESOURCE_GROUP "custom-rg"
│
└─ NO ──> Use default (pccsa-rg)


Running deployment multiple times?
│
└─ ✅ SAFE! Deployment is idempotent
   - Won't create duplicates
   - Updates existing resources
   - Can run azd up anytime
```

## Timeline

```
Total Time: ~45 minutes

┌─────────────────────────────────────────────────────┐
│ Automated (via setup.ps1)              │ 15 min    │
│ ├─ Prerequisites check                 │  1 min    │
│ ├─ Configuration prompts               │  2 min    │
│ ├─ Azure provisioning (azd up)         │ 10 min    │
│ └─ Post-provision hooks                │  2 min    │
├─────────────────────────────────────────────────────┤
│ Manual Steps                           │ 30 min    │
│ ├─ Fabric workspace setup              │ 15 min    │
│ ├─ Purview role assignments            │  5 min    │
│ └─ Custom Types Tool installation      │ 10 min    │
└─────────────────────────────────────────────────────┘
```

## Common Paths

### Path 1: Fresh Start (Most Common)
```bash
1. Install azd
2. Create service principal
3. Run .\scripts\setup.ps1
4. Follow prompts (accept defaults)
5. Wait for deployment
6. Configure Fabric manually
7. Configure Purview manually
```

### Path 2: Reuse Existing Purview
```bash
1. Check existing: .\scripts\check-purview-accounts.ps1
2. Note Purview account name
3. Run .\scripts\setup.ps1
4. When prompted, enter existing Purview name
5. Deployment reuses Purview, creates other resources
```

### Path 3: Manual Control
```bash
1. azd init
2. azd env set AZURE_CLIENT_ID "..."
3. azd env set AZURE_CLIENT_SECRET "..."
4. azd env set PURVIEW_ACCOUNT_NAME "..." (optional)
5. azd env set AZURE_RESOURCE_GROUP "..." (optional)
6. azd up
```

## Resource Dependencies

```
Resource Group
    │
    ├─> Key Vault
    │   └─> Stores: client-secret
    │
    ├─> Purview Account
    │   └─> Role Assignments
    │       ├─ Purview Data Curator → Service Principal
    │       └─ Purview Data Reader → Service Principal
    │
    └─> Storage Account (ADLS Gen2)
        ├─> Container: pccsa
        │   ├─> Folder: incoming/
        │   └─> Folder: processed/
        └─> Used by: Fabric Workspace (manual config)
```
