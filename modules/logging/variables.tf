variable "org_name" {
  type = string
}

variable "retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 365
}

variable "tags" {
  type    = map(string)
  default = {}
}
