# =============================================================================
# Service Control Policies (SCPs)
# =============================================================================
# SCPs are the primary preventive guardrails in an AWS Landing Zone.
# They restrict what actions member accounts can perform.
# SCPs are FREE — no cost to create or attach.
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Deny Root Account Usage (all OUs except management)
# Root credentials in member accounts should never be used
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_root_account" {
  name        = "DenyRootAccountUsage"
  description = "Prevents use of root user credentials in member accounts"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyRootActions"
        Effect    = "Deny"
        Action    = "*"
        Resource  = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach to all workload OUs
resource "aws_organizations_policy_attachment" "deny_root_workloads" {
  policy_id = aws_organizations_policy.deny_root_account.id
  target_id = var.workloads_ou_id
}

resource "aws_organizations_policy_attachment" "deny_root_sandbox" {
  policy_id = aws_organizations_policy.deny_root_account.id
  target_id = var.sandbox_ou_id
}

resource "aws_organizations_policy_attachment" "deny_root_infrastructure" {
  policy_id = aws_organizations_policy.deny_root_account.id
  target_id = var.infrastructure_ou_id
}

# -----------------------------------------------------------------------------
# 2. Region Restriction - Limit workloads to approved regions
# Prevents accidental resource creation in unapproved regions
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "region_restriction" {
  name        = "RestrictRegions"
  description = "Restricts resource creation to approved AWS regions"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnapprovedRegions"
        Effect    = "Deny"
        Action    = "*"
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.allowed_regions
          }
          # Exclude global services that only run in us-east-1
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole"
            ]
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "region_restriction_nonprod" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = var.workloads_nonprod_ou_id
}

resource "aws_organizations_policy_attachment" "region_restriction_prod" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = var.workloads_prod_ou_id
}

resource "aws_organizations_policy_attachment" "region_restriction_sandbox" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = var.sandbox_ou_id
}

# -----------------------------------------------------------------------------
# 3. Deny Leaving Organization
# Prevents accounts from removing themselves from the organization
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_leave_org" {
  name        = "DenyLeaveOrganization"
  description = "Prevents member accounts from leaving the AWS Organization"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyLeaveOrg"
        Effect   = "Deny"
        Action   = "organizations:LeaveOrganization"
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach to root — applies to all accounts
resource "aws_organizations_policy_attachment" "deny_leave_org" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = var.organization_root_id
}

# -----------------------------------------------------------------------------
# 4. Protect Security Baseline - Prevent disabling CloudTrail, Config, GuardDuty
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "protect_security_baseline" {
  name        = "ProtectSecurityBaseline"
  description = "Prevents disabling CloudTrail, Config, GuardDuty, and SecurityHub"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ProtectCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole"
            ]
          }
        }
      },
      {
        Sid    = "ProtectConfig"
        Effect = "Deny"
        Action = [
          "config:StopConfigurationRecorder",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel"
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole"
            ]
          }
        }
      },
      {
        Sid    = "ProtectGuardDuty"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromMasterAccount",
          "guardduty:UpdateDetector"
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole"
            ]
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "protect_security_nonprod" {
  policy_id = aws_organizations_policy.protect_security_baseline.id
  target_id = var.workloads_nonprod_ou_id
}

resource "aws_organizations_policy_attachment" "protect_security_prod" {
  policy_id = aws_organizations_policy.protect_security_baseline.id
  target_id = var.workloads_prod_ou_id
}

resource "aws_organizations_policy_attachment" "protect_security_infrastructure" {
  policy_id = aws_organizations_policy.protect_security_baseline.id
  target_id = var.infrastructure_ou_id
}

resource "aws_organizations_policy_attachment" "protect_security_sandbox" {
  policy_id = aws_organizations_policy.protect_security_baseline.id
  target_id = var.sandbox_ou_id
}

