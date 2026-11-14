
# ============================================================
# AZURE MONITORING AND ALERTING
# ============================================================

resource "azurerm_monitor_action_group" "email" {
  name                = "ag-lead-intake-email"
  resource_group_name = data.azurerm_resource_group.app.name
  short_name          = "leadalert"

  email_receiver {
    name                    = "project-owner"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  tags = var.tags
}

# Alert when Application Insights records at least one
# failed request in a five-minute evaluation window.
resource "azurerm_monitor_metric_alert" "failed_requests" {
  name                = "alert-lead-intake-failed-requests"
  resource_group_name = data.azurerm_resource_group.app.name
  scopes              = [azurerm_application_insights.function.id]

  description   = "Alerts when Application Insights records failed HTTP requests."
  severity      = 2
  enabled       = true
  frequency     = "PT1M"
  window_size   = "PT5M"
  auto_mitigate = true

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }

  tags = var.tags
}

# Alert when a Key Vault deletion is recorded.
resource "azurerm_monitor_activity_log_alert" "key_vault_delete" {
  name                = "alert-lead-intake-keyvault-delete"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = "global"
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]

  description = "Alerts when a Key Vault deletion operation is recorded."

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.KeyVault/vaults/delete"
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }

  tags = var.tags
}

# Alert when an Azure RBAC role assignment is created or changed.
resource "azurerm_monitor_activity_log_alert" "role_assignment_write" {
  name                = "alert-lead-intake-role-assignment"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = "global"
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]

  description = "Alerts when an Azure role assignment write operation is recorded."

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Authorization/roleAssignments/write"
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }

  tags = var.tags
}
