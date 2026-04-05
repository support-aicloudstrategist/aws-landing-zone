# =============================================================================
# Root Outputs
# =============================================================================

# Organization
output "organization_id" {
  description = "AWS Organization ID"
  value       = module.organization.organization_id
}

output "management_account_id" {
  description = "Management account ID"
  value       = module.organization.management_account_id
}

# Account IDs
output "account_ids" {
  description = "Map of all member account IDs"
  value       = module.organization.all_account_ids
}

# OU IDs
output "ou_ids" {
  description = "Map of OU names to IDs"
  value = {
    security        = module.organization.security_ou_id
    infrastructure  = module.organization.infrastructure_ou_id
    workloads       = module.organization.workloads_ou_id
    workloads_nonprod = module.organization.workloads_nonprod_ou_id
    workloads_prod  = module.organization.workloads_prod_ou_id
    sandbox         = module.organization.sandbox_ou_id
    policy_staging  = module.organization.policy_staging_ou_id
    suspended       = module.organization.suspended_ou_id
  }
}

# SCP IDs
output "scp_policy_ids" {
  description = "Map of SCP policy names to IDs"
  value       = module.scp_policies.scp_ids
}

# IAM
output "break_glass_role_arn" {
  description = "ARN of the break-glass admin role (MFA required)"
  value       = module.iam_baseline.break_glass_role_arn
}

output "security_audit_role_arn" {
  description = "ARN of the security audit role"
  value       = module.iam_baseline.security_audit_role_arn
}

# Logging
output "cloudtrail_arn" {
  description = "Organization CloudTrail ARN"
  value       = module.logging.cloudtrail_arn
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = module.logging.cloudtrail_s3_bucket_name
}

output "config_s3_bucket" {
  description = "S3 bucket for Config logs"
  value       = module.logging.config_s3_bucket_name
}

# Security
output "security_findings_topic_arn" {
  description = "SNS topic for security finding alerts"
  value       = module.security_baseline.security_findings_topic_arn
}

# Networking
output "vpc_id" {
  description = "Management VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

# Budget
output "budget_alerts_topic_arn" {
  description = "SNS topic for budget alerts"
  value       = module.budget_alerts.budget_alerts_topic_arn
}
