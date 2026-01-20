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

@description('Service principal client ID')
@secure()
param clientId string

@description('Service principal client secret')
@secure()
param clientSecret string

@description('Service principal name')
param clientName string

// Variables
var generatedPurviewName = '${baseName}purview${uniqueSuffix}'
var storageName = replace(replace(toLower('${baseName}storage${uniqueSuffix}'), '-', ''), '_', '')
var keyVaultName = '${baseName}kv${uniqueSuffix}'
var fabricWorkspaceName = '${baseName}fabric${uniqueSuffix}'
var storageContainerName = 'pccsa'

// Check if a specific Purview account name was provided
var usePurviewName = !empty(purviewAccountName) ? purviewAccountName : generatedPurviewName

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

// Purview Account - Idempotent deployment
resource purviewAccount 'Microsoft.Purview/accounts@2021-12-01' = {
  name: usePurviewName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    networkAcls: {
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'Standard'
    capacity: 1
  }
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

// Role assignments for Purview
var purviewDataCuratorRoleId = '8a3c2885-9b38-4fd2-9d99-91af537c1347'
var purviewDataReaderRoleId = '4465f953-8eca-43a9-b5b2-17be51ca8e01'

// Get the service principal object ID
// Note: This requires the service principal to already exist
// The deployment will handle this via the deployment script

// Outputs
output purviewAccountName string = purviewAccount.name
output purviewEndpoint string = purviewAccount.properties.endpoints.catalog
output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output clientSecretUri string = clientSecretSecret.properties.secretUri
output fabricWorkspaceName string = fabricWorkspaceName
output tenantId string = subscription().tenantId
output subscriptionId string = subscription().subscriptionId
