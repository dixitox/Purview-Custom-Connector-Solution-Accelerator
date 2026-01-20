# Purview Custom Connector Solution Accelerator - Implementation Guide

This guide walks you through implementing the Purview Custom Connector Solution Accelerator with Microsoft Fabric.

## Prerequisites

### Required Azure Resources
- [ ] Azure Subscription with appropriate permissions (Contributor + User Access Administrator)
- [ ] Microsoft Fabric capacity or trial
- [ ] Access to create Azure resources:
  - Resource Group
  - Microsoft Purview Account
  - Azure Storage Account (ADLS Gen2)
  - Azure Key Vault
  - Service Principal (App Registration)

### Required Tools
- [ ] Azure CLI installed ([Download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- [ ] Access to Azure Cloud Shell (alternative to local Azure CLI)
- [ ] Git for cloning the repository
- [ ] Modern web browser for Fabric portal

### Required Access/Licenses
- [ ] Microsoft Fabric license (or trial)
- [ ] Power BI Pro/Premium Per User license (for Fabric access)
- [ ] Permissions to create workspaces in Fabric

---

## Implementation Steps

### Phase 1: Initial Setup (30-45 minutes)

#### Step 1.1: Create Service Principal

This service principal will be used by the solution to authenticate to Purview.

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "<your-subscription-id>"

# Create service principal
az ad sp create-for-rbac --name "PurviewCustomConnectorSP" --role Contributor

# Save the output - you'll need:
# - appId (CLIENT_ID)
# - password (CLIENT_SECRET)
# - tenant (TENANT_ID)
```

**Save these values securely** - you'll need them for configuration.

#### Step 1.2: Configure Settings File

1. Navigate to `purview_connector_services/deploy/`
2. Copy `settings.sh.rename` to `settings.sh`
3. Edit `settings.sh` with your values:

```bash
#!/bin/bash
# Location for Azure resources
location="eastus"  # or your preferred region

# Service Principal details (from Step 1.1)
client_name="PurviewCustomConnectorSP"
client_id="<YOUR_APP_ID>"
client_secret="<YOUR_CLIENT_SECRET>"
```

#### Step 1.3: Clone Repository to Cloud Shell

```bash
# In Azure Cloud Shell (Bash mode)
cd ~/clouddrive
git clone https://github.com/dixitox/Purview-Custom-Connector-Solution-Accelerator.git
cd Purview-Custom-Connector-Solution-Accelerator/purview_connector_services/deploy
```

### Phase 2: Deploy Base Azure Resources (45-60 minutes)

#### Step 2.1: Upload Settings File

1. Open Azure Cloud Shell
2. Click "Upload/Download files" button
3. Upload your configured `settings.sh` to the `purview_connector_services/deploy/` directory

#### Step 2.2: Run Deployment Script

```bash
cd ~/clouddrive/Purview-Custom-Connector-Solution-Accelerator/purview_connector_services/deploy
chmod +x deploy_sa.sh
./deploy_sa.sh
```

**What this creates:**
- ✅ Azure Resource Group
- ✅ Azure Key Vault (with client secret stored)
- ✅ Microsoft Purview Account
- ✅ Azure Storage Account (ADLS Gen2)
- ✅ Storage folder structure
- ⚠️ Note: Fabric workspace creation will need manual steps (see below)

**Expected Duration**: 30-45 minutes

#### Step 2.3: Note Deployed Resource Names

After deployment completes, resource names are saved in `export_names.sh`:

```bash
# View your deployed resources
cat export_names.sh
```

Save these names - you'll need them for Fabric configuration.

### Phase 3: Create Microsoft Fabric Workspace (15-20 minutes)

Since Fabric doesn't have ARM template deployment, create workspace manually:

#### Step 3.1: Create Fabric Workspace

1. Navigate to [Microsoft Fabric Portal](https://app.fabric.microsoft.com)
2. Click "Workspaces" → "New workspace"
3. Configure workspace:
   - **Name**: `purview-connector-fabric-ws` (or match naming from deploy script)
   - **License mode**: Fabric capacity or Trial
   - **Description**: Purview Custom Connector Solution Accelerator
4. Click "Apply"

#### Step 3.2: Enable Required Features

In your workspace settings:
1. Go to Workspace settings → Data Engineering/Science
2. Ensure Spark compute is available
3. Note your Workspace ID (found in URL or workspace settings)

### Phase 4: Configure Storage Access for Fabric (10 minutes)

Grant your Fabric workspace access to the storage account:

```bash
# Get storage account name from export_names.sh
source ~/clouddrive/Purview-Custom-Connector-Solution-Accelerator/purview_connector_services/deploy/export_names.sh

# Get your Fabric workspace identity
# This must be done via Fabric Portal or Power BI REST API

# Grant Storage Blob Data Contributor role to Fabric workspace
# (Replace <FABRIC_WORKSPACE_OBJECT_ID> with actual object ID)
az role assignment create \
  --assignee <FABRIC_WORKSPACE_OBJECT_ID> \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.Storage/storageAccounts/$storage_name"
```

### Phase 5: Create Lakehouse (10 minutes)

1. In your Fabric workspace, click "New" → "Lakehouse"
2. Name it `purview_connector_lakehouse`
3. Once created, go to Lakehouse settings
4. Add a shortcut to your ADLS Gen2 storage:
   - Source: Azure Data Lake Storage Gen2
   - Connection: Create new connection to your storage account
   - Path: `/pccsa`

### Phase 6: Import Notebooks (15 minutes)

#### Step 6.1: Prepare Notebooks for Upload

Notebooks are located in:
- `purview_connector_services/Fabric/notebook/`
- `examples/tag_db/fabric/notebook/`
- `examples/ssis/fabric/notebook/`

#### Step 6.2: Import Base Notebook

1. In Fabric workspace, click "New" → "Import notebook"
2. Upload `Purview_Load_Entity.ipynb` from `purview_connector_services/Fabric/notebook/`
3. Once imported, open the notebook
4. Attach to your Lakehouse
5. Configure Spark environment (see Step 6.3)

#### Step 6.3: Configure Spark Environment

Create a Fabric environment for Python packages:

1. In workspace, click "New" → "Environment"
2. Name it `purview_connector_env`
3. Add custom libraries from `purview_connector_services/deploy/requirements.txt`:
   - pyapacheatlas
   - (any other packages listed)
4. Publish the environment
5. Attach this environment to your notebook

### Phase 7: Import Pipelines (20 minutes)

Fabric Data Pipelines need to be created manually:

#### Step 7.1: Create Base Pipeline

1. In Fabric workspace, click "New" → "Data pipeline"
2. Name it `Purview Load Custom Types`
3. Switch to JSON view
4. Copy content from `purview_connector_services/Fabric/pipeline/Purview Load Custom Types.json`
5. Update placeholders:
   - Replace `<tag_storage_account>` with your storage account name
   - Replace `<tag_purview_account>` with your Purview account name
   - Replace `<tag_tenant_id>` with your tenant ID
   - Replace `<tag_client_id>` with your client ID
   - Replace `<tag_secret_uri>` with your Key Vault secret URI
6. Save pipeline

#### Step 7.2: Configure Pipeline Activities

Update the notebook activity:
1. Select the notebook activity
2. Point it to your imported `Purview_Load_Entity` notebook
3. Verify parameters are correctly mapped

### Phase 8: Configure Purview (20 minutes)

#### Step 8.1: Configure Purview Collection Permissions

1. Open [Purview Studio](https://web.purview.azure.com)
2. Select your Purview account
3. Navigate to Data Map → Collections
4. Select root collection
5. Go to "Role assignments" tab
6. Add your service principal to:
   - **Data Curators** role
   - **Data Readers** role

#### Step 8.2: Install Purview Custom Types Tool

1. Follow instructions at: [Purview Custom Types Tool](https://github.com/microsoft/Purview-Custom-Types-Tool-Solution-Accelerator)
2. Use your service principal credentials
3. Connect to your Purview instance

#### Step 8.3: Create Generic Entity Type

Using the Custom Types Tool:

1. Create new Service Type: `Purview Custom Connector`
2. Create new Type Definition:
   - **Name**: `purview_custom_connector_generic_entity`
   - **Super Type**: `DataSet`
   - **Attributes**:
     - `purview_qualifiedName` (string)
     - `original_source` (string)
3. Save to Azure

### Phase 9: Testing (30 minutes)

#### Step 9.1: Upload Test Data

Create a test JSON file to trigger the pipeline:

```json
{
  "typeName": "purview_custom_connector_generic_entity",
  "attributes": {
    "qualifiedName": "test://my-test-entity",
    "name": "Test Entity",
    "purview_qualifiedName": "test://my-test-entity",
    "original_source": "test"
  }
}
```

Upload to: `<storage-account>/pccsa/pccsa_main/incoming/test-entity.json`

#### Step 9.2: Trigger Pipeline Manually

1. Go to your Fabric workspace
2. Open `Purview Load Custom Types` pipeline
3. Click "Run"
4. Monitor execution

#### Step 9.3: Verify in Purview

1. Open Purview Studio
2. Navigate to Data Catalog
3. Search for your test entity
4. Verify it was created successfully

### Phase 10: Deploy Examples (Optional - 1-2 hours each)

Choose which example to deploy:

#### Option A: Tag DB Example

Follow: [Tag DB Deployment Guide](examples/tag_db/deploy/deploy_tag_db.md)

**Best for**: Understanding custom data source scanning

#### Option B: SSIS Example

Follow: [SSIS Deployment Guide](examples/ssis/deploy/deploy_ssis.md)

**Best for**: ETL lineage tracking
**Note**: More complex, requires SQL Server VM

---

## Deployment Checklist

Use this checklist to track your progress:

### Pre-Deployment
- [ ] Azure subscription access confirmed
- [ ] Fabric capacity/trial available
- [ ] Service principal created and credentials saved
- [ ] settings.sh configured

### Base Deployment
- [ ] Base Azure resources deployed (Purview, Storage, Key Vault)
- [ ] Fabric workspace created
- [ ] Storage access granted to Fabric workspace
- [ ] Lakehouse created with ADLS shortcut

### Application Deployment
- [ ] Spark environment created with packages
- [ ] Notebooks imported and attached to environment
- [ ] Pipeline imported and configured
- [ ] Pipeline parameters updated

### Purview Configuration
- [ ] Service principal added to Purview roles
- [ ] Custom Types Tool installed
- [ ] Generic entity type created

### Testing
- [ ] Test pipeline execution successful
- [ ] Entity visible in Purview catalog
- [ ] End-to-end workflow validated

---

## Troubleshooting Common Issues

### Issue: Notebook fails with "Package not found"
**Solution**: Ensure Spark environment is created and attached with pyapacheatlas package

### Issue: Pipeline can't access storage
**Solution**: Verify Fabric workspace has Storage Blob Data Contributor role on storage account

### Issue: Purview authentication fails
**Solution**: 
- Verify service principal credentials in Key Vault
- Ensure service principal has Purview Data Curator role
- Check tenant ID, client ID, and secret URI in pipeline

### Issue: Entity not appearing in Purview
**Solution**:
- Check pipeline execution logs
- Verify JSON format is correct
- Ensure generic entity type exists in Purview
- Check Purview collection permissions

---

## Next Steps After Implementation

1. **Explore Examples**: Try deploying Tag DB or SSIS examples
2. **Build Custom Connector**: Use this as template for your own data sources
3. **Automate Triggers**: Set up scheduled pipeline runs
4. **Monitor**: Use Fabric monitoring to track pipeline executions
5. **Scale**: Deploy to production Fabric capacity

---

## Support Resources

- **Fabric Documentation**: https://learn.microsoft.com/fabric/
- **Purview Documentation**: https://learn.microsoft.com/purview/
- **Original Repository**: https://github.com/microsoft/Purview-Custom-Connector-Solution-Accelerator
- **Migration Notes**: See [FABRIC_MIGRATION_NOTES.md](FABRIC_MIGRATION_NOTES.md)
- **Troubleshooting**: See [Troubleshooting.md](Troubleshooting.md)

---

## Estimated Total Time

- **Minimum deployment** (base + testing): ~3-4 hours
- **Full deployment with examples**: ~6-8 hours
- **Production-ready setup**: ~2-3 days

---

**Good luck with your implementation!** 🚀
