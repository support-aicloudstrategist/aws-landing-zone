# =============================================================================
# AWS Landing Zone - Root Module
# =============================================================================
# This is the top-level orchestrator that wires all modules together.
# Apply this from the management (root) account with admin credentials.
# =============================================================================

# -----------------------------------------------------------------------------
# 1. AWS Organizations - OUs and Accounts
# Cost: FREE
# -----------------------------------------------------------------------------
module "organization" {
  source = "./modules/organization"

  org_name                      = var.org_name
  security_account_email        = local.security_account_email
  log_archive_account_email     = local.log_archive_account_email
  shared_services_account_email = local.shared_services_account_email
  dev_account_email             = local.dev_account_email
  staging_account_email         = local.staging_account_email
  prod_account_email            = local.prod_account_email
  tags                          = local.common_tags
}

# -----------------------------------------------------------------------------
# 2. Service Control Policies (SCPs) - Guardrails
# Cost: FREE
# -----------------------------------------------------------------------------
module "scp_policies" {
  source = "./modules/scp-policies"

  organization_root_id = module.organization.organization_root_id
  security_ou_id       = module.organization.security_ou_id
  infrastructure_ou_id    = module.organization.infrastructure_ou_id
  workloads_ou_id         = module.organization.workloads_ou_id
  workloads_nonprod_ou_id = module.organization.workloads_nonprod_ou_id
  workloads_prod_ou_id    = module.organization.workloads_prod_ou_id
  sandbox_ou_id           = module.organization.sandbox_ou_id
  suspended_ou_id         = module.organization.suspended_ou_id
  allowed_regions      = var.allowed_regions
  tags                 = local.common_tags

  depends_on = [module.organization]
}

# -----------------------------------------------------------------------------
# 3. IAM Baseline - Roles & Password Policy
# Cost: FREE
# -----------------------------------------------------------------------------
module "iam_baseline" {
  source = "./modules/iam-baseline"

  org_name            = var.org_name
  security_account_id = module.organization.security_account_id
  tags                = local.common_tags

  depends_on = [module.organization]
}

# -----------------------------------------------------------------------------
# 4. Centralized Logging - CloudTrail, Config, S3
# Cost: ~$3-5/month (CloudTrail S3 storage + Config recorder)
# First CloudTrail trail is FREE. Config recorder ~$2/month.
# -----------------------------------------------------------------------------
module "logging" {
  source = "./modules/logging"

  org_name               = var.org_name
  retention_days         = var.cloudtrail_retention_days
  enable_config_recorder = var.enable_config_recorder
  tags                   = local.common_tags

  depends_on = [module.organization]
}

# -----------------------------------------------------------------------------
# 5. Security Baseline - Security Hub, IAM Access Analyzer
# Cost: Security Hub ~$5/month after 30-day trial. Access Analyzer FREE.
# -----------------------------------------------------------------------------
module "security_baseline" {
  source = "./modules/security-baseline"

  org_name               = var.org_name
  security_account_id    = module.organization.security_account_id
  enable_delegated_admin = var.enable_security_hub
  enable_security_hub    = var.enable_security_hub
  notification_emails    = var.budget_alert_emails
  tags                   = local.common_tags

  depends_on = [module.organization, module.logging]
}

# -----------------------------------------------------------------------------
# 6. GuardDuty - Threat Detection (optional)
# Cost: FREE for 30 days, then ~$4/account/month
# Set enable_guardduty = false to skip
# -----------------------------------------------------------------------------
module "guardduty" {
  source = "./modules/guardduty"
  count  = var.enable_guardduty ? 1 : 0

  org_name               = var.org_name
  security_account_id    = module.organization.security_account_id
  enable_delegated_admin = true
  enable_sns_alerts      = true
  sns_topic_arn          = module.security_baseline.security_findings_topic_arn
  tags                   = local.common_tags

  depends_on = [module.organization, module.security_baseline]
}

# -----------------------------------------------------------------------------
# 7. Config Rules - Compliance Checks (optional)
# Cost: ~$0.001 per rule evaluation
# Set enable_config_rules = false to skip
# -----------------------------------------------------------------------------
module "config_rules" {
  source = "./modules/config-rules"
  count  = var.enable_config_rules ? 1 : 0

  tags = local.common_tags

  depends_on = [module.logging]
}

# -----------------------------------------------------------------------------
# 8. Networking Foundation - VPC (management account)
# Cost: FREE (VPC, subnets, IGW, route tables are all free)
# NAT Gateway is DISABLED by default (~$32/month if enabled)
# -----------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  org_name             = var.org_name
  enable_nat_gateway   = false # Set to true if you need private subnet internet access (~$32/month)
  flow_logs_bucket_arn = "arn:aws:s3:::${module.logging.access_logs_bucket_name}"
  tags                 = local.common_tags

  depends_on = [module.logging]
}

# -----------------------------------------------------------------------------
# 9. Budget Alerts - Cost Controls
# Cost: FREE (first 2 budgets per account are free)
# -----------------------------------------------------------------------------
module "budget_alerts" {
  source = "./modules/budget-alerts"

  org_name         = var.org_name
  budget_limit_usd = var.budget_limit_usd
  alert_emails     = var.budget_alert_emails
  tags             = local.common_tags
}
