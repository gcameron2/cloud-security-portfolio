# Audit Methodology

## Overview

This audit was conducted using Prowler v5.30.2, an open-source cloud security tool that maps findings to CIS Benchmarks, NIST frameworks, SOC 2, and other compliance standards.

## Scope

| Item | Detail |
|------|--------|
| Account | 092645363677 |
| Services scanned | IAM, S3 |
| Regions | All AWS regions (except opt-in regions) |
| Audit date | June 18, 2026 |
| Tool | Prowler 5.30.2 |

## Approach

### 1. Prepare
- Confirmed AWS CLI access and account identity
- Verified Prowler version and installed dependencies
- Identified scan scope (IAM and S3 as high-signal starting point)

### 2. Scan
Prowler executed 69 individual checks across IAM and S3:
```bash
prowler aws --service iam s3 \
  --output-formats json-ocsf html \
  --output-directory reports/
```

Output formats:
- `json-ocsf` — Open Cybersecurity Schema Framework, machine-readable
- `html` — human-readable visual report

### 3. Analyze
Findings were triaged using a two-axis risk model:
- **Exploitability:** How easily could an attacker use this?
- **Impact:** What is the blast radius if exploited?

Each finding was assessed in context — a misconfiguration that matters in a 500-person SaaS company may be acceptable in a personal lab account, and vice versa.

### 4. Categorize
| Category | Criteria |
|----------|----------|
| **Remediate** | Real risk that should be fixed |
| **Accept** | Low risk, compensating control exists, or not applicable |
| **Defer** | Real risk but lower priority; scheduled for a future sprint |

## Auditor Notes

**This audit was run as the root account**, which itself generated a High finding (`iam_avoid_root_usage`). In production, a dedicated `ProwlerAuditRole` should be created with the following policies:
- `arn:aws:iam::aws:policy/SecurityAudit`
- `arn:aws:iam::aws:policy/ReadOnlyAccess`

Running as root for this audit was a deliberate trade-off made to get the audit completed quickly. The root access key and root usage findings are valid and have been prioritized for remediation.

## Limitations

- **Scope:** Only IAM and S3 were scanned. A full audit would include EC2, VPC, CloudTrail, KMS, RDS, Lambda, and more.
- **Point-in-time:** This is a snapshot. New resources created after the scan date are not covered.
- **Context:** Prowler cannot know the business context of every finding. Human judgment is required to distinguish true risk from acceptable configuration.
