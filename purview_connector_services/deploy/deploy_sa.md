# Deployment of the Purview Custom Connector Solution Accelerator

> **⚠️ NOTICE**: This deployment method has been replaced with Azure Developer CLI (azd).
> 
> **👉 Please use the new deployment method**: See [../../README.md](../../README.md) for updated instructions.
>
> The new deployment offers:
> - ✅ Idempotent deployments (run multiple times safely)
> - ✅ Custom resource group names
> - ✅ Reuse existing Purview accounts
> - ✅ Better tooling and automation
>
> Legacy files have been moved to the `legacy/` folder for reference.

---

## Legacy Deployment Documentation

The original bash script deployment (`deploy_sa.sh`) and ARM templates are preserved in the `legacy/` folder.

For the new recommended deployment approach, see the [main README](../../README.md).

### Quick Start with New Deployment

1. Install [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
2. Run the interactive setup script:
   ```powershell
   # Windows
   .\scripts\setup.ps1
   
   # Mac/Linux  
   ./scripts/setup.sh
   ```

---

## Original Documentation (Legacy)

**Note**: The following documentation describes the legacy deployment process. It is kept for reference only.

## Services Installed
  
  ![deployed services / changes](../../assets/images/service_deploy_block.svg)

## Prerequisites

- Azure CLI installed locally ([Download](https://docs.microsoft.com/cli/azure/install-azure-cli))
- Git installed
- Bash shell (Git Bash on Windows, native on Mac/Linux)
- Azure subscription with Contributor and User Access Administrator permissions

## Deployment Steps

### Create an application identity and corresponding secret

This will be the identity used for access to the Purview workspace from the Custom Type Tool application and from the Fabric connector services. See [Create a service principal](https://docs.microsoft.com/en-us/azure/purview/tutorial-using-rest-apis#create-a-service-principal-application)

```bash
az login
az ad sp create-for-rbac --name "PurviewCustomConnectorSP" --role Contributor
```

**Save the output values** (appId, password, tenant)

### Clone the repository locally

```bash
# Clone to your local machine
git clone https://github.com/microsoft/Purview-Custom-Connector-Solution-Accelerator.git
cd Purview-Custom-Connector-Solution-Accelerator/purview_connector_services/deploy
```

### Configure application settings file

1. Copy `settings.sh.rename` to `settings.sh`
2. Edit `settings.sh` with your values:

```bash
#!/bin/bash
location="eastus"  # or your preferred region
client_name="PurviewCustomConnectorSP"
client_id="<YOUR_APP_ID>"
client_secret="<YOUR_CLIENT_SECRET>"
```

### Run the deployment script

**From VS Code Terminal (or any bash terminal):**

```bash
# Navigate to deploy directory
cd purview_connector_services/deploy

# Make executable (Mac/Linux)
chmod +x deploy_sa.sh

# Run deployment
./deploy_sa.sh
```

**From Windows (Git Bash):**

```bash
# Open Git Bash
cd /c/path/to/Purview-Custom-Connector-Solution-Accelerator/purview_connector_services/deploy
bash deploy_sa.sh
```

The script will run for approximately 30-45 minutes.

  For details about the scripts functionality, see [Reference - script actions](#reference---script-actions)

### Save deployment output

After deployment completes, save the resource names:

```bash
cat export_names.sh
```

These values will be needed for Fabric configuration.

### Configure Microsoft Fabric (Manual Steps)

⚠️ **Note:** Fabric workspace, notebooks, and pipelines must be configured manually via the Fabric portal or REST API. See the [Quick Start](#quick-start) in README.md for steps.

### [Configure your Purview catalog to trust the service principal](https://docs.microsoft.com/en-us/azure/purview/tutorial-using-rest-apis#configure-your-catalog-to-trust-the-service-principal-application)

* Open Purview Studio and select the Data Map icon in the left bar

  ![purview_root_collection.png](../../assets/images/purview_root_collection.png)

* Choose the "View Details" link on the root collection

  ![purview_root_collection_detail.png](../../assets/images/purview_root_collection_detail.png)

* Click on the 'Role assignments' tab in the root collection pane

  ![purview_root_collection_role_assignments.png](../../assets/images/purview_root_collection_role_assignments.png)

* Click on the icon next to the role name and add the application identity you created above to the following roles:
  * Data curators
  * Data readers

### Install the [Purview Custom Types Tool](https://github.com/microsoft/Purview-Custom-Types-Tool-Solution-Accelerator)

* Follow the instructions in the project readme file  
* You will need the app identity and secret you created above as well as information from the installed Purview service
* **_Note: If you are installing Node, be sure to install the LTS branch (v 14) NOT the latest (v 16)_**

## Reference - script actions

* Create resource group
* Deploy KeyVault
  * Save client secret
  * Save secret URL
* Deploy Purview
  * Add app sp to purview roles
* Deploy Microsoft Fabric Workspace
  * Add Fabric workspace to storage roles
  * Add Fabric workspace to retrieve KeyVault secrets
  * Create linked service to storage
  * Create spark pool
  * Add package dependencies (PyApacheAtlas)
  * Import notebooks
  * Import pipelines
  * Import trigger
* Deploy Storage Account
  * Create folder structure
  * Save storage account key to KeyVault secret
* Write output name variables to file for use in other deployments

## Privacy

To opt out of information collection as described in [privacy.md](../../PRIVACY.md), remove the GUID section from all templates in the Purview-Custom-Connector-Solution-Accelerator/purview_connector_services/deploy/arm directory
