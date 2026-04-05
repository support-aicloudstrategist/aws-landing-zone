locals {
  # Derive account emails from pattern if not explicitly set
  security_account_email        = var.security_account_email != "" ? var.security_account_email : "${var.email_prefix}-security@${var.email_domain}"
  log_archive_account_email     = var.log_archive_account_email != "" ? var.log_archive_account_email : "${var.email_prefix}-log-archive@${var.email_domain}"
  shared_services_account_email = var.shared_services_account_email != "" ? var.shared_services_account_email : "${var.email_prefix}-shared@${var.email_domain}"
  dev_account_email             = var.dev_account_email != "" ? var.dev_account_email : "${var.email_prefix}-dev@${var.email_domain}"
  staging_account_email         = var.staging_account_email != "" ? var.staging_account_email : "${var.email_prefix}-staging@${var.email_domain}"
  prod_account_email            = var.prod_account_email != "" ? var.prod_account_email : "${var.email_prefix}-prod@${var.email_domain}"

  common_tags = merge(var.tags, {
    ManagedBy   = "terraform"
    Project     = "aws-landing-zone"
    OrgName     = var.org_name
    Environment = "management"
  })
}
