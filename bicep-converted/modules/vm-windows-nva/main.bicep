targetScope = 'resourceGroup'

param name string
param location string
param subnetId string
param privateIpAddress string
param size string
param adminUsername string
@secure()
param adminPassword string
param bgpAsn int?
param routeServerIps string[]
param advertisedRoutes string[]
param tags object

var configureBgp = bgpAsn != null && !empty(routeServerIps)
var peerCommands = configureBgp ? join(map(routeServerIps, (ip, index) => 'if (-not (Get-BgpPeer -Name \'RouteServer${index + 1}\' -ErrorAction SilentlyContinue)) { Add-BgpPeer -Name \'RouteServer${index + 1}\' -LocalIPAddress \'${privateIpAddress}\' -PeerIPAddress \'${ip}\' -PeerASN 65515 }'), '\n') : ''
var routeCommands = configureBgp ? join(map(advertisedRoutes, route => 'Add-BgpCustomRoute -Network \'${route}\' -ErrorAction SilentlyContinue'), '\n') : ''
var bgpConfig = configureBgp ? join([
  '# Configure BGP Router if not exists'
  'if (-not (Get-BgpRouter -ErrorAction SilentlyContinue)) {'
  '    Add-BgpRouter -BgpIdentifier \'${privateIpAddress}\' -LocalASN ${bgpAsn}'
  '}'
  '# Add BGP Peers'
  peerCommands
  '# Add custom routes'
  routeCommands
], '\n') : ''
var startupScript = join([
  '# RRAS and BGP Configuration Script'
  '# This script runs at startup to ensure RRAS is running and BGP is configured'
  '$logFile = "C:\\rras-config.log"'
  '$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"'
  'Add-Content -Path $logFile -Value "`n[$timestamp] Starting RRAS configuration..."'
  'try {'
  '    $rrasFeature = Get-WindowsFeature -Name RemoteAccess'
  '    if ($rrasFeature.InstallState -ne \'Installed\') { Add-Content -Path $logFile -Value "[$timestamp] RRAS feature not installed, waiting for installation..."; exit 0 }'
  '    $rrasConfig = Get-RemoteAccess -ErrorAction SilentlyContinue'
  '    if (-not $rrasConfig -or $rrasConfig.RoutingStatus -ne \'Installed\') { Add-Content -Path $logFile -Value "[$timestamp] Installing RemoteAccess routing..."; Install-RemoteAccess -VpnType RoutingOnly -ErrorAction Stop }'
  '    Set-Service RemoteAccess -StartupType Automatic -ErrorAction SilentlyContinue'
  '    $svc = Get-Service RemoteAccess'
  '    if ($svc.Status -ne \'Running\') { Add-Content -Path $logFile -Value "[$timestamp] Starting RemoteAccess service..."; Start-Service RemoteAccess -ErrorAction Stop; Start-Sleep -Seconds 10 }'
  '    Add-Content -Path $logFile -Value "[$timestamp] RemoteAccess service is running"'
  bgpConfig
  '    Add-Content -Path $logFile -Value "[$timestamp] BGP configuration complete"'
  '    Get-BgpRouter | Out-File -Append $logFile'
  '    Get-BgpPeer | Out-File -Append $logFile'
  '} catch { Add-Content -Path $logFile -Value "[$timestamp] ERROR: $($_.Exception.Message)" }'
], '\n')
var fullScript = join([
  'powershell -ExecutionPolicy Unrestricted -Command "'
  'Write-Host \'Installing RRAS features...\''
  'Install-WindowsFeature -Name RemoteAccess,Routing,RSAT-RemoteAccess -IncludeManagementTools'
  '$scriptContent = @\''
  startupScript
  '\'@'
  '$scriptPath = \'C:\\ConfigureRRAS.ps1\''
  'Set-Content -Path $scriptPath -Value $scriptContent -Force'
  '$action = New-ScheduledTaskAction -Execute \'powershell.exe\' -Argument \'-ExecutionPolicy Bypass -File C:\\ConfigureRRAS.ps1\''
  '$trigger = New-ScheduledTaskTrigger -AtStartup'
  '$principal = New-ScheduledTaskPrincipal -UserId \'SYSTEM\' -LogonType ServiceAccount -RunLevel Highest'
  '$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable'
  'Unregister-ScheduledTask -TaskName \'ConfigureRRAS\' -Confirm:`$false -ErrorAction SilentlyContinue'
  'Register-ScheduledTask -TaskName \'ConfigureRRAS\' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force'
  'Write-Host \'Scheduled task created. Running initial configuration...\''
  '& $scriptPath'
  '$feature = Get-WindowsFeature -Name RemoteAccess'
  'if ($feature.InstallState -eq \'InstallPending\') { Write-Host \'Reboot required to complete installation. Scheduling reboot...\'; shutdown /r /t 60 /c \'Rebooting to complete RRAS installation\' }'
  '"'
], '\n')

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${name}-nic'
  location: location
  tags: tags
  properties: { enableIPForwarding: true, ipConfigurations: [{ name: 'internal', properties: { subnet: { id: subnetId }, privateIPAllocationMethod: 'Static', privateIPAddress: privateIpAddress } }] }
}
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    hardwareProfile: { vmSize: size }
    osProfile: { computerName: name, adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: { imageReference: { publisher: 'MicrosoftWindowsServer', offer: 'WindowsServer', sku: '2022-datacenter-core-smalldisk', version: 'latest' }, osDisk: { createOption: 'FromImage', caching: 'ReadWrite', managedDisk: { storageAccountType: 'Standard_LRS' } } }
    networkProfile: { networkInterfaces: [{ id: nic.id }] }
  }
}
resource extension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'install-rras-bgp'
  location: location
  tags: tags
  properties: { publisher: 'Microsoft.Compute', type: 'CustomScriptExtension', typeHandlerVersion: '1.10', autoUpgradeMinorVersion: true, settings: { commandToExecute: fullScript } }
}

output id string = vm.id
output name string = vm.name
output networkInterfaceId string = nic.id
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
