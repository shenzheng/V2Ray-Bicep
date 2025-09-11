# 部署V2Ray代理

## 概述

本项目会基于镜像ghcr.io/li-yanzhi/connectworld2:latest来部署V2Ray的服务端。服务端会提供VMess服务以及TLS的连接方式。

在TLS的连接方式下，会使用CADDY服务。该服务会生成证书，存放在磁盘（卷）上。

## 限制

在Azure上，容器相关的服务主要是Azure Container Instances以及AKS服务。前者比较轻量级，后者比较重。这种轻量级代理服务，通常不会超过几十美金/月。
在Azure Container Instances上，支持挂卷，只有Azure File Share一种，且只支持Storage Account Access Key。

目前很多Policy开始禁用了Storage Account Access Key，导致无法使用Azure Container Instances。因此，本项目会通过一个VM来实现对应的功能，绕开这个限制。

## 简要说明

我们是通过在VM上部署docker服务，然后依然使用镜像来完成具体的工作。具体说明请参考[VM Bicep](VMBICEP.md)。

## 准备工作

镜像准备

如果使用自己的Container Registry，需要做好镜像准备。

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

### 通过Bicep部署

```sh
az group create --name ladderRG --location japaneast
```

```bash
az deployment group create \
  -g ladderRG \
  -p ./v2ray-vm.bicepparam \
  -p dnsLabel="v2ray-vm-jpe" \
  -p vmName="v2ray-vm-jpe" \
  -p sshPublicKey="$(< ~/.ssh/id_rsa.pub)"
```

需要注意的点：
- vmName就是机器名，需要有唯一性
- dnsLabel是域名的前缀，最终域名是https://v2ray-vm-jpe.japaneast.cloudapp.azure.com/
- 由于该VM打开了SSH服务和22端口，所以需要创建时提供一个公钥文件，之后远程连接时，会使用本机对应的私钥

## 附录

### Caddy文档

https://caddy2.dengxiaolong.com/docs/

请参考[Caddy](./Caddy.md)。

## 创建V2Ray VM示例

```bash
# 删除资源组
az group delete -n v2ray-vm-jpe --yes

# 创建资源组 japaneast
az group create -n v2ray-vm-jpe -l japaneast

# 创建资源组 westus
az group create -n v2ray-vm-wus -l westus

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

```bash
# yanzhi订阅的japaneast部署
# 删除资源组
az group delete -n v2ray-vm-jpe-yz --yes

# 创建资源组 japaneast
az group create -n v2ray-vm-jpe-yz -l japaneast

az deployment group create \
  -g v2ray-vm-jpe-yz \
  -p ./v2ray-vm.bicepparam \
  -p dnsLabel="v2ray-vm-jpe-yz" \
  -p vmName="v2ray-vm-jpe-yz" \
  -p sshPublicKey="$(< ~/.ssh/id_rsa.pub)"

# yanzhi订阅的japaneast2部署
# 删除资源组
az group delete -n v2ray-vm-jpe2-yz --yes

# 创建资源组 japaneast2
az group create -n v2ray-vm-jpe2-yz -l japaneast

az deployment group create \
  -g v2ray-vm-jpe2-yz \
  -p ./v2ray-vm.bicepparam \
  -p dnsLabel="v2ray-vm-jpe2-yz" \
  -p vmName="v2ray-vm-jpe2-yz" \
  -p sshPublicKey="$(< ~/.ssh/id_rsa.pub)"

# https://v2ray-vm-jpe2-yz.japaneast.cloudapp.azure.com/

# yanzhi订阅的westus部署
# 删除资源组
az group delete -n v2ray-vm-wus-yz --yes

# 创建资源组 westus
az group create -n v2ray-vm-wus-yz -l westus

az deployment group create \
  -g v2ray-vm-wus-yz \
  -p ./v2ray-vm.bicepparam \
  -p dnsLabel="v2ray-vm-wus-yz" \
  -p vmName="v2ray-vm-wus-yz" \
  -p sshPublicKey="$(< ~/.ssh/id_rsa.pub)"

# https://v2ray-vm-wus-yz.japaneast.cloudapp.azure.com

# yanzhi订阅的westus2部署
# 删除资源组
az group delete -n v2ray-vm-wus2-yz --yes

# 创建资源组 westus2
az group create -n v2ray-vm-wus2-yz -l westus2

az deployment group create \
  -g v2ray-vm-wus2-yz \
  -p ./v2ray-vm.bicepparam \
  -p dnsLabel="v2ray-vm-wus2-yz" \
  -p vmName="v2ray-vm-wus2-yz" \
  -p sshPublicKey="$(< ~/.ssh/id_rsa.pub)"

# https://v2ray-vm-wus2-yz.japaneast.cloudapp.azure.com
```

