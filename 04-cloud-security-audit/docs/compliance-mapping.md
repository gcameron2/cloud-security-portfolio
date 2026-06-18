# Compliance Mapping

This document maps the audit findings to common compliance frameworks.

## Frameworks Referenced

| Framework | Relevance |
|-----------|-----------|
| CIS AWS Foundations Benchmark v3.0 | Industry standard AWS hardening guide |
| NIST 800-53 Rev 5 | US federal and enterprise baseline |
| AWS Well-Architected Security Pillar | AWS's own best practices |
| SOC 2 Type II | Common SaaS compliance requirement |

---

## Finding-to-Framework Mapping

### FINDING-001: Root Access Key Exists

| Framework | Control |
|-----------|---------|
| CIS AWS v3.0 | 1.4 — Ensure no root account access key exists |
| NIST 800-53 | AC-6 — Least Privilege |
| AWS Well-Architected | SEC02-BP01 — Strong sign-in mechanisms |
| SOC 2 | CC6.1 — Logical access controls |

---

### FINDING-002: Root MFA Is Virtual, Not Hardware

| Framework | Control |
|-----------|---------|
| CIS AWS v3.0 | 1.6 — Ensure hardware MFA is enabled for root |
| NIST 800-53 | IA-2(1) — Multi-factor authentication |
| AWS Well-Architected | SEC02-BP02 — MFA for all users |
| SOC 2 | CC6.1 — Logical access controls |

---

### FINDING-003: Root Account Used Recently

| Framework | Control |
|-----------|---------|
| CIS AWS v3.0 | 1.7 — Eliminate use of the root account |
| NIST 800-53 | AC-6 — Least Privilege |
| AWS Well-Architected | SEC02-BP01 — Strong sign-in mechanisms |
| SOC 2 | CC6.3 — Access restriction |

---

### FINDINGS 004-009: Password Policy Not Configured

| Framework | Control |
|-----------|---------|
| CIS AWS v3.0 | 1.8–1.15 — IAM password policy controls |
| NIST 800-53 | IA-5 — Authenticator management |
| AWS Well-Architected | SEC02-BP03 — Store secrets securely |
| SOC 2 | CC6.1 — Logical access controls |

---

## Compliance Posture Summary

| Framework | Applicable Controls | Passing | Failing | Pass Rate |
|-----------|-------------------|---------|---------|-----------|
| CIS AWS v3.0 (IAM chapter) | 12 | 7 | 5 | 58% |
| NIST 800-53 (AC/IA controls) | 8 | 5 | 3 | 63% |
| AWS Well-Architected (SEC02) | 5 | 3 | 2 | 60% |

> Note: Compliance pass rates reflect only the IAM and S3 services scanned. A full compliance assessment would require scanning all services.

---

## Path to CIS Level 1 Compliance

CIS AWS Foundations Benchmark Level 1 is the baseline hardening standard. To achieve it for IAM:

- [x] MFA enabled on root
- [ ] **Root access key deleted** ← FINDING-001
- [ ] **Hardware MFA on root** ← FINDING-002
- [ ] **Stop using root** ← FINDING-003
- [ ] **Password policy configured** ← FINDINGS 004-009
- [ ] SecurityAudit role created ← FINDING-011
