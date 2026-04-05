output "break_glass_role_arn" {
  value = aws_iam_role.break_glass_admin.arn
}

output "security_audit_role_arn" {
  value = aws_iam_role.security_audit.arn
}

output "support_access_role_arn" {
  value = aws_iam_role.support_access.arn
}

output "require_mfa_policy_arn" {
  value = aws_iam_policy.require_mfa.arn
}
