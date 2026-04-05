variable "org_name" {
  description = "Organization name prefix for accounts"
  type        = string
}

variable "security_account_email" {
  description = "Email for the Security account"
  type        = string
}

variable "log_archive_account_email" {
  description = "Email for the Log Archive account"
  type        = string
}

variable "shared_services_account_email" {
  description = "Email for the Shared Services account"
  type        = string
}

variable "dev_account_email" {
  description = "Email for the Dev account"
  type        = string
}

variable "staging_account_email" {
  description = "Email for the Staging account"
  type        = string
}

variable "prod_account_email" {
  description = "Email for the Production account"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
