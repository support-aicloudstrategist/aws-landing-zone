# =============================================================================
# AWS Organizations - OUs and Accounts
# =============================================================================
# Based on AWS Well-Architected Framework & Control Tower best practices
# OU structure follows the recommended multi-account strategy
# =============================================================================

# -----------------------------------------------------------------------------
# Organization
# -----------------------------------------------------------------------------
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "access-analyzer.amazonaws.com",
    "tagpolicies.tag.amazonaws.com",
    "sso.amazonaws.com",
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]

  feature_set = "ALL"
}

# -----------------------------------------------------------------------------
# Organizational Units (OUs)
# -----------------------------------------------------------------------------

# Security OU - contains security and log archive accounts
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.org.roots[0].id
}

# Infrastructure OU - shared services, networking, CI/CD
resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.org.roots[0].id
}

# Workloads OU - application accounts (dev, staging, prod)
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.org.roots[0].id
}

# Non-Prod sub-OU under Workloads
resource "aws_organizations_organizational_unit" "workloads_nonprod" {
  name      = "NonProd"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

# Prod sub-OU under Workloads
resource "aws_organizations_organizational_unit" "workloads_prod" {
  name      = "Prod"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

# Sandbox OU - experimentation, learning, PoCs
resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.org.roots[0].id
}

# Policy Staging OU - test SCPs before applying to production OUs
resource "aws_organizations_organizational_unit" "policy_staging" {
  name      = "PolicyStaging"
  parent_id = aws_organizations_organization.org.roots[0].id
}

# Suspended OU - quarantine decommissioned accounts
resource "aws_organizations_organizational_unit" "suspended" {
  name      = "Suspended"
  parent_id = aws_organizations_organization.org.roots[0].id
}

# -----------------------------------------------------------------------------
# Member Accounts
# -----------------------------------------------------------------------------

# Security Account
resource "aws_organizations_account" "security" {
  name      = "${var.org_name}-security"
  email     = var.security_account_email
  parent_id = aws_organizations_organizational_unit.security.id

  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType = "security"
  })
}

# Log Archive Account
resource "aws_organizations_account" "log_archive" {
  name      = "${var.org_name}-log-archive"
  email     = var.log_archive_account_email
  parent_id = aws_organizations_organizational_unit.security.id

  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType = "log-archive"
  })
}

# Shared Services Account
resource "aws_organizations_account" "shared_services" {
  name      = "${var.org_name}-shared-services"
  email     = var.shared_services_account_email
  parent_id = aws_organizations_organizational_unit.infrastructure.id

  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType = "shared-services"
  })
}

# Dev Account
resource "aws_organizations_account" "dev" {
  name      = "${var.org_name}-dev"
  email     = var.dev_account_email
  parent_id = aws_organizations_organizational_unit.workloads_nonprod.id

  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType  = "workload"
    Environment  = "dev"
  })
}

# Staging Account
resource "aws_organizations_account" "staging" {
  name      = "${var.org_name}-staging"
  email     = var.staging_account_email
  parent_id = aws_organizations_organizational_unit.workloads_nonprod.id

  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType  = "workload"
    Environment  = "staging"
  })
}

# Production Account
resource "aws_organizations_account" "prod" {
  name      = "${var.org_name}-prod"
  email     = var.prod_account_email
  parent_id = aws_organizations_organizational_unit.workloads_prod.id

  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType  = "workload"
    Environment  = "production"
  })
}
