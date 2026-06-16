# Project 4: Running a Cloud Security Audit With Prowler

## Overview

One of the most underrated but powerful projects you can do is a cloud security audit. Using a tool like Prowler, you scan your environment and generate findings across IAM, logging, networking, and data protection. But the value is not in running the tool—the value is in how you interpret the results.

## Audit Process Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         CLOUD SECURITY AUDIT LIFECYCLE                          │
└─────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │   PREPARE   │────▶│    SCAN     │────▶│   ANALYZE   │────▶│   REPORT    │
    └─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
          │                   │                   │                   │
          ▼                   ▼                   ▼                   ▼
    ┌───────────────────────────────────────────────────────────────────────────┐
    │                                                                           │
    │  • Define scope       • Run Prowler      • Triage findings    • Executive │
    │  • Get credentials    • Collect output   • Prioritize risks     summary   │
    │  • Baseline context   • Check coverage   • Identify patterns • Technical  │
    │                                          • Accept/remediate     details   │
    │                                                               • Roadmap   │
    └───────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │   REMEDIATE     │
                              │   & RETEST      │
                              └─────────────────┘
```

## What Prowler Checks

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         PROWLER CHECK CATEGORIES                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                              IAM                                        │   │
│  │  • Root account usage           • MFA enforcement                       │   │
│  │  • Password policies            • Access key rotation                   │   │
│  │  • Overprivileged policies      • Unused credentials                    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                            LOGGING                                      │   │
│  │  • CloudTrail enabled           • S3 access logging                     │   │
│  │  • CloudTrail encryption        • VPC Flow Logs                         │   │
│  │  • Log file validation          • CloudWatch Logs retention             │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                           NETWORKING                                    │   │
│  │  • Security group rules         • Public subnets                        │   │
│  │  • NACLs                        • VPC peering                           │   │
│  │  • Default VPC usage            • Internet gateways                     │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         DATA PROTECTION                                 │   │
│  │  • S3 bucket encryption         • RDS encryption at rest                │   │
│  │  • S3 bucket policies           • EBS encryption                        │   │
│  │  • Public S3 buckets            • KMS key rotation                      │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Signal vs Noise

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    DISTINGUISHING SIGNAL FROM NOISE                             │
└─────────────────────────────────────────────────────────────────────────────────┘

  Prowler Output: 500 findings
         │
         ▼
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │                          TRIAGE PROCESS                                      │
  ├──────────────────────────────────────────────────────────────────────────────┤
  │                                                                              │
  │   CRITICAL (Fix Immediately)                                    ~5-10       │
  │   ═══════════════════════════                                               │
  │   • S3 bucket publicly accessible with sensitive data                       │
  │   • Root account without MFA                                                │
  │   • IAM user with full admin + no MFA                                       │
  │   • Security group allowing 0.0.0.0/0 to SSH/RDP                            │
  │                                                                              │
  │   HIGH (Fix This Sprint)                                        ~20-50      │
  │   ══════════════════════                                                    │
  │   • CloudTrail not enabled in all regions                                   │
  │   • Access keys > 90 days old                                               │
  │   • EBS volumes unencrypted                                                 │
  │   • No VPC Flow Logs                                                        │
  │                                                                              │
  │   MEDIUM (Fix This Quarter)                                     ~50-100     │
  │   ═════════════════════════                                                 │
  │   • Password policy doesn't require symbols                                 │
  │   • S3 bucket versioning not enabled                                        │
  │   • CloudWatch Logs retention < 1 year                                      │
  │                                                                              │
  │   LOW / INFORMATIONAL (Backlog)                                 ~200+       │
  │   ═════════════════════════════                                             │
  │   • Using us-east-1 instead of opted-in regions                             │
  │   • Default VPC exists but unused                                           │
  │   • Some logging best practices not followed                                │
  │                                                                              │
  │   ACCEPTED RISK (Document & Move On)                            ~50-100     │
  │   ══════════════════════════════════                                        │
  │   • Check doesn't apply to this use case                                    │
  │   • Compensating control in place                                           │
  │   • Cost/benefit doesn't justify                                            │
  │                                                                              │
  └──────────────────────────────────────────────────────────────────────────────┘
```

