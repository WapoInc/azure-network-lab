targetScope = 'subscription'

type contextType = {
  project: string
  location: string
  tags: object
}

type deploymentFlagsType = {
  vwan: bool
  vhubFirewall: bool
  vpn: bool
  routeServer: bool
  dnsResolver: bool
  privateDnsZones: bool
  bastion: bool
  applicationGateway: bool
  loadBalancer: bool
  natGateway: bool
  privateEndpoint: bool
  spoke1Vms: bool
  spoke2Vms: bool
  onpremVms: bool
  nvas: bool
}

@description('Azure subscription ID targeted by this deployment.')
#disable-next-line no-unused-params
param subscriptionId string

@description('Lab context used for naming, location, and tags.')
param ctx contextType

@description('Master switches controlling which lab services are deployed.')
param deploy deploymentFlagsType

param vhubAddressPrefix string = '10.10.0.0/23'
param spoke1AddressSpace string[] = ['10.1.0.0/16']
param spoke2AddressSpace string[] = ['10.2.0.0/16']
param onpremAddressSpace string[] = ['192.168.0.0/16']
param adminUsername string = 'azureadmin'

@secure()
@minLength(12)
@maxLength(123)
param adminPassword string

@secure()
param vpnSharedKey string

param vmSize string = 'Standard_B2s'

var prefix = toLower(ctx.project)
var resourceGroupName = 'rg-${prefix}-v3'
var defaultTags = {
  ManagedBy: 'Bicep'
  Purpose: 'AZ-700 Networking Lab'
}
var effectiveTags = union(defaultTags, ctx.tags)
var defaultNsgRules = {
  AllowRDP: { priority: 100, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourcePortRange: '*', destinationPortRange: '3389', sourceAddressPrefix: '10.0.0.0/8', destinationAddressPrefix: '*' }
  AllowICMP: { priority: 110, direction: 'Inbound', access: 'Allow', protocol: 'Icmp', sourcePortRange: '*', destinationPortRange: '*', sourceAddressPrefix: '*', destinationAddressPrefix: '*' }
  AllowHTTP: { priority: 120, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourcePortRange: '*', destinationPortRange: '80', sourceAddressPrefix: '*', destinationAddressPrefix: '*' }
  AllowHTTPS: { priority: 130, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourcePortRange: '*', destinationPortRange: '443', sourceAddressPrefix: '*', destinationAddressPrefix: '*' }
}
var onpremNsgRules = union(defaultNsgRules, {
  AllowRDPFromInternet: { priority: 200, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourcePortRange: '*', destinationPortRange: '3389', sourceAddressPrefix: '192.168.0.0/16', destinationAddressPrefix: '*' }
})

module tags './modules/tags/main.bicep' = {
  params: { defaults: defaultTags, extra: ctx.tags }
}

resource labResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: ctx.location
  tags: effectiveTags
}

module logAnalytics './modules/log-analytics/main.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'log-${prefix}', location: ctx.location, retentionInDays: 30, tags: effectiveTags }
  dependsOn: [labResourceGroup]
}

module nsgSpoke1 './modules/nsg/main.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'nsg-spoke1-${prefix}', location: ctx.location, securityRules: defaultNsgRules, tags: effectiveTags }
  dependsOn: [labResourceGroup]
}
module nsgSpoke2 './modules/nsg/main.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'nsg-spoke2-${prefix}', location: ctx.location, securityRules: defaultNsgRules, tags: effectiveTags }
  dependsOn: [labResourceGroup]
}
module nsgOnprem './modules/nsg/main.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'nsg-onprem-${prefix}', location: ctx.location, securityRules: onpremNsgRules, tags: effectiveTags }
  dependsOn: [labResourceGroup]
}

module natGateway './modules/nat-gateway/main.bicep' = if (deploy.natGateway) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'nat-${prefix}', location: ctx.location, tags: effectiveTags }
  dependsOn: [labResourceGroup]
}

