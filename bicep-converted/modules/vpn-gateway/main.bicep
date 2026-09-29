targetScope = 'resourceGroup'

param name string
param location string
param gatewaySubnetId string
param sku string = 'VpnGw1'
param enableBgp bool = true
param bgpAsn int = 65510
param tags object

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${name}-pip'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: { name: sku, tier: sku }
    activeActive: false
    enableBgp: enableBgp
    ipConfigurations: [{ name: 'vnetGatewayConfig', properties: { publicIPAddress: { id: publicIp.id }, privateIPAllocationMethod: 'Dynamic', subnet: { id: gatewaySubnetId } } }]
    bgpSettings: enableBgp ? { asn: bgpAsn } : null
  }
}

output id string = gateway.id
output name string = gateway.name
output publicIpAddress string = publicIp.properties.ipAddress
output bgpPeeringAddress string = gateway.properties.bgpSettings.bgpPeeringAddress
