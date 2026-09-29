targetScope = 'resourceGroup'

type delegationType = {
  name: string
  serviceName: string
  actions: string[]
}

type subnetType = {
  addressPrefix: string
  serviceEndpoints: string[]
  delegation: delegationType?
  privateEndpointNetworkPolicies: ('Disabled' | 'Enabled')?
  networkSecurityGroupId: string?
  natGatewayId: string?
}

type subnetsType = {
  *: subnetType
}

param name string
param location string
param addressSpace string[]
param subnets subnetsType
param tags object

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
  }
}

@batchSize(1)
resource subnetResources 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = [for subnetName in items(subnets): {
  parent: virtualNetwork
  name: subnetName.key
  properties: union({
    addressPrefix: subnetName.value.addressPrefix
    serviceEndpoints: map(subnetName.value.serviceEndpoints, service => {
      service: service
    })
    privateEndpointNetworkPolicies: subnetName.value.?privateEndpointNetworkPolicies ?? 'Enabled'
    delegations: subnetName.value.?delegation == null ? [] : [
      {
        name: subnetName.value.delegation!.name
        properties: {
          serviceName: subnetName.value.delegation!.serviceName
          actions: subnetName.value.delegation!.actions
        }
      }
    ]
  }, subnetName.value.?networkSecurityGroupId == null ? {} : {
    networkSecurityGroup: {
      id: subnetName.value.networkSecurityGroupId!
    }
  }, subnetName.value.?natGatewayId == null ? {} : {
    natGateway: {
      id: subnetName.value.natGatewayId!
    }
  })
}]

output id string = virtualNetwork.id
output name string = virtualNetwork.name
output addressSpace string[] = addressSpace
output subnetIds object = toObject(items(subnets), subnet => subnet.key, subnet => resourceId('Microsoft.Network/virtualNetworks/subnets', name, subnet.key))
output subnetAddressPrefixes object = toObject(items(subnets), subnet => subnet.key, subnet => subnet.value.addressPrefix)