var spoke1Subnets = {
  Workload: { addressPrefix: '10.1.1.0/24', serviceEndpoints: [], delegation: null, networkSecurityGroupId: nsgSpoke1.outputs.id, natGatewayId: deploy.natGateway ? natGateway!.outputs.id : null }
  AppGwSubnet: { addressPrefix: '10.1.2.0/24', serviceEndpoints: [], delegation: null }
  AzureBastionSubnet: { addressPrefix: '10.1.3.0/26', serviceEndpoints: [], delegation: null }
  PrivateEndpointSubnet: { addressPrefix: '10.1.4.0/24', serviceEndpoints: [], delegation: null, privateEndpointNetworkPolicies: 'Disabled' }
  DnsResolverInbound: { addressPrefix: '10.1.5.0/28', serviceEndpoints: [], delegation: { name: 'dns-resolver-delegation', serviceName: 'Microsoft.Network/dnsResolvers', actions: ['Microsoft.Network/virtualNetworks/subnets/join/action'] } }
  DnsResolverOutbound: { addressPrefix: '10.1.5.16/28', serviceEndpoints: [], delegation: { name: 'dns-resolver-delegation', serviceName: 'Microsoft.Network/dnsResolvers', actions: ['Microsoft.Network/virtualNetworks/subnets/join/action'] } }
  LoadBalancerSubnet: { addressPrefix: '10.1.6.0/24', serviceEndpoints: [], delegation: null }
  RouteServerSubnet: { addressPrefix: '10.1.7.0/27', serviceEndpoints: [], delegation: null }
  NvaSubnet: { addressPrefix: '10.1.8.0/24', serviceEndpoints: [], delegation: null, networkSecurityGroupId: nsgSpoke1.outputs.id }
}
var spoke2Subnets = {
  Workload: { addressPrefix: '10.2.1.0/24', serviceEndpoints: ['Microsoft.Storage'], delegation: null, networkSecurityGroupId: nsgSpoke2.outputs.id }
}
var onpremSubnets = {
  GatewaySubnet: { addressPrefix: '192.168.0.0/27', serviceEndpoints: [], delegation: null }
  Default: { addressPrefix: '192.168.1.0/24', serviceEndpoints: [], delegation: null, networkSecurityGroupId: nsgOnprem.outputs.id }
  NvaSubnet: { addressPrefix: '192.168.2.0/24', serviceEndpoints: [], delegation: null, networkSecurityGroupId: nsgOnprem.outputs.id }
}

module vnetSpoke1 './modules/vnet/main.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vnet-spoke1-${prefix}', location: ctx.location, addressSpace: spoke1AddressSpace, subnets: spoke1Subnets, tags: effectiveTags }
  dependsOn: [labResourceGroup]
}
module vnetSpoke2 './modules/vnet/main.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vnet-spoke2-${prefix}', location: ctx.location, addressSpace: spoke2AddressSpace, subnets: spoke2Subnets, tags: effectiveTags }
  dependsOn: [labResourceGroup]
}
module vnetOnprem './modules/vnet/main.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vnet-onprem-${prefix}', location: ctx.location, addressSpace: onpremAddressSpace, subnets: onpremSubnets, tags: effectiveTags }
  dependsOn: [labResourceGroup]
}

module peerSpoke1ToSpoke2 './modules/vnet-peering/main.bicep' = if (deploy.routeServer) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'peer-spoke1-to-spoke2', virtualNetworkName: vnetSpoke1.outputs.name, remoteVirtualNetworkId: vnetSpoke2.outputs.id, allowVirtualNetworkAccess: true, allowForwardedTraffic: true, allowGatewayTransit: false, useRemoteGateways: false }
}
module peerSpoke2ToSpoke1 './modules/vnet-peering/main.bicep' = if (deploy.routeServer) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'peer-spoke2-to-spoke1', virtualNetworkName: vnetSpoke2.outputs.name, remoteVirtualNetworkId: vnetSpoke1.outputs.id, allowVirtualNetworkAccess: true, allowForwardedTraffic: true, allowGatewayTransit: false, useRemoteGateways: false }
}

