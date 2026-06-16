# Project 6: Break-Glass Access and Emergency Controls

## Overview

This is a project almost no junior or mid-level candidate thinks about, yet it is extremely common in real organisations. Systems fail. People make mistakes. Security has to account for both. This project designs a break-glass access model for emergencies—with strong controls, audit trails, and clear documentation.

## What is Break-Glass Access?

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                       BREAK-GLASS CONCEPT                                       │
└─────────────────────────────────────────────────────────────────────────────────┘

    NORMAL OPERATIONS                         EMERGENCY SITUATION
    ══════════════════                        ═══════════════════

    ┌───────────────┐                         ┌───────────────┐
    │   Engineer    │                         │   On-Call     │
    │               │                         │   Engineer    │
    └───────┬───────┘                         └───────┬───────┘
            │                                         │
            │ Standard access                         │ SSO is down!
            │ via SSO                                 │ IdP unavailable!
            │                                         │ Critical outage!
            ▼                                         │
    ┌───────────────┐                                 │
    │   Normal      │                                 │
    │   IAM Role    │                                 ▼
    │  (Read-only)  │                         ┌───────────────┐
    └───────────────┘                         │  Break-Glass  │
                                              │    Account    │
                                              │  (Emergency)  │
                                              └───────┬───────┘
                                                      │
                                                      │ MFA + approval
                                                      │ 1-hour session
                                                      │ Full logging
                                                      ▼
                                              ┌───────────────┐
                                              │  Emergency    │
                                              │  Admin Role   │
                                              └───────────────┘

    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║  "Break glass" = Emergency access when normal paths fail                  ║
    ║  Named after fire alarm boxes that require breaking glass to activate    ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     BREAK-GLASS ACCESS ARCHITECTURE                             │
└─────────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │         BREAK-GLASS ACCOUNT         │
                    │         (Separate AWS Account)      │
                    │                                     │
                    │  ┌───────────────────────────────┐  │
                    │  │    Emergency Admin User       │  │
                    │  │    (bg-admin-1, bg-admin-2)   │  │
                    │  │                               │  │
                    │  │  • MFA REQUIRED (hardware)    │  │
                    │  │  • Password in vault          │  │
                    │  │  • Console access only        │  │
                    │  │  • No programmatic access     │  │
                    │  └───────────────────────────────┘  │
                    │                 │                   │
                    │                 │ AssumeRole        │
                    │                 ▼                   │
                    │  ┌───────────────────────────────┐  │
                    │  │    Emergency Response Role    │  │
                    │  │                               │  │
                    │  │  • AdministratorAccess        │  │
                    │  │  • 1-hour max session         │  │
                    │  │  • Condition: MFA required    │  │
                    │  │  • Condition: Source IP       │  │
                    │  └───────────────────────────────┘  │
                    │                 │                   │
                    └─────────────────┼───────────────────┘
                                      │
            ┌─────────────────────────┼─────────────────────────┐
            │                         │                         │
            ▼                         ▼                         ▼
    ┌───────────────┐         ┌───────────────┐         ┌───────────────┐
    │   Production  │         │    Staging    │         │     Dev       │
    │    Account    │         │    Account    │         │   Account     │
    │               │         │               │         │               │
    │  Trust Policy │         │  Trust Policy │         │  Trust Policy │
    │  allows BG    │         │  allows BG    │         │  allows BG    │
    │  account      │         │  account      │         │  account      │
    └───────────────┘         └───────────────┘         └───────────────┘