## Prioritization Framework

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      RISK PRIORITIZATION MATRIX                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│                              EXPLOITABILITY                                     │
│                    Low            Medium           High                         │
│               ┌────────────┬────────────────┬────────────────┐                 │
│               │            │                │                │                 │
│    High       │   MEDIUM   │      HIGH      │   CRITICAL     │                 │
│               │            │                │                │                 │
│  I ───────────┼────────────┼────────────────┼────────────────┤                 │
│  M            │            │                │                │                 │
│  P  Medium    │    LOW     │     MEDIUM     │     HIGH       │                 │
│  A            │            │                │                │                 │
│  C ───────────┼────────────┼────────────────┼────────────────┤                 │
│  T            │            │                │                │                 │
│    Low        │    INFO    │      LOW       │    MEDIUM      │                 │
│               │            │                │                │                 │
│               └────────────┴────────────────┴────────────────┘                 │
│                                                                                 │
│                                                                                 │
│  EXPLOITABILITY FACTORS:          IMPACT FACTORS:                              │
│  • Publicly accessible?           • Data sensitivity                           │
│  • Known exploit exists?          • Regulatory implications                    │
│  • Skill required?                • Business criticality                       │
│  • Authentication needed?         • Blast radius                               │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Example Finding Analysis

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    FINDING ANALYSIS TEMPLATE                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  FINDING: Security group allows SSH from 0.0.0.0/0                              │
│  ══════════════════════════════════════════════════                             │
│                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │  Raw Finding Details:                                                  │    │
│  │  • Security Group: sg-abc123                                           │    │
│  │  • VPC: vpc-def456                                                     │    │
│  │  • Inbound Rule: TCP 22 from 0.0.0.0/0                                │    │
│  │  • Attached to: 3 EC2 instances                                       │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │  Context Questions:                                                    │    │
│  │  • Are these instances in public subnets?         YES ──▶ CRITICAL    │    │
│  │  • Do they have public IPs?                       YES                  │    │
│  │  • What's running on them?                        Production web app  │    │
│  │  • Is there a bastion or VPN available?           NO                   │    │
│  │  • Why was this rule created?                     "Needed for dev"     │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │  Risk Assessment:                                                      │    │
│  │  • Exploitability: HIGH (no auth needed to attempt)                   │    │
│  │  • Impact: HIGH (direct access to production)                         │    │
│  │  • Overall: CRITICAL                                                   │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │  Remediation Plan:                                                     │    │
│  │  1. Immediate: Restrict to corporate IP range                          │    │
│  │  2. Short-term: Implement AWS SSM Session Manager                      │    │
│  │  3. Long-term: Remove SSH entirely, use SSM only                       │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Accepted Risk Documentation

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    RISK ACCEPTANCE TEMPLATE                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  Finding ID: prowler-iam-16                                                     │
│  Description: IAM password policy does not require uppercase                    │
│  Severity: LOW                                                                  │
│                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │  Decision: ACCEPT RISK                                                 │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  Justification:                                                                 │
│  ─────────────                                                                  │
│  • All IAM users have MFA enforced (compensating control)                       │
│  • Password length is 16 characters minimum                                     │
│  • Most access is via SSO, not IAM passwords                                    │
│  • NIST 800-63B no longer recommends complexity requirements                    │
│                                                                                 │
│  Compensating Controls:                                                         │
│  ──────────────────────                                                         │
│  • MFA required on all accounts                                                 │
│  • 90-day password rotation                                                     │
│  • Account lockout after 5 failed attempts                                      │
│                                                                                 │
│  Review Date: 2026-06-01                                                        │
│  Approved By: Security Team                                                     │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
04-cloud-security-audit/
├── README.md
├── reports/
│   ├── sample-prowler-output.json     # Raw Prowler output
│   ├── executive-summary.md           # High-level findings
│   └── detailed-findings.md           # Technical details
├── remediation/
│   ├── critical-findings.md           # Immediate action items
│   ├── high-findings.md               # Sprint-level items
│   ├── medium-findings.md             # Quarter-level items
│   └── accepted-risks.md              # Documented exceptions
├── scripts/
│   ├── run-prowler.sh                 # Prowler execution script
│   └── parse-results.py               # Results parsing helper
└── docs/
    ├── methodology.md                 # How the audit was conducted
    └── compliance-mapping.md          # Maps to CIS, SOC2, etc.
