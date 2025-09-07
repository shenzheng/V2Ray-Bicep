@description('Location to deploy the resources. Default = resource group location.')
param location string = resourceGroup().location

@description('Virtual machine name.')
param vmName string = 'v2ray-vm'

@description('VM size. Default: Standard_B2s')
param vmSize string = 'Standard_B2s' // 更便宜可用 Standard_B1s

@description('Admin username for the VM OS.')
param adminUsername string = 'azureuser'

@description('SSH public key. Example: ssh-ed25519 AAAA... user@host')
param sshPublicKey string

@description('Whether to open SSH(22) on the NSG. If false, SSH inbound is not allowed.')
param allowSsh bool = false

@description('Public IP DNS label (left part of FQDN). Must be unique within the Azure region.')
param dnsLabel string

@description('Container image to run.')
param containerImage string = 'ghcr.io/li-yanzhi/connectworld2:latest'

@description('Container args EXCLUDING the first arg (domain). The template will prepend the VM FQDN automatically.')
param containerArgs array = [
  'V2RAY_WS'
  '2F15E03B-075E-460E-A27C-93ED282431BD'
]

@description('VNet CIDR')
param vnetCidr string = '10.0.0.0/16'

@description('Subnet CIDR')
param subnetCidr string = '10.0.0.0/24'

/* ===== Names ===== */
var nsgName = '${vmName}-nsg'
var vnetName = '${vmName}-vnet'
var subnetName = 'subnet'
var pipName = '${vmName}-pip'
var nicName = '${vmName}-nic'
var osDiskName = '${vmName}-osdisk-${uniqueString(resourceGroup().id, deployment().name)}' // 避免与残留旧盘重名

/* ===== Public IP (with DNS) ===== */
resource pip 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: pipName
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: { domainNameLabel: dnsLabel }
  }
}

/* ===== NSG ===== */
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: concat(
      [
        {
          name: 'Allow-HTTPS-443'
          properties: {
            description: 'Allow inbound 443 for V2Ray container'
            priority: 1000
            direction: 'Inbound'
            access: 'Allow'
            protocol: 'Tcp'
            sourceAddressPrefix: '*'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: '443'
          }
        }
      ],
      allowSsh
        ? [
            {
              name: 'Allow-SSH-22'
              properties: {
                description: 'Allow inbound SSH if enabled'
                priority: 1010
                direction: 'Inbound'
                access: 'Allow'
                protocol: 'Tcp'
                sourceAddressPrefix: '*'
                sourcePortRange: '*'
                destinationAddressPrefix: '*'
                destinationPortRange: '22'
              }
            }
          ]
        : [],
      [
        {
          name: 'Deny-All-Inbound'
          properties: {
            priority: 4096
            direction: 'Inbound'
            access: 'Deny'
            protocol: '*'
            sourceAddressPrefix: '*'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: '*'
            description: 'Explicitly deny all other inbound'
          }
        }
      ]
    )
  }
}

/* ===== VNet / Subnet ===== */
resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [vnetCidr] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetCidr
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

/* ===== NIC ===== */
resource nic 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: pip.id }
          subnet: { id: vnet.properties.subnets[0].id }
        }
      }
    ]
  }
}

/* ===== Derived values ===== */
var fqdnValue = pip.properties.dnsSettings.fqdn
var containerArgsFinal = concat([fqdnValue], containerArgs)
var argsJoined = join(containerArgsFinal, ' ')

/* systemd unit content（容器镜像 + 参数已注入） */
var unitText = format(
  '''[Unit]
Description=V2Ray container (Docker)
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=5s
ExecStartPre=-/usr/bin/docker rm -f v2ray
ExecStart=/usr/bin/docker run --name v2ray --pull=always --restart=unless-stopped -p 443:443 -v /var/lib/v2ray-local:/root/.local {0} {1}
ExecStop=/usr/bin/docker stop v2ray

[Install]
WantedBy=multi-user.target
''',
  containerImage,
  argsJoined
)

/* ===== VM ===== */
resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
      // 不使用 customData，避免后续“不可修改”限制
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Standard_LRS' } // 最便宜 HDD
      }
    }
    networkProfile: { networkInterfaces: [{ id: nic.id, properties: { primary: true } }] }
  }
}

/* ===== VM Extension: CustomScript（Docker 官方仓库安装 + 写单元 + 启动） ===== */
resource ext 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'v2rayUnitWriter'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: format(
        '''bash -c 'set -euxo pipefail
# 1) 安装依赖并添加 Docker 官方 APT 源
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

CODENAME="$(. /etc/os-release && echo $VERSION_CODENAME)"
ARCH="$(dpkg --print-architecture)"
echo "deb [arch=${{ARCH}} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${{CODENAME}} stable" > /etc/apt/sources.list.d/docker.list

apt-get update

# 2) 安装 Docker CE
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3) 目录与 unit
mkdir -p /var/lib/v2ray-local
chmod 700 /var/lib/v2ray-local
chown root:root /var/lib/v2ray-local

# 写入 systemd unit（单引号 heredoc，禁止变量展开）
cat >/etc/systemd/system/v2ray-container.service <<'EOF'
{0}
EOF

systemctl daemon-reload
systemctl enable v2ray-container
systemctl restart v2ray-container
' ''',
        unitText
      )
    }
  }
}

/* ===== Outputs ===== */
output publicIp string = pip.properties.ipAddress
output fqdn string = fqdnValue
var joinedArgsForOut = join(containerArgsFinal, ' ')
output dockerRunExample string = 'docker run --name v2ray -p 443:443 -v /var/lib/v2ray-local:/root/.local ${containerImage} ${joinedArgsForOut}'
output sshHint string = allowSsh
  ? 'SSH: ssh ${adminUsername}@${fqdnValue} (port 22 open)'
  : 'SSH inbound blocked by NSG (allowSsh=false)'
