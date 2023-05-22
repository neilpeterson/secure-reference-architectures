param Name string
param RandomName string = take(uniqueString(Name),7)
param Location string = resourceGroup().location

resource KeyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'kv${RandomName}'
  location: Location
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
          id: '${VirtualNetwork.id}/subnets/${VirtualNetwork.properties.subnets[0].name}'
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
  }
}

resource KeyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: Name
  parent: KeyVault
  properties: {
    value: 'hello-world'
  }
}

resource NetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: Name
  location: Location
  properties: {}
}

resource VirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: Name
  location: Location
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
          networkSecurityGroup: {
            id: NetworkSecurityGroup.id
          }
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

resource StorageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: RandomName
  location: Location
  kind: 'StorageV2'
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

resource HostingPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: Name
  location: Location
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
  name: Name
  kind: 'functionapp,linux'
  location: Location
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
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount};AccountKey=${StorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'KV_REFERENCE'
          value: '@Microsoft.KeyVault(VaultName=kv${RandomName};SecretName=${Name})'
        }
      ]
    }
    serverFarmId: HostingPlan.id
    clientAffinityEnabled: false
    virtualNetworkSubnetId: '${VirtualNetwork.id}/subnets/${VirtualNetwork.properties.subnets[0].name}'
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}
