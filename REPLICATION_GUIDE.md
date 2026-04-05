# AWS Landing Zone - Replication & Cloning Guide

This guide provides step-by-step instructions for replicating this AWS Landing Zone
on a new AWS root account. The entire setup is designed to be portable and reusable
via Terraform.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Architecture Overview](#2-architecture-overview)
3. [Quick Start (5-Minute Setup)](#3-quick-start-5-minute-setup)
4. [Detailed Configuration](#4-detailed-configuration)
5. [Deployment Steps](#5-deployment-steps)
6. [Post-Deployment Configuration](#6-post-deployment-configuration)
7. [Cost Breakdown](#7-cost-breakdown)
8. [Customization Options](#8-customization-options)
9. [Troubleshooting](#9-troubleshooting)
10. [Tearing Down](#10-tearing-down)
11. [Security Considerations](#11-security-considerations)
12. [FAQ](#12-faq)

---

## 1. Prerequisites

### Required

| Requirement | Details |
|---|---|
| **AWS Root Account** | A fresh AWS account (or one without an existing Organization) |
| **IAM Admin User** | An IAM user with `AdministratorAccess` in the root account (do NOT use root credentials) |
| **AWS CLI v2** | Installed and configured with the admin user's credentials |
| **Terraform >= 1.5.0** | [Download here](https://developer.hashicorp.com/terraform/downloads) |
| **Email Addresses** | 6 unique email addresses for member accounts (see [Email Setup](#email-setup) below) |

### Verify Your Setup

```bash
# Verify AWS CLI
aws --version
aws sts get-caller-identity  # Should show your management account ID

# Verify Terraform
terraform --version  # Must be >= 1.5.0
```

### Email Setup

Each AWS account requires a **globally unique email address**. You have three options:

#### Option A: Gmail Plus Aliases (Recommended for personal/small orgs)
Gmail ignores everything after `+`, so all emails land in one inbox:
```
youremail+security@gmail.com
youremail+log-archive@gmail.com
youremail+shared-services@gmail.com
youremail+dev@gmail.com
youremail+staging@gmail.com
youremail+prod@gmail.com
```

#### Option B: Custom Domain with Catch-All
If you own a domain, set up a catch-all and use:
```
aws-security@yourdomain.com
aws-logs@yourdomain.com
aws-shared@yourdomain.com
aws-dev@yourdomain.com
aws-staging@yourdomain.com
aws-prod@yourdomain.com
```

#### Option C: Separate Email Accounts
Create individual email accounts for each AWS member account.

> **Important**: AWS account emails must be globally unique across ALL of AWS.
> If an email was previously used for another AWS account, it cannot be reused.

---

## 2. Architecture Overview

### Organizational Unit (OU) Structure

```
Root (Management Account)
├── Security OU
│   ├── Security Account          ← Delegated admin for GuardDuty, SecurityHub
│   └── Log Archive Account       ← Centralized CloudTrail & Config logs
│
├── Infrastructure OU
│   └── Shared Services Account   ← Transit Gateway, DNS, CI/CD tooling
│
├── Workloads OU
│   ├── NonProd Sub-OU
│   │   ├── Dev Account
│   │   └── Staging Account
│   └── Prod Sub-OU
│       └── Production Account
│
├── Sandbox OU                    ← Experimentation (cost-restricted)
├── Policy Staging OU             ← Test SCPs before applying to prod
└── Suspended OU                  ← Quarantine for decommissioned accounts
```

### What Gets Created

| Module | Resources | Cost |
|---|---|---|
| **Organization** | AWS Organization, 8 OUs, 6 member accounts | Free |
| **SCP Policies** | 9 Service Control Policies (guardrails) | Free |
| **IAM Baseline** | Password policy, Break-Glass/Audit/Support roles, MFA policy | Free |
| **Logging** | Organization CloudTrail, Config recorder, 3 S3 buckets | ~$3-5/mo |
| **Security Baseline** | SecurityHub, IAM Access Analyzer (org + account), SNS alerts | ~$5/mo after trial |
| **GuardDuty** | Threat detection across all accounts | ~$4/account/mo after trial |
| **Config Rules** | 12 compliance rules (encryption, public access, MFA, etc.) | ~$1-2/mo |
| **Networking** | VPC, 2 public + 2 private subnets, IGW, flow logs | Free |
| **Budget Alerts** | Monthly budget with 4 alert thresholds + zero-spend alert | Free |

### Service Control Policies (SCPs) Applied

| SCP | Attached To | Purpose |
|---|---|---|
| Deny Root Account Usage | Workloads, Sandbox, Infrastructure | Block root user in member accounts |
| Restrict Regions | NonProd, Prod, Sandbox | Limit resource creation to approved regions |
| Deny Leave Organization | Root (all accounts) | Prevent accounts from leaving the org |
| Protect Security Baseline | NonProd, Prod, Infrastructure, Sandbox | Prevent disabling CloudTrail/Config/GuardDuty |
| Deny S3 Public Access | Workloads, Security, Infrastructure | Block public S3 buckets |
| Sandbox Cost Guardrails | Sandbox | Block expensive services, allow only small instances |
| Deny IAM User Creation | Workloads | Enforce SSO/federated access |
| Deny All (Suspended) | Suspended | Full lockdown for quarantined accounts |
| Require Encryption at Rest | Workloads, Infrastructure | Enforce EBS/RDS encryption |

---

## 3. Quick Start (5-Minute Setup)

For experienced users who want to get going fast:

```bash
# 1. Clone this repo
git clone https://github.com/YOUR_USERNAME/aws-landing-zone.git
cd aws-landing-zone

# 2. Configure your variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (see below)

# 3. Configure AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"  # or your preferred region

# 4. Deploy
terraform init
terraform plan -out=plan.tfplan
terraform apply plan.tfplan

# 5. Post-deployment (from security account)
# See Section 6 for details
```

### Minimum terraform.tfvars

```hcl
org_name     = "your-org-name"
aws_region   = "us-east-1"
email_domain = "gmail.com"
email_prefix = "youremail+aws"

budget_limit_usd   = "100"
budget_alert_emails = ["youremail@gmail.com"]
```

That's it. All other variables have sensible defaults.

---

## 4. Detailed Configuration

### terraform.tfvars Reference

Copy `terraform.tfvars.example` to `terraform.tfvars` and customize:

```hcl
# =============================================================================
# REQUIRED: Organization Identity
# =============================================================================

# A short name for your org (used as prefix for all AWS resources)
# Use lowercase, no spaces. Examples: "acme", "mycompany", "startup-io"
org_name = "your-org-name"

# Primary AWS region for the landing zone
# All management resources (CloudTrail, Config, VPC) deploy here
aws_region = "ap-south-1"  # Mumbai (change to your nearest region)

# =============================================================================
# REQUIRED: Account Email Configuration
# =============================================================================

# Option 1: Auto-generate emails from a pattern
# This creates: youremail+aws-security@gmail.com, youremail+aws-dev@gmail.com, etc.
email_domain = "gmail.com"
email_prefix = "youremail+aws"

# Option 2: Override individual account emails (takes precedence over pattern)
# Uncomment and customize any or all:
# security_account_email        = "aws-security@yourdomain.com"
# log_archive_account_email     = "aws-logs@yourdomain.com"
# shared_services_account_email = "aws-shared@yourdomain.com"
# dev_account_email             = "aws-dev@yourdomain.com"
# staging_account_email         = "aws-staging@yourdomain.com"
# prod_account_email            = "aws-prod@yourdomain.com"

# =============================================================================
# REQUIRED: Budget & Alerts
# =============================================================================

# Monthly spending limit (USD) — alerts fire at 50%, 80%, 100%, 120%
budget_limit_usd = "50"

# Email addresses for budget alert notifications
budget_alert_emails = ["youremail@gmail.com"]

# =============================================================================
# OPTIONAL: Region Restrictions
# =============================================================================

# Regions allowed for workloads (enforced via SCP)
# Include us-east-1 if you use global services (IAM, CloudFront, Route53)
allowed_regions = ["us-east-1", "ap-south-1"]

# =============================================================================
# OPTIONAL: Security Services
# =============================================================================

# GuardDuty: FREE for 30 days, then ~$4/account/month
# Set to false if cost is a concern
enable_guardduty = true

# Config Rules: ~$0.001 per rule evaluation
# Set to false if cost is a concern
enable_config_rules = true

# CloudTrail log retention in S3 (days)
cloudtrail_retention_days = 365

# =============================================================================
# OPTIONAL: Resource Tags
# =============================================================================

tags = {
  Owner      = "platform-team"
  CostCenter = "infrastructure"
}
```

### AWS Credentials Configuration

#### Option 1: Environment Variables (recommended for one-time setup)

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"
```

#### Option 2: AWS CLI Named Profile

```bash
# Configure a named profile
aws configure --profile landing-zone-admin
# Enter: Access Key ID, Secret Access Key, Region, Output format

# Use the profile
export AWS_PROFILE=landing-zone-admin
# OR pass it to terraform:
# AWS_PROFILE=landing-zone-admin terraform plan
```

#### Option 3: AWS SSO (if you already have SSO configured)

```bash
aws sso login --profile your-sso-profile
export AWS_PROFILE=your-sso-profile
```

---

## 5. Deployment Steps

### Step 1: Initialize Terraform

```bash
cd aws-landing-zone
terraform init
```

This downloads the AWS provider and initializes the backend. You should see:

```
Terraform has been successfully initialized!
```

### Step 2: Review the Plan

```bash
terraform plan -out=plan.tfplan
```

Review the output carefully. You should see approximately **70+ resources** to be created:
- 1 AWS Organization
- 8 Organizational Units
- 6 Member Accounts
- 9 SCPs with ~20 attachments
- 4 IAM Roles + password policy
- 3 S3 Buckets (CloudTrail, Config, Access Logs)
- 1 Organization CloudTrail
- 1 Config Recorder + delivery channel
- 1 GuardDuty Detector
- 1 SecurityHub enablement + 2 standards
- 2 IAM Access Analyzers
- 12 Config Rules (if enabled)
- 1 VPC + subnets + IGW + route tables
- 2 AWS Budgets
- SNS Topics + EventBridge rules

### Step 3: Apply

```bash
terraform apply plan.tfplan
```

> **This takes 3-8 minutes.** Most time is spent creating member accounts.

If you see errors, check the [Troubleshooting](#9-troubleshooting) section.

### Step 4: Save the Outputs

```bash
terraform output > landing-zone-outputs.txt
terraform output -json > landing-zone-outputs.json
```

Keep these safe — they contain all account IDs, role ARNs, bucket names, etc.

---

## 6. Post-Deployment Configuration

After `terraform apply` succeeds, complete these manual steps:

### 6.1 Confirm SNS Email Subscriptions

AWS sends confirmation emails to the addresses in `budget_alert_emails`. Check your
inbox and click **"Confirm subscription"** for each email. There will be 2 topics:

- `{org_name}-budget-alerts` — budget threshold notifications
- `{org_name}-security-findings` — high/critical security findings

> **Without confirming, you will NOT receive alerts.**

### 6.2 Enable SecurityHub & GuardDuty Across All Accounts

Due to AWS API restrictions, organization-wide auto-enable must be configured from the
**delegated admin (security) account**, not the management account. Run these commands:

```bash
# Get the security account ID from Terraform output
SECURITY_ACCOUNT_ID=$(terraform output -json account_ids | jq -r '.security')

# Assume role into the security account
eval $(aws sts assume-role \
  --role-arn "arn:aws:iam::${SECURITY_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "security-setup" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text | awk '{
    printf "export AWS_ACCESS_KEY_ID=%s\nexport AWS_SECRET_ACCESS_KEY=%s\nexport AWS_SESSION_TOKEN=%s\n", $1, $2, $3
  }')

# Verify you're in the security account
aws sts get-caller-identity

# ---- SecurityHub ----
# Enable auto-enrollment for new accounts
aws securityhub update-organization-configuration \
  --auto-enable \
  --region YOUR_REGION

# Enroll existing member accounts
aws securityhub create-members --account-details \
  '[{"AccountId":"ACCOUNT_1"},{"AccountId":"ACCOUNT_2"},...]' \
  --region YOUR_REGION

# ---- GuardDuty ----
# Get the detector ID
DETECTOR_ID=$(aws guardduty list-detectors --region YOUR_REGION --query 'DetectorIds[0]' --output text)

# Enable auto-enrollment for new accounts
aws guardduty update-organization-configuration \
  --detector-id $DETECTOR_ID \
  --auto-enable \
  --region YOUR_REGION

# Enroll existing member accounts
aws guardduty create-members --detector-id $DETECTOR_ID --account-details \
  '[{"AccountId":"ACCOUNT_1","Email":"email1"},{"AccountId":"ACCOUNT_2","Email":"email2"},...]' \
  --region YOUR_REGION
```

Replace `YOUR_REGION` and account details with your actual values from `terraform output`.

### 6.3 (Optional) Set Up AWS IAM Identity Center (SSO)

For production use, set up SSO for human access instead of IAM users:

1. Go to **AWS IAM Identity Center** in the management account console
2. Choose your identity source (built-in, Active Directory, or external IdP)
3. Create permission sets (e.g., AdministratorAccess, ViewOnlyAccess)
4. Assign users/groups to accounts with appropriate permission sets

### 6.4 (Optional) Configure Remote State Backend

For team collaboration, move Terraform state to S3:

```hcl
# In versions.tf, uncomment the backend block:
terraform {
  backend "s3" {
    bucket         = "your-org-terraform-state"
    key            = "landing-zone/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Then run:
```bash
# Create the S3 bucket and DynamoDB table first
aws s3 mb s3://your-org-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket your-org-terraform-state \
  --versioning-configuration Status=Enabled
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Migrate state
terraform init -migrate-state
```

---

## 7. Cost Breakdown

### Monthly Cost Estimate (Minimal Activity)

| Service | Free Tier / Trial | After Trial |
|---|---|---|
| AWS Organizations + SCPs | Always free | Always free |
| IAM (roles, policies) | Always free | Always free |
| CloudTrail (1st org trail) | Always free | Free (S3 storage ~$0.50/mo) |
| AWS Config (recorder) | No free tier | ~$2/mo |
| SecurityHub | 30-day trial | ~$5/mo |
| GuardDuty | 30-day trial | ~$4/account/mo |
| IAM Access Analyzer | Always free | Always free |
| S3 (log storage) | 5 GB free tier | ~$0.50/mo |
| VPC + Subnets + IGW | Always free | Always free |
| AWS Budgets (first 2) | Always free | Always free |
| SNS (first 1M publishes) | Always free | Always free |
| NAT Gateway | N/A | ~$32/mo (disabled by default) |

### Total Estimates

| Scenario | Monthly Cost |
|---|---|
| First 30 days (free trials active) | ~$2-5 |
| After trials, GuardDuty ON | ~$10-15 |
| After trials, GuardDuty OFF | ~$7-10 |
| With NAT Gateway enabled | Add ~$32/mo |

### Cost Optimization Tips

1. **Disable GuardDuty** (`enable_guardduty = false`) to save ~$4/account/month
2. **Disable Config Rules** (`enable_config_rules = false`) to save ~$1-2/month
3. **Reduce CloudTrail retention** (`cloudtrail_retention_days = 90`) to save on S3
4. **Keep NAT Gateway disabled** unless private subnets need internet access

---

## 8. Customization Options

### Adding More Member Accounts

Edit `modules/organization/main.tf` to add new accounts:

```hcl
resource "aws_organizations_account" "new_account" {
  name      = "${var.org_name}-new-account"
  email     = "your-email+new@gmail.com"
  parent_id = aws_organizations_organizational_unit.workloads_nonprod.id

  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = false

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType = "workload"
    Environment = "new"
  })
}
```

Add the corresponding variable in `modules/organization/variables.tf` and wire it
through `main.tf` and `outputs.tf`.

### Adding Custom SCPs

Add new policies in `modules/scp-policies/main.tf`:

```hcl
resource "aws_organizations_policy" "your_custom_scp" {
  name        = "YourCustomSCP"
  description = "Description of what it does"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "YourRule"
        Effect   = "Deny"
        Action   = ["service:Action"]
        Resource = "*"
      }
    ]
  })
  tags = var.tags
}

resource "aws_organizations_policy_attachment" "your_scp_attachment" {
  policy_id = aws_organizations_policy.your_custom_scp.id
  target_id = var.workloads_ou_id  # or whichever OU
}
```

> **Warning**: AWS allows a maximum of **5 SCPs per OU** (including the default
> `FullAWSAccess`). If you hit the limit, attach to sub-OUs instead.

### Changing the VPC CIDR

Edit `modules/networking/variables.tf` — default is `10.0.0.0/16`. Change it to
avoid conflicts with existing networks.

### Enabling NAT Gateway

In `main.tf`, change:

```hcl
module "networking" {
  # ...
  enable_nat_gateway = true  # Adds ~$32/month
}
```

### Changing Allowed Regions

In `terraform.tfvars`:

```hcl
allowed_regions = ["us-east-1", "eu-west-1", "ap-southeast-1"]
```

> Always include `us-east-1` — many global AWS services (IAM, CloudFront, Route53)
> require it.

---

## 9. Troubleshooting

### Common Errors

#### "You already have an organization"

```
Error: error creating organization: AlreadyInOrganizationException
```

**Fix**: This account already has an AWS Organization. Either:
- Use a different AWS account
- Import the existing organization: `terraform import module.organization.aws_organizations_organization.org <org-id>`

#### "Maximum number of policies attached"

```
Error: ConstraintViolationException: You have attached the maximum number of policies
```

**Fix**: AWS allows max 5 SCPs per target (including the default `FullAWSAccess`).
Move SCP attachments to sub-OUs instead of parent OUs, or remove the `FullAWSAccess`
default policy from the target.

#### "Email already associated with another account"

```
Error: ConstraintViolationException: The email address is already associated with another account
```

**Fix**: Use different email addresses. Each AWS account email must be globally unique.

#### "Config recorder already exists"

```
Error: error putting Configuration Recorder: MaxNumberOfConfigurationRecordersExceededException
```

**Fix**: Delete the existing recorder first:
```bash
aws configservice delete-configuration-recorder --configuration-recorder-name default
aws configservice delete-delivery-channel --delivery-channel-name default
```

#### Plan-time "value of count cannot be determined"

**Fix**: This happens when `count` depends on a value only known at apply time.
Use a boolean variable instead (e.g., `enable_delegated_admin = true`).

### Deployment Order Issues

If you see dependency errors, deploy modules incrementally:

```bash
terraform apply -target=module.organization
terraform apply -target=module.scp_policies
terraform apply -target=module.iam_baseline
terraform apply -target=module.logging
terraform apply -target=module.security_baseline
terraform apply -target=module.guardduty
terraform apply -target=module.config_rules
terraform apply -target=module.networking
terraform apply -target=module.budget_alerts
```

### Checking Current State

```bash
# List all managed resources
terraform state list

# Show details of a specific resource
terraform state show module.organization.aws_organizations_organization.org

# Verify AWS resources match
aws organizations describe-organization
aws organizations list-accounts
aws organizations list-policies --filter SERVICE_CONTROL_POLICY
```

---

## 10. Tearing Down

> **WARNING**: Destroying the landing zone will close all member accounts and delete
> all resources. This is NOT easily reversible.

### Full Teardown

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy (requires confirmation)
terraform destroy
```

### Partial Teardown (keep organization, remove services)

```bash
# Remove only GuardDuty
terraform destroy -target=module.guardduty

# Remove only Config Rules
terraform destroy -target=module.config_rules

# Remove networking
terraform destroy -target=module.networking
```

### Important Notes on Teardown

- **S3 Buckets**: Won't be destroyed if they contain data (`force_destroy = false`).
  Empty them first or set `force_destroy = true`.
- **Member Accounts**: Terraform sets `close_on_deletion = false`, so accounts are
  **removed from the organization but not closed**. Close them manually in the AWS console.
- **CloudTrail**: The org trail will stop logging but existing logs remain in S3.

---

## 11. Security Considerations

### For Production Use

1. **Enable MFA** on the management account root user immediately
2. **Do not use root credentials** — create IAM users or use SSO
3. **Store Terraform state remotely** with encryption and locking (see Section 6.4)
4. **Restrict access** to the management account — only platform/infra team
5. **Review SCPs regularly** — they are your primary preventive controls
6. **Monitor GuardDuty findings** — respond to HIGH/CRITICAL alerts promptly
7. **Enable AWS CloudTrail Lake** for long-term audit log analytics (additional cost)

### Break-Glass Procedure

In emergencies, use the Break-Glass Admin role:

```bash
aws sts assume-role \
  --role-arn "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:role/YOUR_ORG-BreakGlassAdmin" \
  --role-session-name "emergency-access" \
  --serial-number "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:mfa/YOUR_MFA_DEVICE" \
  --token-code YOUR_MFA_CODE
```

This role:
- Requires MFA
- Has a 1-hour max session
- Has full AdministratorAccess
- Is audited via CloudTrail

### Accessing Member Accounts

Use the `OrganizationAccountAccessRole` to access any member account:

```bash
aws sts assume-role \
  --role-arn "arn:aws:iam::MEMBER_ACCOUNT_ID:role/OrganizationAccountAccessRole" \
  --role-session-name "admin-access"
```

---

## 12. FAQ

### Can I use this with an existing AWS Organization?

Yes, but you'll need to import the existing organization into Terraform state:
```bash
terraform import module.organization.aws_organizations_organization.org o-xxxxxxxxxx
```
You may also need to import existing OUs, accounts, and policies.

### Can I deploy to multiple regions?

The landing zone deploys management resources to a single region. Global services
(IAM, Organizations, SCPs) work across all regions automatically. To deploy workload
infrastructure in multiple regions, create separate Terraform configurations for each
region using the member account credentials.

### Can I add more accounts later?

Yes. Add a new `aws_organizations_account` resource in `modules/organization/main.tf`,
add it to the outputs, and run `terraform apply`. The account will be created in the
specified OU with all SCPs automatically inherited.

### Can I use this with AWS Control Tower?

This landing zone provides similar functionality to Control Tower but via Terraform.
They can coexist, but may conflict on:
- SCPs (both manage guardrails)
- Config Rules (both deploy compliance checks)
- CloudTrail (both create org trails)

If using Control Tower, disable the overlapping modules in this project.

### How do I update SCPs or policies?

Edit the Terraform code, run `terraform plan` to review changes, then `terraform apply`.
SCPs take effect immediately on attachment.

### What if I need to change the org_name?

Changing `org_name` will rename all resources (S3 buckets, IAM roles, etc.). Since S3
bucket names are globally unique, the old names may not be reclaimable. Plan carefully:

```bash
# Preview the impact
terraform plan  # Review all resources that will be recreated
```

### How do I give developers access to their accounts?

Set up **AWS IAM Identity Center (SSO)** in the management account. Create permission
sets and assign developers to the appropriate accounts (dev, staging, prod) with the
right level of access.

---

## Replication Checklist

Use this checklist when setting up a new landing zone:

- [ ] Fresh AWS account with IAM admin user created
- [ ] AWS CLI configured and verified (`aws sts get-caller-identity`)
- [ ] Terraform >= 1.5.0 installed
- [ ] 6 unique email addresses prepared
- [ ] Cloned this repository
- [ ] Copied `terraform.tfvars.example` to `terraform.tfvars`
- [ ] Updated `org_name` in `terraform.tfvars`
- [ ] Updated email configuration in `terraform.tfvars`
- [ ] Updated `aws_region` in `terraform.tfvars`
- [ ] Updated `allowed_regions` in `terraform.tfvars`
- [ ] Updated `budget_limit_usd` and `budget_alert_emails`
- [ ] Ran `terraform init`
- [ ] Ran `terraform plan -out=plan.tfplan` and reviewed output
- [ ] Ran `terraform apply plan.tfplan`
- [ ] Saved `terraform output` to a safe location
- [ ] Confirmed SNS email subscriptions in inbox
- [ ] Enabled SecurityHub org-wide from security account
- [ ] Enrolled all member accounts in SecurityHub
- [ ] Enabled GuardDuty org-wide from security account
- [ ] Enrolled all member accounts in GuardDuty
- [ ] Enabled MFA on management account root user
- [ ] (Optional) Set up remote Terraform state backend
- [ ] (Optional) Set up AWS IAM Identity Center (SSO)
