
resource "azurerm_portal_dashboard" "lead_intake" {
  name                = "dashboard-lead-intake"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_resource_group.app.location

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = {
              x       = 0
              y       = 0
              rowSpan = 3
              colSpan = 6
            }

            metadata = {
              inputs = []
              type   = "Extension/HubsExtension/PartType/MarkdownPart"

              settings = {
                content = {
                  settings = {
                    title    = "Azure Lead Intake API"
                    subtitle = "Portfolio monitoring dashboard"
                    content  = <<-EOT
                      ## Lead Intake API

                      **Environment:** ${var.environment}

                      **Hosting:** Azure Functions Flex Consumption

                      **Storage:** Azure Table Storage (Standard LRS)

                      **Monitoring:** Application Insights and Azure Monitor

                      **Security:** Managed Identity, Entra ID and Key Vault

                      ### Monitoring resources

                      - Application Insights: ${azurerm_application_insights.function.name}
                      - Log Analytics: ${azurerm_log_analytics_workspace.function.name}
                      - Alert group: ${azurerm_monitor_action_group.email.name}

                      ### Investigation

                      Use the saved KQL queries in the repository's `queries/` folder to investigate failed requests, performance, exceptions and dependencies.
                    EOT
                  }
                }
              }
            }
          }
        }
      }
    }

    metadata = {
      model = {
        timeRange = {
          value = {
            relative = {
              duration = 24
              timeUnit = 1
            }
          }
          type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
      }
    }
  })

  tags = merge(var.tags, {
    "hidden-title" = "Lead Intake API Monitoring"
  })
}
