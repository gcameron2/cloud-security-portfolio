# Project 1: IAM Cross-Account Access

## Overview

Identity and Access Management is not a beginner topic—and that's exactly why it makes such a powerful project. In real organisations, everything is multi-account. This project demonstrates how to implement cross-account access properly, the way it's done in production environments.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AWS ORGANIZATION                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────┐      ┌────────────────────────────┐         │
│  │   SECURITY/ADMIN ACCOUNT   │      │    WORKLOAD ACCOUNT        │         │
│  │   (Account: 111111111111)  │      │   (Account: 222222222222)  │         │
│  │                            │      │                            │         │
│  │  ┌──────────────────────┐  │      │  ┌──────────────────────┐  │         │
│  │  │   IAM User/Role      │  │      │  │  Cross-Account Role  │  │         │
│  │  │   "SecurityAdmin"    │──┼──────┼─▶│  "SecurityAuditRole" │  │         │
│  │  │                      │  │ STS  │  │                      │  │         │
│  │  │  ┌────────────────┐  │  │Assume│  │  ┌────────────────┐  │  │         │
│  │  │  │ AssumeRole     │  │  │ Role │  │  │ Trust Policy   │  │  │         │
│  │  │  │ Permission     │  │  │      │  │  │                │  │  │         │
│  │  │  └────────────────┘  │  │      │  │  │ Principal:     │  │  │         │
│  │  └──────────────────────┘  │      │  │  │ 111111111111   │  │  │         │
│  │                            │      │  │  │                │  │  │         │
│  │                            │      │  │  │ Condition:     │  │  │         │
│  │                            │      │  │  │ ExternalId     │  │  │         │
│  │                            │      │  │  │ MFA Required   │  │  │         │
│  │                            │      │  │  └────────────────┘  │  │         │
│  │                            │      │  └──────────────────────┘  │         │
│  └────────────────────────────┘      └────────────────────────────┘         │
│                                                                              │
│  ┌────────────────────────────┐      ┌────────────────────────────┐         │
│  │     LOGGING ACCOUNT        │      │    DEV/TEST ACCOUNT        │         │
│  │   (Account: 333333333333)  │      │   (Account: 444444444444)  │         │
│  │                            │      │                            │         │
│  │  ┌──────────────────────┐  │      │  ┌──────────────────────┐  │         │
│  │  │  Cross-Account Role  │  │      │  │  Cross-Account Role  │  │         │
│  │  │  "LogArchiveRole"    │  │      │  │  "DevAccessRole"     │  │         │
│  │  └──────────────────────┘  │      │  └──────────────────────┘  │         │
│  └────────────────────────────┘      └────────────────────────────┘         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## The Role Assumption Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CROSS-ACCOUNT ROLE ASSUMPTION                          │
└─────────────────────────────────────────────────────────────────────────────┘

     SECURITY ACCOUNT                              WORKLOAD ACCOUNT
     ═══════════════                               ════════════════

  ┌──────────────────┐                          ┌──────────────────┐
  │  1. User/Role    │                          │                  │
  │  authenticates   │                          │                  │
  │  with MFA        │                          │                  │
  └────────┬─────────┘                          │                  │
           │                                    │                  │
           ▼                                    │                  │
  ┌──────────────────┐                          │                  │
  │  2. Calls STS    │                          │                  │
  │  AssumeRole      │─────────────────────────▶│  3. Trust Policy │
  │  with:           │                          │     Evaluated    │
  │  - Role ARN      │                          │                  │
  │  - ExternalId    │                          │  ┌────────────┐  │
  │  - Session name  │                          │  │ ✓ Account  │  │
  └────────┬─────────┘                          │  │ ✓ ExtId    │  │
           │                                    │  │ ✓ MFA      │  │
           │                                    │  └────────────┘  │
           │                                    │                  │
           │◀───────────────────────────────────│  4. Temporary    │
           │                                    │     Credentials  │
           ▼                                    │     Returned     │
  ┌──────────────────┐                          └──────────────────┘
  │  5. Use temp     │
  │  credentials     │
  │  (1 hour max)    │
  └──────────────────┘
