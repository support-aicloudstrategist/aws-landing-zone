output "organization_id" {
  description = "The ID of the AWS Organization"
  value       = aws_organizations_organization.org.id
}

output "organization_root_id" {
  description = "The root ID of the organization"
  value       = aws_organizations_organization.org.roots[0].id
}

output "management_account_id" {
  description = "The management (root) account ID"
  value       = aws_organizations_organization.org.master_account_id
}

# OU IDs
output "security_ou_id" {
  value = aws_organizations_organizational_unit.security.id
}

output "infrastructure_ou_id" {
  value = aws_organizations_organizational_unit.infrastructure.id
}

output "workloads_ou_id" {
  value = aws_organizations_organizational_unit.workloads.id
}

output "workloads_nonprod_ou_id" {
  value = aws_organizations_organizational_unit.workloads_nonprod.id
}

output "workloads_prod_ou_id" {
  value = aws_organizations_organizational_unit.workloads_prod.id
}

output "sandbox_ou_id" {
  value = aws_organizations_organizational_unit.sandbox.id
}

output "policy_staging_ou_id" {
  value = aws_organizations_organizational_unit.policy_staging.id
}

output "suspended_ou_id" {
  value = aws_organizations_organizational_unit.suspended.id
}

# Account IDs
output "security_account_id" {
  value = aws_organizations_account.security.id
}

output "log_archive_account_id" {
  value = aws_organizations_account.log_archive.id
}

output "shared_services_account_id" {
  value = aws_organizations_account.shared_services.id
}

output "dev_account_id" {
  value = aws_organizations_account.dev.id
}

output "staging_account_id" {
  value = aws_organizations_account.staging.id
}

output "prod_account_id" {
  value = aws_organizations_account.prod.id
}

output "all_account_ids" {
  description = "Map of all account names to IDs"
  value = {
    security        = aws_organizations_account.security.id
    log_archive     = aws_organizations_account.log_archive.id
    shared_services = aws_organizations_account.shared_services.id
    dev             = aws_organizations_account.dev.id
    staging         = aws_organizations_account.staging.id
    prod            = aws_organizations_account.prod.id
  }
}
