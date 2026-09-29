targetScope = 'resourceGroup'

param name string
param virtualHubName string
param remoteVirtualNetworkId string
param internetSecurityEnabled bool

resource virtualHub 'Microsoft.Network/virtualHubs@2024-05-01' existing = { name: virtualHubName }
resource connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-05-01' = {
  parent: virtualHub
  name: name
  properties: {
    remoteVirtualNetwork: { id: remoteVirtualNetworkId }
    enableInternetSecurity: internetSecurityEnabled
  }
}

output id string = connection.id
output name string = connection.name
