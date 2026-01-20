# Implementation Overview - Visual Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PURVIEW CUSTOM CONNECTOR WITH FABRIC                      │
│                         Implementation Flow                                  │
└─────────────────────────────────────────────────────────────────────────────┘

PHASE 1: PREREQUISITES (10 min)
═══════════════════════════════════════════════════════════════════════════════
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Azure     │      │   Service   │      │   Fabric    │
│Subscription │ ───> │  Principal  │ ───> │   License   │
└─────────────┘      └─────────────┘      └─────────────┘
                            │
                            ▼
                     Save Credentials
                     (appId, password, tenant)


PHASE 2: AZURE RESOURCES (45 min - Automated)
═══════════════════════════════════════════════════════════════════════════════
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Run: ./deploy_sa.sh                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Purview    │    │  Key Vault   │    │   Storage    │
│   Account    │    │  + Secrets   │    │ (ADLS Gen2)  │
└──────────────┘    └──────────────┘    └──────────────┘
        │                   │                   │
        │                   │                   │
        └───────────────────┴───────────────────┘
                            │
                            ▼
                    export_names.sh
                    (Save these values!)


PHASE 3: FABRIC WORKSPACE (30 min - Manual)
═══════════════════════════════════════════════════════════════════════════════
┌─────────────────────────────────────────────────────────────────────────────┐
│                    https://app.fabric.microsoft.com                          │
└─────────────────────────────────────────────────────────────────────────────┘
        │
        ├──> 1. Create Workspace
        │         │
        │         ├──> 2. Create Lakehouse
        │         │         │
        │         │         └──> 3. Add ADLS Shortcut ──┐
        │         │                                      │
        │         └──> 4. Create Spark Environment      │
        │                   │                            │
        │                   └──> Add pyapacheatlas       │
        │                                                │
        └──> 5. Import Notebook ─────────────────────────┤
                  │                                      │
                  └──> Attach to Environment & Lakehouse│
                                                         │
┌────────────────────────────────────────────────────────┘
│
│  RESOURCES CONNECTED:
│  ✓ Fabric Workspace
│  ✓ Lakehouse → ADLS Storage
│  ✓ Notebook → Spark Environment
│  ✓ pyapacheatlas package available


PHASE 4: PURVIEW CONFIGURATION (20 min - Manual)
═══════════════════════════════════════════════════════════════════════════════
┌─────────────────────────────────────────────────────────────────────────────┐
│                     https://web.purview.azure.com                            │
└─────────────────────────────────────────────────────────────────────────────┘
        │
        ├──> 1. Add Service Principal to Roles
        │         │
        │         ├──> Data Curators
        │         └──> Data Readers
        │
        └──> 2. Install Custom Types Tool
                  │
                  └──> 3. Create Generic Entity Type
                        ┌────────────────────────────────┐
                        │ purview_custom_connector_      │
                        │ generic_entity                 │
                        └────────────────────────────────┘


PHASE 5: DATA PIPELINE (15 min - Manual)
═══════════════════════════════════════════════════════════════════════════════
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Fabric Workspace                                    │
└─────────────────────────────────────────────────────────────────────────────┘
        │
        └──> Create Data Pipeline
                  │
                  ├──> Activity 1: Get Secret from Key Vault
                  │         │
                  │         └──> Store in variable: acc_secret
                  │
                  └──> Activity 2: Run Notebook
                        │
                        ├──> Input: Files from incoming/
                        ├──> Process: Transform & Load to Purview
                        └──> Output: Move to processed/


EXECUTION FLOW (Runtime)
═══════════════════════════════════════════════════════════════════════════════
┌─────────────┐
│ Upload JSON │
│   file to   │
│  incoming/  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Fabric Data Pipeline                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  1. Trigger: New file detected                                       │   │
│  │  2. Get Secret: Fetch client_secret from Key Vault                   │   │
│  │  3. Run Notebook:                                                     │   │
│  │     ├─> Read JSON from incoming/                                     │   │
│  │     ├─> Transform to Purview entities                                │   │
│  │     ├─> Authenticate to Purview (Service Principal)                  │   │
│  │     ├─> Upload entities via PyApacheAtlas                            │   │
│  │     └─> Move processed files to processed/                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Microsoft Purview                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Entities Created:                                                    │   │
│  │  ✓ Custom entities visible in Data Catalog                           │   │
│  │  ✓ Lineage relationships established                                 │   │
│  │  ✓ Searchable and discoverable                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘


DATA FLOW
═══════════════════════════════════════════════════════════════════════════════

Source System               ADLS Gen2                 Fabric              Purview
     │                          │                        │                   │
     │  1. Export metadata      │                        │                   │
     ├─────────────────────────>│                        │                   │
     │                          │  2. Trigger pipeline   │                   │
     │                          ├───────────────────────>│                   │
     │                          │                        │  3. Process       │
     │                          │<───────────────────────┤  & transform      │
     │                          │  Read files            │                   │
     │                          │                        │  4. Upload        │
     │                          │                        ├──────────────────>│
     │                          │                        │  entities         │
     │                          │  5. Move to processed  │                   │
     │                          │<───────────────────────┤                   │
     │                          │                        │                   │


FOLDER STRUCTURE IN ADLS
═══════════════════════════════════════════════════════════════════════════════
storage-account/
└── pccsa/
    └── pccsa_main/
        ├── incoming/          ← Drop JSON files here
        │   └── *.json        (Triggers pipeline)
        │
        └── processed/         ← Successfully processed files
            └── *.json        (Archived for audit)


TIMELINE
═══════════════════════════════════════════════════════════════════════════════
┌────────────┬────────────┬────────────┬────────────┬────────────┬──────────┐
│ Phase 1    │ Phase 2    │ Phase 3    │ Phase 4    │ Phase 5    │  Test    │
│ Prereqs    │ Azure      │ Fabric     │ Purview    │ Pipeline   │ E2E      │
│            │ Deploy     │ Setup      │ Config     │ Create     │          │
│ 10 min     │ 45 min     │ 30 min     │ 20 min     │ 15 min     │ 5 min    │
└────────────┴────────────┴────────────┴────────────┴────────────┴──────────┘
                          Total: ~2 hours

Add Examples: +1-2 hours each (Tag DB or SSIS)


KEY SUCCESS METRICS
═══════════════════════════════════════════════════════════════════════════════
✓ Service principal created and configured
✓ All Azure resources deployed successfully
✓ Fabric workspace with Lakehouse connected to ADLS
✓ Notebook imports and runs without errors
✓ Service principal has Purview permissions
✓ Generic entity type exists in Purview
✓ Pipeline executes successfully
✓ Test entity appears in Purview Data Catalog


TROUBLESHOOTING CHECKPOINTS
═══════════════════════════════════════════════════════════════════════════════
After Phase 2: Check export_names.sh exists
After Phase 3: Test notebook runs manually
After Phase 4: Verify service principal roles in Purview
After Phase 5: Test pipeline execution
After Test: Search for entity in Purview
```

## Next Steps Based on Your Goal

### Goal: Learn the Solution
→ Follow **QUICK_START.md** to deploy base + test

### Goal: Production Deployment  
→ Follow **IMPLEMENTATION_GUIDE.md** with proper governance

### Goal: Build Custom Connector
→ Complete base deployment, then study examples:
   - Tag DB: Simple custom data source
   - SSIS: Complex ETL lineage tracking

### Goal: Understand Migration
→ Read **FABRIC_MIGRATION_NOTES.md** for Synapse → Fabric changes
