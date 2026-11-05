
# ============================================================
# 1. EXISTING RESOURCE GROUP AND TENANT
# ============================================================

# Reference the application resource group created by bootstrap.
data "azurerm_resource_group" "app" {
  name = var.resource_group_name
}

# Identify the Azure tenant for Key Vault configuration.
data "azurerm_client_config" "current" {}


# ============================================================
# 2. RANDOM SUFFIX FOR GLOBALLY UNIQUE RESOURCE NAMES
# ============================================================

resource "random_string" "storage_suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}


# ============================================================
# 3. APPLICATION STORAGE ACCOUNT
# ============================================================

# Stores lead records and Azure Functions deployment packages.
resource "azurerm_storage_account" "app" {
  name                     = "stleadintake${random_string.storage_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.app.name
  location                 = data.azurerm_resource_group.app.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access           = "Enabled"
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  local_user_enabled              = false
  allow_nested_items_to_be_public = false

  tags = var.tags
}


# ============================================================
# 4. LEADS TABLE
# ============================================================

# Stores submitted lead records.
resource "azurerm_storage_table" "leads" {
  name               = "Leads"
  storage_account_id = azurerm_storage_account.app.id
}


# ============================================================
# 5. FUNCTION DEPLOYMENT CONTAINER
# ============================================================

# Private Blob container used by Flex Consumption deployments.
resource "azurerm_storage_container" "function_deployment" {
  name                  = "function-deployment"
  storage_account_id    = azurerm_storage_account.app.id
  container_access_type = "private"
}


# ============================================================
# 6. USER-ASSIGNED MANAGED IDENTITY
# ============================================================

# Identity used by the Function App to access Azure resources.
resource "azurerm_user_assigned_identity" "function" {
  name                = "id-lead-intake-function"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_resource_group.app.location

  tags = var.tags
}


# ============================================================
# 7. FLEX CONSUMPTION HOSTING PLAN
# ============================================================

# Serverless Linux hosting plan for the Python Function App.
resource "azurerm_service_plan" "function" {
  name                = "asp-lead-intake"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_resource_group.app.location

  os_type  = "Linux"
  sku_name = "FC1"

  tags = var.tags
}


# ============================================================
# 8. LOG ANALYTICS WORKSPACE
# ============================================================

# Central workspace for application logs and queries.
resource "azurerm_log_analytics_workspace" "function" {
  name                = "law-lead-intake-${random_string.storage_suffix.result}"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_resource_group.app.location

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = var.tags
}


# ============================================================
# 9. APPLICATION INSIGHTS
# ============================================================

# Collects Function execution telemetry, failures and performance.
resource "azurerm_application_insights" "function" {
  name                = "appi-lead-intake-${random_string.storage_suffix.result}"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_resource_group.app.location

  application_type = "web"
  workspace_id     = azurerm_log_analytics_workspace.function.id

  retention_in_days = 30

  tags = var.tags
}


# ============================================================
# 10. KEY VAULT
# ============================================================

# Secure storage for Slack and HubSpot credentials.
resource "azurerm_key_vault" "app" {
  name                = "kv-lead-intake-${random_string.storage_suffix.result}"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_resource_group.app.location

  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name  = "standard"

  rbac_authorization_enabled    = true
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7
  public_network_access_enabled = true

  tags = var.tags
}


# ============================================================
# 11. AZURE FUNCTIONS FLEX CONSUMPTION APP
# ============================================================

# Hosts the Python Lead-Intake API.
resource "azurerm_function_app_flex_consumption" "api" {
  name                                           = "func-lead-intake-${random_string.storage_suffix.result}"
  resource_group_name                            = data.azurerm_resource_group.app.name
  location                                       = data.azurerm_resource_group.app.location
  webdeploy_publish_basic_authentication_enabled = false

  service_plan_id = azurerm_service_plan.function.id

  # Deployment package storage.
  storage_container_type     = "blobContainer"
  storage_container_endpoint = "${azurerm_storage_account.app.primary_blob_endpoint}${azurerm_storage_container.function_deployment.name}"

  storage_authentication_type       = "UserAssignedIdentity"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.function.id

  # Python runtime.
  runtime_name    = "python"
  runtime_version = "3.11"

  # Limit scale-out for this portfolio environment.
  maximum_instance_count = 1
  instance_memory_in_mb  = 2048

  https_only = true

  # Use the same identity for deployment and application access.
  identity {
    type = "UserAssigned"

    identity_ids = [
      azurerm_user_assigned_identity.function.id
    ]
  }

  # Function host storage uses managed identity authentication.
  app_settings = {
    "AzureWebJobsStorage"              = ""
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.app.name
    "AzureWebJobsStorage__credential"  = "managedidentity"
    "AzureWebJobsStorage__clientId"    = azurerm_user_assigned_identity.function.client_id

    # Use managed identity for Application Insights telemetry.
    "APPLICATIONINSIGHTS_AUTHENTICATION_STRING" = "ClientId=${azurerm_user_assigned_identity.function.client_id};Authorization=AAD"
    "AZURE_CLIENT_ID"                           = azurerm_user_assigned_identity.function.client_id

    # Application-specific settings.
    "LEADS_TABLE_ENDPOINT" = azurerm_storage_account.app.primary_table_endpoint
    "LEADS_TABLE_NAME"     = azurerm_storage_table.leads.name
    "KEY_VAULT_URI"        = azurerm_key_vault.app.vault_uri
    "DOWNSTREAM_ENABLED"   = "false"
  }

  auth_settings_v2 {
    auth_enabled           = true
    require_authentication = false
    unauthenticated_action = "AllowAnonymous"

    active_directory_v2 {
      client_id = "bb85dbd3-4f25-4318-8f1d-47b436ce9edb"

      tenant_auth_endpoint = "https://login.microsoftonline.com/4cda0241-5f6e-432c-b040-cb47a5b607b2/v2.0"

      allowed_audiences = [
        "api://bb85dbd3-4f25-4318-8f1d-47b436ce9edb"
      ]
    }

    login {
      token_store_enabled = false
    }
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.function.connection_string
  }

  tags = var.tags
}


# ============================================================
# 12. MANAGED IDENTITY PERMISSIONS
# ============================================================

# Access to the private Function deployment container.
resource "azurerm_role_assignment" "function_deployment_storage" {
  scope                = azurerm_storage_container.function_deployment.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}

# Access to create, read and update lead records.
resource "azurerm_role_assignment" "function_table_access" {
  scope                = azurerm_storage_account.app.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}

# Azure Functions host storage access.
resource "azurerm_role_assignment" "function_host_storage" {
  scope                = azurerm_storage_account.app.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}

# Read secrets from Key Vault.
resource "azurerm_role_assignment" "function_key_vault_access" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}

# Send telemetry using Application Insights managed identity authentication.
resource "azurerm_role_assignment" "function_app_insights_access" {
  scope                = azurerm_application_insights.function.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}
