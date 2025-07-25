param location string = resourceGroup().location

@minLength(3)
@maxLength(24)
param storageAccountName string

@minLength(3)
@maxLength(63)
param fileShareName string

resource storageaccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource fileservice 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' = {
  parent: storageaccount
  name: 'default'
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = {
  parent: fileservice
  name: fileShareName
  properties: {
    shareQuota: 5
  }
}

output storageAccountName string = storageaccount.name
output fileShareName string = fileShareName
output storageAccountKey string = storageaccount.listKeys().keys[0].value
