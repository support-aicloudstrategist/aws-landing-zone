# =============================================================================
# AWS Config Rules - Compliance Checks
# =============================================================================
# COST NOTES:
# - Each rule evaluation costs ~$0.001
# - We use only essential managed rules to minimize cost
# - With 6 accounts and ~10 rules, expect ~$2-5/month total
# =============================================================================

# -----------------------------------------------------------------------------
# Essential AWS Managed Config Rules
# These are the minimum recommended rules for Well-Architected compliance
# -----------------------------------------------------------------------------

# 1. Root account MFA enabled
resource "aws_config_config_rule" "root_mfa" {
  name = "root-account-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  maximum_execution_frequency = "TwentyFour_Hours"

  tags = var.tags
}

# 2. IAM password policy meets requirements
resource "aws_config_config_rule" "iam_password_policy" {
  name = "iam-password-policy"

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  input_parameters = jsonencode({
    RequireUppercaseCharacters = "true"
    RequireLowercaseCharacters = "true"
    RequireSymbols             = "true"
    RequireNumbers             = "true"
    MinimumPasswordLength      = "14"
    PasswordReusePrevention    = "24"
    MaxPasswordAge             = "90"
  })

  maximum_execution_frequency = "TwentyFour_Hours"

  tags = var.tags
}

# 3. CloudTrail enabled
resource "aws_config_config_rule" "cloudtrail_enabled" {
  name = "cloudtrail-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  maximum_execution_frequency = "TwentyFour_Hours"

  tags = var.tags
}

# 4. S3 bucket encryption
resource "aws_config_config_rule" "s3_encryption" {
  name = "s3-bucket-server-side-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  tags = var.tags
}

# 5. S3 bucket public read prohibited
resource "aws_config_config_rule" "s3_public_read" {
  name = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  tags = var.tags
}

# 6. S3 bucket public write prohibited
resource "aws_config_config_rule" "s3_public_write" {
  name = "s3-bucket-public-write-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  tags = var.tags
}

# 7. EBS volumes encrypted
resource "aws_config_config_rule" "ebs_encrypted" {
  name = "encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  tags = var.tags
}

# 8. RDS encryption enabled
resource "aws_config_config_rule" "rds_encrypted" {
  name = "rds-storage-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  tags = var.tags
}

# 9. VPC Flow Logs enabled
resource "aws_config_config_rule" "vpc_flow_logs" {
  name = "vpc-flow-logs-enabled"

  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }

  maximum_execution_frequency = "TwentyFour_Hours"

  tags = var.tags
}

# 10. Multi-region CloudTrail enabled
resource "aws_config_config_rule" "multi_region_cloudtrail" {
  name = "multi-region-cloudtrail-enabled"

  source {
    owner             = "AWS"
    source_identifier = "MULTI_REGION_CLOUD_TRAIL_ENABLED"
  }

  maximum_execution_frequency = "TwentyFour_Hours"

  tags = var.tags
}

# 11. Restricted SSH (no 0.0.0.0/0 on port 22)
resource "aws_config_config_rule" "restricted_ssh" {
  name = "restricted-ssh"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  tags = var.tags
}

# 12. Restricted common ports
resource "aws_config_config_rule" "restricted_common_ports" {
  name = "restricted-common-ports"

  source {
    owner             = "AWS"
    source_identifier = "RESTRICTED_INCOMING_TRAFFIC"
  }

  input_parameters = jsonencode({
    blockedPort1 = "3389" # RDP
    blockedPort2 = "3306" # MySQL
    blockedPort3 = "5432" # PostgreSQL
    blockedPort4 = "1433" # MSSQL
    blockedPort5 = "6379" # Redis
  })

  tags = var.tags
}
