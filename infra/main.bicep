@description('Language of Function Worker')
@allowed([
  'dotnet'
  'dotnet-isolated'
  'node'
  'java'
  'python'
])
param functionRuntime string = 'node'

@description('Version of Function Host')
@allowed([
  '4'
  '3'
])
param functionHostVersion string = '4'

@description('Container App Name')
param containerAppName string = 'ca-func-${uniqueString(resourceGroup().id)}'

@description('Container App Environment Name')
param containerAppsEnvironmentName string = 'cae-func-${uniqueString(resourceGroup().id)}'

@description('Networking type for Container App Environment')
@allowed([
  'Public'
  'In VNet with ELB'
  'In VNet with ILB'
])
param containerAppsEnvironmentNetworkType string = 'Public'

@description('Existing subnet ID for Container App Environment')
param existingSubnetIdForContainerAppsEnvironment string = ''

@description('Storage Account Name')
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

@description('Log Analytics Name')
param logAnalyticsName string = 'log-func-${uniqueString(resourceGroup().id)}'

@description('Application Insights Name')
param applicationInsightsName string = 'ai-func-${uniqueString(resourceGroup().id)}'

param location string = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  location: location
  name: storageAccountName
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  resource fileShareService 'fileServices@2022-09-01' = {
    name: 'default'
    resource fileShare 'shares@2022-09-01' = {
      name: 'file-share-${containerAppName}'
    }
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  location: location
  name: logAnalyticsName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  location: location
  name: applicationInsightsName
  kind: ''
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource containerAppEnv 'Microsoft.App/managedEnvironments@2022-10-01' = {
  location: location
  name: containerAppsEnvironmentName
  properties: {
    vnetConfiguration: containerAppsEnvironmentNetworkType == 'Public' ? null : {
      infrastructureSubnetId: existingSubnetIdForContainerAppsEnvironment
      internal: containerAppsEnvironmentNetworkType == 'In VNet with ILB'
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
  resource containerAppEnvVolume 'storages@2022-10-01' = {
    name: '${containerAppName}-storage'
    properties: {
      azureFile: {
        accessMode: 'ReadWrite'
        accountKey: storageAccount.listKeys().keys[0].value
        accountName: storageAccount.name
        shareName: storageAccount::fileShareService::fileShare.name
      }
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
          image: 'mcr.microsoft.com/azure-functions/${functionRuntime}:${functionHostVersion}'
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
          storageName: containerAppEnv::containerAppEnvVolume.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}
