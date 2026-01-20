# Quick Start Guide - Purview Custom Connector with Fabric

⏱️ **Time to first working deployment: ~3-4 hours**

## Before You Start

**Have ready:**
- [ ] Azure subscription ID
- [ ] Admin access to create resources
- [ ] Microsoft Fabric capacity or trial license
- [ ] Text editor for configuration files

---

## 5-Minute Setup

### 1. Create Service Principal (5 min)

```bash
az login
az ad sp create-for-rbac --name "PurviewCustomConnectorSP" --role Contributor
```

**💾 Save the output** - Copy `appId`, `password`, and `tenant` to a secure note.

### 2. Configure Settings (2 min)

Create `settings.sh` in `purview_connector_services/deploy/`:

```bash
#!/bin/bash
location="eastus"
client_name="PurviewCustomConnectorSP"
client_id="<YOUR_APP_ID_HERE>"
client_secret="<YOUR_PASSWORD_HERE>"
```

---

## 30-Minute Azure Deployment

### 3. Run Deployment Script

```bash
# In Azure Cloud Shell
cd ~/clouddrive
git clone https://github.com/dixitox/Purview-Custom-Connector-Solution-Accelerator.git
cd Purview-Custom-Connector-Solution-Accelerator/purview_connector_services/deploy

# Upload your settings.sh file here, then:
chmod +x deploy_sa.sh
./deploy_sa.sh
```

☕ **Take a break** - This runs for ~30-45 minutes.

When complete, run:
```bash
cat export_names.sh  # Save these values!
```

---

## 30-Minute Fabric Setup

### 4. Create Fabric Workspace

1. Go to https://app.fabric.microsoft.com
2. Workspaces → New workspace
3. Name: `purview-connector-ws`
4. License: Select your Fabric capacity or trial
5. Click Apply

### 5. Create Lakehouse

1. In your workspace: New → Lakehouse
2. Name: `purview_connector_lakehouse`
3. Create

### 6. Add Storage Shortcut

1. In Lakehouse, click "..." → New shortcut
2. Source: Azure Data Lake Storage Gen2
3. Create connection to your storage account (from export_names.sh)
4. Path: `/pccsa`
5. Create shortcut

### 7. Create Spark Environment

1. In workspace: New → Environment
2. Name: `purview_env`
3. Public libraries → Add from PyPI:
   - `pyapacheatlas`
4. Publish environment

### 8. Import Notebook

1. In workspace: Import → Notebook
2. Upload: `purview_connector_services/Fabric/notebook/Purview_Load_Entity.ipynb`
3. Open notebook → Attach to `purview_env`

---

## 20-Minute Purview Setup

### 9. Configure Purview Access

1. Go to https://web.purview.azure.com
2. Select your Purview account (name from export_names.sh)
3. Data Map → Collections → Root collection
4. Role assignments → Add role assignment
5. Add your service principal to:
   - Data Curators
   - Data Readers

### 10. Install Custom Types Tool

```bash
# Follow guide at:
https://github.com/microsoft/Purview-Custom-Types-Tool-Solution-Accelerator

# Use your service principal credentials
# Connect to your Purview instance
```

### 11. Create Generic Entity Type

In Custom Types Tool:
1. New Service Type: `Purview Custom Connector`
2. New Type Definition:
   - Name: `purview_custom_connector_generic_entity`
   - Super Type: `DataSet`
   - Attributes: `purview_qualifiedName` (string), `original_source` (string)
3. Save to Azure

---

## 15-Minute Pipeline Setup

### 12. Create Pipeline

1. In Fabric workspace: New → Data pipeline
2. Name: `Purview Load Custom Types`
3. Add activity → Notebook
4. Select your `Purview_Load_Entity` notebook
5. Configure parameters (use values from export_names.sh):
   - blob_container_name: `pccsa`
   - blob_account_name: `<your_storage_name>`
   - blob_relative_path: `pccsa_main/incoming`
   - purview_name: `<your_purview_name>`
   - TENANT_ID: `<your_tenant_id>`
   - CLIENT_ID: `<your_client_id>`
   - CLIENT_SECRET: `@activity('kv-AccSecret').output.value`
   - blob_processed: `pccsa_main/processed`

6. Add activity → Web (before notebook)
   - URL: `https://<keyvault_name>.vault.azure.net/secrets/client-secret?api-version=7.0`
   - Method: GET
   - Authentication: Managed Identity
   - Resource: `https://vault.azure.net`

7. Add variable: `acc_secret` (String)

8. Save pipeline

---

## 5-Minute Test

### 13. Test End-to-End

**Create test file** `test-entity.json`:
```json
{
  "typeName": "purview_custom_connector_generic_entity",
  "attributes": {
    "qualifiedName": "test://my-first-entity",
    "name": "My First Entity",
    "purview_qualifiedName": "test://my-first-entity",
    "original_source": "test"
  }
}
```

**Upload to storage:**
```bash
az storage blob upload \
  --account-name <storage_name> \
  --container-name pccsa \
  --name pccsa_main/incoming/test-entity.json \
  --file test-entity.json \
  --auth-mode login
```

**Run pipeline:**
1. Open pipeline in Fabric
2. Click "Run"
3. Wait for completion (~2-3 minutes)

**Verify in Purview:**
1. Go to Purview Studio
2. Data Catalog → Search: "My First Entity"
3. You should see your entity! 🎉

---

## ✅ Success Checklist

You're done when you can check all these:

- [ ] Service principal created with saved credentials
- [ ] Azure resources deployed (check export_names.sh)
- [ ] Fabric workspace created with Lakehouse
- [ ] Spark environment created with pyapacheatlas
- [ ] Notebook imported and working
- [ ] Service principal has Purview permissions
- [ ] Generic entity type exists in Purview
- [ ] Pipeline created and configured
- [ ] Test entity successfully appears in Purview

---

## What's Next?

### Deploy an Example

**Option 1: Tag DB (Easier)**
```bash
cd examples/tag_db/deploy
./deploy_tag_db.sh
```

**Option 2: SSIS (Advanced)**
Follow [SSIS Deployment Guide](examples/ssis/deploy/deploy_ssis.md)

### Build Your Own Connector

1. Study the examples
2. Define your source metadata structure
3. Create custom types in Purview
4. Write parsing logic in a new notebook
5. Create pipeline to orchestrate

---

## Common Quick Fixes

**"Can't access storage"**
→ Grant Fabric workspace "Storage Blob Data Contributor" role

**"Package not found"**
→ Ensure notebook is attached to Spark environment with pyapacheatlas

**"Authentication failed"**
→ Verify service principal credentials in Key Vault
→ Check Purview role assignments

**"Entity not in Purview"**
→ Check pipeline logs in Fabric monitoring
→ Verify generic entity type exists

---

## Need Help?

📖 **Detailed guide**: [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)  
🐛 **Issues**: [Troubleshooting.md](Troubleshooting.md)  
📝 **Migration notes**: [FABRIC_MIGRATION_NOTES.md](FABRIC_MIGRATION_NOTES.md)

---

**Ready? Let's start with Step 1!** 🚀