```

## Remediation Roadmap

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         REMEDIATION ROADMAP                                     │
└─────────────────────────────────────────────────────────────────────────────────┘

  Week 1-2                 Week 3-4                 Month 2-3
  ════════                 ════════                 ═════════
      │                        │                        │
      ▼                        ▼                        ▼
┌───────────────┐       ┌───────────────┐       ┌───────────────┐
│   CRITICAL    │       │     HIGH      │       │    MEDIUM     │
├───────────────┤       ├───────────────┤       ├───────────────┤
│               │       │               │       │               │
│ • Close SSH   │       │ • Enable      │       │ • Update      │
│   0.0.0.0/0   │       │   CloudTrail  │       │   password    │
│               │       │   all regions │       │   policies    │
│ • Fix public  │       │               │       │               │
│   S3 buckets  │       │ • Rotate old  │       │ • Enable S3   │
│               │       │   access keys │       │   versioning  │
│ • Enable MFA  │       │               │       │               │
│   on root     │       │ • Enable VPC  │       │ • Extend log  │
│               │       │   Flow Logs   │       │   retention   │
│ • Remove      │       │               │       │               │
│   admin users │       │ • Encrypt EBS │       │ • Clean up    │
│               │       │   volumes     │       │   unused SGs  │
└───────────────┘       └───────────────┘       └───────────────┘
      │                        │                        │
      │                        │                        │
      └────────────────────────┴────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   CONTINUOUS        │
                    │   MONITORING        │
                    │                     │
                    │ • Weekly Prowler    │
                    │   scans             │
                    │ • Track fix rate    │
                    │ • Alert on new      │
                    │   critical findings │
                    └─────────────────────┘
```

## Deliverables Checklist

- [ ] Prowler scan results (JSON and HTML)
- [ ] Executive summary for non-technical audience
- [ ] Detailed findings with context
- [ ] Prioritized remediation list
- [ ] Accepted risk documentation
- [ ] Remediation roadmap
- [ ] Before/after comparison (if doing remediation)
- [ ] Compliance mapping (CIS, SOC 2, etc.)

## Questions to Answer in Your Documentation

1. **How do you distinguish between signal and noise?**
2. **Which findings actually matter in this context?**
3. **What would be accepted risks in a real organization?**
4. **How would you prioritize remediation over time?**
5. **What compensating controls might justify accepting a risk?**
6. **How would you present this to non-technical leadership?**

## Demonstrating Judgment

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    SHOWING PROFESSIONAL JUDGMENT                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  JUNIOR APPROACH:                  SENIOR APPROACH:                             │
│  ════════════════                  ════════════════                             │
│                                                                                 │
│  "Prowler found 500 issues.        "Prowler identified 500 findings,            │
│   All need to be fixed."           but after analysis:                          │
│                                                                                 │
│                                    • 8 are critical - public S3 and             │
│                                      open SSH. Fixing this week.                │
│                                                                                 │
│                                    • 45 are high - mostly logging gaps.         │
│                                      Remediation plan attached.                 │
│                                                                                 │
│                                    • 120 are context-dependent.                 │
│                                      Need business input.                       │
│                                                                                 │
│                                    • 200+ are informational or                  │
│                                      don't apply to our setup.                  │
│                                                                                 │
│                                    Here's my recommended roadmap..."            │
│                                                                                 │
│  ─────────────────────────────────────────────────────────────────────────────  │
│  │  The difference is JUDGMENT, not just technical ability.                  │  │
│  │  Anyone can run a scanner. Professionals interpret results.               │  │
│  ─────────────────────────────────────────────────────────────────────────────  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Further Reading

- [Prowler Documentation](https://docs.prowler.cloud/)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)

---

**Remember:** This demonstrates judgment, not just technical ability. In real jobs, security professionals are constantly asked to prioritise and explain risk, not just list vulnerabilities.
