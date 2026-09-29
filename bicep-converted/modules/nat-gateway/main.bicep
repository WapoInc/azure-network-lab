targetScope = 'resourceGroup'

param name string
param location string
param tags object

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${name}-pip'
  location: location
  zones: ['1', '2', '3']
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: name
  location: location
  zones: ['1']
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [{ id: publicIp.id }]
  }
}

output id string = natGateway.id
output name string = natGateway.name
