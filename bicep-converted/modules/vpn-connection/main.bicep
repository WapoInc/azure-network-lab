targetScope = 'resourceGroup'

param name string
param location string
param virtualNetworkGatewayId string
param localNetworkGatewayId string
@secure()
param sharedKey string
param enableBgp bool = true
param tags object

resource connection 'Microsoft.Network/connections@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: { id: virtualNetworkGatewayId, properties: {} }
    localNetworkGateway2: { id: localNetworkGatewayId, properties: {} }
    sharedKey: sharedKey
    enableBgp: enableBgp
    connectionProtocol: 'IKEv2'
  }
}

output id string = connection.id
output name string = connection.name
