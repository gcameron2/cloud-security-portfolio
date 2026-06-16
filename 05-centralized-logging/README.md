# Project 5: Centralized Logging Pipeline

A production-grade centralized logging pipeline built on AWS using Terraform — the same architecture enterprises use to meet SOC 2, PCI-DSS, and HIPAA compliance requirements.

---

## What This Is

This project collects CloudTrail API logs, VPC Flow Logs, and security events from an AWS account, ships everything into a tamper-proof S3 archive encrypted with a Customer Managed KMS Key, replicates across regions for resilience, and alerts on security events in real time via CloudWatch.

Built entirely as Infrastructure as Code — no console clicking, fully repeatable and version-controlled.

---

## Architecture

```
CloudTrail (all regions)  ──┐
VPC Flow Logs             ──┼──► S3 Log Archive (us-east-2, SSE-KMS, Object Lock)
Simulated Workload Role   ──┘         │
                                      ▼
                              S3 Replica (us-west-2)

CloudTrail ──► CloudWatch Logs ──► Metric Filters ──► Alarms ──► SNS ──► Email
```

---

## Security Controls

| Control | Implementation |
|---|---|
| Encryption at rest | Customer Managed KMS Key (CMK) — you control who decrypts |
| Tamper-proof logs | S3 Object Lock (Governance mode, 90-day retention) |
| No-delete policy | Explicit deny on all deletes — blocks even the account root |
| Immutable hash chain | CloudTrail log file validation (SHA-256) |
| Cross-region resilience | S3 replication to us-west-2 |
| Least privilege | Separate IAM roles for write-only (workload) and read-only (security) |
| Real-time alerting | 8 CloudWatch alarms across P1/P2/P3 severity tiers |

---

## Real-Time Alerts

**P1 — Critical (immediate response)**
- CloudTrail stopped, deleted, or modified
- Log bucket policy changed
- Root account used

**P2 — High**
- Console login without MFA
- IAM policy created, modified, or deleted
- Security group rules changed
- Network ACL modified

**P3 — Medium**
- More than 5 unauthorized API calls in 10 minutes

---

## Terraform File Structure

```
05-centralized-logging/
├── terraform/
│   ├── main.tf                  # Dual-region providers (us-east-2 + us-west-2)
│   ├── variables.tf             # Account ID, VPC ID, bucket names, alert email
│   ├── terraform.tfvars         # Your values (not committed to source control)
│   ├── kms.tf                   # CMK with key policy for CloudTrail, Flow Logs, SecurityReader
│   ├── log-archive-bucket.tf    # Primary + replica buckets, Object Lock, SSE-KMS, replication, bucket policy
│   ├── iam.tf                   # SimulatedWorkload, SecurityReader, CloudTrail→CW, FlowLogs, S3Replication roles
│   ├── cloudtrail.tf            # Multi-region trail, log validation, CloudWatch integration
│   ├── vpc-flow-logs.tf         # VPC flow logs shipping to primary bucket
│   └── cloudwatch-alarms.tf     # SNS topic + 8 alarms
└── docs/
    ├── architecture.md          # Design decisions and trade-offs
    ├── incident-response.md     # IR playbooks for P1 scenarios
    └── compliance-mapping.md    # CIS AWS Foundations Benchmark mapping
```

---

## IAM Roles

**SimulatedWorkloadRole** — write-only to `workload-logs/` prefix. Simulates what a separate workload account would do in a real multi-account setup.

**SecurityLogReader** — read-only, requires MFA to assume. Used for incident investigation via Athena queries.

**CloudTrailToCloudWatch** — allows CloudTrail to stream events to CloudWatch Logs for real-time metric filters.

**S3LogReplication** — allows S3 to copy objects from primary to replica bucket cross-region.

---

## Single-Account Trade-Off

In a real enterprise the log archive lives in a completely separate AWS account — a compromised workload account cannot reach logs in another account. This project simulates that isolation using strict IAM boundaries and an explicit deny bucket policy.

The security gap is real and documented. In a production environment with a multi-account AWS Organizations setup, the log archive account would have no trust relationship with workload accounts, making it unreachable even with compromised credentials.

---

## Deploy

```bash
cd terraform

# Review before touching AWS
terraform plan

# Deploy all resources (~2 minutes)
terraform apply
```

After apply: confirm the SNS subscription email sent to your alert address — alarms will not deliver until confirmed.

---

## Verify

```bash
# CloudTrail is active
aws cloudtrail get-trail-status --name central-trail --region us-east-2

# Logs landing in S3 (wait ~10 min after deploy)
aws s3 ls s3://YOUR-BUCKET/cloudtrail/ --recursive

# Validate hash chain — detects tampering
aws cloudtrail validate-logs \
  --trail-arn arn:aws:cloudtrail:us-east-2:YOUR_ACCOUNT_ID:trail/central-trail \
  --start-time 2024-01-01T00:00:00Z

# Test delete is denied (this must fail)
aws s3 rm s3://YOUR-BUCKET/cloudtrail/ --recursive

# Check replica is receiving objects
aws s3 ls s3://YOUR-REPLICA-BUCKET/ --recursive --region us-west-2
```

---

## Compliance Mapping (CIS AWS Foundations Benchmark)

| CIS Control | Requirement | Implementation |
|---|---|---|
| 2.1 | CloudTrail enabled in all regions | `is_multi_region_trail = true` |
| 2.2 | Log file validation enabled | `enable_log_file_validation = true` |
| 2.3 | CloudTrail S3 bucket not publicly accessible | Public access block on both buckets |
| 2.4 | CloudTrail integrated with CloudWatch Logs | `cloud_watch_logs_group_arn` set |
| 2.7 | CloudTrail logs encrypted at rest | SSE-KMS with CMK |
| 3.1 | Unauthorized API calls alarm | P3-Unauthorized-API-Calls |
| 3.3 | Root account usage alarm | P1-Root-Account-Usage |
| 3.4 | IAM policy changes alarm | P2-IAM-Policy-Changes |
| 3.10 | Security group changes alarm | P2-Security-Group-Changes |
| 3.11 | NACL changes alarm | P2-NACL-Changes |

**Known gaps:** Single-account setup simulates but does not fully replicate a dedicated logging account. CIS 2.6 (access logging on the log bucket itself) not implemented.

---

## Tools & Services

AWS CloudTrail · AWS S3 · AWS KMS · AWS IAM · AWS CloudWatch · AWS SNS · VPC Flow Logs · Amazon Athena · Terraform
