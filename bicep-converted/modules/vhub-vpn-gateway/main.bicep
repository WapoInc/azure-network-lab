targetScope = 'resourceGroup'

param name string
param location string
param virtualHubId string
param scaleUnit int = 1
param tags object

resource gateway 'Microsoft.Network/vpnGateways@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    virtualHub: { id: virtualHubId }
    connections: []
    bgpSettings: { asn: 65515, peerWeight: 0 }
    vpnGatewayScaleUnit: scaleUnit
  }
}

output id string = gateway.id
output name string = gateway.name
output bgpSettings object = gateway.properties.bgpSettings
output tunnelIp string = gateway.properties.bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]
output defaultBgpIp string = gateway.properties.bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]
