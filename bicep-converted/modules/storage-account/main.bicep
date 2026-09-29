targetScope = 'resourceGroup'

param namePrefix string
param location string
param publicNetworkAccessEnabled bool = false
param tags object

var accountName = take('${namePrefix}${uniqueString(subscription().id, resourceGroup().id, namePrefix)}', 24)
resource account 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: accountName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
  }
}

output id string = account.id
output name string = account.name
output primaryBlobEndpoint string = account.properties.primaryEndpoints.blob
