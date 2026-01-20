// Core resources for Purview Custom Connector Solution Accelerator
targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string

@description('Base name for resources')
param baseName string

@description('Unique suffix for resource names')
param uniqueSuffix string

@description('Purview account name (if empty, will search for existing or generate)')
param purviewAccountName string = ''

@description('Resource group of existing Purview account (only needed if reusing)')
param purviewResourceGroup string = ''

// NOTE: Client ID and Name are passed to post-provision hooks via environment variables
// They are not used in the Bicep template itself
// @description('Service principal client ID')
// @secure()
// param clientId string

@description('Service principal client secret')
@secure()
param clientSecret string

// @description('Service principal name')
// param clientName string

// Variables
var generatedPurviewName = '${baseName}purview${uniqueSuffix}'
// Storage account names: max 24 chars, lowercase alphanumeric only
// Use 'st' prefix instead of 'storage' to save space: baseName(5) + 'st'(2) + uniqueSuffix(13) = 20 chars
var storageName = replace(replace(toLower('${baseName}st${uniqueSuffix}'), '-', ''), '_', '')
var keyVaultName = '${baseName}kv${uniqueSuffix}'
var fabricWorkspaceName = '${baseName}fabric${uniqueSuffix}'
var storageContainerName = 'pccsa'

// Check if a specific Purview account name was provided
var usePurviewName = !empty(purviewAccountName) ? purviewAccountName : generatedPurviewName
var shouldCreatePurview = empty(purviewAccountName)

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    accessPolicies: []
  }
}

// Store client secret in Key Vault
resource clientSecretSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'client-secret'
  parent: keyVault
  properties: {
    value: clientSecret
  }
}

// Purview Account - Create only if not reusing existing
resource purviewAccount 'Microsoft.Purview/accounts@2021-12-01' = if (shouldCreatePurview) {
  name: usePurviewName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

// Reference existing Purview account in same resource group
resource existingPurviewAccountSameRg 'Microsoft.Purview/accounts@2021-12-01' existing = if (!shouldCreatePurview && empty(purviewResourceGroup)) {
  name: usePurviewName
}

// Reference existing Purview account in different resource group
resource existingPurviewAccountDiffRg 'Microsoft.Purview/accounts@2021-12-01' existing = if (!shouldCreatePurview && !empty(purviewResourceGroup)) {
  name: usePurviewName
  scope: resourceGroup(subscription().subscriptionId, purviewResourceGroup)
}

// Storage Account with ADLS Gen2
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobServices
  name: storageContainerName
  properties: {
    publicAccess: 'None'
  }
}

// NOTE: Role assignments for Purview are handled in the post-provision hook
// var purviewDataCuratorRoleId = '8a3c2885-9b38-4fd2-9d99-91af537c1347'
// var purviewDataReaderRoleId = '4465f953-8eca-43a9-b5b2-17be51ca8e01'

// Outputs
output purviewAccountName string = usePurviewName
output purviewEndpoint string = shouldCreatePurview 
  ? purviewAccount.properties.endpoints.catalog 
  : (!empty(purviewResourceGroup) 
    ? existingPurviewAccountDiffRg.properties.endpoints.catalog 
    : existingPurviewAccountSameRg.properties.endpoints.catalog)
output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output clientSecretUri string = clientSecretSecret.properties.secretUri
output fabricWorkspaceName string = fabricWorkspaceName
output tenantId string = subscription().tenantId
output subscriptionId string = subscription().subscriptionId
