
# Tag DB Custom Connector

This Sample will allow you to scan TAG DB metadata, exported from the TAG DB API. With some small changes you should be able to use the TAG DB SDK to direcly connect to the TAG DB and extract in real time. With this sample you will be able to:

- Read TAG DB Metadata XML file and trransform into json
- Load into a folder to be processed by [Purview Custom Connector Solution Accelerator](https://github.com/microsoft/Purview-Custom-Connector-Solution-Accelerator), to be uploaded to Purview Catalog
- Monitor the process end to end
- Automate the metadata capture
  - Scheduling
  - Triggered by File event

![Purview TAG DB Custom Metadata Scanner](../../assets/images/tag_db_diagram.svg)

## Pull Tag DB Meta-data

You should be able to export TAG DB metadata way to export Metadata from TAG DB Server (xml format)

## Define the Tag DB Meta-model

The TAG DB module was design following the hierarchical structure of the tags it is composed by:

1. AFDatabase - it is the root and has one or more AFElement
    1. AFElement - Has relationship with multiples AFElement
        1. AFAttribute
        2. AFAnalysis

![TAG DB Metadata Hierarchy](../../assets/images/AF_Hierarchy.svg)

## Running the Example Solution

### Prerequisites

1. Deploy the 'Purview Custom Connector Solution Accelerator' - [Deploy Solution](../../README.md#deployment)
2. Install the 'Purview Custom Types Tool' - [Download](https://github.com/microsoft/Purview-Custom-Types-Tool-Solution-Accelerator/releases)
3. Have TAG DB metadata exported as XML files

### Step 1: Create Storage Folders

Create the following folders in your storage account container (e.g., `pccsa`):

```bash
# Using Azure CLI
az storage fs directory create --name tag-db-xml --file-system pccsa --account-name <your-storage-account> --auth-mode login
az storage fs directory create --name tag-db-json --file-system pccsa --account-name <your-storage-account> --auth-mode login
az storage fs directory create --name tag-db-purview-json --file-system pccsa --account-name <your-storage-account> --auth-mode login
az storage fs directory create --name tag-db-processed --file-system pccsa --account-name <your-storage-account> --auth-mode login
```

**Folder Structure and Purpose:**

- `tag-db-xml/` - Source XML files exported from TAG DB
- `tag-db-json/` - Converted JSON files (intermediate format for scanner)
- `tag-db-purview-json/` - Purview-ready entity JSON (scanner output)
- `tag-db-processed/` - Archive of processed files

### Step 2: Convert XML to JSON

TAG DB exports metadata as XML, but the scanner requires JSON format. Convert your XML files:

**Option A: Using Python Script (for testing)**

```bash
# Install required package
pip install xmltodict

# Run the conversion script
python examples/tag_db/convert_xml_to_json.py
```

**Option B: Using Fabric Pipeline (for production)**

Import and configure the `Convert TAG DB XML Metadata to Json` pipeline from `examples/tag_db/fabric/pipeline/`.

**Upload converted JSON to storage:**

```bash
az storage blob upload --account-name <storage-account> --container-name pccsa \
  --name tag-db-json/your-file.json --file converted-file.json --auth-mode login
``` 

### Step 3: Create Custom Entity Types in Purview

For general Atlas type information, review the resource list in [README.MD](../../README.MD#purview-development-resources).

1. **Launch Purview Custom Types Tool** and connect to your Purview account
2. **Create New Service Type**: Name it `TAG_DB` or `osi_pi`

Create the following entity types in order:

#### Entity Type 1: afdatabase
- **Category**: Entity
- **Super Type**: Asset
- **Name**: `afdatabase`
- **Attributes**:
  - `DefaultPIServer` (string, required, unique)
  - `DefaultPIServerID` (string, required, unique)

#### Entity Type 2: afelement
- **Category**: Entity
- **Super Type**: Asset  
- **Name**: `afelement`
- **Attributes**:
  - `Template` (string, optional, unique)
  - `IsAnnotated` (int, optional, unique)
  - `Modifier` (string, optional, unique)
  - `Comment` (string, optional, unique)
  - `EffectiveDate` (string, optional, unique)
  - `ObsoleteDate` (date, optional, unique)

#### Entity Type 3: afattribute
- **Category**: Entity
- **Super Type**: Asset
- **Name**: `afattribute`
- **Attributes**: 13 attributes (see [tag_db_type_def.json](meta_model/tag_db_type_def.json) for complete list)

#### Entity Type 4: afanalysis
- **Category**: Entity
- **Super Type**: Asset
- **Name**: `afanalysis`
- **Attributes**: 8 attributes (see [tag_db_type_def.json](meta_model/tag_db_type_def.json) for complete list)

#### Relationship Types

Create these composition relationships:

1. **afdatabase_afelement**: Links AFDatabase to AFElements
2. **afelement_afelement**: Parent-child AFElement hierarchy
3. **afelement_afattribute**: Links AFElement to AFAttributes
4. **afelement_afanalysis**: Links AFElement to AFAnalyses

**Save all types to Azure** before proceeding.

### Step 4: Configure and Run TAG DB Scanner Notebook

1. **Import notebook** to Fabric workspace: `examples/tag_db/fabric/notebook/Purview_TAG_DB_Scan.ipynb`

2. **Update Cell 2 configuration**:

```python
# Storage Configuration
blob_container_name = "pccsa"  # Your container name
blob_account_name = "your-storage-account"
blob_relative_path = "tag-db-json"  # Reads JSON files (not XML)
blob_processed = "tag-db-processed"
out_file = "tag-db-purview-json"

# Purview Configuration  
app_name = "your-service-principal-name"
key_vault_uri = "https://your-keyvault.vault.azure.net/"
purview_account_name = "your-purview-account"
```

3. **Run the notebook** - it will:
   - Read JSON files from `tag-db-json/`
   - Parse TAG DB hierarchy
   - Generate Purview entity JSON in `tag-db-purview-json/`
   - Move processed files to `tag-db-processed/`

### Step 5: Load Entities into Purview

**Option A: Copy to incoming folder**

```bash
# Copy TAG DB output to incoming folder
az storage blob copy start --account-name <storage> --destination-container pccsa \
  --destination-blob incoming/tagdb-entities.json \
  --source-container pccsa --source-blob tag-db-purview-json/<output-file>.json \
  --auth-mode login
```

Then run the main **Purview_Load_Entity** notebook.

**Option B: Create dedicated loader notebook**

Duplicate `Purview_Load_Entity` and update Cell 2:
```python
storage_path = "tag-db-purview-json"  # Read from TAG DB output
processed_path = "tag-db-json"         # Archive location
```

### Step 6: Verify in Purview

1. Open [Microsoft Purview Governance Portal](https://web.purview.azure.com/)
2. Navigate to **Data Catalog** → **Browse** or **Search**
3. Search for: `osipi://` or your database name (e.g., `DB_Operational`)
4. Verify the hierarchical structure:
   - AFDatabase entities
   - Nested AFElement hierarchy
   - AFAttribute and AFAnalysis relationships

## Quick Start with Sample Data

To test with the provided sample:

```bash
# 1. Upload sample XML
az storage blob upload --account-name <storage> --container-name pccsa \
  --name tag-db-xml/tag-db-xml-sample.xml \
  --file examples/tag_db/example_data/tag-db-xml-sample.xml --auth-mode login

# 2. Convert to JSON
python examples/tag_db/convert_xml_to_json.py

# 3. Upload JSON
az storage blob upload --account-name <storage> --container-name pccsa \
  --name tag-db-json/tag-db-xml-sample.json \
  --file examples/tag_db/example_data/tag-db-xml-sample.json --auth-mode login

# 4. Run TAG DB Scanner notebook in Fabric
# 5. Run Purview_Load_Entity notebook in Fabric
# 6. Verify in Purview portal
```

## Production Deployment

For production use:

1. **Automate XML to JSON conversion** using the Fabric pipeline
2. **Schedule the TAG DB Scanner** notebook to run periodically
3. **Set up event-driven triggers** to process new files automatically
4. **Monitor processing** through Fabric monitoring tools

### Create types in Purview (DEPRECATED - See Step 3 above)

For general Atlas type information review the resource list in [README.MD](../../README.MD#purview-development-resources)

* After configuring and starting the Purview Custom Types tool, you will be presented with a drop down allowing you to create a new service type (think of this like a grouping of all the types for a particular connector project), or a view of all types. We wil be creating new types for TAG DB, let select 'Create New Service Type' and on the next screen name it 'TAG DB'
  ![pcttsa_select_service_type.png](../../assets/images/pcttsa_select_service_type.png)
* In the 'New Type Definition' Screen:
    * Select 'Category' as Entity.
        * Super Type = Dataset
        * Name = 'afdatabase'
        * Attibutes:
        
| Attribute Name    | Data Type | Cardinality  | Optional?    | Unique? |
| :---------------- | :-------- | :----------- | :----------- | :------ |
| DefaultPIServer   | string    | Single       | not Optional | Unique  |
| DefaultPIServerID | string    | Single       | not Optional | Unique  |

![AFDatabase](../../assets/images/crate_entity_afdatabase.svg)

* Save to Azure

* In the 'New Type Definition' Screen:
    * Select 'Category' as Entity.
        * Super Type = Dataset
        * Name = 'afelement'
        * Attibutes:

| Attribute Name    | Data Type | Cardinality  | Optional?    | Unique? |
| :---------------- | :-------- | :----------- | :----------- | :------ |
| Template          | string    | Single       | is Optional  | Unique  |
| IsAnnotated       | string    | Single       | is Optional  | Unique  |
| Modifier          | string    | Single       | is Optional  | Unique  |
| Comment           | string    | Single       | is Optional  | Unique  |
| EffectiveDate     | string    | Single       | is Optional  | Unique  |
| ObsoleteDate      | date      | Single       | is Optional  | Unique  |

![AFElement](../../assets/images/afelement.svg)

* Save to Azure

* In the 'New Type Definition' Screen:
    * Select 'Category' as Entity.
        * Super Type = Dataset
        * Name = 'afattribute'
        * Attibutes:

| Attribute Name         | Data Type | Cardinality  | Optional?    | Unique? |
| :--------------------- | :-------- | :----------- | :----------- | :------ |
| IsHidden               | int       | Single       | not Optional | Unique  |
| IsManualDataEntry      | int       | Single       | not Optional | Unique  |
| IsConfigurationItem    | int       | Single       | not Optional | Unique  |
| IsExcluded             | int       | Single       | not Optional | Unique  |
| Trait                  | string    | Single       | is Optional  | Unique  |
| DefaultUOM             | string    | Single       | is Optional  | Unique  |
| DisplayDigits          | int       | Single       | not Optional | Unique  |
| Type                   | string    | Single       | is Optional  | Unique  |
| TypeQualifier          | string    | Single       | is Optional  | Unique  |
| DataReference          | string    | Single       | is Optional  | Unique  |
| ConfigString           | string    | Single       | is Optional  | Unique  |
| Value                  | string    | Single       | is Optional  | Unique  |
| AFAttributeCategoryRef | string    | Single       | is Optional  | Unique  |

![AFAttribute](../../assets/images/afattribute.svg)

* In the 'New Type Definition' Screen:
    * Select 'Category' as Entity.
        * Super Type = Dataset
        * Name = 'afanalysis'
        * Attibutes:

| Attribute Name         | Data Type | Cardinality  | Optional?    | Unique? |
| :--------------------- | :-------- | :----------- | :----------- | :------ |
| Template               | string    | Single       | not Optional | Unique  |
| CaseTemplate           | string    | Single       | not Optional | Unique  |
| OutputTime             | string    | Single       | is Optional  | Unique  |
| Status                 | string    | Single       | not Optional | Unique  |
| PublishResults         | int       | Single       | not Optional | Unique  |
| Priority               | string    | Single       | not Optional | Unique  |
| MaxQueueSize           | int       | Single       | not Optional | Unique  |
| GroupID                | int       | Single       | not Optional | Unique  |

![AFAnalysis](../../assets/images/afanalysis.svg)

* In the 'New Type Definition' Screen:
    * Select 'Category' as Relationship:
        * Relationship Category = Composition
        * Name = 'afdatabase_afelement'
        * Relationship:
  
 | Type         | Name      | Cardinality  | Container?   | Legacy? |
 | :----------- | :-------- | :----------- | :----------- | :------ |
 | afdatabase   | Element   | Set          | true         | false   |
 | afelement    | Database  | Single       | false         | false  |

![afdatabase_afelement](../../assets/images/afdatabase_afelement.svg)

* In the 'New Type Definition' Screen:
    * Select 'Category' as Relationship:
        * Relationship Category = Composition
        * Name = 'afelement_afelement'
        * Relationship:
  
 | Type         | Name      | Cardinality  | Container?   | Legacy? |
 | :----------- | :-------- | :----------- | :----------- | :------ |
 | afelement    | Child     | Set          | true         | false   |
 | afelement    | Parent    | Single       | false        | false   |

![afdatabase_afelement](../../assets/images/afelement_afelement.svg)

* In the 'New Type Definition' Screen:
    * Select 'Category' as Relationship:
        * Relationship Category = Composition
        * Name = 'afelement_afattribute'
        * Relationship:
  
 | Type         | Name           | Cardinality  | Container?   | Legacy? |
 | :----------- | :------------- | :----------- | :----------- | :------ |
 | afattribute  | Parent Element | Single       | false        | false   |
 | afelement    | Attribute      | Set          | true         | false   |

![afdatabase_afelement](../../assets/images/afelement_afattribute.svg)

* In the 'New Type Definition' Screen:
    * Select 'Category' as Relationship:
        * Relationship Category = Composition
        * Name = 'afelement_afanalysis'
        * Relationship:
  
 | Type         | Name              | Cardinality  | Container?   | Legacy? |
 | :----------- | :---------------- | :----------- | :----------- | :------ |
 | afanalysis   | Reference Element | Single       | false        | false   |
 | afelement    | Analysis          | Set          | true         | false   |

![afdatabase_afelement](../../assets/images/afelement_afanalysis.svg)

- The file xml sample metadata from TAG DB [tag-db-xml-sample.xml](./files/tag-db-xml-sample.xml)
