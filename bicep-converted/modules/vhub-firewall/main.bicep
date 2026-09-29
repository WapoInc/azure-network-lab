targetScope = 'resourceGroup'

param name string
param policyName string
param location string
param virtualHubId string
param tags object

resource virtualHub 'Microsoft.Network/virtualHubs@2024-05-01' existing = {
  name: last(split(virtualHubId, '/'))
}

resource policy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: policyName
  location: location
  tags: tags
  properties: {
    sku: { tier: 'Standard' }
    threatIntelMode: 'Alert'
    dnsSettings: { enableProxy: true }
  }
}

resource ruleGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: policy
  name: 'DefaultRuleCollectionGroup'
  properties: {
    priority: 100
    ruleCollections: [
      {
        name: 'AllowNetworkRules'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: { type: 'Allow' }
        rules: [
          { name: 'AllowAllOutbound', ruleType: 'NetworkRule', ipProtocols: ['TCP', 'UDP', 'ICMP'], sourceAddresses: ['10.0.0.0/8', '192.168.0.0/16'], destinationAddresses: ['*'], destinationPorts: ['*'] }
          { name: 'AllowICMP', ruleType: 'NetworkRule', ipProtocols: ['ICMP'], sourceAddresses: ['*'], destinationAddresses: ['*'], destinationPorts: ['*'] }
        ]
      }
      {
        name: 'AllowWebTraffic'
        priority: 200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: { type: 'Allow' }
        rules: [
          { name: 'AllowHTTPS', ruleType: 'ApplicationRule', protocols: [{ protocolType: 'Https', port: 443 }], sourceAddresses: ['10.0.0.0/8', '192.168.0.0/16'], targetFqdns: ['*'] }
          { name: 'AllowHTTP', ruleType: 'ApplicationRule', protocols: [{ protocolType: 'Http', port: 80 }], sourceAddresses: ['10.0.0.0/8', '192.168.0.0/16'], targetFqdns: ['*'] }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: { name: 'AZFW_Hub', tier: 'Standard' }
    firewallPolicy: { id: policy.id }
    virtualHub: { id: virtualHubId }
    hubIPAddresses: {
      publicIPs: { count: 1 }
    }
  }
  dependsOn: [ruleGroup]
}

resource routingIntent 'Microsoft.Network/virtualHubs/routingIntent@2024-05-01' = {
  parent: virtualHub
  name: 'RoutingIntent'
  properties: {
    routingPolicies: [
      { name: 'InternetTrafficPolicy', destinations: ['Internet'], nextHop: firewall.id }
      { name: 'PrivateTrafficPolicy', destinations: ['PrivateTraffic'], nextHop: firewall.id }
    ]
  }
}

output id string = firewall.id
output name string = firewall.name
output policyId string = policy.id
output privateIpAddress string = firewall.properties.hubIPAddresses.privateIPAddress
output publicIpAddresses array = map(firewall.properties.hubIPAddresses.publicIPs.addresses, address => address.address)
