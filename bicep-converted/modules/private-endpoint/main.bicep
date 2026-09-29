targetScope = 'resourceGroup'

param name string
param location string
param subnetId string
param privateConnectionResourceId string
param subresourceNames string[]
param privateDnsZoneIds string[]
param tags object

resource endpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [{ name: '${name}-connection', properties: { privateLinkServiceId: privateConnectionResourceId, groupIds: subresourceNames } }]
  }
}
resource zoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(privateDnsZoneIds)) {
  parent: endpoint
  name: 'dns-zone-group'
  properties: { privateDnsZoneConfigs: map(privateDnsZoneIds, (zoneId, index) => { name: 'zone-${index}', properties: { privateDnsZoneId: zoneId } }) }
}

output id string = endpoint.id
output name string = endpoint.name
output privateIpAddress string = endpoint.properties.customDnsConfigs[0].ipAddresses[0]
