@description('Networking type for Container App Environment')
@allowed([
  'public'
  'vnetWithELB'
  'vnetWithILB'
])
param envNetworking string = 'public'

@description('Subnet ID for Container App Environment')
param containerEnvSubnetId string = ''

@description('Storage Account Name')
param storageName string = 'st${uniqueString(resourceGroup().id)}'
@description('Log Analytics Name')
param logAnalyticsName string = 'log-func-${uniqueString(resourceGroup().id)}'
@description('Application Insights Name')
param appInsightsName string = 'ai-func-${uniqueString(resourceGroup().id)}'
@description('Container App Environment Name')
param containerAppEnvName string = 'cae-func-${uniqueString(resourceGroup().id)}'
@description('Container App Name')
param containerAppName string = 'ca-func-${uniqueString(resourceGroup().id)}'
@description('Language of Function Worker')
@allowed([
  'dotnet'
  'dotnet-isolated'
  'node'
  'java'
  'python'
])
param runtime string = 'node'
param location string = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  location: location
  name: storageName
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource fileShareService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
}
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  parent: fileShareService
  name: 'home-site-wwwroot'
  properties: {

  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  location: location
  name: logAnalyticsName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  location: location
  name: appInsightsName
  kind: ''
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource containerAppEnv 'Microsoft.App/managedEnvironments@2022-10-01' = {
  location: location
  name: containerAppEnvName
  properties: {
    vnetConfiguration: envNetworking == 'public' ? null : {
      infrastructureSubnetId: containerEnvSubnetId
      internal: envNetworking == 'vnetWithILB'
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
  sku: {
    name: 'Consumption'
  }
}

resource containerAppEnvVolume 'Microsoft.App/managedEnvironments/storages@2022-10-01' = {
  parent: containerAppEnv
  name: '${containerAppEnv.name}-storage'
  properties: {
    azureFile: {
      accessMode: 'ReadWrite'
      accountKey: storageAccount.listKeys().keys[0].value
      accountName: storageAccount.name
      shareName: fileShare.name
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2022-10-01' = {
  location: location
  name: containerAppName
  properties: {
    environmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
      }
    }
    template: {
      scale: {
        minReplicas: 0
        maxReplicas: 10
      }
      containers: [
        {
          name: 'functions-container'
          image: 'mcr.microsoft.com/azure-functions/${runtime}:4'
          volumeMounts: [
            {
              mountPath: '/home/site/wwwroot'
              volumeName: 'azure-files-volume'
            }
          ]
          env: [
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: appInsights.properties.InstrumentationKey
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
            {
              name: 'AzureWebJobsStorage'
              value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'azure-files-volume'
          storageName: containerAppEnvVolume.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}