module vwan './modules/vwan/main.bicep' = if (deploy.vwan) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vwan-${prefix}', location: ctx.location, tags: effectiveTags }
  dependsOn: [labResourceGroup]
}
module vhub './modules/vhub/main.bicep' = if (deploy.vwan) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vhub-${prefix}', location: ctx.location, virtualWanId: vwan!.outputs.id, addressPrefix: vhubAddressPrefix, tags: effectiveTags }
}
module vhubFirewall './modules/vhub-firewall/main.bicep' = if (deploy.vwan && deploy.vhubFirewall) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'fw-vhub-${prefix}', policyName: 'fwpol-${prefix}', location: ctx.location, virtualHubId: vhub!.outputs.id, tags: effectiveTags }
}
module vhubVpnGateway './modules/vhub-vpn-gateway/main.bicep' = if (deploy.vwan && deploy.vpn) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vpngw-vhub-${prefix}', location: ctx.location, virtualHubId: vhub!.outputs.id, scaleUnit: 1, tags: effectiveTags }
}
module vhubConnectionSpoke1 './modules/vhub-connection/main.bicep' = if (deploy.vwan && !deploy.routeServer) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'conn-spoke1-${prefix}', virtualHubName: vhub!.outputs.name, remoteVirtualNetworkId: vnetSpoke1.outputs.id, internetSecurityEnabled: true }
  dependsOn: [vhubFirewall]
}
module vhubConnectionSpoke2 './modules/vhub-connection/main.bicep' = if (deploy.vwan) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'conn-spoke2-${prefix}', virtualHubName: vhub!.outputs.name, remoteVirtualNetworkId: vnetSpoke2.outputs.id, internetSecurityEnabled: true }
  dependsOn: [vhubFirewall]
}

module vpnGatewayOnprem './modules/vpn-gateway/main.bicep' = if (deploy.vpn) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vpngw-onprem-${prefix}', location: ctx.location, gatewaySubnetId: vnetOnprem.outputs.subnetIds.GatewaySubnet, sku: 'VpnGw1', enableBgp: true, bgpAsn: 65510, tags: effectiveTags }
}
module vpnSiteOnprem './modules/vpn-site/main.bicep' = if (deploy.vwan && deploy.vpn) {
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'site-onprem-${prefix}', location: ctx.location, virtualWanId: vwan!.outputs.id, vpnGatewayName: vhubVpnGateway!.outputs.name
    addressCidrs: onpremAddressSpace, vpnDeviceIp: vpnGatewayOnprem!.outputs.publicIpAddress, sharedKey: vpnSharedKey
    bgpEnabled: true, bgpAsn: 65510, bgpPeeringAddress: vpnGatewayOnprem!.outputs.bgpPeeringAddress, tags: effectiveTags
  }
}
module localNetworkGatewayVhub './modules/local-network-gateway/main.bicep' = if (deploy.vwan && deploy.vpn) {
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'lng-vhub-${prefix}', location: ctx.location, gatewayAddress: vhubVpnGateway!.outputs.tunnelIp, addressSpace: ['10.0.0.0/8']
    bgpEnabled: true, bgpAsn: 65515, bgpPeeringAddress: vhubVpnGateway!.outputs.defaultBgpIp, tags: effectiveTags
  }
}
module vpnConnectionOnpremToVhub './modules/vpn-connection/main.bicep' = if (deploy.vwan && deploy.vpn) {
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'conn-onprem-to-vhub-${prefix}', location: ctx.location, virtualNetworkGatewayId: vpnGatewayOnprem!.outputs.id
    localNetworkGatewayId: localNetworkGatewayVhub!.outputs.id, sharedKey: vpnSharedKey, enableBgp: true, tags: effectiveTags
  }
  dependsOn: [vpnSiteOnprem]
}

module routeServer './modules/route-server/main.bicep' = if (deploy.routeServer) {
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'rs-${prefix}', location: ctx.location, subnetId: vnetSpoke1.outputs.subnetIds.RouteServerSubnet
    branchToBranchTrafficEnabled: true, bgpConnections: { 'spoke1-nva': { peerIp: '10.1.8.10', peerAsn: 65501 } }, tags: effectiveTags
  }
}

var vnetLinks = { spoke1: vnetSpoke1.outputs.id, spoke2: vnetSpoke2.outputs.id, onprem: vnetOnprem.outputs.id }
module privateDnsInternal './modules/private-dns-zone/main.bicep' = if (deploy.privateDnsZones) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'lab.internal', virtualNetworkLinks: vnetLinks, registrationEnabled: true, tags: effectiveTags }
}
module privateDnsBlob './modules/private-dns-zone/main.bicep' = if (deploy.privateDnsZones) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'privatelink.blob.${environment().suffixes.storage}', virtualNetworkLinks: vnetLinks, registrationEnabled: false, tags: effectiveTags }
}
module dnsResolver './modules/dns-private-resolver/main.bicep' = if (deploy.dnsResolver) {
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'dnspr-${prefix}', location: ctx.location, virtualNetworkId: vnetSpoke1.outputs.id
    inboundSubnetId: vnetSpoke1.outputs.subnetIds.DnsResolverInbound, outboundSubnetId: vnetSpoke1.outputs.subnetIds.DnsResolverOutbound, tags: effectiveTags
  }
}