```

## Access Control Layers

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    DEFENSE IN DEPTH FOR BREAK-GLASS                             │
└─────────────────────────────────────────────────────────────────────────────────┘

     LAYER 1: Knowledge (Something You Know)
     ════════════════════════════════════════
     ┌─────────────────────────────────────────────────────────────────────┐
     │  • Password stored in secure vault (e.g., 1Password, HashiCorp)    │
     │  • Requires vault access + vault MFA                               │
     │  • Password is complex, 32+ characters                             │
     └─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
     LAYER 2: Possession (Something You Have)
     ═════════════════════════════════════════
     ┌─────────────────────────────────────────────────────────────────────┐
     │  • Hardware MFA token (YubiKey)                                    │
     │  • Stored in physical safe or secure location                      │
     │  • Multiple tokens for redundancy                                  │
     └─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
     LAYER 3: Authorization (Approval Required)
     ═══════════════════════════════════════════
     ┌─────────────────────────────────────────────────────────────────────┐
     │  • Must document reason before access                              │
     │  • Peer approval for non-critical (Slack/PagerDuty)                │
     │  • Manager approval for production changes                         │
     └─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
     LAYER 4: Constraints (Limited Scope)
     ═════════════════════════════════════
     ┌─────────────────────────────────────────────────────────────────────┐
     │  • Session duration: 1 hour maximum                                │
     │  • Source IP: Corporate VPN or office only                         │
     │  • Time restriction: Alert if used outside business hours          │
     └─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
     LAYER 5: Monitoring (Everything Logged)
     ════════════════════════════════════════
     ┌─────────────────────────────────────────────────────────────────────┐
     │  • All actions logged to immutable log archive                     │
     │  • Real-time alerts on break-glass activation                      │
     │  • Mandatory post-incident review                                  │
     └─────────────────────────────────────────────────────────────────────┘
```

## When to Use Break-Glass

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    BREAK-GLASS SCENARIOS                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ✓ APPROPRIATE USE CASES:                                                       │
│  ════════════════════════                                                       │
│                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │  • SSO/IdP is completely down and engineers can't access AWS          │    │
│  │  • Critical production outage requiring immediate admin access        │    │
│  │  • Security incident requiring account lockdown                       │    │
│  │  • Normal admin is unavailable and urgent change needed               │    │
│  │  • Recovering from failed automation that locked out normal access    │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  ✗ INAPPROPRIATE USE CASES:                                                     │
│  ══════════════════════════                                                     │
│                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │  • "It's faster than going through normal process"                    │    │
│  │  • Routine maintenance tasks                                          │    │
│  │  • Testing or development work                                        │    │
│  │  • Working around access control for convenience                      │    │
│  │  • Any non-emergency situation                                        │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  ╔════════════════════════════════════════════════════════════════════════╗    │
│  ║  RULE: If you have time to ask "should I use break-glass?"            ║    │
│  ║        the answer is probably NO.                                      ║    │
│  ╚════════════════════════════════════════════════════════════════════════╝    │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Break-Glass Procedure

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    BREAK-GLASS ACTIVATION PROCEDURE                             │
└─────────────────────────────────────────────────────────────────────────────────┘

    STEP 1: Identify Emergency                    STEP 2: Get Approval
    ══════════════════════                        ═══════════════════
           │                                              │
           ▼                                              ▼
    ┌─────────────────┐                          ┌─────────────────┐
    │ Is normal       │──── YES ───▶ Use normal  │ Contact second  │
    │ access working? │             access!      │ person:         │
    └────────┬────────┘                          │ • On-call       │
             │                                   │ • Manager       │
            NO                                   │ • Security team │
             │                                   └────────┬────────┘
             ▼                                            │
    ┌─────────────────┐                                   ▼
    │ Document the    │                          ┌─────────────────┐
    │ reason in       │                          │ Get verbal or   │
    │ incident ticket │                          │ written approval│
    └────────┬────────┘                          │ (Slack, call)   │
             │                                   └────────┬────────┘
             │                                            │
             └────────────────┬───────────────────────────┘
                              │
                              ▼
    STEP 3: Access Credentials                   STEP 4: Use Access
    ══════════════════════════                   ═══════════════════
           │                                              │
           ▼                                              ▼
    ┌─────────────────┐                          ┌─────────────────┐
    │ Retrieve from   │                          │ Login to        │
    │ vault:          │                          │ break-glass     │
    │ • Password      │                          │ account         │
    │ • MFA device    │                          │                 │
    │   location      │                          │ Assume role     │
    └────────┬────────┘                          │ into target     │
             │                                   │ account         │
             │                                   └────────┬────────┘
             │                                            │
             └────────────────┬───────────────────────────┘
                              │
                              ▼
    STEP 5: Perform Action                       STEP 6: Close Out
    ══════════════════════                       ═════════════════
           │                                              │
           ▼                                              ▼
    ┌─────────────────┐                          ┌─────────────────┐
    │ • Take minimal  │                          │ • Log out       │
    │   required      │                          │ • Update ticket │
    │   actions       │                          │ • Rotate creds  │
    │ • Document      │                          │   if exposed    │
    │   everything    │                          │ • Schedule      │
    │ • Screenshot    │                          │   review        │
    │   as needed     │                          └─────────────────┘
    └─────────────────┘
