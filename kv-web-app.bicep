param Name string
param RandomName string = take(uniqueString(Name),7)
param location string = resourceGroup().location

resource KeyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'kv${RandomName}'
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: WebApplication.identity.principalId
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
  location: location
  properties: {}
}

resource VirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: Name
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
  location: location
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
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
    size: 'S1'
    family: 'S'
    capacity: 1
  }
  kind: 'app'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource WebApplication 'Microsoft.Web/sites@2021-01-15' = {
  name: Name
  location: location
  kind: 'app'
  properties: {
    serverFarmId: HostingPlan.id
    virtualNetworkSubnetId: '${VirtualNetwork.id}/subnets/${VirtualNetwork.properties.subnets[0].name}'
    httpsOnly: true
    hostNameSslStates: [
      {
        name: '${Name}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${Name}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    siteConfig: {
      numberOfWorkers: 1
      netFrameworkVersion: 'v7.0'
      acrUseManagedIdentityCreds: false
      alwaysOn: true
      http20Enabled: false
      functionAppScaleLimit: 0
      minimumElasticInstanceCount: 0
      appSettings: [
        {
          name: 'KV_REFERENCE'
          value: '@Microsoft.KeyVault(VaultName=kv${RandomName};SecretName=${Name})'
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}