module loadBalancer './modules/load-balancer/main.bicep' = if (deploy.loadBalancer) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'ilb-${prefix}', location: ctx.location, subnetId: vnetSpoke1.outputs.subnetIds.LoadBalancerSubnet, tags: effectiveTags }
}
module applicationGateway './modules/application-gateway/main.bicep' = if (deploy.applicationGateway) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'appgw-${prefix}', location: ctx.location, subnetId: vnetSpoke1.outputs.subnetIds.AppGwSubnet, skuName: 'WAF_v2', skuTier: 'WAF_v2', capacity: 1, wafEnabled: true, tags: effectiveTags }
}
module bastion './modules/bastion/main.bicep' = if (deploy.bastion) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'bas-${prefix}', location: ctx.location, subnetId: vnetSpoke1.outputs.subnetIds.AzureBastionSubnet, sku: 'Basic', tags: effectiveTags }
}

var storagePrefix = 'st${toLower(replace(effectiveTags.Project, '-', ''))}'
module storageAccount './modules/storage-account/main.bicep' = if (deploy.privateEndpoint) {
  scope: resourceGroup(resourceGroupName)
  params: { namePrefix: storagePrefix, location: ctx.location, publicNetworkAccessEnabled: false, tags: effectiveTags }
  dependsOn: [labResourceGroup]
}
module privateEndpointStorage './modules/private-endpoint/main.bicep' = if (deploy.privateEndpoint && deploy.privateDnsZones) {
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'pe-storage-${prefix}', location: ctx.location, subnetId: vnetSpoke1.outputs.subnetIds.PrivateEndpointSubnet
    privateConnectionResourceId: storageAccount!.outputs.id, subresourceNames: ['blob'], privateDnsZoneIds: [privateDnsBlob!.outputs.id], tags: effectiveTags
  }
}

module vmSpoke11 './modules/vm-windows/main.bicep' = if (deploy.spoke1Vms) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vm-spoke1-1', location: ctx.location, subnetId: vnetSpoke1.outputs.subnetIds.Workload, size: vmSize, adminUsername: adminUsername, adminPassword: adminPassword, joinLbBackendPool: deploy.loadBalancer, lbBackendPoolId: deploy.loadBalancer ? loadBalancer!.outputs.backendPoolId : '', tags: effectiveTags }
}
module vmSpoke12 './modules/vm-windows/main.bicep' = if (deploy.spoke1Vms) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vm-spoke1-2', location: ctx.location, subnetId: vnetSpoke1.outputs.subnetIds.Workload, size: vmSize, adminUsername: adminUsername, adminPassword: adminPassword, joinLbBackendPool: deploy.loadBalancer, lbBackendPoolId: deploy.loadBalancer ? loadBalancer!.outputs.backendPoolId : '', tags: effectiveTags }
}
module vmSpoke21 './modules/vm-windows/main.bicep' = if (deploy.spoke2Vms) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vm-spoke2-1', location: ctx.location, subnetId: vnetSpoke2.outputs.subnetIds.Workload, size: vmSize, adminUsername: adminUsername, adminPassword: adminPassword, joinLbBackendPool: false, tags: effectiveTags }
}
module vmOnprem1 './modules/vm-windows/main.bicep' = if (deploy.onpremVms) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vm-onprem-1', location: ctx.location, subnetId: vnetOnprem.outputs.subnetIds.Default, size: vmSize, adminUsername: adminUsername, adminPassword: adminPassword, joinLbBackendPool: false, tags: effectiveTags }
}
module vmOnpremNva './modules/vm-windows-nva/main.bicep' = if (deploy.nvas) {
  scope: resourceGroup(resourceGroupName)
  params: { name: 'vm-onprem-nva', location: ctx.location, subnetId: vnetOnprem.outputs.subnetIds.NvaSubnet, privateIpAddress: '192.168.2.10', size: vmSize, adminUsername: adminUsername, adminPassword: adminPassword, bgpAsn: null, routeServerIps: [], advertisedRoutes: [], tags: effectiveTags }
}
module vmSpoke1Nva './modules/vm-windows-nva/main.bicep' = if (deploy.nvas) {
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'vm-spoke1-nva', location: ctx.location, subnetId: vnetSpoke1.outputs.subnetIds.NvaSubnet, privateIpAddress: '10.1.8.10'
    size: vmSize, adminUsername: adminUsername, adminPassword: adminPassword, bgpAsn: deploy.routeServer ? 65501 : null
    routeServerIps: deploy.routeServer ? routeServer!.outputs.virtualRouterIps : [], advertisedRoutes: deploy.routeServer ? ['10.100.0.0/16'] : [], tags: effectiveTags
  }
}