```

## Monitoring and Alerting

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    BREAK-GLASS MONITORING                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  REAL-TIME ALERTS (Immediate):                                                  │
│  ══════════════════════════════                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │  • Break-glass account login                ──▶ PagerDuty + Slack     │    │
│  │  • Role assumption from BG account          ──▶ PagerDuty + Slack     │    │
│  │  • Any action in target account from BG     ──▶ Log aggregation       │    │
│  │  • Failed BG login attempts                 ──▶ Security team         │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  DAILY REVIEW:                                                                  │
│  ═════════════                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │  • Was break-glass used in last 24 hours?                             │    │
│  │  • Were all uses documented?                                          │    │
│  │  • Are all tickets closed?                                            │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  MONTHLY REVIEW:                                                                │
│  ═══════════════                                                                │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │  • How many times was BG used?                                        │    │
│  │  • Were uses appropriate?                                             │    │
│  │  • Are credentials still secure?                                      │    │
│  │  • Is MFA hardware accounted for?                                     │    │
│  │  • Any process improvements needed?                                   │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
06-break-glass-access/
├── README.md
├── terraform/
│   ├── main.tf                     # Provider config
│   ├── break-glass-account.tf      # BG account resources
│   ├── emergency-role.tf           # Emergency admin role
│   ├── trust-policies.tf           # Cross-account trust
│   ├── cloudwatch-alarms.tf        # Monitoring
│   └── variables.tf
├── runbooks/
│   ├── activation-procedure.md     # Step-by-step guide
│   ├── sso-outage.md               # Specific scenario
│   ├── security-incident.md        # Specific scenario
│   └── post-incident-review.md     # Template for review
└── docs/
    ├── architecture.md             # Design decisions
    ├── credential-storage.md       # How creds are stored
    └── testing-procedure.md        # How to test BG access
```

## Deliverables Checklist

- [ ] Break-glass account configuration
- [ ] Emergency admin IAM user(s)
- [ ] Cross-account emergency role
- [ ] MFA enforcement
- [ ] Session duration limits
- [ ] IP restriction (optional)
- [ ] CloudWatch alarms for activation
- [ ] Activation runbook
- [ ] Post-incident review template
- [ ] Monthly audit checklist

## Questions to Answer in Your Documentation

1. **What scenarios require break-glass access?**
2. **How is the access secured (layers of control)?**
3. **Who is authorized to use it?**
4. **How would misuse be detected?**
5. **What happens after break-glass is used?**
6. **How often should break-glass access be tested?**

## Testing Break-Glass Access

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    BREAK-GLASS TESTING                                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  WHY TEST?                                                                      │
│  ═════════                                                                      │
│  • Ensure credentials work when needed                                          │
│  • Verify MFA devices are functional                                            │
│  • Confirm runbooks are accurate                                                │
│  • Practice the process before real emergency                                   │
│                                                                                 │
│  TESTING SCHEDULE:                                                              │
│  ═════════════════                                                              │
│  • Monthly: Verify vault access and MFA devices                                 │
│  • Quarterly: Full activation test (non-production)                             │
│  • Annually: Full activation test (production, read-only)                       │
│                                                                                 │
│  TEST PROCEDURE:                                                                │
│  ════════════════                                                               │
│  1. Schedule test window                                                        │
│  2. Retrieve credentials from vault                                             │
│  3. Activate break-glass access                                                 │
│  4. Verify role assumption works                                                │
│  5. Verify alerts fire correctly                                                │
│  6. Document any issues                                                         │
│  7. Rotate credentials after test                                               │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Further Reading

- [AWS Break Glass Access Pattern](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/implement-a-break-glass-procedure-in-aws-accounts.html)
- [NIST Emergency Access Guidelines](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [Hardware MFA Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa.html)

---

**Remember:** The value here is not the technical complexity. It's the governance thinking. You explain scenarios where normal access fails, how to recover safely, and how misuse would be detected and reviewed. This tells reviewers that you understand operational reality.
