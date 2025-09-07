# 部署V2Ray代理

## 概述

本项目文件用于部署V2Ray代理服务。此服务托管于Azure Container Instances。依赖于Azure Storage Account的File Share，用于存放证书。

## 限制

Azure Container Instances不支持使用Managed Identity挂载Azure File Share，也不支持Azure Managed Disk，因此只能使用Storage Account Key
https://learn.microsoft.com/zh-cn/azure/container-instances/container-instances-volume-azure-files

Azure CLI示例

``` sh
az container create --resource-group ladder --name zhshen2025eastus --location eastus2 --image ghcr.io/li-yanzhi/connectworld2:latest --dns-name-label zhshen2025eastus --ports 443 --restart-policy Always --os-type Linux --command-line "'/caddy.sh' 'zhshen2025eastus.eastus2.azurecontainer.io' 'V2RAY_WS' '2F15E03B-075E-460E-A27C-93ED282431BD'" --azure-file-volume-account-name ladder --azure-file-volume-account-key 1hBEJ+7Bf1DbCAslIb+YBEjw9pctpEIBSlDoXdKFTroOaUVvSxC5YwCz/84X+icEQNMHSAbYqVgf+AStDO46hQ== --azure-file-volume-share-name ladder-share --azure-file-volume-mount-path /root/.local/
```

## 准备工作

### 镜像准备

下载镜像
``` sh
docker pull ghcr.io/li-yanzhi/connectworld2:latest
```

另存镜像
``` sh
docker save -o connectworld2.lastest.tar ghcr.io/li-yanzhi/connectworld2:latest
```

在另一台机器上加载镜像
``` sh
docker load -i connectworld2.lastest.tar
```

启用ACR的匿名访问。只有Standard以上Tier可以如此设置。Standard价格约为$20。
``` sh
az acr update --name zhshenacr --anonymous-pull-enabled
```

登录ACR
``` sh
echo "{acr password}" | docker login zhshenacr.azurecr.io -u zhshenacr --password-stdin
```

推送到另外一个repo
``` sh
docker tag ghcr.io/li-yanzhi/connectworld2 zhshenacr.azurecr.io/v2ray/connectworld2:latest

docker push zhshenacr.azurecr.io/v2ray/connectworld2:latest
```

### Resource Provider

``` sh
az provider register --namespace Microsoft.ContainerInstance

az provider show --namespace Microsoft.ContainerInstance --query "registrationState" --output table
```

### 创建资源组

```sh
az group create --name ladderRG --location eastus
```

## 通过Bicep部署

### 仅部署storageAccount
```sh
az deployment group create --resource-group ladderRG --template-file ./modules/storage.bicep --parameters storageAccountName=myv2raysa fileShareName=laddershare
```

### 指定镜像
```sh
az deployment group create --resource-group ladderRG --template-file main.bicep --parameters image=zhshenacr.azurecr.io/v2ray/connectworld2:latest --name customDeployment
```

## 附录

### Caddy文档

https://caddy2.dengxiaolong.com/docs/

### 可用的Storage Account Key
ACI_CERT_STORAGE_ACCOUNT_NAME=connectworldcert
STORAGE_KEY=yfLTTviMqFLhxQXB+slpNS8HwlHG1xczLbcBORXmtczG/ylkDe0QEApOQLES3GriQ5UGdbSMbbNZ+AStW640lg==

### 创建storage、VNet以及Managed Identity

这些功能，由于ACI不支持Managed Identity访问File Share，因此仅作为示例。

#### 创建VNet

``` bicep
param location string
param vnetName string
param aciSubnetName string = 'aciSubnet'
param storageSubnetName string = 'storageSubnet'

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: aciSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          // delegations: [
          //   {
          //     name: 'aciDelegation'
          //     properties: {
          //       serviceName: 'Microsoft.ContainerInstance/containerGroups'
          //     }
          //   }
          // ]
        }
      }
      {
        name: storageSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
          // delegations: [
          //   {
          //     name: 'aciDelegation'
          //     properties: {
          //       serviceName: 'Microsoft.'
          //     }
          //   }
          // ]
        }
      }
    ]
  }
}

output aciSubnetId string = vnet.properties.subnets[0].id
output storageSubnetId string = vnet.properties.subnets[1].id
output vnetId string = vnet.id
```

### 创建Storage account

``` bicep
param location string
param storageAccountName string
param fileShareName string
param subnetId string

// Storage Account
resource sa 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// File Service
resource fs 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' = {
  parent: sa
  name: 'default'
}

// File Share
resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = {
  parent: fs
  name: fileShareName
  properties: {
    shareQuota: 5
  }
}

// Private Endpoint
resource pe 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  name: 'pe-storage-files'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'storageFilePeConnection'
        properties: {
          privateLinkServiceId: sa.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

output storageAccountName string = sa.name
output fileShareId string = fs.id
```

#### 创建Managed Identity

``` bicep
param location string
param identityName string
param storageAccountName string

resource sa 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageAccountName
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: identityName
  location: location
}

// 角色分配
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(uami.id, 'Storage File Data SMB Share Contributor')
  scope: sa
  properties: {
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor，https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
    )
  }
}

output identityId string = uami.id
```

#### 创建ACI

