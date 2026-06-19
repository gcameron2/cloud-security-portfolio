# Cloud Security Portfolio

Cloud Security | AWS | Infrastructure as Code

This portfolio documents hands-on AWS security projects built to demonstrate practical skills in cloud security auditing, Infrastructure as Code, compliance, and incident detection. Each project reflects real work done in a personal AWS environment.

---

## Projects

### [Project 4: Cloud Security Audit with Prowler](./04-cloud-security-audit/)

**Skills:** Prowler, IAM, Security Groups, S3, CloudTrail, Risk Prioritization, Compliance (CIS, SOC 2)

Ran a full cloud security audit against a live AWS account using Prowler, then did the harder part: triaging 500+ findings into what actually matters. Produced an executive summary, a prioritized remediation roadmap broken into Critical / High / Medium / Accepted Risk tiers, and documented accepted risks with compensating controls.

Key outputs:
- Prowler HTML and OCSF JSON scan report
- Executive summary written for non-technical leadership
- Detailed findings with context and business impact
- Risk acceptance documentation with justification
- Compliance mapping to CIS AWS Foundations Benchmark

> The project demonstrates judgment: anyone can run a scanner. The value is in knowing which 8 of 500 findings to fix this week, and why.

---

### [Project 5: Centralized Logging Pipeline](./05-centralized-logging/)

**Skills:** Terraform, AWS CloudTrail, S3 Object Lock, KMS, CloudWatch, SNS, VPC Flow Logs, IAM, SOC 2 / PCI-DSS / HIPAA controls

Built a production-grade centralized logging pipeline entirely in Terraform, the same architecture enterprises use to meet compliance requirements. Collects CloudTrail API logs and VPC Flow Logs, ships to a tamper-proof S3 archive encrypted with a Customer Managed KMS Key, replicates cross-region, and fires real-time alerts on security events.

Security controls implemented:
- Customer Managed KMS Key (CMK): encryption at rest with full key control
- S3 Object Lock (Governance mode, 90-day retention): tamper-proof log archive
- Explicit deny bucket policy: blocks deletions even from the account root
- CloudTrail log file validation: SHA-256 hash chain detects tampering
- Cross-region S3 replication: resilience against region failure
- Least-privilege IAM roles: separate write-only (workload) and read-only (security) roles
- 8 CloudWatch alarms across P1 / P2 / P3 severity tiers

Real-time alert coverage includes: CloudTrail stopped or deleted, root account used, console login without MFA, IAM policy changes, security group changes, NACL changes, and unauthorized API call spikes.

---

## Tech Stack

| Category | Tools |
|---|---|
| Cloud | AWS (IAM, S3, CloudTrail, CloudWatch, SNS, KMS, VPC) |
| IaC | Terraform |
| Security Scanning | Prowler |
| Compliance Frameworks | CIS AWS Foundations Benchmark, SOC 2, PCI-DSS, HIPAA |
| Languages | Python, Bash |

---

## About

These projects are built in a real AWS environment, not simulations, to develop the skills that matter on day one: reading audit findings, writing IaC, understanding compliance controls, and documenting decisions clearly.
