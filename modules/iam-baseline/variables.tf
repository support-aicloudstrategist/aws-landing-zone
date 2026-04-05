variable "org_name" {
  type = string
}

variable "security_account_id" {
  description = "Account ID of the security account for cross-account audit role"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
