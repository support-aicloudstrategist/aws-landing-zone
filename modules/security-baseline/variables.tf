variable "org_name" {
  type = string
}

variable "security_account_id" {
  description = "Account ID of the Security account (delegated admin)"
  type        = string
  default     = ""
}

variable "enable_delegated_admin" {
  description = "Enable delegated admin for Security Hub"
  type        = bool
  default     = true
}

variable "notification_emails" {
  description = "Email addresses for security finding notifications"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
