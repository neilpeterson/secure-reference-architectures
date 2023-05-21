param name string
param RandomName string = take(uniqueString(name),7)
param location string = resourceGroup().location

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: RandomName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: FunctionApp.identity.principalId
        permissions: {
          keys: [
            'get'
          ]
          secrets: [
            'list'
            'get'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: [
        {
          id: '${virtualNetwork.id}/subnets/${virtualNetwork.properties.subnets[0].name}'
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
  }
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: name
  parent: keyVault
  properties: {
    value: 'hello-world'
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'function-app'
        properties: {
          addressPrefix: '10.0.0.0/24'
          delegations: [
            {
              name: 'Microsoft.Web/serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
    ]
  }
}

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: RandomName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Premium_LRS'
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
    size: 'EP1'
    family: 'EP'
    capacity: 1
  }
  kind: 'elastic'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 20
    isSpot: false
    reserved: true
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource FunctionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  kind: 'functionapp,linux'
  location: location
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageaccount};AccountKey=${storageaccount.listKeys().keys[0].value}'
        }
        {
          name: 'KV_REFERENCE'
          value: '@Microsoft.KeyVault(VaultName=${RandomName};SecretName=${name})'
        }
      ]
    }
    serverFarmId: hostingPlan.id
    clientAffinityEnabled: false
    virtualNetworkSubnetId: '${virtualNetwork.id}/subnets/${virtualNetwork.properties.subnets[0].name}'
  }
  identity: {
    type: 'SystemAssigned'
  }
}
