
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.13"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "fa7fcbf6-fa53-4805-98e7-18f0cfa314ff"
  # Use Microsoft Entra ID for Azure Storage data-plane operations.
  storage_use_azuread = true
}
