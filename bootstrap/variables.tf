
variable "location" {
  description = "Azure region for the project."
  type        = string
  default     = "southeastasia"
}

variable "bootstrap_resource_group_name" {
  description = "Resource group for Terraform bootstrap resources."
  type        = string
  default     = "rg-lead-intake-bootstrap"
}

variable "application_resource_group_name" {
  description = "Resource group for application infrastructure."
  type        = string
  default     = "rg-lead-intake"
}

variable "storage_account_prefix" {
  description = "Prefix for the globally unique Terraform state storage account."
  type        = string
  default     = "stleadintake"
}

variable "allowed_locations" {
  description = "Azure regions permitted for application resources."
  type        = list(string)
  default     = ["southeastasia"]
}

variable "required_tag_name" {
  description = "Tag required on application resources."
  type        = string
  default     = "project"
}
