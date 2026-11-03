
output "bootstrap_resource_group_name" {
  description = "Bootstrap resource group name."
  value       = azurerm_resource_group.bootstrap.name
}

output "application_resource_group_name" {
  description = "Application resource group name."
  value       = azurerm_resource_group.application.name
}

output "storage_account_name" {
  description = "Terraform state storage account name."
  value       = azurerm_storage_account.tfstate.name
}

output "storage_container_name" {
  description = "Terraform state blob container name."
  value       = azurerm_storage_container.tfstate.name
}

output "storage_account_id" {
  description = "Terraform state storage account resource ID."
  value       = azurerm_storage_account.tfstate.id
}
