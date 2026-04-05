variable "org_name" {
  type = string
}

variable "security_account_id" {
  description = "Account ID of the Security account (delegated admin)"
  type        = string
  default     = ""
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for GuardDuty finding notifications"
  type        = string
  default     = ""
}

variable "enable_delegated_admin" {
  description = "Enable delegated admin for GuardDuty"
  type        = bool
  default     = true
}

variable "enable_sns_alerts" {
  description = "Enable SNS alerts for GuardDuty findings"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
