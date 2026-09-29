targetScope = 'resourceGroup'

param name string
param location string
param subnetId string
param skuName string = 'WAF_v2'
param skuTier string = 'WAF_v2'
param capacity int = 1
param wafEnabled bool = true
param tags object

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${name}-pip'
  location: location
  zones: ['1', '2', '3']
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource gateway 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: { name: skuName, tier: skuTier, capacity: capacity }
    gatewayIPConfigurations: [{ name: 'gateway-ip-config', properties: { subnet: { id: subnetId } } }]
    frontendIPConfigurations: [{ name: 'frontend-public', properties: { publicIPAddress: { id: publicIp.id } } }]
    frontendPorts: [{ name: 'http-port', properties: { port: 80 } }]
    backendAddressPools: [{ name: 'backend-pool' }]
    backendHttpSettingsCollection: [{ name: 'http-settings', properties: { cookieBasedAffinity: 'Disabled', port: 80, protocol: 'Http', requestTimeout: 30 } }]
    httpListeners: [{ name: 'http-listener', properties: {
      frontendIPConfiguration: { id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, 'frontend-public') }
      frontendPort: { id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, 'http-port') }
      protocol: 'Http'
    } }]
    requestRoutingRules: [{ name: 'http-rule', properties: {
      priority: 100
      ruleType: 'Basic'
      httpListener: { id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, 'http-listener') }
      backendAddressPool: { id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, 'backend-pool') }
      backendHttpSettings: { id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, 'http-settings') }
    } }]
    webApplicationFirewallConfiguration: wafEnabled ? { enabled: true, firewallMode: 'Detection', ruleSetType: 'OWASP', ruleSetVersion: '3.2' } : null
  }
}

output id string = gateway.id
output name string = gateway.name
output publicIpAddress string = publicIp.properties.ipAddress
