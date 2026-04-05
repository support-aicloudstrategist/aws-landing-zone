output "scp_ids" {
  description = "Map of SCP names to their IDs"
  value = {
    deny_root_account         = aws_organizations_policy.deny_root_account.id
    region_restriction        = aws_organizations_policy.region_restriction.id
    deny_leave_org            = aws_organizations_policy.deny_leave_org.id
    protect_security_baseline = aws_organizations_policy.protect_security_baseline.id
    deny_s3_public            = aws_organizations_policy.deny_s3_public.id
    sandbox_cost_guardrails   = aws_organizations_policy.sandbox_cost_guardrails.id
    deny_iam_user_creation    = aws_organizations_policy.deny_iam_user_creation.id
    deny_all_suspended        = aws_organizations_policy.deny_all_suspended.id
    require_encryption        = aws_organizations_policy.require_encryption.id
  }
}
