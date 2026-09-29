targetScope = 'resourceGroup'

param name string
param location string
param tags object

resource virtualWan 'Microsoft.Network/virtualWans@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    type: 'Standard'
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true
  }
}

output id string = virtualWan.id
output name string = virtualWan.name
