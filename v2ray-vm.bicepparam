using './v2ray-vm.bicep'

param location = 'japaneast'
param vmName = 'v2ray-vm-jpe'
param vmSize = 'Standard_B1ls'
param adminUsername = 'azureuser'


param sshPublicKey = 'ssh-rsa xxx'

param allowSsh = true
param dnsLabel = 'v2ray-vm-jpe'
param containerImage = 'ghcr.io/li-yanzhi/connectworld2:latest'

param containerArgs = [
  'V2RAY_WS'
  '2F15E03B-075E-460E-A27C-93ED282431BD'
]

param vnetCidr = '10.0.0.0/16'
param subnetCidr = '10.0.0.0/24'
