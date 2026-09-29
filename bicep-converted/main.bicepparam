using './main.bicep'

param subscriptionId = readEnvironmentVariable('AZURE_SUBSCRIPTION_ID', '00000000-0000-0000-0000-000000000000')

param ctx = {
  project: 'az700-lab'
  location: 'southafricanorth'
  tags: {
    Owner: 'Your Name'
    CostCenter: 'Training'
    Environment: 'lab'
    Project: 'az700'
  }
}

param deploy = {
  vwan: true
  vpn: false
  vhubFirewall: true
  dnsResolver: true
  privateDnsZones: true
  routeServer: true
  applicationGateway: false
  loadBalancer: true
  natGateway: true
  bastion: false
  privateEndpoint: true
  spoke1Vms: true
  spoke2Vms: true
  onpremVms: false
  nvas: true
}

param vhubAddressPrefix = '10.10.0.0/23'
param spoke1AddressSpace = ['10.1.0.0/16']
param spoke2AddressSpace = ['10.2.0.0/16']
param onpremAddressSpace = ['192.168.0.0/16']
param adminUsername = 'azureadmin'
param adminPassword = readEnvironmentVariable('AZURE_ADMIN_PASSWORD')
param vpnSharedKey = readEnvironmentVariable('AZURE_VPN_SHARED_KEY', '<shared-key>')
param vmSize = 'Standard_B1ms'
