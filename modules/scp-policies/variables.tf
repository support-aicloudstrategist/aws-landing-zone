variable "organization_root_id" {
  description = "Root ID of the AWS Organization"
  type        = string
}

variable "security_ou_id" {
  type = string
}

variable "infrastructure_ou_id" {
  type = string
}

variable "workloads_ou_id" {
  type = string
}

variable "workloads_nonprod_ou_id" {
  type = string
}

variable "workloads_prod_ou_id" {
  type = string
}

variable "sandbox_ou_id" {
  type = string
}

variable "suspended_ou_id" {
  type = string
}

variable "allowed_regions" {
  description = "List of allowed AWS regions"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
