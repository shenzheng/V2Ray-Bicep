param location string = resourceGroup().location
param storageAccountName string = 'ladder'
param fileShareName string = 'laddershare'
param containerName string = 'zhshen2025'
param image string = 'ghcr.io/li-yanzhi/connectworld2:latest'

// 调用 storage 模块
module storage './modules/storage.bicep' = {
  name: 'storageModule'
  params: {
    location: location
    storageAccountName: storageAccountName
    fileShareName: fileShareName
  }
}

// 调用 aci 模块，使用 storage 模块的输出
module aci './modules/aci.bicep' = {
  name: 'aciModule'
  params: {
    containerName: containerName
    image: image
    location: location
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.storageAccountKey
    fileShareName: storage.outputs.fileShareName
  }
}
