targetScope = 'resourceGroup'

param name string
param virtualNetworkLinks object
param registrationEnabled bool
param tags object

resource zone 'Microsoft.Network/privateDnsZones@2024-06-01' = { name: name, location: 'global', tags: tags }
resource links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for link in items(virtualNetworkLinks): {
  parent: zone
  name: link.key
  location: 'global'
  properties: { virtualNetwork: { id: link.value }, registrationEnabled: registrationEnabled }
}]

output id string = zone.id
output name string = zone.name
