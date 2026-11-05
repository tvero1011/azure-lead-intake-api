variable "location" {
  description = "Azure region for application resources."
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "Name of the application resource group."
  type        = string
  default     = "rg-lead-intake"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project identifier used for resource naming."
  type        = string
  default     = "lead-intake"
}

variable "tags" {
  description = "Tags applied to application resources."
  type        = map(string)

  default = {
    project     = "azure-lead-intake-api"
    environment = "dev"
    managed_by  = "terraform"
  }
}