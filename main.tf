data "azurerm_resource_group" "app" {
  name = var.resource_group_name
}

resource "random_string" "storage_suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

resource "azurerm_storage_account" "app" {
  name                     = "stleadintake${random_string.storage_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.app.name
  location                 = data.azurerm_resource_group.app.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = true
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_table" "leads" {
  name                 = "Leads"
  storage_account_name = azurerm_storage_account.app.name
}