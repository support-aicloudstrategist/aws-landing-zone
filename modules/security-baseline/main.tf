# =============================================================================
# Security Baseline - Security Hub, IAM Access Analyzer
# =============================================================================
# COST NOTES:
# - Security Hub: 30-day free trial, then ~$0.0010 per check per account
# - IAM Access Analyzer: Free
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# AWS Security Hub (organization-wide)
# -----------------------------------------------------------------------------
resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0
}

resource "aws_securityhub_organization_admin_account" "security" {
  count            = var.enable_security_hub && var.enable_delegated_admin ? 1 : 0
  admin_account_id = var.security_account_id

  depends_on = [aws_securityhub_account.main]
}

# NOTE: Organization auto-enable must be configured from the delegated admin
# account (security account), not the management account. After deploying,
# assume a role into the security account and run:
#   aws securityhub update-organization-configuration --auto-enable

# Enable AWS Foundational Security Best Practices standard
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.main]
}

# Enable CIS AWS Foundations Benchmark
resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"

  depends_on = [aws_securityhub_account.main]
}

# -----------------------------------------------------------------------------
# IAM Access Analyzer (organization-wide) - FREE
# Identifies resources shared with external entities
# -----------------------------------------------------------------------------
resource "aws_accessanalyzer_analyzer" "org_analyzer" {
  analyzer_name = "${var.org_name}-org-access-analyzer"
  type          = "ORGANIZATION"

  tags = merge(var.tags, {
    Purpose = "external-access-analysis"
  })
}

# Account-level analyzer for unused access (free)
resource "aws_accessanalyzer_analyzer" "account_analyzer" {
  analyzer_name = "${var.org_name}-account-access-analyzer"
  type          = "ACCOUNT"

  tags = merge(var.tags, {
    Purpose = "account-access-analysis"
  })
}

# -----------------------------------------------------------------------------
# SNS Topic for Security Findings
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "security_findings" {
  name = "${var.org_name}-security-findings"

  tags = merge(var.tags, {
    Purpose = "security-notifications"
  })
}

resource "aws_sns_topic_policy" "security_findings" {
  arn = aws_sns_topic.security_findings.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecurityHubPublish"
        Effect = "Allow"
        Principal = {
          Service = "securityhub.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_findings.arn
      },
      {
        Sid    = "AllowGuardDutyPublish"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_findings.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "security_email" {
  count     = length(var.notification_emails)
  topic_arn = aws_sns_topic.security_findings.arn
  protocol  = "email"
  endpoint  = var.notification_emails[count.index]
}

# -----------------------------------------------------------------------------
# EventBridge Rule for High-Severity SecurityHub Findings
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "high_severity_findings" {
  name        = "${var.org_name}-high-severity-findings"
  description = "Captures high and critical severity Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "high_severity_to_sns" {
  rule      = aws_cloudwatch_event_rule.high_severity_findings.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.security_findings.arn
}

# -----------------------------------------------------------------------------
# Account-level S3 Block Public Access
# -----------------------------------------------------------------------------
resource "aws_s3_account_public_access_block" "block_public" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# EBS Default Encryption
# -----------------------------------------------------------------------------
resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}
