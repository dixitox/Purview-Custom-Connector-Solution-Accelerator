// Main Bicep template for Purview Custom Connector Solution Accelerator
targetScope = 'subscription'

@description('Azure region for all resources')
param location string = 'eastus'

@description('Base name for resources (max 7 chars, letters only)')
@maxLength(7)
param baseName string = 'pccsa'

@description('Resource group name')
param resourceGroupName string = '${baseName}-rg'

@description('Purview account name (if empty, will search for existing or generate)')
param purviewAccountName string = ''

@description('Resource group of existing Purview account (only needed if reusing)')
param purviewResourceGroup string = ''

@description('Service principal client ID')
@secure()
param clientId string

@description('Service principal client secret')
@secure()
param clientSecret string

@description('Service principal name')
param clientName string = 'PurviewCustomConnectorSP'

@description('Generate unique suffix for resource names')
param uniqueSuffix string = uniqueString(subscription().subscriptionId, resourceGroupName)

// Create resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// Deploy core resources
module coreResources './modules/core-resources.bicep' = {
  name: 'core-resources-deployment'
  scope: rg
  params: {
    location: location
    baseName: baseName
    uniqueSuffix: uniqueSuffix
    purviewAccountName: purviewAccountName
    purviewResourceGroup: purviewResourceGroup
    clientSecret: clientSecret
  }
}

// Outputs
output resourceGroupName string = rg.name
output purviewAccountName string = coreResources.outputs.purviewAccountName
output storageAccountName string = coreResources.outputs.storageAccountName
output keyVaultName string = coreResources.outputs.keyVaultName
output fabricWorkspaceName string = coreResources.outputs.fabricWorkspaceName
output location string = location
