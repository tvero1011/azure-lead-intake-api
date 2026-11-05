terraform {
  backend "azurerm" {
    resource_group_name  = "rg-lead-intake-bootstrap"
    storage_account_name = "stleadintakejj5rrhm0"
    container_name       = "tfstate"
    key                  = "lead-intake-app.tfstate"

    use_azuread_auth = true
  }
}