output resourceGroupName string = labResourceGroup.name
output resourceGroupLocation string = labResourceGroup.location
output vwanId string? = deploy.vwan ? vwan!.outputs.id : null
output vhubId string? = deploy.vwan ? vhub!.outputs.id : null
output firewallPrivateIp string? = deploy.vwan && deploy.vhubFirewall ? vhubFirewall!.outputs.privateIpAddress : null
output firewallPublicIps array? = deploy.vwan && deploy.vhubFirewall ? vhubFirewall!.outputs.publicIpAddresses : null
output vnetSpoke1Id string = vnetSpoke1.outputs.id
output vnetSpoke2Id string = vnetSpoke2.outputs.id
output vnetOnpremId string = vnetOnprem.outputs.id
output onpremVpnGatewayPublicIp string? = deploy.vpn ? vpnGatewayOnprem!.outputs.publicIpAddress : null
output vmSpoke11PrivateIp string? = deploy.spoke1Vms ? vmSpoke11!.outputs.privateIpAddress : null
output vmSpoke12PrivateIp string? = deploy.spoke1Vms ? vmSpoke12!.outputs.privateIpAddress : null
output vmSpoke21PrivateIp string? = deploy.spoke2Vms ? vmSpoke21!.outputs.privateIpAddress : null
output vmOnprem1PrivateIp string? = deploy.onpremVms ? vmOnprem1!.outputs.privateIpAddress : null
output vmOnpremNvaPrivateIp string? = deploy.nvas ? vmOnpremNva!.outputs.privateIpAddress : null
output loadBalancerFrontendIp string? = deploy.loadBalancer ? loadBalancer!.outputs.frontendIpAddress : null
output applicationGatewayPublicIp string? = deploy.applicationGateway ? applicationGateway!.outputs.publicIpAddress : null
output bastionDnsName string? = deploy.bastion ? bastion!.outputs.dnsName : null
output dnsResolverInboundIp string? = deploy.dnsResolver ? dnsResolver!.outputs.inboundEndpointIp : null
output storageAccountName string? = deploy.privateEndpoint ? storageAccount!.outputs.name : null
output privateEndpointStorageIp string? = deploy.privateEndpoint && deploy.privateDnsZones ? privateEndpointStorage!.outputs.privateIpAddress : null
output routeServerId string? = deploy.routeServer ? routeServer!.outputs.id : null
output routeServerVirtualRouterAsn int? = deploy.routeServer ? routeServer!.outputs.virtualRouterAsn : null
output routeServerVirtualRouterIps array? = deploy.routeServer ? routeServer!.outputs.virtualRouterIps : null
output vmSpoke1NvaPrivateIp string? = deploy.nvas ? vmSpoke1Nva!.outputs.privateIpAddress : null
output connectionInfo object = {
  bastionConnect: deploy.bastion ? 'Connect via Azure Portal -> Bastion -> ${bastion!.outputs.name}' : 'Bastion not deployed'
  vmAdminUser: adminUsername
  spoke1Vms: deploy.spoke1Vms ? [vmSpoke11!.outputs.privateIpAddress, vmSpoke12!.outputs.privateIpAddress] : []
  spoke1Nva: deploy.nvas ? vmSpoke1Nva!.outputs.privateIpAddress : null
  spoke2Vms: deploy.spoke2Vms ? [vmSpoke21!.outputs.privateIpAddress] : []
  onpremVms: deploy.onpremVms && deploy.nvas ? [vmOnprem1!.outputs.privateIpAddress, vmOnpremNva!.outputs.privateIpAddress] : (deploy.onpremVms ? [vmOnprem1!.outputs.privateIpAddress] : [])
  routeServer: deploy.routeServer ? { asn: routeServer!.outputs.virtualRouterAsn, peerIps: routeServer!.outputs.virtualRouterIps } : null
}
