
# --------------------------------------------------
# CURRENT AZURE ACCOUNT
# --------------------------------------------------

data "azurerm_client_config" "current" {}


# --------------------------------------------------
# RANDOM STORAGE ACCOUNT SUFFIX
# --------------------------------------------------

resource "random_string" "storage_suffix" {
  length  = 8
  upper   = false
  lower   = true
  numeric = true
  special = false
}


# --------------------------------------------------
# COMMON RESOURCE TAGS
# --------------------------------------------------

locals {
  common_tags = {
    project     = "azure-lead-intake-api"
    managed_by  = "terraform"
    environment = "bootstrap"
  }
}


# --------------------------------------------------
# BOOTSTRAP RESOURCE GROUP
# --------------------------------------------------

resource "azurerm_resource_group" "bootstrap" {
  name     = var.bootstrap_resource_group_name
  location = var.location

  tags = local.common_tags
}


# --------------------------------------------------
# APPLICATION RESOURCE GROUP
# --------------------------------------------------

resource "azurerm_resource_group" "application" {
  name     = var.application_resource_group_name
  location = var.location

  tags = {
    project     = "azure-lead-intake-api"
    managed_by  = "terraform"
    environment = "application"
  }
}


# --------------------------------------------------
# TERRAFORM STATE STORAGE ACCOUNT
# --------------------------------------------------

resource "azurerm_storage_account" "tfstate" {
  name = "${var.storage_account_prefix}${random_string.storage_suffix.result}"

  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  # Use Entra ID / OAuth instead of storage account keys.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  local_user_enabled              = false

  # The endpoint is reachable for authenticated clients,
  # including GitHub-hosted runners. Blob access remains private.
  public_network_access_enabled = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.common_tags
}


# --------------------------------------------------
# GRANT CURRENT TERRAFORM USER STORAGE ACCESS
# --------------------------------------------------

resource "azurerm_role_assignment" "current_user_blob_access" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}


# --------------------------------------------------
# PRIVATE TERRAFORM STATE CONTAINER
# --------------------------------------------------

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"

  depends_on = [
    azurerm_role_assignment.current_user_blob_access
  ]
}


# --------------------------------------------------
# AZURE POLICY: ALLOWED LOCATIONS
# --------------------------------------------------

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "lead-intake-allowed-locations"
  display_name         = "Allowed locations for Lead Intake"
  resource_group_id    = azurerm_resource_group.application.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_locations
    }
  })
}


# --------------------------------------------------
# AZURE POLICY: REQUIRE PROJECT TAG
# --------------------------------------------------

resource "azurerm_resource_group_policy_assignment" "require_project_tag" {
  name                 = "lead-intake-require-project-tag"
  display_name         = "Require project tag on resources"
  resource_group_id    = azurerm_resource_group.application.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"

  parameters = jsonencode({
    tagName = {
      value = var.required_tag_name
    }
  })
}
