---
page_type: sample
languages:
- python
- bash
products:
- microsoft-purview
- microsoft-fabric
---
![Purview Custom Connector Solution Accelerator Banner](./assets/images/pccsa.png)

# Purview Custom Connector Solution Accelerator

## 📋 Table of Contents
- [Quick Start](#-quick-start---3-easy-steps) - Deploy in 15 minutes
- [Step-by-Step Deployment](#deployment---step-by-step) - Detailed instructions
- [Examples](#next-steps) - SSIS and Tag Database examples
- [Troubleshooting](#troubleshooting) - Common issues and solutions
- [Advanced Configuration](./docs/DEPLOYMENT_AZD.md) - Advanced deployment options

---

Microsoft Purview is a unified data governance service that helps you manage and govern your on-premises, multi-cloud, and software-as-a-service (SaaS) data. Microsoft Purview Data Map provides the foundation for data discovery and effective data governance, however, no solution can support scanning metadata for all existing data sources or lineage for every ETL tool or process that exists today. That is why Purview was built for extensibility using the open Apache Atlas API set. This API set allows customers to develop their own scanning capabilities for data sources or ETL tools which are not yet supported out of the box. This Solution Accelerator is designed to jump start the development process and provide patterns and reusable tooling to help accelerate the creation of Custom Connectors for Microsoft Purview.

The accelerator includes documentation, resources and examples to inform about the custom connector development process, tools, and APIs. It further works with utilities to make it easier to create a meta-model for your connector (Purview Custom Types Tool) with examples including ETL tool lineage as well as a custom data source. It includes infrastructure / architecture to support scanning of on-prem and complex data sources using Microsoft Fabric Spark for compute and Fabric Data Pipelines for orchestration.

## Applicability

There are multiple ways to integrate with Purview.  Apache Atlas integration (as demonstrated in this Solution Accelerator) is appropriate for most integrations.  For integrations requiring ingestion of a large amount of data into Purview / high scalability, it is recommended to integrate through the [Purview Kafka endpoint](https://docs.microsoft.com/en-us/azure/purview/manage-kafka-dotnet). This will be demonstrated through an example in a future release of this accelerator.

The examples provided demonstrate how the design and services can be used to accelerate the creation of custom connectors, but are not designed to be generic production SSIS or Tag Database connectors. Work will be required to support specific customer use cases.

## 🚀 Quick Start - 3 Easy Steps

```
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: Install Tools (5 min)                                  │
│  ├─ Azure CLI: az.ms/install-cli                               │
│  └─ Azure Developer CLI: aka.ms/install-azd                     │
├─────────────────────────────────────────────────────────────────┤
│  Step 2: Create Service Principal (2 min)                       │
│  └─ az ad sp create-for-rbac --name "PurviewCustomConnectorSP"  │
├─────────────────────────────────────────────────────────────────┤
│  Step 3: Run Setup Script (auto-deploy)                         │
│  Windows:  .\scripts\setup.ps1                                  │
│  Mac/Linux: ./scripts/setup.sh                                  │
└─────────────────────────────────────────────────────────────────┘
         ↓
    DEPLOYED ✓
```

**Total Time**: ~15 minutes (most is Azure provisioning)

## Prerequisites

- Azure Subscription with Contributor and User Access Administrator permissions
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed locally
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) installed locally
- Microsoft Fabric capacity or trial license (for Fabric workspace configuration)
- [Purview Custom Types Tool SA](https://github.com/microsoft/Purview-Custom-Types-Tool-Solution-Accelerator) - Required for running examples

## Deployment - Step by Step

### Step 1: Install Prerequisites (5 minutes)

Install Azure Developer CLI (azd):

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

### Step 2: Create Service Principal (2 minutes)

```bash
# Login to Azure
az login

# Create service principal
az ad sp create-for-rbac --name "PurviewCustomConnectorSP" --role Contributor

# SAVE THIS OUTPUT - You'll need:
# - appId (your client ID)
# - password (your client secret)
# - tenant (your tenant ID)
```

### Step 3: Check for Existing Purview Account (1 minute)

⚠️ **IMPORTANT**: You can only have **ONE Purview account per Azure tenant**.

**Windows:**
```powershell
.\scripts\check-purview-accounts.ps1
```

**macOS/Linux:**
```bash
./scripts/check-purview-accounts.sh
```

**If you have an existing Purview account, note its name - you'll reuse it in Step 5.**

### Step 4: Run Interactive Setup (3 minutes)

**Windows:**
```powershell
.\scripts\setup.ps1
```

**macOS/Linux:**
```bash
./scripts/setup.sh
```

The setup script will ask you for:
- Environment name (e.g., `dev`)
- Service principal credentials (from Step 2)
- Whether to reuse existing Purview account (from Step 3)
- Resource group name (default: `pccsa-rg`)
- Azure region (default: `eastus`)

Then it will deploy everything automatically!

### Step 5: Manual Configuration (If You Skipped Interactive Setup)

If you prefer manual configuration:

```bash
# Initialize environment
azd init

# Set required variables
azd env set AZURE_CLIENT_ID "<your-appId-from-step-2>"
azd env set AZURE_CLIENT_SECRET "<your-password-from-step-2>"

# Optional: Use existing Purview account (recommended if you have one)
azd env set PURVIEW_ACCOUNT_NAME "<your-existing-purview-account>"

# Optional: Custom resource group name
azd env set AZURE_RESOURCE_GROUP "my-custom-rg"

# Optional: Choose Azure region
azd env set AZURE_LOCATION "eastus"

# Deploy
azd up
```

### Step 6: Verify Deployment (2 minutes)

```bash
# View deployed resources
azd env get-values

# Or check in Azure Portal
az resource list --resource-group <your-resource-group> --output table
```

**What was deployed:**
✅ Resource Group (your custom name or default)  
✅ Purview Account (reused existing or created new)  
✅ Storage Account with ADLS Gen2  
✅ Key Vault (with service principal secret)  
✅ Storage folders (`/incoming`, `/processed`)  
✅ Role assignments (Purview Data Curator & Reader)

### Step 7: Configure Microsoft Fabric Workspace (10 minutes)

**Manual steps required** (Fabric workspace creation cannot be automated):

#### 7.1 Create Fabric Workspace
1. Go to [Microsoft Fabric Portal](https://app.fabric.microsoft.com)
2. Create a new workspace with Fabric capacity or trial license
3. Note your workspace name

#### 7.2 Import Core Notebook
Import the main notebook that loads entities into Purview:

**Required Notebook:**
- Location: `purview_connector_services/Fabric/notebook/Purview_Load_Entity.ipynb`
- Purpose: Core functionality to load custom entities/types into Purview

**How to import:**
1. In your Fabric workspace, click **+ New** → **Import notebook**
2. Select `Purview_Load_Entity.ipynb`
3. The notebook will be available to run

#### 7.3 Configure Storage Connection
1. In the notebook, update the storage account connection to: `pccsast6nvsfni5vtcj6` (or your deployed storage account name from Step 6)
2. Grant your service principal **Storage Blob Data Contributor** role on the storage account

> **Note**: Pipelines and triggers are **optional** and used only for automation. You can skip them initially and run the notebook manually for testing.

#### 7.4 Example Notebooks (Optional - for Testing)
The solution includes example notebooks for specific use cases:

**SSIS Example Notebooks** (location: `examples/ssis/fabric/notebook/`):
- `SSIS_Scan_Package.ipynb` - Scans SSIS packages
- `SSISDB_Get_Params.ipynb` - Gets SSIS parameters

**Tag Database Example Notebooks** (location: `examples/tag_db/fabric/notebook/`):
- `Purview_TAG_DB_Scan.ipynb` - Scans tag database metadata

Only import these if you plan to run the specific examples.

### Step 8: Configure Purview Root Collection (5 minutes)

1. Go to [Purview Studio](https://web.purview.azure.com)
2. Select your Purview account
3. Navigate to **Data Map** → **Collections** → **Root collection**
4. Click **Role assignments**
5. Add your service principal to:
   - **Data Curators** role
   - **Data Readers** role

### Step 9: Install Purview Custom Types Tool (10 minutes)

Install the companion tool to create custom entity types:

1. Visit [Purview Custom Types Tool](https://github.com/microsoft/Purview-Custom-Types-Tool-Solution-Accelerator)
2. Follow installation instructions
3. Create base entity type: `purview_custom_connector_generic_entity` (DataSet supertype)

---

## ✅ You're Done!

Your deployment is complete. You now have:
- ✅ Azure infrastructure deployed (Purview, Storage, Key Vault)
- ✅ Microsoft Fabric workspace configured
- ✅ Purview permissions configured
- ✅ Ready to run examples (SSIS, Tag Database)

## Next Steps

### Run the Examples

This accelerator includes two working examples:

**1. SSIS Package Lineage Example**
- Location: `examples/ssis/`
- Shows how to capture SSIS package execution lineage
- See [examples/ssis/ssis.md](examples/ssis/ssis.md)

**2. Tag Database Example**
- Location: `examples/tag_db/`
- Shows how to scan custom metadata from XML files
- See [examples/tag_db/tag_db.md](examples/tag_db/tag_db.md)

### Updating Your Deployment

To update infrastructure after changes:

```bash
azd provision  # Update infrastructure only
# or
azd up        # Full update
```

### Managing Multiple Environments

```bash
# Create new environments
azd env new test
azd env new prod

# Switch between them
azd env select dev
azd env select test
```

### Cleaning Up

To delete all resources:

```bash
azd down  # Deletes everything in the resource group
```

---

## Troubleshooting

### "Purview account already exists"
You can only have ONE Purview account per tenant. Reuse it:
```bash
azd env set PURVIEW_ACCOUNT_NAME "<existing-account-name>"
azd up
```

### "Service principal not found"
Verify it exists:
```bash
az ad sp list --display-name "PurviewCustomConnectorSP"
```

### "Insufficient permissions"
Ensure you have:
- Contributor role on subscription
- User Access Administrator role (for role assignments)

### Deployment fails
Check logs:
```bash
azd monitor
# or
az deployment group show --resource-group <your-rg> --name core-resources-deployment
```

---

## Additional Information

### What Gets Deployed?

| Resource | Purpose |
|----------|---------|
| **Resource Group** | Container for all resources |
| **Purview Account** | Data governance and catalog |
| **Storage Account (ADLS Gen2)** | Store incoming metadata files |
| **Key Vault** | Securely store service principal secret |
| **Role Assignments** | Grant service principal access to Purview |

### Configuration Options

All configurable via environment variables:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AZURE_CLIENT_ID` | ✅ Yes | - | Service principal ID |
| `AZURE_CLIENT_SECRET` | ✅ Yes | - | Service principal password |
| `AZURE_RESOURCE_GROUP` | No | pccsa-rg | Resource group name |
| `AZURE_LOCATION` | No | eastus | Azure region |
| `PURVIEW_ACCOUNT_NAME` | No | (auto) | Existing Purview account |
| `BASE_NAME` | No | pccsa | Base name (max 7 chars) |

### Useful Commands

```bash
azd up              # Deploy everything
azd provision       # Update infrastructure only
azd env get-values  # View configuration
azd env select      # Switch environments
azd down            # Delete all resources
```

---

## Solution Overview

### Architecture

![Purview Custom Connector Solution Accelerator Design](./assets/images/pccsa-design.svg)

This accelerator uses Microsoft Fabric for compute and orchestration. Getting and transforming source metadata is done using Fabric notebooks, and is orchestrated and combined with other Azure Services using Fabric Data Pipelines. Once a solution is developed (see development process below) running the solution involves the following steps:

1. Scan of custom source is triggered through Fabric Data Pipeline
2. Custom source notebook code pulls source data and transforms into Atlas json - predefined custom types
3. Data is written into folder in ADLS
4. Data write triggers Purview Entity import notebook pipeline
5. Scan data is written into Purview

### Connector Development Process

![pccsa_dev_processing.svg](./assets/images/pccsa_dev_process.svg)

#### Determine data available from custom source

The first step in the development process is to determine what metadata is available for the target source, and how to access the metadata. This is a foundational decision and there are often a number of considerations. Some sources might have readily accessible meta-data that can be queried through an API, others may have various file types that need to be transformed and parsed. Some sources require deep access to the virtual machine or on prem server requiring some type of agent (see the SSIS example). For some it might make sense to use the source logs as the meta-data to distinguish between what is defined in a transformation document, and what has been actually applied to the data. For examples of this process, see the [SSIS Meta-data](./examples/ssis/ssis.md#pull-ssis-meta-data) and [Tag DB Meta-data](./examples/tag_db/tag_db.md#pull-tag-db-meta-data) examples.

#### Define types for custom source

Purview uses Apache Atlas defined types which allows for inter-connectivity with existing management tools and a standardized way to define source types. After determining what meta-data is available for the particular source, the next step is how to represent that data in Purview using Atlas types. This step is called defining the meta-model and there are multiple ways this can be accomplished depending on the metadata source, and the desired visualization of the information. It is easy to derive new types from existing ones, ore create types from scratch using the [Purview Custom Type Tool](https://github.com/microsoft/Purview-Custom-Types-Tool-Solution-Accelerator). The examples in this accelerator make use of this tool to define their meta-models (see [SSIS Meta-model](./examples/ssis/ssis.md#define-the-ssis-meta-model), and [Tag DB Meta-model](./examples/tag_db/tag_db.md#define-the-tag-db-meta-model))

#### Develop script for translation of source entity data to purview entities / lineage

Meta-data parsing is one of the more time consuming aspects of Purview Custom Connector development. It is also an activity which, by its nature, is very bespoke to the particular data source targeted. The parsing examples are provided to illustrate how parsers can be plugged into the solution, and the use of generic Purview templates based on the meta-model types to transform the metadata. There are also some libraries and tools such as [Apache Tika](https://tika.apache.org/) which may be helpful for parsing certain kinds of metadata. Parsing examples can be found here: [SSIS Parsing](./examples/ssis/ssis.md#parsing-the-ssis-package), [Tag DB Parsing](./examples/tag_db/tag_db.md). The resulting entity definition file is passed to the [Purview Connector Services](./purview_connector_services/purview_connector_services.md) for ingestion into Purview.

#### Define pipeline and triggers for source connection

All of the above activities are orchestrated through a Fabric Data Pipeline. The [SSIS Pipeline](./examples/ssis/ssis.md#define-the-ssis-pipeline) demonstrates a complex example designed to mimic what is found in real customer scenarios. The [Tag DB](./examples/tag_db/tag_db.md) example focuses more on the meta-modeling and Purview visualization of the data.

Using Fabric Data Pipelines and Spark pools for connector development offers a number of advantages including:

* UI view of pipeline and parameters allowing operators to run and configure pipelines and view results in a standardized way
* Built in support for logging
* Built in scalability by running jobs in a Spark Cluster

## Getting Started

Follow the [Quick Start](#quick-start) steps above to deploy the base solution.

### Deploy Examples (Optional)

After base deployment, you can deploy examples:
* [ETL Tool Lineage (SSIS) Example Deployment](./examples/ssis/deploy/deploy_ssis.md)
* [Data Source (Tag DB) Example Deployment](./examples/tag_db/deploy/deploy_tag_db.md)

### Run Example Connectors

For Steps to run the example connectors, please see the example connector documentation ([SSIS](./examples/ssis/ssis.md#running-the-example-solution), [Tag DB](./examples/tag_db/tag_db.md#running-the-example-solution))

## Purview Development Resources

* [Tutorial](https://docs.microsoft.com/en-us/azure/purview/tutorial-using-rest-apis) on using the REST API in MS Docs
API [methods supported by Purview](https://docs.microsoft.com/en-us/azure/purview/tutorial-using-rest-apis#view-the-rest-apis-documentation)
* PyApacheAtlas
[training video](https://www.youtube.com/watch?v=4qzjnMf1GN4) and [code samples](https://github.com/wjohnson/pyapacheatlas/tree/master/samples)
[PyApacheAtlas SDK](https://pypi.org/project/pyapacheatlas/), [Docs](https://wjohnson.github.io/pyapacheatlas-docs/latest/)
* [CLI wrapper to REST API](https://github.com/tayganr/purviewcli)
Documentation​​​​​​​ and notebook samples

## Note about Libraries with MPL-2.0 and LGPL-2.1 Licenses

The following libraries are not **explicitly included** in this repository, but users who use this Solution Accelerator may need to install them locally and in Microsoft Fabric to fully utilize this Solution Accelerator. However, the actual binaries and files associated with the libraries **are not included** as part of this repository, but they are available for installation via the PyPI library using the pip installation tool.

## Contributing
This project welcomes contributions and suggestions.  Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks
This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.
