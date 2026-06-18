# Accepted Risks

**Account:** 092645363677
**Audit Date:** June 18, 2026
**Review Date:** December 18, 2026

Findings documented here have been reviewed and accepted. They will not be remediated at this time due to the justifications below.

---

## AR-001: No SAML Identity Provider

- **Finding:** `iam_check_saml_providers_sts`
- **Severity:** Low
- **Detail:** No SAML Providers found.

**Justification:**
SAML/SSO federation is appropriate for multi-user organizations where employees need centralized identity management (e.g., connecting Okta or Azure AD to AWS). This is a single-owner personal lab account. There are no employees, no HR system, and no external identity provider to federate with.

**Compensating Controls:**
- Single account owner with MFA on root
- Access controlled via IAM user (post-remediation)

**Accepted By:** Account Owner
**Review Date:** December 18, 2026 — reassess if this account grows to support multiple users

---

## AR-002: No AWS Support Role

- **Finding:** `iam_support_role_created`
- **Severity:** Low
- **Detail:** AWS Support Access policy is not attached to any role.

**Justification:**
The AWS Support role (`AWSSupportAccess` policy) enables AWS Enterprise Support engineers to access your account for troubleshooting. This account is on the Basic Support plan with no enterprise support agreement. Creating a role with this policy provides no practical benefit without a support engagement.

**Compensating Controls:**
- N/A — this is not an active risk, it is a missing configuration

**Accepted By:** Account Owner
**Review Date:** December 18, 2026 — reassess if upgrading to Business or Enterprise support

---

## AR-003: Stale Bedrock Permission on AWS-Managed Service Role

- **Finding:** `iam_role_access_not_stale_to_bedrock` (AWSServiceRoleForSupport)
- **Severity:** Medium
- **Detail:** AWSServiceRoleForSupport has Bedrock permissions but has never used them.

**Justification:**
AWSServiceRoleForSupport is an AWS-managed service-linked role. Its trust policy only allows the AWS Support service to assume it — it cannot be assumed by external actors or account users. The Bedrock permission is defined in the AWS-managed policy and cannot be removed by the account owner without replacing the entire service role.

The finding is technically accurate but not exploitable in this context. The role exists to allow AWS Support to help troubleshoot issues, not for general workload use.

**Compensating Controls:**
- Role can only be assumed by AWS Support service (not user-assumable)
- No Bedrock usage has been observed in the account

**Accepted By:** Account Owner
**Review Date:** December 18, 2026
