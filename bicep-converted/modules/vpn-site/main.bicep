targetScope = 'resourceGroup'

param name string
param location string
param virtualWanId string
param vpnGatewayName string
param addressCidrs string[]
param vpnDeviceIp string
@secure()
param sharedKey string
param bgpEnabled bool = true
param bgpAsn int
param bgpPeeringAddress string
param tags object

resource site 'Microsoft.Network/vpnSites@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    virtualWan: { id: virtualWanId }
    addressSpace: { addressPrefixes: addressCidrs }
    vpnSiteLinks: [{
      name: 'link1'
      properties: { ipAddress: vpnDeviceIp, bgpProperties: { asn: bgpAsn, bgpPeeringAddress: bgpPeeringAddress } }
    }]
  }
}

resource gateway 'Microsoft.Network/vpnGateways@2024-05-01' existing = { name: vpnGatewayName }
resource connection 'Microsoft.Network/vpnGateways/vpnConnections@2024-05-01' = {
  parent: gateway
  name: '${name}-connection'
  properties: {
    remoteVpnSite: { id: site.id }
    vpnLinkConnections: [{
      name: 'link1'
      properties: {
        vpnSiteLink: { id: resourceId('Microsoft.Network/vpnSites/vpnSiteLinks', name, 'link1') }
        sharedKey: sharedKey
        enableBgp: bgpEnabled
      }
    }]
  }
}

output id string = site.id
output name string = site.name
output connectionId string = connection.id
