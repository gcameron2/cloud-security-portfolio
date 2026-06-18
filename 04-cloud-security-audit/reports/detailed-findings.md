# Detailed Findings Report

**Account:** 092645363677
**Scan Date:** June 18, 2026
**Tool:** Prowler v5.30.2
**Raw Output:** `prowler-output-092645363677-20260618060915.ocsf.json`

---

## CRITICAL Findings

### FINDING-001: Root Account Has Active Access Key
- **Check ID:** `iam_no_root_access_key`
- **Severity:** Critical
- **Status:** FAIL
- **Detail:** Root account has one active access key.

**Why This Matters:**
Root access keys are permanent programmatic credentials tied to the most privileged identity in AWS. Unlike IAM user keys, they cannot be restricted by IAM policies, SCPs, or permission boundaries. If this key is exposed — in code, logs, environment variables, or a data breach — an attacker has full, unrestricted access to the entire AWS account.

**Risk Assessment:**
- Exploitability: HIGH — key can be used from anywhere, no MFA required for API calls
- Impact: CRITICAL — full account takeover, data exfiltration, resource destruction
- Compliance violations: CIS 1.4/1.5/2.0 §1.4, AWS Foundational Security Best Practices

**Remediation:**
1. Go to AWS Console → IAM → Security Credentials (root)
2. Locate the active access key
3. Delete it — do not deactivate, delete
4. Rotate any systems using this key to use IAM role-based access instead

---

### FINDING-002: Root Account Using Virtual MFA Instead of Hardware MFA
- **Check ID:** `iam_root_hardware_mfa_enabled`
- **Severity:** Critical
- **Status:** FAIL
- **Detail:** Root account has a virtual MFA instead of a hardware MFA device enabled.

**Why This Matters:**
Virtual MFA (TOTP apps like Google Authenticator, Authy) relies on a secret seed stored on a mobile device. That device can be compromised via malware, SIM swapping, iCloud/Google backup leaks, or physical theft. Hardware MFA (YubiKey, FIDO2 keys) stores the cryptographic secret in tamper-resistant hardware that cannot be extracted.

For the root account — the single most powerful identity in AWS — a virtual MFA provides meaningfully weaker protection than a hardware key.

**Risk Assessment:**
- Exploitability: MEDIUM — requires phone compromise or SIM swap
- Impact: CRITICAL — root account takeover
- Compliance violations: CIS 1.5 §1.6, AWS Well-Architected Security Pillar SEC02-BP01

**Remediation:**
1. Purchase a hardware security key (YubiKey 5 series or similar FIDO2 key, ~$50)
2. AWS Console → IAM → Security Credentials → Assign MFA Device → Hardware TOTP/U2F
3. Register the hardware key and remove the virtual MFA
4. Store the hardware key in a physically secure location

---

## HIGH Findings

### FINDING-003: Root Account Was Used Recently
- **Check ID:** `iam_avoid_root_usage`
- **Severity:** High
- **Status:** FAIL
- **Detail:** Root user in the account was last accessed 1 days ago.

**Why This Matters:**
AWS CloudTrail logged root account activity within the past 24 hours (this audit was conducted as root). AWS documentation explicitly states root should only be used for tasks that require it by design — such as changing the account's support plan, closing the account, or enabling MFA on root itself. All other operations should use IAM identities with scoped permissions.

**Context:**
The root usage that triggered this finding was running the Prowler security scan itself. This highlights the operational risk: even well-intentioned administrative work performed as root creates unnecessary exposure.

**Risk Assessment:**
- Exploitability: N/A (this is a behavioral finding, not an open vulnerability)
- Impact: HIGH — root sessions cannot be restricted; any compromise during an active root session is total
- Compliance violations: CIS 1.4/1.5/2.0 §1.7, NIST 800-53 AC-6

**Remediation:**
1. Create a dedicated IAM user or role with `AdministratorAccess` for day-to-day admin tasks
2. Create a `ProwlerAuditRole` with `SecurityAudit` + `ReadOnlyAccess` for future scans
3. Lock root credentials away — only use root for the narrow set of root-only tasks
4. Set a CloudWatch alarm on root login events via CloudTrail

---

## MEDIUM Findings

### FINDING-004 through 009: IAM Password Policy Not Configured
- **Check IDs:** `iam_password_policy_number`, `iam_password_policy_symbol`, `iam_password_policy_uppercase`, `iam_password_policy_lowercase`, `iam_password_policy_minimum_length_14`, `iam_password_policy_expires_passwords_within_90_days_or_less`, `iam_password_policy_reuse_24`
- **Severity:** Medium
- **Status:** FAIL

**Why This Matters:**
The account has no IAM password policy configured. While this account currently has no IAM users with console passwords (only root), this is a foundational control gap. Any IAM user created in the future would inherit weak password defaults.

**Context for This Account:**
Since there are currently no IAM users with passwords, the immediate risk is low. However, this should be configured before creating any IAM users.

**Recommended Policy Settings:**
```
Minimum length: 14 characters
Require uppercase: Yes
Require lowercase: Yes
Require numbers: Yes
Require symbols: Yes
Password expiry: 90 days
Prevent reuse: Last 24 passwords
```

**Remediation:**
AWS Console → IAM → Account Settings → Edit Password Policy

---

### FINDING-010: Stale Bedrock Permission on Service Role
- **Check ID:** `iam_role_access_not_stale_to_bedrock`
- **Severity:** Medium
- **Status:** FAIL
- **Detail:** IAM Role AWSServiceRoleForSupport has Bedrock permissions but has never used them.

**Assessment:** This is an AWS-managed service role created automatically. The Bedrock permission exists in AWS's managed policy definition but has never been exercised. This is a low-risk finding — the role cannot be modified and is not directly exploitable. Documented as accepted risk.

---

## LOW Findings

### FINDING-011: No SecurityAudit Role Created
- **Check ID:** `iam_securityaudit_role_created`
- **Detail:** SecurityAudit policy is not attached to any role.

**Remediation:** Create a `ProwlerAuditRole` or `SecurityAuditRole` with the AWS managed `SecurityAudit` and `ReadOnlyAccess` policies. Use this role for all future security tool runs instead of root.

---

### FINDING-012: No SAML Identity Provider Configured
- **Check ID:** `iam_check_saml_providers_sts`
- **Detail:** No SAML Providers found.

**Assessment:** Not applicable for a personal lab account. Accepted risk — documented in accepted-risks.md.

---

### FINDING-013: No AWS Support Role Created
- **Check ID:** `iam_support_role_created`
- **Detail:** AWS Support Access policy is not attached to any role.

**Assessment:** Low priority for a personal account. In an enterprise, this role allows AWS Support to access your account for troubleshooting. Accepted risk for lab use.

---

### FINDING-014: Password Policy Does Not Require Lowercase
- **Check ID:** `iam_password_policy_lowercase`
- **Detail:** IAM password policy does not require at least one lowercase letter.
- **Remediation:** Covered under FINDING-004 through 009 — fix the full password policy in one action.
