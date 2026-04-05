# =============================================================================
# Root Variables - AWS Landing Zone
# =============================================================================

variable "org_name" {
  description = "Organization name used for naming resources"
  type        = string
}

variable "aws_region" {
  description = "Primary AWS region for the landing zone"
  type        = string
  default     = "us-east-1"
}

variable "email_domain" {
  description = "Domain for account email addresses (e.g., yourdomain.com)"
  type        = string
}

variable "email_prefix" {
  description = "Email prefix for sub-account emails (e.g., admin+aws). Accounts will be admin+aws-security@domain.com"
  type        = string
  default     = "admin+aws"
}

# Account emails - override if you want custom emails per account
variable "security_account_email" {
  description = "Email for the Security account"
  type        = string
  default     = ""
}

variable "log_archive_account_email" {
  description = "Email for the Log Archive account"
  type        = string
  default     = ""
}

variable "shared_services_account_email" {
  description = "Email for the Shared Services account"
  type        = string
  default     = ""
}

variable "dev_account_email" {
  description = "Email for the Dev account"
  type        = string
  default     = ""
}

variable "staging_account_email" {
  description = "Email for the Staging account"
  type        = string
  default     = ""
}

variable "prod_account_email" {
  description = "Email for the Production account"
  type        = string
  default     = ""
}

variable "enable_guardduty" {
  description = "Enable GuardDuty across the organization (has cost after 30-day trial)"
  type        = bool
  default     = true
}

variable "enable_config_rules" {
  description = "Enable AWS Config rules (has per-evaluation cost)"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable Security Hub (~$5/month after 30-day trial)"
  type        = bool
  default     = true
}

variable "enable_config_recorder" {
  description = "Enable AWS Config recorder (~$2/month)"
  type        = bool
  default     = true
}

variable "cloudtrail_retention_days" {
  description = "Number of days to retain CloudTrail logs in S3"
  type        = number
  default     = 365
}

variable "budget_limit_usd" {
  description = "Monthly budget limit in USD for budget alerts"
  type        = string
  default     = "50"
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alert notifications"
  type        = list(string)
  default     = []
}

variable "allowed_regions" {
  description = "List of AWS regions allowed for workloads (SCP enforcement)"
  type        = list(string)
  default     = ["us-east-1", "us-west-2", "eu-west-1"]
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
