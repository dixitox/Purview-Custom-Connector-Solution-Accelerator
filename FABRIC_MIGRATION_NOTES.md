# Migration from Azure Synapse to Microsoft Fabric

This document outlines the changes made to migrate the Purview Custom Connector Solution Accelerator from Azure Synapse Analytics to Microsoft Fabric.

## Overview of Changes

The solution has been updated to use Microsoft Fabric instead of Azure Synapse Analytics for compute and orchestration. This migration includes updates to:

- Infrastructure deployment
- Notebooks and pipelines
- Documentation
- Deployment scripts

## Key Changes

### 1. Folder Structure

All `Synapse` and `synapse` folders have been renamed to `Fabric` and `fabric`:
- `purview_connector_services/Synapse/` → `purview_connector_services/Fabric/`
- `examples/tag_db/synapse/` → `examples/tag_db/fabric/`
- `examples/ssis/synapse/` → `examples/ssis/fabric/`

### 2. Pipeline Activity Types

Pipeline JSON files have been updated to use Fabric-compatible activity types:
- `SynapseNotebook` → `SparkNotebook`
- `Microsoft.Synapse/workspaces/pipelines` → `Microsoft.DataFactory/factories/pipelines`
- `Microsoft.Synapse/workspaces/datasets` → `Microsoft.DataFactory/factories/datasets`
- `Microsoft.Synapse/workspaces/linkedservices` → `Microsoft.DataFactory/factories/linkedservices`

### 3. Notebook Metadata

Notebook kernel specifications updated:
- Kernel name: `synapse_pyspark` → `fabric_pyspark`
- Display name: `Synapse PySpark` → `Fabric PySpark`

### 4. Deployment Scripts

Deployment scripts have been updated with the following important notes:

⚠️ **IMPORTANT**: Microsoft Fabric does not have direct Azure CLI support like Azure Synapse. The deployment scripts now contain placeholders and comments indicating where manual configuration or REST API calls are needed.

Key areas requiring manual attention:
- Fabric workspace creation (no direct ARM template equivalent)
- Notebook import (must be done via Fabric UI or REST API)
- Pipeline import (must be done via Fabric UI or REST API)
- Trigger configuration (must be done via Fabric UI or REST API)
- Linked services/connections (Fabric uses different connection model)

### 5. Variable Names

Deployment script variables updated:
- `synapse_name` → `fabric_workspace_name`
- References to Synapse workspace → Microsoft Fabric workspace

### 6. ARM Templates

- `deploy_synapse.json` remains as-is (would need to be replaced with Fabric workspace provisioning)
- `deploy_storage.json` updated to reference Fabric workspace instead of Synapse
- Storage role assignments now require manual configuration of Fabric workspace identity

## Important Notes for Deployment

### Fabric Workspace Provisioning

Microsoft Fabric workspaces are typically created through:
1. **Fabric Portal UI** - Simplest method for initial setup
2. **Power BI REST API** - Fabric uses Power BI service backend
3. **Fabric REST API** - Available for programmatic workspace management

### Notebook and Pipeline Deployment

Unlike Azure Synapse which had `az synapse notebook create` and `az synapse pipeline create` commands, Fabric requires:

1. **Manual Import via UI**:
   - Navigate to your Fabric workspace
   - Import notebooks from the `fabric/notebook/` folders
   - Import pipelines from the `fabric/pipeline/` folders

2. **REST API Approach**:
   - Use Fabric REST API to programmatically deploy
   - Requires authentication token and workspace ID
   - See [Microsoft Fabric REST API documentation](https://learn.microsoft.com/en-us/rest/api/fabric/articles/)

### Spark Compute

- Fabric Spark compute is managed differently than Synapse Spark pools
- Configure Spark environment and library management through workspace settings
- Package requirements (requirements.txt) should be managed via Fabric environment settings

### Connection and Data Sources

Fabric uses a different model for data connections:
- Lakehouses instead of linked services
- OneLake as the default storage layer
- Consider creating a Lakehouse for your data processing needs

## Migration Checklist

When deploying this solution to Fabric, complete these steps:

- [ ] Create a Microsoft Fabric workspace
- [ ] Configure workspace identity and permissions
- [ ] Set up storage account access for Fabric workspace
- [ ] Create Lakehouse or configure storage connections
- [ ] Import notebooks manually or via REST API
- [ ] Import pipelines manually or via REST API
- [ ] Configure Spark environment with required packages (PyApacheAtlas)
- [ ] Configure pipeline triggers
- [ ] Update any hardcoded references to match your environment
- [ ] Test the complete workflow

## Compatibility Notes

### What Remains Compatible

- Python code in notebooks is fully compatible
- PyApacheAtlas library works the same way
- Purview integration unchanged
- Storage account integration unchanged
- KeyVault integration unchanged

### What Requires Attention

- Deployment automation (requires REST API instead of Azure CLI)
- Spark pool configuration (managed differently in Fabric)
- Pipeline scheduling and triggers (UI-based configuration)
- Linked services vs. Lakehouse connections

## Resources

- [Microsoft Fabric Documentation](https://learn.microsoft.com/en-us/fabric/)
- [Fabric REST API Reference](https://learn.microsoft.com/en-us/rest/api/fabric/articles/)
- [Migrate from Synapse to Fabric](https://learn.microsoft.com/en-us/fabric/data-engineering/migrate-synapse)
- [Fabric Spark Documentation](https://learn.microsoft.com/en-us/fabric/data-engineering/spark-overview)

## Support

For issues specific to this solution accelerator, please refer to:
- [Original Repository](https://github.com/microsoft/Purview-Custom-Connector-Solution-Accelerator)
- Troubleshooting.md (updated for Fabric)
- Community discussions

---

**Last Updated**: Migration completed for Fabric compatibility
**Migration Status**: Core functionality migrated; deployment automation requires manual steps or REST API implementation
