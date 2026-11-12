output "bootstrap_resource_group_name" {
  description = "Bootstrap resource group name."
  value       = azurerm_resource_group.bootstrap.name
}

output "application_resource_group_name" {
  description = "Application resource group name."
  value       = azurerm_resource_group.application.name
}