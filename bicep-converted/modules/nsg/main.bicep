targetScope = 'resourceGroup'

param name string
param location string
param securityRules object
param tags object

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: [for rule in items(securityRules): {
      name: rule.key
      properties: {
        priority: rule.value.priority
        direction: rule.value.direction
        access: rule.value.access
        protocol: rule.value.protocol
        sourcePortRange: rule.value.sourcePortRange
        destinationPortRange: rule.value.destinationPortRange
        sourceAddressPrefix: rule.value.sourceAddressPrefix
        destinationAddressPrefix: rule.value.destinationAddressPrefix
      }
    }]
  }
}

output id string = networkSecurityGroup.id
output name string = networkSecurityGroup.name
