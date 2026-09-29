targetScope = 'resourceGroup'

param name string
param location string
param subnetId string
param size string
param adminUsername string
@secure()
param adminPassword string
param joinLbBackendPool bool
param lbBackendPoolId string = ''
param tags object

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${name}-nic'
  location: location
  tags: tags
  properties: { ipConfigurations: [{ name: 'internal', properties: union({ subnet: { id: subnetId }, privateIPAllocationMethod: 'Dynamic' }, joinLbBackendPool ? { loadBalancerBackendAddressPools: [{ id: lbBackendPoolId }] } : {}) }] }
}
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    hardwareProfile: { vmSize: size }
    osProfile: { computerName: name, adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: { publisher: 'MicrosoftWindowsServer', offer: 'WindowsServer', sku: '2022-datacenter-core-smalldisk', version: 'latest' }
      osDisk: { createOption: 'FromImage', caching: 'ReadWrite', managedDisk: { storageAccountType: 'Standard_LRS' } }
    }
    networkProfile: { networkInterfaces: [{ id: nic.id }] }
  }
}

output id string = vm.id
output name string = vm.name
output networkInterfaceId string = nic.id
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
