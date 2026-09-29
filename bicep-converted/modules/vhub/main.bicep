targetScope = 'resourceGroup'

param name string
param location string
param virtualWanId string
param addressPrefix string
param tags object

resource virtualHub 'Microsoft.Network/virtualHubs@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    virtualWan: { id: virtualWanId }
    addressPrefix: addressPrefix
    sku: 'Standard'
  }
}

output id string = virtualHub.id
output name string = virtualHub.name
output defaultRouteTableId string = '${virtualHub.id}/hubRouteTables/defaultRouteTable'
