targetScope = 'resourceGroup'

param name string
param location string
param subnetId string
param tags object

resource loadBalancer 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    frontendIPConfigurations: [{
      name: 'frontend'
      properties: {
        subnet: { id: subnetId }
        privateIPAllocationMethod: 'Dynamic'
      }
    }]
    backendAddressPools: [{ name: '${name}-backend' }]
    probes: [{
      name: 'http-probe'
      properties: { protocol: 'Http', port: 80, requestPath: '/', intervalInSeconds: 5, numberOfProbes: 2 }
    }]
    loadBalancingRules: [{
      name: 'http-rule'
      properties: {
        protocol: 'Tcp'
        frontendPort: 80
        backendPort: 80
        frontendIPConfiguration: { id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', name, 'frontend') }
        backendAddressPool: { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', name, '${name}-backend') }
        probe: { id: resourceId('Microsoft.Network/loadBalancers/probes', name, 'http-probe') }
        enableFloatingIP: false
        idleTimeoutInMinutes: 4
        loadDistribution: 'Default'
      }
    }]
  }
}

output id string = loadBalancer.id
output name string = loadBalancer.name
output backendPoolId string = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', name, '${name}-backend')
output frontendIpAddress string = loadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress
