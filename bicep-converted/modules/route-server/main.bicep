targetScope = 'resourceGroup'

param name string
param location string
param subnetId string
param branchToBranchTrafficEnabled bool = true
param bgpConnections object
param tags object

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${name}-pip'
  location: location
  zones: ['1', '2', '3']
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}
resource routeServer 'Microsoft.Network/virtualHubs@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: branchToBranchTrafficEnabled
  }
}
resource ipConfiguration 'Microsoft.Network/virtualHubs/ipConfigurations@2024-05-01' = {
  parent: routeServer
  name: 'Default'
  properties: { subnet: { id: subnetId }, publicIPAddress: { id: publicIp.id } }
}
resource peers 'Microsoft.Network/virtualHubs/bgpConnections@2024-05-01' = [for peer in items(bgpConnections): {
  parent: routeServer
  name: peer.key
  properties: { peerIp: peer.value.peerIp, peerAsn: peer.value.peerAsn }
  dependsOn: [ipConfiguration]
}]

output id string = routeServer.id
output name string = routeServer.name
output virtualRouterAsn int = routeServer.properties.virtualRouterAsn
output virtualRouterIps array = routeServer.properties.virtualRouterIps
