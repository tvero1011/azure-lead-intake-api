output "resource_group_name" {
  description = "Application resource group."
  value       = data.azurerm_resource_group.app.name
}

output "storage_account_name" {
  description = "Application storage account name."
  value       = azurerm_storage_account.app.name
}

output "storage_table_name" {
  description = "Lead storage table name."
  value       = azurerm_storage_table.leads.name
}

output "storage_table_endpoint" {
  description = "Azure Table Storage endpoint."
  value       = azurerm_storage_account.app.primary_table_endpoint
}

output "monitoring_dashboard_id" {
  description = "Azure Portal monitoring dashboard resource ID."
  value       = azurerm_portal_dashboard.lead_intake.id
}