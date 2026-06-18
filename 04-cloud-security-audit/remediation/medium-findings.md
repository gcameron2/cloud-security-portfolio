# Medium Findings — Remediation This Month

**Account:** 092645363677
**Target:** Resolve within 30 days of audit date (by July 18, 2026)

---

## FINDINGS 004-009: Configure IAM Password Policy

**Current State:** No IAM password policy is set. AWS defaults apply (minimum 8 chars, no complexity requirements).

**Why It Matters:** While there are currently no IAM users with console passwords in this account, the password policy is a foundational control that must be in place before any IAM users are created. Configuring it now ensures it is never accidentally skipped.

### One-Command Fix (AWS CLI)

```bash
aws iam update-account-password-policy \
  --minimum-password-length 14 \
  --require-symbols \
  --require-numbers \
  --require-uppercase-characters \
  --require-lowercase-characters \
  --allow-users-to-change-password \
  --max-password-age 90 \
  --password-reuse-prevention 24 \
  --hard-expiry false
```

### What Each Setting Does

| Setting | Value | Rationale |
|---------|-------|-----------|
| Minimum length | 14 | CIS benchmark requirement; longer = exponentially harder to brute-force |
| Uppercase + lowercase + numbers + symbols | Required | Increases character space; NIST now recommends length over complexity but AWS compliance frameworks still require it |
| Max age | 90 days | Balance between rotation hygiene and user friction |
| Reuse prevention | 24 | Prevents cycling through a small set of known passwords |

### Verification

```bash
aws iam get-account-password-policy
```

Re-run Prowler:
```bash
prowler aws --check iam_password_policy_minimum_length_14 \
  iam_password_policy_number \
  iam_password_policy_symbol \
  iam_password_policy_uppercase \
  iam_password_policy_lowercase \
  iam_password_policy_reuse_24 \
  iam_password_policy_expires_passwords_within_90_days_or_less
```

**Expected result:** All 7 checks PASS

---

## FINDING-010: Stale Bedrock Permission on AWSServiceRoleForSupport

**Check:** `iam_role_access_not_stale_to_bedrock`
**Detail:** AWSServiceRoleForSupport has Bedrock permissions but has never used them.

**Assessment:** This is an AWS-managed service-linked role. Its policies are controlled by AWS, not by the account owner. The Bedrock permission exists in the AWS-managed policy definition but poses no exploitable risk — the role can only be assumed by the AWS Support service, not by external actors.

**Decision:** Accept risk. Documented in `accepted-risks.md`.
