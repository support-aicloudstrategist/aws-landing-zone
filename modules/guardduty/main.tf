# =============================================================================
# Amazon GuardDuty - Organization-wide Threat Detection
# =============================================================================
# COST NOTES:
# - 30-day FREE trial per account per region
# - After trial: ~$4/account/month for a low-activity account
# - Charges based on CloudTrail events, VPC Flow Logs, and DNS queries analyzed
# - Set enable_guardduty = false if cost is a concern
# =============================================================================

# -----------------------------------------------------------------------------
# GuardDuty Detector (management account)
# -----------------------------------------------------------------------------
resource "aws_guardduty_detector" "main" {
  enable = true

  # Use lowest-cost configuration
  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false # Enable only if using EKS
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = false # Enable if needed — has additional cost
        }
      }
    }
  }

  finding_publishing_frequency = "SIX_HOURS" # Least frequent = lowest cost

  tags = merge(var.tags, {
    Purpose = "threat-detection"
  })
}

# -----------------------------------------------------------------------------
# Delegate Administration to Security Account
# -----------------------------------------------------------------------------
resource "aws_guardduty_organization_admin_account" "security" {
  count            = var.enable_delegated_admin ? 1 : 0
  admin_account_id = var.security_account_id

  depends_on = [aws_guardduty_detector.main]
}

# NOTE: Organization auto-enable must be configured from the delegated admin
# account (security account), not the management account. After deploying,
# assume a role into the security account and run:
#   aws guardduty update-organization-configuration --detector-id <id> --auto-enable

# -----------------------------------------------------------------------------
# EventBridge Rule for GuardDuty High/Critical Findings
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.org_name}-guardduty-high-findings"
  description = "Captures high and critical severity GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [
        { numeric = [">=", 7] } # High and Critical (7-8.9)
      ]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  count     = var.enable_sns_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "send-to-sns"
  arn       = var.sns_topic_arn
}
