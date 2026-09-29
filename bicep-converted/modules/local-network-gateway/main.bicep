targetScope = 'resourceGroup'

param name string
param location string
param gatewayAddress string
param addressSpace string[]
param bgpEnabled bool = true
param bgpAsn int
param bgpPeeringAddress string
param tags object

resource gateway 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    gatewayIpAddress: gatewayAddress
    localNetworkAddressSpace: { addressPrefixes: addressSpace }
    bgpSettings: bgpEnabled ? { asn: bgpAsn, bgpPeeringAddress: bgpPeeringAddress } : null
  }
}

output id string = gateway.id
output name string = gateway.name
