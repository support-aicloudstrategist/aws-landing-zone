# AWS Landing Zone - Terraform

## Architecture Overview

This Terraform project implements a production-grade AWS Landing Zone based on the
**AWS Well-Architected Framework** and **AWS Control Tower** best practices.

## Organizational Unit (OU) Structure

```
Root
├── Security OU
│   ├── Security Account        (GuardDuty delegated admin, Security Hub, IAM Access Analyzer)
│   └── Log Archive Account     (centralized CloudTrail, Config, VPC Flow Logs)
│
├── Infrastructure OU
│   └── Shared Services Account (Transit Gateway, DNS, shared AMIs, CI/CD tooling)
│
├── Workloads OU
│   ├── Dev Account
│   ├── Staging Account
│   └── Production Account
│
├── Sandbox OU                  (experimentation, auto-nuke policies)
│
├── Policy Staging OU           (test SCPs before applying to prod OUs)
│
└── Suspended OU                (quarantine for decommissioned accounts)
```

## What Gets Created (All Free / Minimal Cost)

| Resource | Cost |
|---|---|
| AWS Organizations + OUs | Free |
| Service Control Policies (SCPs) | Free |
| IAM Roles & Policies | Free |
| AWS Config (recorder) | ~$2/month per account (per rule evaluation) |
| CloudTrail (org trail) | First trail free; S3 storage ~$0.023/GB |
| GuardDuty | 30-day free trial, then ~$4/month per account |
| S3 Buckets (logging) | ~$0.023/GB stored |
| SNS Topics (alerts) | Free tier covers 1M publishes |
| AWS Budgets | First 2 budgets free per account |

**Estimated total: < $15/month** for a small org with minimal activity.

## Cost Alerts

- **AWS Config**: Charges per rule evaluation. We use only essential managed rules.
- **GuardDuty**: 30-day free trial. ~$4/account/month after. Can be disabled if cost is a concern.
- **CloudTrail S3 storage**: Grows over time. Lifecycle policies auto-delete after 365 days.
- **Budget Alerts**: First 2 free per account. We create 1 per account.

## Prerequisites

1. An AWS root account (management account)
2. AWS CLI configured with admin credentials for the management account
3. Terraform >= 1.5.0
4. An email address pattern for sub-accounts (e.g., admin+security@yourdomain.com)

## Usage

```bash
# 1. Initialize
cd aws-landing-zone
terraform init

# 2. Review variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Plan & Apply
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

## Enabling Security Services

Security services (GuardDuty, SecurityHub, Config Recorder, Config Rules) are disabled
by default to minimize costs for PoC environments. See the full
**[Enable Services Guide](ENABLE_SERVICES_GUIDE.md)** for step-by-step instructions
to enable them when you're ready for production.

## Replicating to Another AWS Root Account

See the full **[Replication Guide](REPLICATION_GUIDE.md)** for detailed step-by-step
instructions, troubleshooting, cost breakdown, and a deployment checklist.

**Quick version:**

1. Clone this repo
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and update values
3. Configure AWS CLI with the new root account's admin credentials
4. Run `terraform init && terraform plan -out=plan.tfplan && terraform apply plan.tfplan`
5. Complete post-deployment steps (SNS confirmation, SecurityHub/GuardDuty enrollment)

## Modules

| Module | Purpose |
|---|---|
| `organization` | AWS Organizations, OUs, accounts, trusted access |
| `scp-policies` | Service Control Policies (guardrails) |
| `iam-baseline` | Baseline IAM roles per account (cross-account access) |
| `logging` | Centralized CloudTrail, Config, S3 buckets |
| `security-baseline` | GuardDuty, Security Hub, IAM Access Analyzer |
| `guardduty` | GuardDuty org-wide enablement |
| `config-rules` | AWS Config conformance rules |
| `networking` | VPC, Transit Gateway foundations |
| `budget-alerts` | AWS Budgets with SNS notifications |
