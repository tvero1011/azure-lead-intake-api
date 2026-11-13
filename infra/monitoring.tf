
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

# Alert when at least one failed request is recorded
# in a five-minute evaluation window.
resource "azurerm_monitor_metric_alert" "failed_requests" {
  name                = "alert-lead-intake-http5xx"
  resource_group_name = data.azurerm_resource_group.app.name
  scopes              = [azurerm_function_app_flex_consumption.api.id]

  description   = "Alerts when the Lead Intake Function App returns HTTP 5xx errors."
  severity      = 2
  enabled       = true
  frequency     = "PT1M"
  window_size   = "PT5M"
  auto_mitigate = true

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
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
