targetScope = 'resourceGroup'

param name string
param location string
param subnetId string
param sku string = 'Basic'
param tags object

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${name}-pip'
  location: location
  zones: ['1', '2', '3']
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: sku }
  properties: {
    disableCopyPaste: false
    enableFileCopy: sku == 'Standard'
    enableTunneling: sku == 'Standard'
    enableIpConnect: sku == 'Standard'
    enableShareableLink: sku == 'Standard'
    ipConfigurations: [{ name: 'configuration', properties: { subnet: { id: subnetId }, publicIPAddress: { id: publicIp.id } } }]
  }
}

output id string = bastion.id
output name string = bastion.name
output dnsName string = publicIp.properties.dnsSettings.fqdn
