# 部署V2Ray代理

## 概述

本项目文件用于部署V2Ray代理服务。此服务托管于Azure Container Instances。依赖于Azure Storage Account的File Share，用于存放证书。

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

### 默认参数
```sh
az deployment group create --resource-group ladderRG --template-file main.bicep --name mainDeployment
```

### 指定镜像
```sh
az deployment group create --resource-group ladderRG --template-file main.bicep --parameters image=zhshenacr.azurecr.io/v2ray/connectworld2:latest --name customDeployment
```