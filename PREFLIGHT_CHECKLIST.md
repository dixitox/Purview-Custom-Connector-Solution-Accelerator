# Pre-Flight Checklist - Before You Begin

Use this checklist to ensure you have everything ready before starting the implementation.

## ✅ Access & Permissions

### Azure Access
- [ ] I have an Azure subscription
- [ ] I have Contributor access to the subscription
- [ ] I have User Access Administrator role (to assign roles to service principal)
- [ ] I can create resource groups in my subscription
- [ ] I can create App Registrations (Service Principals)

### Microsoft Fabric Access
- [ ] I have access to Microsoft Fabric portal (https://app.fabric.microsoft.com)
- [ ] I have a Fabric capacity OR Fabric trial activated
- [ ] I can create workspaces in Fabric
- [ ] I have Power BI Pro or Premium Per User license (required for Fabric)

### Deployment Access
- [ ] I can access Azure Cloud Shell OR have Azure CLI installed locally
- [ ] I have Git installed (for cloning repository)
- [ ] I have a text editor for editing configuration files

## ✅ Required Information

### Gather Before Starting
- [ ] Azure Subscription ID: ________________________________
- [ ] Preferred Azure Region (e.g., eastus): ________________________________
- [ ] Email address for notifications: ________________________________

### Will Be Generated During Setup
- [ ] Service Principal App ID (client_id)
- [ ] Service Principal Secret (client_secret)
- [ ] Tenant ID
- [ ] Purview account name
- [ ] Storage account name
- [ ] Key Vault name
- [ ] Fabric workspace name

## ✅ Time & Resources

### Time Commitment
- [ ] I have allocated 3-4 hours for base implementation
- [ ] I understand the deployment runs unattended for ~45 minutes
- [ ] I can dedicate focused time without interruptions

### Optional: For Examples
- [ ] Tag DB Example: Additional 1-2 hours
- [ ] SSIS Example: Additional 2-4 hours + SQL Server VM

## ✅ Technical Prerequisites

### Required Tools
- [ ] Azure CLI installed OR access to Azure Cloud Shell
  - Test: Run `az --version` (should return version info)
- [ ] Git installed
  - Test: Run `git --version` (should return version info)
- [ ] Modern web browser (Chrome, Edge, or Firefox)

### Optional Tools (Helpful but not required)
- [ ] Visual Studio Code (for editing files)
- [ ] Azure Storage Explorer (for browsing storage)
- [ ] Postman (for API testing)

## ✅ Knowledge Prerequisites

### Required Understanding
- [ ] Basic familiarity with Azure portal
- [ ] Understanding of what Microsoft Purview does
- [ ] Basic knowledge of data governance concepts
- [ ] Comfortable running command-line scripts

### Helpful But Not Required
- [ ] Experience with Azure Data Factory or Synapse pipelines
- [ ] Knowledge of Apache Atlas
- [ ] Python basics
- [ ] JSON format understanding

## ✅ Decision Points

### Architecture Decisions
- [ ] I will deploy in region: ________________________________
  (Purview available in: eastus, westeurope, southeastasia, canadacentral, southcentralus, brazilsouth, centralindia, uksouth, australiaeast, eastus2)

- [ ] My Fabric capacity tier: ________________________________
  (or "Trial" if using trial)

- [ ] Naming convention for resources: ________________________________
  (default is "pccsa" prefix with random suffix)

### Which Examples to Deploy?
- [ ] Just base deployment (recommended for learning)
- [ ] Tag DB example (simple custom data source)
- [ ] SSIS example (ETL lineage tracking - requires SQL Server VM)
- [ ] Both examples
- [ ] None, I'll build my own connector

## ✅ Security & Governance

### Security Considerations
- [ ] I understand service principal will have access to Purview
- [ ] I will store service principal credentials securely
- [ ] I will follow my organization's security policies for:
  - [ ] Service principal naming
  - [ ] Secret management
  - [ ] Resource naming
  - [ ] Access control

### Compliance
- [ ] This deployment complies with my organization's policies
- [ ] I have approval to create Azure resources (if required)
- [ ] I have approval to create Fabric workspaces (if required)
- [ ] I understand data residency requirements

## ✅ Cost Understanding

### Expected Costs (Approximate Monthly)

**Azure Resources:**
- [ ] Microsoft Purview: ~$140/month (10 GB data map)
- [ ] Storage Account (ADLS Gen2): ~$5-20/month
- [ ] Key Vault: ~$1/month
- [ ] Total Azure: ~$150-200/month

**Microsoft Fabric:**
- [ ] Fabric Capacity: Varies by SKU (F2 = ~$262/month)
- [ ] OR Fabric Trial: $0 (60 days)

**Optional (SSIS Example):**
- [ ] SQL Server VM: ~$100-500/month (depending on size)

**Total Estimated**: $150-700/month (or ~$5-20/month with Fabric trial)

### Cost Optimization
- [ ] I will delete resources after testing (if only learning)
- [ ] I will use Fabric trial for evaluation
- [ ] I will monitor costs via Azure Cost Management
- [ ] I will set up cost alerts

## ✅ Support & Documentation

### Documentation Review
- [ ] I have reviewed the [README.md](README.md)
- [ ] I have the [QUICK_START.md](QUICK_START.md) available
- [ ] I have the [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) available
- [ ] I have the [Troubleshooting.md](Troubleshooting.md) available

### Backup Plan
- [ ] I know where to get help if stuck (GitHub issues, Microsoft Docs)
- [ ] I have a test subscription (not production) for initial deployment
- [ ] I can rollback by deleting the resource group

## ✅ Post-Deployment Plans

### What's Next?
- [ ] I will test the solution with sample data
- [ ] I will deploy one of the examples
- [ ] I will build a custom connector for: ________________________________
- [ ] I will integrate with existing data sources
- [ ] I will present findings to my team

### Success Criteria
Define what success looks like for you:
- [ ] _______________________________________________
- [ ] _______________________________________________
- [ ] _______________________________________________

## 🚀 Ready to Start?

### Final Checks
- [ ] All "Access & Permissions" items checked
- [ ] All "Required Information" gathered
- [ ] All "Time & Resources" confirmed
- [ ] All "Technical Prerequisites" met
- [ ] All decisions made
- [ ] Cost implications understood and approved

### If All Checked Above:
✅ **You're ready!** Proceed to [QUICK_START.md](QUICK_START.md)

### If Any Unchecked:
⚠️ **Pause and address gaps** before proceeding:
1. Review unchecked items
2. Obtain missing access/approvals
3. Gather missing information
4. Return to this checklist when ready

---

## Quick Links

- **Start Here**: [QUICK_START.md](QUICK_START.md)
- **Detailed Steps**: [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)
- **Visual Flow**: [IMPLEMENTATION_FLOW.md](IMPLEMENTATION_FLOW.md)
- **Troubleshooting**: [Troubleshooting.md](Troubleshooting.md)
- **Migration Notes**: [FABRIC_MIGRATION_NOTES.md](FABRIC_MIGRATION_NOTES.md)

---

**Questions before starting?** Review the documentation above or file an issue on GitHub.

**Ready to go?** Head to [QUICK_START.md](QUICK_START.md) and let's get started! 🚀
