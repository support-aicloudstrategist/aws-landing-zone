# How to Enable Security Services

This guide walks you through re-enabling the security services that were disabled
to minimize costs during the PoC phase. Each service can be enabled independently.

---

## Table of Contents

1. [Overview of Disabled Services](#1-overview-of-disabled-services)
2. [Prerequisites](#2-prerequisites)
3. [Enable AWS Config Recorder](#3-enable-aws-config-recorder)
4. [Enable AWS Config Rules](#4-enable-aws-config-rules)
5. [Enable AWS Security Hub](#5-enable-aws-security-hub)
6. [Enable Amazon GuardDuty](#6-enable-amazon-guardduty)
7. [Enable All Services at Once](#7-enable-all-services-at-once)
8. [Post-Enablement Steps](#8-post-enablement-steps)
9. [Cost Impact Summary](#9-cost-impact-summary)
10. [Verifying Services Are Running](#10-verifying-services-are-running)
11. [Rollback (Disable Again)](#11-rollback-disable-again)

---

## 1. Overview of Disabled Services

| Service | What It Does | Monthly Cost | Free Trial |
|---|---|---|---|
| **Config Recorder** | Continuously records resource configurations and changes | ~$2/month | No |
| **Config Rules** | 12 compliance rules (encryption, public access, MFA, etc.) | ~$1-2/month | No |
| **Security Hub** | Aggregates security findings, runs compliance checks | ~$5/month | 30 days |
| **GuardDuty** | AI-powered threat detection across all accounts | ~$4/account/month | 30 days |

### Dependency Chain

```
Config Recorder ──► Config Rules (requires Config Recorder)
                       │
Security Hub ──────────┘ (uses Config findings)
                       │
GuardDuty ─────────────┘ (sends findings to Security Hub)
```

**Recommended enablement order:**
1. Config Recorder (required by Config Rules)
2. Config Rules
3. Security Hub
4. GuardDuty

---

## 2. Prerequisites

Before enabling any service, ensure you have:

- [ ] AWS CLI configured with management account admin credentials
- [ ] Terraform installed (>= 1.5.0)
- [ ] Access to the `terraform.tfvars` file in the project directory

```bash
# Verify you're in the right account
aws sts get-caller-identity

# Navigate to the project
cd aws-landing-zone
```

---

## 3. Enable AWS Config Recorder

**What it does:** Continuously records the configuration of your AWS resources.
Tracks changes over time and delivers configuration snapshots to S3.

**Cost:** ~$2/month per account

### Step 1: Update terraform.tfvars

Open `terraform.tfvars` and change:

```hcl
# Before
enable_config_recorder = false

# After
enable_config_recorder = true
```

### Step 2: Plan and Apply

```bash
terraform plan -out=plan.tfplan
```

You should see approximately **6 resources to add**:
- `aws_config_configuration_recorder.main`
- `aws_config_delivery_channel.main`
- `aws_config_configuration_recorder_status.main`
- `aws_iam_role.config_role` (IAM role for Config service)
- `aws_iam_role_policy_attachment.config_role`
- `aws_iam_role_policy.config_s3_delivery`

Review the plan, then apply:

```bash
terraform apply plan.tfplan
```

### Step 3: Verify

```bash
aws configservice describe-configuration-recorder-status --region YOUR_REGION
```

Expected output:
```json
{
    "ConfigurationRecordersStatus": [{
        "name": "your-org-config-recorder",
        "recording": true,
        "lastStatus": "SUCCESS"
    }]
}
```

---

## 4. Enable AWS Config Rules

**What it does:** Evaluates your AWS resources against 12 compliance rules:

| Rule | What It Checks |
|---|---|
| root-account-mfa-enabled | Root account has MFA |
| iam-password-policy | Password policy meets requirements |
| cloudtrail-enabled | CloudTrail is active |
| s3-bucket-server-side-encryption-enabled | S3 buckets are encrypted |
| s3-bucket-public-read-prohibited | No public read access on S3 |
| s3-bucket-public-write-prohibited | No public write access on S3 |
| encrypted-volumes | EBS volumes are encrypted |
| rds-storage-encrypted | RDS instances are encrypted |
| vpc-flow-logs-enabled | VPC flow logs are enabled |
| multi-region-cloudtrail-enabled | CloudTrail covers all regions |
| restricted-ssh | SSH (port 22) not open to 0.0.0.0/0 |
| restricted-common-ports | Dangerous ports (RDP, MySQL, etc.) not open |

**Cost:** ~$0.001 per rule evaluation (~$1-2/month for a small org)

**Requires:** Config Recorder must be enabled first (see Step 3 above)

### Step 1: Update terraform.tfvars

```hcl
# Before
enable_config_rules = false

# After
enable_config_rules = true
```

> **Important:** If `enable_config_recorder` is still `false`, enable it first.
> Config Rules depend on the Config Recorder to function.

### Step 2: Plan and Apply

```bash
terraform plan -out=plan.tfplan
```

You should see **12 resources to add** (one per Config rule). Review and apply:

```bash
terraform apply plan.tfplan
```

### Step 3: Verify

```bash
aws configservice describe-config-rules --region YOUR_REGION \
  --query 'ConfigRules[].{Name:ConfigRuleName,State:ConfigRuleState}' \
  --output table
```

Expected: 12 rules, all in `ACTIVE` state.

---

## 5. Enable AWS Security Hub

**What it does:** Provides a comprehensive view of security alerts and compliance
status across your AWS accounts. Aggregates findings from Config Rules, GuardDuty,
IAM Access Analyzer, and third-party tools.

**Enabled standards:**
- AWS Foundational Security Best Practices v1.0.0
- CIS AWS Foundations Benchmark v1.2.0

**Cost:** ~$5/month after 30-day free trial (~$0.0010 per check)

### Step 1: Update terraform.tfvars

```hcl
# Before
enable_security_hub = false

# After
enable_security_hub = true
```

### Step 2: Plan and Apply

```bash
terraform plan -out=plan.tfplan
```

You should see approximately **4 resources to add**:
- `aws_securityhub_account.main`
- `aws_securityhub_organization_admin_account.security` (delegates to security account)
- `aws_securityhub_standards_subscription.aws_foundational`
- `aws_securityhub_standards_subscription.cis`

Review and apply:

```bash
terraform apply plan.tfplan
```

### Step 3: Enable Organization-Wide from Security Account

After Terraform apply succeeds, you must configure org-wide auto-enable from the
**security account** (not the management account):

```bash
# Get security account ID
SECURITY_ACCOUNT_ID=$(terraform output -json account_ids | python -c "import sys,json; print(json.load(sys.stdin)['security'])")

# Assume role into security account
CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::${SECURITY_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "enable-securityhub" \
  --output json)

# Export credentials (adjust for your OS/shell)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python -c "import sys,json; print(json.load(sys.stdin)['Credentials']['AccessKeyId'])")
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python -c "import sys,json; print(json.load(sys.stdin)['Credentials']['SecretAccessKey'])")
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python -c "import sys,json; print(json.load(sys.stdin)['Credentials']['SessionToken'])")

# Verify you're in the security account
aws sts get-caller-identity

# Enable auto-enrollment for new accounts
aws securityhub update-organization-configuration \
  --auto-enable \
  --region YOUR_REGION

# Enroll existing member accounts (replace with your actual account IDs)
aws securityhub create-members --account-details \
  '[{"AccountId":"ACCOUNT_1"},{"AccountId":"ACCOUNT_2"},{"AccountId":"ACCOUNT_3"},{"AccountId":"ACCOUNT_4"},{"AccountId":"ACCOUNT_5"},{"AccountId":"ACCOUNT_6"}]' \
  --region YOUR_REGION

# Unset temporary credentials when done
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

> Replace `YOUR_REGION` and account IDs with your actual values from `terraform output`.

### Step 4: Verify

```bash
# From management account
aws securityhub describe-hub --region YOUR_REGION
```

Expected: returns Hub ARN and subscription date.

---

## 6. Enable Amazon GuardDuty

**What it does:** Continuously monitors for malicious activity and unauthorized
behavior. Analyzes CloudTrail events, VPC Flow Logs, and DNS queries to detect
threats like compromised instances, reconnaissance, and data exfiltration.

**Cost:** ~$4/account/month after 30-day free trial. Charges based on:
- CloudTrail management events analyzed
- VPC Flow Log data analyzed
- DNS query data analyzed

### Step 1: Update terraform.tfvars

```hcl
# Before
enable_guardduty = false

# After
enable_guardduty = true
```

### Step 2: Plan and Apply

```bash
terraform plan -out=plan.tfplan
```

You should see approximately **4 resources to add**:
- `aws_guardduty_detector.main`
- `aws_guardduty_organization_admin_account.security` (delegates to security account)
- `aws_cloudwatch_event_rule.guardduty_findings` (alerts on severity >= 7)
- `aws_cloudwatch_event_target.guardduty_to_sns` (sends alerts to SNS)

Review and apply:

```bash
terraform apply plan.tfplan
```

### Step 3: Enable Organization-Wide from Security Account

Same as SecurityHub — assume a role into the security account:

```bash
# Get security account ID
SECURITY_ACCOUNT_ID=$(terraform output -json account_ids | python -c "import sys,json; print(json.load(sys.stdin)['security'])")

# Assume role into security account
CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::${SECURITY_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "enable-guardduty" \
  --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python -c "import sys,json; print(json.load(sys.stdin)['Credentials']['AccessKeyId'])")
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python -c "import sys,json; print(json.load(sys.stdin)['Credentials']['SecretAccessKey'])")
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python -c "import sys,json; print(json.load(sys.stdin)['Credentials']['SessionToken'])")

# Verify you're in the security account
aws sts get-caller-identity

# Get the detector ID
DETECTOR_ID=$(aws guardduty list-detectors --region YOUR_REGION \
  --query 'DetectorIds[0]' --output text)

# Enable auto-enrollment for new accounts
aws guardduty update-organization-configuration \
  --detector-id "$DETECTOR_ID" \
  --auto-enable \
  --region YOUR_REGION

# Enroll existing member accounts (replace with your actual account IDs and emails)
aws guardduty create-members --detector-id "$DETECTOR_ID" --account-details \
  '[
    {"AccountId":"ACCOUNT_1","Email":"email1@example.com"},
    {"AccountId":"ACCOUNT_2","Email":"email2@example.com"},
    {"AccountId":"ACCOUNT_3","Email":"email3@example.com"},
    {"AccountId":"ACCOUNT_4","Email":"email4@example.com"},
    {"AccountId":"ACCOUNT_5","Email":"email5@example.com"},
    {"AccountId":"ACCOUNT_6","Email":"email6@example.com"}
  ]' \
  --region YOUR_REGION

# Unset temporary credentials when done
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

### Step 4: Verify

```bash
# From management account
aws guardduty list-detectors --region YOUR_REGION
```

Expected: returns a detector ID (not an empty list).

---

## 7. Enable All Services at Once

To enable everything in one go:

### Step 1: Update terraform.tfvars

```hcl
enable_config_recorder = true
enable_config_rules    = true
enable_security_hub    = true
enable_guardduty       = true
```

### Step 2: Plan and Apply

```bash
terraform plan -out=plan.tfplan
# Review: expect ~26 resources to add
terraform apply plan.tfplan
```

### Step 3: Post-Deployment (Security Account Setup)

After Terraform completes, run the organization-wide enablement from the security
account. This script does both SecurityHub and GuardDuty in one session:

```bash
# --- Configuration (update these values) ---
REGION="ap-south-1"  # Your AWS region
SECURITY_ACCOUNT_ID=$(terraform output -json account_ids | python -c "import sys,json; print(json.load(sys.stdin)['security'])")

# Get all member account IDs
ALL_ACCOUNTS=$(terraform output -json account_ids | python -c "
import sys, json
accounts = json.load(sys.stdin)
print(json.dumps([{'AccountId': v} for v in accounts.values()]))
")

ALL_ACCOUNTS_GD=$(terraform output -json account_ids | python -c "
import sys, json
accounts = json.load(sys.stdin)
# GuardDuty needs emails too — use placeholder, org accounts auto-resolve
print(json.dumps([{'AccountId': v, 'Email': f'{k}@placeholder.com'} for k, v in accounts.items()]))
")

# --- Assume role into security account ---
CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::${SECURITY_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "enable-all-services" \
  --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python -c "import sys,json; print(json.load(sys.stdin)['Credentials']['AccessKeyId'])")
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python -c "import sys,json; print(json.load(sys.stdin)['Credentials']['SecretAccessKey'])")
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python -c "import sys,json; print(json.load(sys.stdin)['Credentials']['SessionToken'])")

echo "=== Verifying identity ==="
aws sts get-caller-identity

# --- SecurityHub ---
echo "=== Enabling SecurityHub org-wide ==="
aws securityhub update-organization-configuration --auto-enable --region $REGION
echo "=== Enrolling SecurityHub members ==="
aws securityhub create-members --account-details "$ALL_ACCOUNTS" --region $REGION

# --- GuardDuty ---
DETECTOR_ID=$(aws guardduty list-detectors --region $REGION --query 'DetectorIds[0]' --output text)
echo "=== Enabling GuardDuty org-wide (detector: $DETECTOR_ID) ==="
aws guardduty update-organization-configuration \
  --detector-id "$DETECTOR_ID" --auto-enable --region $REGION
echo "=== Enrolling GuardDuty members ==="
aws guardduty create-members --detector-id "$DETECTOR_ID" \
  --account-details "$ALL_ACCOUNTS_GD" --region $REGION

# --- Cleanup ---
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
echo "=== Done! ==="
```

---

## 8. Post-Enablement Steps

After enabling services, complete these tasks:

### 8.1 Confirm SNS Subscriptions

If not already confirmed, check your email inbox for subscription confirmation
from AWS SNS:

- `{org_name}-security-findings` — high/critical security alerts
- `{org_name}-budget-alerts` — budget threshold notifications

Click **"Confirm subscription"** in each email.

### 8.2 Review Initial Findings

After enabling SecurityHub and GuardDuty, allow 24-48 hours for initial findings
to populate. Then review:

```bash
# Check SecurityHub findings count
aws securityhub get-findings \
  --filters '{"SeverityLabel":[{"Value":"HIGH","Comparison":"EQUALS"},{"Value":"CRITICAL","Comparison":"EQUALS"}]}' \
  --query 'Findings | length(@)' \
  --region YOUR_REGION

# Check GuardDuty findings
DETECTOR_ID=$(aws guardduty list-detectors --region YOUR_REGION --query 'DetectorIds[0]' --output text)
aws guardduty list-findings --detector-id $DETECTOR_ID --region YOUR_REGION \
  --query 'FindingIds | length(@)'
```

### 8.3 Verify Config Recording

```bash
# Check Config is recording
aws configservice get-status --region YOUR_REGION

# Check Config rule compliance
aws configservice describe-compliance-by-config-rule --region YOUR_REGION \
  --query 'ComplianceByConfigRules[].{Rule:ConfigRuleName,Status:Compliance.ComplianceType}' \
  --output table
```

---

## 9. Cost Impact Summary

| Configuration | Monthly Cost |
|---|---|
| All disabled (current PoC setup) | ~$0.50 |
| Config Recorder only | ~$2.50 |
| Config Recorder + Config Rules | ~$4 |
| Config Recorder + Config Rules + SecurityHub | ~$9 |
| **Everything enabled (production-ready)** | **~$35-40** |

### Cost Breakdown by Service

| Service | Cost Driver | Estimate |
|---|---|---|
| Config Recorder | Per configuration item recorded | ~$2/month |
| Config Rules | $0.001 per rule evaluation | ~$1-2/month |
| SecurityHub | $0.0010 per check | ~$5/month |
| GuardDuty | CloudTrail events + VPC logs + DNS | ~$4/account/month |
| S3 Storage | Log file storage | ~$0.50/month |

> **Tip:** GuardDuty is the largest cost driver because it charges per account.
> With 7 accounts (1 management + 6 member), that's ~$28/month. If you only need
> basic compliance, enable Config + SecurityHub and skip GuardDuty to save ~$28/month.

---

## 10. Verifying Services Are Running

Run this one-liner to check the status of all services:

```bash
echo "=== Config Recorder ===" && \
aws configservice describe-configuration-recorder-status --region YOUR_REGION \
  --query 'ConfigurationRecordersStatus[0].{Recording:recording,LastStatus:lastStatus}' 2>&1 && \
echo "" && \
echo "=== Config Rules ===" && \
aws configservice describe-config-rules --region YOUR_REGION \
  --query 'ConfigRules | length(@)' 2>&1 && \
echo " rules active" && \
echo "" && \
echo "=== SecurityHub ===" && \
aws securityhub describe-hub --region YOUR_REGION \
  --query '{Status:"ENABLED",SubscribedAt:SubscribedAt}' 2>&1 && \
echo "" && \
echo "=== GuardDuty ===" && \
aws guardduty list-detectors --region YOUR_REGION \
  --query '{DetectorCount:DetectorIds|length(@)}' 2>&1
```

---

## 11. Rollback (Disable Again)

To disable any service and stop charges, set the flag back to `false`:

```hcl
# In terraform.tfvars — set any combination to false
enable_config_recorder = false
enable_config_rules    = false
enable_security_hub    = false
enable_guardduty       = false
```

Then apply:

```bash
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

### Important: If SecurityHub or GuardDuty Had Org-Wide Enrollment

Before running `terraform apply` to disable SecurityHub or GuardDuty, you must
first remove member accounts and disable org-wide settings from the **security
account**:

```bash
# Assume role into security account (same method as enablement)
# Then run:

# --- SecurityHub cleanup ---
aws securityhub update-organization-configuration --no-auto-enable --region YOUR_REGION
aws securityhub disassociate-members --account-ids '["ACCT1","ACCT2","..."]' --region YOUR_REGION
aws securityhub delete-members --account-ids '["ACCT1","ACCT2","..."]' --region YOUR_REGION

# --- GuardDuty cleanup ---
DETECTOR_ID=$(aws guardduty list-detectors --region YOUR_REGION --query 'DetectorIds[0]' --output text)
aws guardduty update-organization-configuration --detector-id $DETECTOR_ID --no-auto-enable --region YOUR_REGION
aws guardduty disassociate-members --detector-id $DETECTOR_ID --account-ids '["ACCT1","ACCT2","..."]' --region YOUR_REGION
aws guardduty delete-members --detector-id $DETECTOR_ID --account-ids '["ACCT1","ACCT2","..."]' --region YOUR_REGION

# --- Then remove delegated admin from management account ---
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws securityhub disable-organization-admin-account --admin-account-id SECURITY_ACCT_ID --region YOUR_REGION
aws guardduty disable-organization-admin-account --admin-account-id SECURITY_ACCT_ID --region YOUR_REGION
```

After this cleanup, run `terraform apply` from the management account to destroy
the remaining resources.

---

## Quick Reference

| Want to... | Set in terraform.tfvars | Cost Impact |
|---|---|---|
| Enable compliance recording | `enable_config_recorder = true` | +$2/mo |
| Enable compliance rules | `enable_config_rules = true` | +$1-2/mo |
| Enable security dashboard | `enable_security_hub = true` | +$5/mo |
| Enable threat detection | `enable_guardduty = true` | +$28/mo |
| Enable everything | All four = `true` | +$35-40/mo |
| Disable everything | All four = `false` | Save $35-40/mo |
