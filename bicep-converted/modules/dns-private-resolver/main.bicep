targetScope = 'resourceGroup'

param name string
param location string
param virtualNetworkId string
param inboundSubnetId string
param outboundSubnetId string
param tags object

resource resolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: { virtualNetwork: { id: virtualNetworkId } }
}
resource inbound 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = {
  parent: resolver
  name: '${name}-inbound'
  location: location
  tags: tags
  properties: { ipConfigurations: [{ privateIpAllocationMethod: 'Dynamic', subnet: { id: inboundSubnetId } }] }
}
resource outbound 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' = {
  parent: resolver
  name: '${name}-outbound'
  location: location
  tags: tags
  properties: { subnet: { id: outboundSubnetId } }
}

output id string = resolver.id
output name string = resolver.name
output inboundEndpointIp string = inbound.properties.ipConfigurations[0].privateIpAddress
