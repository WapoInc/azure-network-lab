targetScope = 'resourceGroup'

param name string
param virtualNetworkName string
param remoteVirtualNetworkId string
param allowVirtualNetworkAccess bool
param allowForwardedTraffic bool
param allowGatewayTransit bool
param useRemoteGateways bool

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = { name: virtualNetworkName }
resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: virtualNetwork
  name: name
  properties: {
    remoteVirtualNetwork: { id: remoteVirtualNetworkId }
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
  }
}

output id string = peering.id
output name string = peering.name
