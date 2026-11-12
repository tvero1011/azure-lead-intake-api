
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