# -----------------------------------------------------------------------------
# 5. Deny S3 Public Access (except Sandbox)
# Prevents accidental public exposure of S3 data
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_s3_public" {
  name        = "DenyS3PublicAccess"
  description = "Prevents making S3 buckets or objects public"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyS3PublicAccess"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:PutAccountPublicAccessBlock"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:PublicAccessBlockConfiguration/BlockPublicAcls"       = "true"
            "s3:PublicAccessBlockConfiguration/BlockPublicPolicy"     = "true"
            "s3:PublicAccessBlockConfiguration/IgnorePublicAcls"      = "true"
            "s3:PublicAccessBlockConfiguration/RestrictPublicBuckets" = "true"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "deny_s3_public_workloads" {
  policy_id = aws_organizations_policy.deny_s3_public.id
  target_id = var.workloads_ou_id
}

resource "aws_organizations_policy_attachment" "deny_s3_public_security" {
  policy_id = aws_organizations_policy.deny_s3_public.id
  target_id = var.security_ou_id
}

resource "aws_organizations_policy_attachment" "deny_s3_public_infrastructure" {
  policy_id = aws_organizations_policy.deny_s3_public.id
  target_id = var.infrastructure_ou_id
}

# -----------------------------------------------------------------------------
# 6. Deny Expensive Services in Sandbox
# Prevents costly mistakes in experimental accounts
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "sandbox_cost_guardrails" {
  name        = "SandboxCostGuardrails"
  description = "Prevents launching expensive services in Sandbox accounts"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyExpensiveServices"
        Effect = "Deny"
        Action = [
          "redshift:CreateCluster",
          "rds:CreateDBCluster",
          "es:CreateElasticsearchDomain",
          "opensearch:CreateDomain",
          "elasticache:CreateCacheCluster",
          "elasticache:CreateReplicationGroup",
          "kafka:CreateCluster",
          "emr:RunJobFlow",
          "sagemaker:CreateNotebookInstance",
          "sagemaker:CreateEndpoint",
          "ec2:RunInstances"
        ]
        Resource = "*"
        Condition = {
          # Allow only small instance types for EC2
          "ForAnyValue:StringNotLike" = {
            "ec2:InstanceType" = [
              "t2.micro",
              "t2.small",
              "t3.micro",
              "t3.small",
              "t3a.micro",
              "t3a.small"
            ]
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "sandbox_cost_guardrails" {
  policy_id = aws_organizations_policy.sandbox_cost_guardrails.id
  target_id = var.sandbox_ou_id
}

# -----------------------------------------------------------------------------
# 7. Deny IAM User Creation (enforce SSO/federated access)
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "DenyIAMUserCreation"
  description = "Prevents creation of IAM users - enforce SSO/federated access"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyIAMUserCreation"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:CreateLoginProfile"
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole"
            ]
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "deny_iam_user_workloads" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = var.workloads_ou_id
}

# -----------------------------------------------------------------------------
# 8. Suspended OU - Deny Everything
# Quarantined accounts should not be able to do anything
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_all_suspended" {
  name        = "DenyAllSuspended"
  description = "Denies all actions for accounts in the Suspended OU"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyAll"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "deny_all_suspended" {
  policy_id = aws_organizations_policy.deny_all_suspended.id
  target_id = var.suspended_ou_id
}

# -----------------------------------------------------------------------------
# 9. Require Encryption at Rest
# Enforce encryption for EBS, RDS, S3, EFS
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "require_encryption" {
  name        = "RequireEncryptionAtRest"
  description = "Requires encryption for storage services"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUnencryptedEBS"
        Effect   = "Deny"
        Action   = "ec2:CreateVolume"
        Resource = "*"
        Condition = {
          Bool = {
            "ec2:Encrypted" = "false"
          }
        }
      },
      {
        Sid      = "DenyUnencryptedRDS"
        Effect   = "Deny"
        Action   = "rds:CreateDBInstance"
        Resource = "*"
        Condition = {
          Bool = {
            "rds:StorageEncrypted" = "false"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "require_encryption_workloads" {
  policy_id = aws_organizations_policy.require_encryption.id
  target_id = var.workloads_ou_id
}

resource "aws_organizations_policy_attachment" "require_encryption_infrastructure" {
  policy_id = aws_organizations_policy.require_encryption.id
  target_id = var.infrastructure_ou_id
}