不能执行，因为Volume不支持Managed Identity访问Azure File Share
``` bicep
param location string
param containerGroupName string
param imageName string
param dnsNameLabel string
param subnetId string
param storageAccountName string
param fileShareName string
param userIdentityId string

resource aci 'Microsoft.ContainerInstance/containerGroups@2024-11-01-preview' = {
  name: containerGroupName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentityId}': {}
    }
  }
  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    ipAddress: {
      type: 'Public'
      dnsNameLabel: dnsNameLabel
      ports: [
        {
          protocol: 'TCP'
          port: 443
        }
      ]
    }
    subnetIds: [
      {
        id: subnetId
      }
    ]
    containers: [
      {
        name: 'app'
        properties: {
          image: imageName
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          ports: [
            {
              protocol: 'TCP'
              port: 443
            }
          ]
          volumeMounts: [
            {
              name: 'filesharevol'
              mountPath: '/root/.local/'
            }
          ]
        }
      }
    ]
    volumes: [
      {
        name: 'filesharevol'
        azureFile: {
          shareName: fileShareName
          storageAccountName: storageAccountName
          identity: {
            type: 'UserAssigned'
            userAssignedIdentity: userIdentityId
          }
        }
      }
    ]
  }
}
```

#### main.bicep
未验证

``` bicep
param location string = resourceGroup().location
param vnetName string = 'myAciVnet'
param aciSubnetName string = 'aciSubnet'
param storageSubnetName string = 'storageSubnet'
param storageAccountName string = 'stfileacct${uniqueString(resourceGroup().id)}'
param fileShareName string = 'myfileshare'
param identityName string = 'aciUserMI'
param containerGroupName string = 'myAciGroup'
param imageName string = 'ghcr.io/li-yanzhi/connectworld2:latest'
param dnsNameLabel string = 'aci-demo-${uniqueString(resourceGroup().id)}'

// 1. VNet
module vnetModule './modules/vnet.bicep' = {
  name: 'deployVnet'
  params: {
    location: location
    vnetName: vnetName
    aciSubnetName: aciSubnetName
    storageSubnetName: storageSubnetName
  }
}

// 2. Storage + File Share + Private Endpoint
module storageModule './modules/storage.bicep' = {
  name: 'deployStorage'
  params: {
    location: location
    storageAccountName: storageAccountName
    fileShareName: fileShareName
    subnetId: vnetModule.outputs.storageSubnetId
  }
}

// 3. Managed Identity + Role
module identityModule './modules/identity.bicep' = {
  name: 'deployIdentity'
  params: {
    location: location
    identityName: identityName
    storageAccountName: storageModule.outputs.storageAccountName
  }
}

// 4. ACI
module aciModule './modules/aci.bicep' = {
  name: 'deployAci'
  params: {
    location: location
    containerGroupName: containerGroupName
    imageName: imageName
    dnsNameLabel: dnsNameLabel
    subnetId: vnetModule.outputs.subnetId
    storageAccountName: storageModule.outputs.storageAccountName
    fileShareName: fileShareName
    userIdentityId: identityModule.outputs.identityId
  }
}
```

## 命令行创建ACI

```bash
az container create \
  --resource-group V2Ray \
  --name mymanualaci \
  --location japaneast \
  --image ghcr.io/li-yanzhi/connectworld2:latest \
  --dns-name-label mymanualaci \
  --ports 443 \
  --restart-policy Always \
  --os-type Linux \
  --command-line "'/caddy.sh' 'mymanualaci.japaneast.azurecontainer.io' 'V2RAY_WS' '2F15E03B-075E-460E-A27C-93ED282431BD'" \
  --azure-file-volume-account-name myv2raysa \
  --azure-file-volume-account-key {storage account key}} \
  --azure-file-volume-share-name laddershare \
  --azure-file-volume-mount-path /root/.local/ \
  --cpu 1 \
  --memory 1
```

## Automation Runbook

```powershell
param(
    [string] $ResourceGroupName,
    [string] $StorageAccountName
)

Connect-AzAccount -Identity | Out-Null

Write-Output "Enabling Shared Key Access..."
Set-AzStorageAccount -ResourceGroupName $ResourceGroupName `
                     -Name $StorageAccountName `
                     -AllowSharedKeyAccess $true | Out-Null

Write-Output "Enabling Public Network Access..."
Set-AzStorageAccount -ResourceGroupName $ResourceGroupName `
                     -Name $StorageAccountName `
                     -PublicNetworkAccess Enabled | Out-Null

Write-Output "✅ All settings applied."
```

## 创建V2Ray VM

```bash
# 删除资源组
az group delete -n v2ray-vm-jpe --yes

# 创建资源组
az group create -n v2ray-vm-jpe -l japaneast

# 试运行
az deployment group what-if \
  -g v2ray-vm-jpe \
  -p ./v2ray-vm.bicepparam \
  -p sshPublicKey="$(< ~/.ssh/id_rsa.pub)"

# 指定外部public key文件
az deployment group create \
  -g v2ray-vm-jpe \
  -p ./v2ray-vm.bicepparam \
  -p sshPublicKey="$(< ~/.ssh/id_rsa.pub)"

# 更换vmSize
az deployment group create \
  -g v2ray-vm-jpe \
  -p ./v2ray-vm.bicepparam \
  -p vmSize="Standard_B1s"
  -p sshPublicKey="$(< ~/.ssh/id_rsa.pub)"

```