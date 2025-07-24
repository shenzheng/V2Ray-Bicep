param containerName string = 'zhshen2025'
param location string = resourceGroup().location
param image string = 'ghcr.io/li-yanzhi/connectworld2:latest'
param dnsNameLabel string = '${containerName}'
param port int = 443
param cpu int  = 1
param memory int  = 2

param storageAccountName string = 'ladder'

@secure()
param storageAccountKey string

param fileShareName string = 'laddershare'
param fileVolumeMountPath string = '/root/.local/'

param commandLine array = [
  '/caddy.sh'
  '${containerName}.eastus.azurecontainer.io'
  'V2RAY_WS'
  '2F15E03B-075E-460E-A27C-93ED282431BD'
]

resource containerInstance 'Microsoft.ContainerInstance/containerGroups@2024-10-01-preview' = {
  name: containerName
  location: location
  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    containers: [
      {
        name: containerName
        properties: {
          image: image
          resources: {
            requests: {
              cpu: cpu
              memoryInGB: memory
            }
          }
          ports: [
            {
              port: port
            }
          ]
          command: commandLine
          volumeMounts: [
            {
              name: 'ladder-volume'
              mountPath: fileVolumeMountPath
            }
          ]
        }
      }
    ]
    ipAddress: {
      type: 'Public'
      dnsNameLabel: dnsNameLabel
      ports: [
        {
          protocol: 'TCP'
          port: port
        }
      ]
    }
    volumes: [
      {
        name: 'ladder-volume'
        azureFile: {
          shareName: fileShareName
          storageAccountName: storageAccountName
          storageAccountKey: storageAccountKey
        }
      }
    ]
  }
}
