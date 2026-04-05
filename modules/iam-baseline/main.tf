# =============================================================================
# IAM Baseline - Cross-Account Roles & Password Policy
# =============================================================================
# Establishes baseline IAM configuration in the management account:
# - Strong password policy
# - Cross-account admin role for break-glass access
# - Read-only audit role for security team
# - Support role for AWS Support access
# All IAM resources are FREE.
# =============================================================================

# -----------------------------------------------------------------------------
# Account Password Policy (management account)
# -----------------------------------------------------------------------------
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
  hard_expiry                    = false
}

# -----------------------------------------------------------------------------
# Break-Glass Admin Role
# Only usable from the management account, with MFA required
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "break_glass_admin" {
  name        = "${var.org_name}-BreakGlassAdmin"
  description = "Emergency admin access - requires MFA, logged and audited"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowManagementAccountWithMFA"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  max_session_duration = 3600 # 1 hour max for break-glass

  tags = merge(var.tags, {
    Purpose = "break-glass-emergency-access"
  })
}

resource "aws_iam_role_policy_attachment" "break_glass_admin" {
  role       = aws_iam_role.break_glass_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# Security Audit Role
# Read-only cross-account role for the security team
# -----------------------------------------------------------------------------
resource "aws_iam_role" "security_audit" {
  name        = "${var.org_name}-SecurityAudit"
  description = "Read-only access for security auditing across accounts"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecurityAccount"
        Effect = "Allow"
        Principal = {
          AWS = var.security_account_id != "" ? "arn:aws:iam::${var.security_account_id}:root" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose = "security-audit"
  })
}

resource "aws_iam_role_policy_attachment" "security_audit_readonly" {
  role       = aws_iam_role.security_audit.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "security_audit_readonly_access" {
  role       = aws_iam_role.security_audit.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# -----------------------------------------------------------------------------
# AWS Support Access Role
# -----------------------------------------------------------------------------
resource "aws_iam_role" "support_access" {
  name        = "${var.org_name}-AWSSupportAccess"
  description = "Access to AWS Support Center"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowManagementAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "support_access" {
  role       = aws_iam_role.support_access.name
  policy_arn = "arn:aws:iam::aws:policy/AWSSupportAccess"
}

# -----------------------------------------------------------------------------
# Deny Policy for sensitive operations without MFA
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "require_mfa" {
  name        = "${var.org_name}-RequireMFAForSensitiveOps"
  description = "Denies sensitive operations unless MFA is present"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyWithoutMFA"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })

  tags = var.tags
}