```

## What You'll Build

### Account Structure
- **Security Account**: Central hub for security operations
- **Workload Account**: Represents production/application environments
- **Logging Account**: Dedicated log archive (referenced in Project 5)

### Roles to Implement

| Role | Purpose | Permissions | Trust |
|------|---------|-------------|-------|
| SecurityAuditRole | Read-only security review | SecurityAudit, ViewOnly | Security Account only |
| IncidentResponseRole | Active incident handling | EC2, VPC, IAM read + limited write | Security Account + MFA |
| DeploymentRole | CI/CD deployments | Scoped to specific services | CI/CD pipeline role |

## Implementation Steps

### Step 1: Set Up the Trust Relationship

```
┌─────────────────────────────────────────────────────────────────┐
│                     TRUST POLICY ANATOMY                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  {                                                              │
│    "Version": "2012-10-17",                                     │
│    "Statement": [                                               │
│      {                                                          │
│        "Effect": "Allow",          ◄── Explicit allow           │
│        "Principal": {                                           │
│          "AWS": "arn:aws:iam::111111111111:root"               │
│        },                          ◄── WHO can assume           │
│        "Action": "sts:AssumeRole", ◄── The action               │
│        "Condition": {                                           │
│          "StringEquals": {                                      │
│            "sts:ExternalId": "UniqueSecretValue"               │
│          },                        ◄── Confused deputy fix      │
│          "Bool": {                                              │
│            "aws:MultiFactorAuthPresent": "true"                │
│          }                         ◄── MFA required             │
│        }                                                        │
│      }                                                          │
│    ]                                                            │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Step 2: Create the Permission Policy

Apply least privilege by scoping to exactly what's needed:

```
┌─────────────────────────────────────────────────────────────────┐
│                    LEAST PRIVILEGE APPROACH                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  BAD (Overprivileged):              GOOD (Least Privilege):     │
│  ─────────────────────              ────────────────────────    │
│                                                                 │
│  {                                  {                           │
│    "Effect": "Allow",                 "Effect": "Allow",        │
│    "Action": "ec2:*",     ✗           "Action": [               │
│    "Resource": "*"                      "ec2:DescribeInstances",│
│  }                                      "ec2:DescribeVpcs",     │
│                                         "ec2:DescribeSubnets"   │
│                                       ],                   ✓    │
│                                       "Resource": "*"           │
│                                     }                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Step 3: Configure the Assuming Role

```
┌─────────────────────────────────────────────────────────────────┐
│              PERMISSION TO ASSUME (Security Account)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  {                                                              │
│    "Version": "2012-10-17",                                     │
│    "Statement": [                                               │
│      {                                                          │
│        "Effect": "Allow",                                       │
│        "Action": "sts:AssumeRole",                              │
│        "Resource": [                                            │
│          "arn:aws:iam::222222222222:role/SecurityAuditRole",   │
│          "arn:aws:iam::333333333333:role/LogArchiveRole"       │
│        ]                                                        │
│      }                           ▲                              │
│    ]                             │                              │
│  }                               │                              │
│                                  │                              │
│         Explicitly list allowed roles ─┘                        │
│         Never use wildcards here!                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Key Decisions to Document

### Why Role Assumption Over Long-Lived Credentials?

```
┌─────────────────────────────────────────────────────────────────┐
│           CREDENTIALS COMPARISON                                │
├─────────────────────┬───────────────────────────────────────────┤
│  Long-Lived Keys    │  Role Assumption                          │
├─────────────────────┼───────────────────────────────────────────┤
│  ✗ Never expire     │  ✓ Temp credentials (1-12 hours)          │
│  ✗ Can be leaked    │  ✓ Auto-rotate                            │
│  ✗ Hard to audit    │  ✓ CloudTrail logs all assumptions        │
│  ✗ No MFA support   │  ✓ Can require MFA                        │
│  ✗ Shared secrets   │  ✓ No secrets to manage                   │
└─────────────────────┴───────────────────────────────────────────┘
```

### How Would This Scale?

```
                        ┌─────────────────┐
                        │  SECURITY HUB   │
                        │    ACCOUNT      │
                        └────────┬────────┘
                                 │
           ┌─────────────────────┼─────────────────────┐
           │                     │                     │
           ▼                     ▼                     ▼
    ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
    │   Prod OU    │     │   Dev OU     │     │  Sandbox OU  │
    ├──────────────┤     ├──────────────┤     ├──────────────┤
    │ ┌──────────┐ │     │ ┌──────────┐ │     │ ┌──────────┐ │
    │ │Account 1 │ │     │ │Account 10│ │     │ │Account 50│ │
    │ └──────────┘ │     │ └──────────┘ │     │ └──────────┘ │
    │ ┌──────────┐ │     │ ┌──────────┐ │     │ ┌──────────┐ │
    │ │Account 2 │ │     │ │Account 11│ │     │ │Account 51│ │
    │ └──────────┘ │     │ └──────────┘ │     │ └──────────┘ │
    │     ...      │     │     ...      │     │     ...      │
    └──────────────┘     └──────────────┘     └──────────────┘

    At scale: Use AWS Organizations with SCPs + StackSets
    to deploy consistent roles across all accounts
```

## Security Considerations

### Risks of Over-Privileged Roles

```
┌─────────────────────────────────────────────────────────────────┐
│                    BLAST RADIUS COMPARISON                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Over-Privileged Role              Properly Scoped Role         │
│  ════════════════════              ════════════════════         │
│                                                                 │
│  Compromised? Attacker can:        Compromised? Attacker can:   │
│  • Delete all resources            • Read EC2 metadata          │
│  • Exfiltrate all data             • View security groups       │
│  • Create backdoor users           • That's it.                 │
│  • Pivot to other accounts                                      │
│  • Disable logging                 Impact: LOW                  │
│  • Mine crypto                     Recovery: EASY               │
│                                                                 │
│  Impact: CATASTROPHIC                                           │
│  Recovery: DIFFICULT                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Detection: What to Monitor

```
CloudTrail Events to Alert On:
─────────────────────────────
• AssumeRole from unexpected source IPs
• AssumeRole failures (brute force attempts)
• Role assumption outside business hours
• Cross-account access from unapproved accounts
• Changes to trust policies
```

## Deliverables Checklist

- [ ] Terraform code for cross-account role setup
- [ ] Trust policies with proper conditions
- [ ] Permission policies following least privilege
- [ ] Documentation explaining design decisions
- [ ] Diagram showing account relationships
- [ ] Write-up on scaling considerations
- [ ] Monitoring/alerting recommendations

## Questions to Answer in Your Documentation

1. **Why did you choose role assumption instead of long-lived credentials?**
2. **How would this scale to 20 or 100 accounts?**
3. **What risks exist if a role is over-privileged?**
4. **How would you detect misuse?**
5. **What happens if the Security Account is compromised?**

## Further Reading

- [AWS Cross-Account Access](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html)
- [The Confused Deputy Problem](https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html)
- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)

---

**Remember:** This project immediately signals maturity. Anyone reviewing your work can see that you understand how modern cloud environments are structured and why IAM mistakes are so dangerous.
