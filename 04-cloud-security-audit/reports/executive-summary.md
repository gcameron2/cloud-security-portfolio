# Executive Summary: AWS Cloud Security Audit

**Account:** 092645363677
**Scan Date:** June 18, 2026
**Tool:** Prowler v5.30.2
**Scope:** IAM (Identity & Access Management), S3

---

## Overall Posture

Prowler executed 69 checks against the AWS account. Of those, **14 failed (58%)** and 10 passed (42%).

The account has a **moderate-to-high risk profile** for a personal/lab environment. No S3 buckets were found, which eliminates an entire class of data exposure risk. However, the IAM configuration has two critical findings that would be unacceptable in any production environment.

---

## Summary of Findings

| Severity | Count | Examples |
|----------|-------|---------|
| Critical | 2 | Root access key exists, Virtual MFA on root |
| High     | 1 | Root account actively used |
| Medium   | 6 | Password policy not configured |
| Low      | 4 | No SecurityAudit role, no SAML/SSO |
| **Total FAIL** | **14** | |

---

## Top 3 Risks That Need Immediate Attention

### 1. Root Account Has a Programmatic Access Key (CRITICAL)
The AWS root account has an active access key. This means anyone who obtains this key has unrestricted, permanent access to every resource in the account — with no way to scope, rotate, or revoke it without full account access. AWS explicitly states root access keys should never exist. This is the highest-priority finding in this audit.

**Business Impact:** Total account compromise if the key is leaked (e.g., committed to GitHub, exposed in logs).

### 2. Root MFA Is Virtual, Not Hardware (CRITICAL)
The root account is protected by a virtual MFA app (e.g., Google Authenticator) rather than a physical hardware token (e.g., YubiKey). Virtual MFA can be compromised if a phone is stolen, cloned via SIM swap, or if the device is infected with malware. For the most privileged account in AWS, virtual MFA is insufficient.

**Business Impact:** Root account takeover possible via phone/SIM compromise.

### 3. Root Account Was Used Recently (HIGH)
The root account was used 1 day ago to perform administrative tasks (running this security scan). AWS best practice is to use root only for a narrow set of tasks that cannot be performed any other way (e.g., closing the account, changing support plan). All day-to-day operations — including running security tools — should use IAM users or roles with scoped permissions.

**Business Impact:** Every root login is an unnecessary risk exposure. Root actions cannot be restricted by SCPs or permission boundaries.

---

## What's Going Well

- Root MFA **is** enabled (passes the baseline check)
- No IAM users with administrative policies exist
- No S3 buckets with public exposure
- No access keys older than 90 days
- No AWS CloudShell full-access policies attached

---

## Recommended Remediation Roadmap

| Timeline | Action |
|----------|--------|
| **This week** | Delete the root access key |
| **This week** | Create a dedicated IAM admin user for daily use; stop using root |
| **This month** | Upgrade root MFA to a hardware key (YubiKey) |
| **This month** | Configure the IAM password policy |
| **This quarter** | Create a SecurityAudit role for future audits |
| **This quarter** | Evaluate SSO/SAML for federated access |

---

## Auditor Note

This audit was conducted using the root account, which itself generated one of the findings (recent root usage). In a production environment, a dedicated `ProwlerAuditRole` with `SecurityAudit` and `ReadOnlyAccess` managed policies would be used instead. This is documented in the methodology.
