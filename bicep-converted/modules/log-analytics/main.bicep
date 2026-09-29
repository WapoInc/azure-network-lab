targetScope = 'resourceGroup'

param name string
param location string
param retentionInDays int = 30
param tags object

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    retentionInDays: retentionInDays
    features: {}
    sku: {
      name: 'PerGB2018'
    }
  }
}

output id string = workspace.id
output name string = workspace.name
output workspaceId string = workspace.properties.customerId
