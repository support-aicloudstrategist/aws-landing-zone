variable "org_name" {
  type = string
}

variable "vpc_cidr" {
  description = "CIDR block for the management VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (WARNING: costs ~$32/month)"
  type        = bool
  default     = false
}

variable "flow_logs_bucket_arn" {
  description = "S3 bucket ARN for VPC Flow Logs"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
