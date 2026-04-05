variable "org_name" {
  type = string
}

variable "retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 365
}

variable "enable_config_recorder" {
  description = "Enable AWS Config recorder (~$2/month)"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
