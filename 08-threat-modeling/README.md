# Project 8: Threat Modeling a Cloud Architecture You Built

## Overview

This is an advanced but extremely effective project. Take one of your existing architectures—the VPC, CI/CD pipeline, or multi-account setup—and perform a basic threat model against it. You don't need a formal framework to make this valuable. What matters is showing structured thinking about what could go wrong.

## What is Threat Modeling?

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                       THREAT MODELING EXPLAINED                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

    Threat modeling answers four key questions:

    ┌─────────────────────────────────────────────────────────────────────────┐
    │  1. WHAT ARE WE BUILDING?                                              │
    │     → Document the system architecture                                 │
    │     → Identify data flows and trust boundaries                         │
    ├─────────────────────────────────────────────────────────────────────────┤
    │  2. WHAT CAN GO WRONG?                                                 │
    │     → Identify threats using STRIDE or similar                         │
    │     → Consider attacker motivations and capabilities                   │
    ├─────────────────────────────────────────────────────────────────────────┤
    │  3. WHAT ARE WE GOING TO DO ABOUT IT?                                  │
    │     → Identify mitigations and controls                                │
    │     → Prioritize based on risk                                         │
    ├─────────────────────────────────────────────────────────────────────────┤
    │  4. DID WE DO A GOOD JOB?                                              │
    │     → Validate the threat model                                        │
    │     → Update as architecture changes                                   │
    └─────────────────────────────────────────────────────────────────────────┘
```

## STRIDE Threat Categories

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                       STRIDE FRAMEWORK                                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  S - SPOOFING                       "Pretending to be someone else"             │
│  ═════════════                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  • Attacker uses stolen credentials                                    │   │
│  │  • Forged IAM role assumption                                          │   │
│  │  • Impersonating trusted service                                       │   │
│  │  Mitigation: Strong authentication, MFA                                │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  T - TAMPERING                      "Modifying data or code"                    │
│  ════════════════                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  • Modifying S3 objects                                                │   │
│  │  • Changing infrastructure via IaC                                     │   │
│  │  • Injecting malicious code in pipeline                                │   │
│  │  Mitigation: Integrity controls, versioning, signing                   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  R - REPUDIATION                    "Denying an action occurred"                │
│  ═══════════════════                                                            │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  • User denies making API call                                         │   │
│  │  • Claiming logs were tampered                                         │   │
│  │  • No audit trail for actions                                          │   │
│  │  Mitigation: Logging, audit trails, immutable records                  │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  I - INFORMATION DISCLOSURE         "Exposing sensitive data"                   │
│  ══════════════════════════════                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  • Public S3 buckets                                                   │   │
│  │  • Secrets in logs                                                     │   │
│  │  • SSRF to metadata service                                            │   │
│  │  Mitigation: Encryption, access controls, data classification          │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  D - DENIAL OF SERVICE              "Making system unavailable"                 │
│  ══════════════════════════                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  • Resource exhaustion                                                 │   │
│  │  • Deleting critical resources                                         │   │
│  │  • Disabling services                                                  │   │
│  │  Mitigation: Rate limiting, redundancy, backup/restore                 │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  E - ELEVATION OF PRIVILEGE         "Gaining unauthorized access"               │
│  ═══════════════════════════════                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  • Escalating from user to admin                                       │   │
│  │  • Assuming roles without authorization                                │   │
│  │  • Exploiting misconfigurations                                        │   │
│  │  Mitigation: Least privilege, boundary enforcement                     │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Example: Threat Modeling the VPC Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    SYSTEM UNDER ANALYSIS                                        │
└─────────────────────────────────────────────────────────────────────────────────┘

                              INTERNET
                                 │
                    ═════════════╪═════════════  TRUST BOUNDARY 1
                                 │
                         ┌───────▼───────┐
                         │      ALB      │
                         │  (Public SN)  │
                         └───────┬───────┘
                                 │
                    ═════════════╪═════════════  TRUST BOUNDARY 2
                                 │
                         ┌───────▼───────┐
                         │  App Server   │
                         │ (Private SN)  │
                         └───────┬───────┘
                                 │
                    ═════════════╪═════════════  TRUST BOUNDARY 3
                                 │
                         ┌───────▼───────┐
                         │   Database    │
                         │  (Data SN)    │
                         └───────────────┘


    DATA FLOW DIAGRAM:
    ═══════════════════

    ┌─────────┐     HTTPS      ┌─────────┐     HTTP      ┌─────────┐     SQL      ┌─────────┐
    │  User   │───────────────▶│   ALB   │──────────────▶│   App   │─────────────▶│   RDS   │
    └─────────┘                └─────────┘               └─────────┘              └─────────┘
         │                          │                         │                        │
         │                          │                         │                        │
    External                   Terminates              Business Logic           Sensitive Data
    Untrusted                  TLS                     App Secrets                   PII
```

## Threat Analysis

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    THREAT ANALYSIS TABLE                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  COMPONENT: ALB (Internet-Facing)                                               │
│  ════════════════════════════════                                               │
│                                                                                 │
│  ┌─────────┬──────────────────────────────┬─────────────────────────────────┐  │
│  │ STRIDE  │         THREAT               │           MITIGATION            │  │
│  ├─────────┼──────────────────────────────┼─────────────────────────────────┤  │
│  │    S    │ Attacker spoofs legitimate   │ TLS certificate validation      │  │
│  │         │ traffic to bypass WAF        │ AWS WAF with managed rules      │  │
│  ├─────────┼──────────────────────────────┼─────────────────────────────────┤  │
│  │    T    │ Attacker modifies requests   │ TLS in transit                  │  │
│  │         │ in transit                   │ Integrity headers               │  │
│  ├─────────┼──────────────────────────────┼─────────────────────────────────┤  │
│  │    R    │ Cannot prove attack origin   │ ALB access logs enabled         │  │
│  │         │                              │ Request ID tracking             │  │
│  ├─────────┼──────────────────────────────┼─────────────────────────────────┤  │
│  │    I    │ TLS downgrade attack         │ TLS 1.2+ only policy            │  │
│  │         │ Exposed internal headers     │ Strip internal headers          │  │
│  ├─────────┼──────────────────────────────┼─────────────────────────────────┤  │
│  │    D    │ DDoS attack overwhelms ALB   │ AWS Shield Standard             │  │
│  │         │                              │ Rate limiting rules             │  │
│  ├─────────┼──────────────────────────────┼─────────────────────────────────┤  │
│  │    E    │ Attacker gains AWS console   │ IAM least privilege             │  │
│  │         │ access to modify ALB         │ CloudTrail monitoring           │  │
│  └─────────┴──────────────────────────────┴─────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Attack Trees

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    ATTACK TREE: DATA EXFILTRATION                               │
└─────────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────┐
                    │     Exfiltrate Database Data    │
                    │          (GOAL)                 │
                    └───────────────┬─────────────────┘
                                    │
            ┌───────────────────────┼───────────────────────┐
            │                       │                       │
            ▼                       ▼                       ▼
    ┌───────────────┐       ┌───────────────┐       ┌───────────────┐
    │ Compromise    │       │ Exploit App   │       │ Insider       │
    │ App Server    │       │ Vulnerability │       │ Threat        │
    └───────┬───────┘       └───────┬───────┘       └───────┬───────┘
            │                       │                       │
    ┌───────┴───────┐       ┌───────┴───────┐               │
    │               │       │               │               │
    ▼               ▼       ▼               ▼               ▼
┌───────┐     ┌───────┐ ┌───────┐     ┌───────┐     ┌───────────────┐
│SSRF to│     │Stolen │ │ SQL   │     │  API  │     │ DB Admin      │
│IMDSv1 │     │ SSH   │ │Inject │     │ Abuse │     │ exports data  │
│       │     │ Key   │ │       │     │       │     │               │
└───┬───┘     └───┬───┘ └───┬───┘     └───┬───┘     └───────┬───────┘
    │             │         │             │                 │
    ▼             ▼         ▼             ▼                 ▼
 Control:      Control:   Control:     Control:         Control:
 IMDSv2        Key        Prepared     Input           Access
 Required      Rotation   Statements   Validation      Review


    RISK RATING:
    ═════════════
    ┌────────────────────┬───────────┬───────────────┬──────────────┐
    │ Attack Path        │ Likelihood│ Impact        │ Risk Level   │
    ├────────────────────┼───────────┼───────────────┼──────────────┤
    │ SSRF → IMDS        │ Medium    │ High          │ HIGH         │
    │ SSH Key Theft      │ Low       │ High          │ MEDIUM       │
    │ SQL Injection      │ Medium    │ Critical      │ CRITICAL     │
    │ API Abuse          │ Medium    │ Medium        │ MEDIUM       │
    │ Insider Threat     │ Low       │ Critical      │ HIGH         │
    └────────────────────┴───────────┴───────────────┴──────────────┘
```

## Threat Modeling the CI/CD Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    CI/CD PIPELINE THREATS                                       │
└─────────────────────────────────────────────────────────────────────────────────┘

                    PIPELINE COMPONENTS & TRUST BOUNDARIES
                    ══════════════════════════════════════

    ┌────────────────────────────────────────────────────────────────────────────┐
    │  DEVELOPER ENVIRONMENT                                                      │
    │  ┌─────────┐    ┌─────────┐                                                │
    │  │   IDE   │───▶│   Git   │                                                │
    │  └─────────┘    └────┬────┘                                                │
    └──────────────────────┼─────────────────────────────────────────────────────┘
                           │ Push
    ═══════════════════════╪═════════════════════════════════  TRUST BOUNDARY
                           ▼
    ┌────────────────────────────────────────────────────────────────────────────┐
    │  CI/CD PLATFORM (GitHub Actions)                                           │
    │  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐                 │
    │  │ Build   │───▶│  Test   │───▶│  Scan   │───▶│ Deploy  │                 │
    │  └─────────┘    └─────────┘    └─────────┘    └────┬────┘                 │
    └────────────────────────────────────────────────────┼───────────────────────┘
                                                         │ Deploy
    ═════════════════════════════════════════════════════╪═════  TRUST BOUNDARY
                                                         ▼
    ┌────────────────────────────────────────────────────────────────────────────┐
    │  AWS PRODUCTION                                                            │
    │  ┌─────────────┐                                                           │
    │  │ ECS/Lambda  │                                                           │
    │  └─────────────┘                                                           │
    └────────────────────────────────────────────────────────────────────────────┘


    THREAT ANALYSIS:
    ═════════════════

    ┌────────────────────────────────────────────────────────────────────────────┐
    │ #  │ Threat                          │ Attack Path              │ Control │
    ├────┼─────────────────────────────────┼──────────────────────────┼─────────┤
    │ T1 │ Malicious code injection        │ Compromised dependency   │ SCA     │
    │ T2 │ Secrets stolen from pipeline    │ Logs or env exposure     │ Vault   │
    │ T3 │ Unauthorized deployment         │ Stolen GitHub token      │ OIDC    │
    │ T4 │ Backdoored container image      │ Base image compromised   │ Scan    │
    │ T5 │ Pipeline configuration change   │ PR without review        │ CODEOWN │
    │ T6 │ Deploy to wrong environment     │ Misconfigured workflow   │ Env prot│
    └────────────────────────────────────────────────────────────────────────────┘
```

## Control Mapping

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    THREAT → CONTROL MAPPING                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  THREAT: SQL Injection leading to data breach                                   │
│  ═══════════════════════════════════════════                                    │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                           DEFENSE LAYERS                                │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                         │   │
│  │  PREVENT:                                                               │   │
│  │  ├── Input validation at API gateway                                   │   │
│  │  ├── Prepared statements in code (enforced via SAST)                   │   │
│  │  └── WAF SQL injection rules                                           │   │
│  │                                                                         │   │
│  │  DETECT:                                                                │   │
│  │  ├── WAF logging and alerting                                          │   │
│  │  ├── Database query logging (unusual patterns)                         │   │
│  │  └── Application error monitoring                                      │   │
│  │                                                                         │   │
│  │  RESPOND:                                                               │   │
│  │  ├── Automated WAF rule update                                         │   │
│  │  ├── Incident response runbook                                         │   │
│  │  └── Database access revocation capability                             │   │
│  │                                                                         │   │
│  │  RECOVER:                                                               │   │
│  │  ├── Database backup/restore procedure                                 │   │
│  │  ├── Audit log preservation                                            │   │
│  │  └── Breach notification process                                       │   │
│  │                                                                         │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  RESIDUAL RISK: Low                                                             │
│  RISK OWNER: Application Security Team                                          │
│  LAST REVIEWED: 2026-01-14                                                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
08-threat-modeling/
├── README.md
├── models/
│   ├── vpc-threat-model.md          # VPC architecture analysis
│   ├── cicd-threat-model.md         # Pipeline analysis
│   ├── iam-threat-model.md          # Cross-account access analysis
│   └── template.md                  # Blank template for new models
├── diagrams/
│   ├── vpc-data-flow.md             # Data flow diagrams
│   ├── attack-trees/                # Attack tree visualizations
│   └── trust-boundaries.md          # Trust boundary documentation
└── docs/
    ├── methodology.md               # How threat modeling is done
    ├── stride-reference.md          # STRIDE quick reference
    └── prioritization.md            # How to prioritize findings
```

## Threat Model Template

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    THREAT MODEL DOCUMENT TEMPLATE                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  1. SYSTEM OVERVIEW                                                             │
│     • What is being built?                                                      │
│     • What data does it handle?                                                 │
│     • Who are the users?                                                        │
│                                                                                 │
│  2. ARCHITECTURE DIAGRAM                                                        │
│     • Components                                                                │
│     • Data flows                                                                │
│     • Trust boundaries                                                          │
│                                                                                 │
│  3. THREAT ENUMERATION                                                          │
│     • STRIDE analysis per component                                             │
│     • Attack trees for critical assets                                          │
│                                                                                 │
│  4. RISK ASSESSMENT                                                             │
│     • Likelihood × Impact scoring                                               │
│     • Prioritized threat list                                                   │
│                                                                                 │
│  5. MITIGATIONS                                                                 │
│     • Existing controls                                                         │
│     • Recommended additional controls                                           │
│     • Residual risk acceptance                                                  │
│                                                                                 │
│  6. VALIDATION                                                                  │
│     • How will mitigations be tested?                                           │
│     • When will this model be reviewed?                                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Deliverables Checklist

- [ ] Architecture diagram with trust boundaries
- [ ] Data flow diagram
- [ ] STRIDE analysis for each component
- [ ] Attack tree for critical scenarios
- [ ] Threat → Control mapping
- [ ] Risk prioritization matrix
- [ ] Residual risk documentation
- [ ] Review schedule

## Questions to Answer in Your Documentation

1. **What are the most valuable assets in this system?**
2. **Who are the likely threat actors?**
3. **What are the most likely attack paths?**
4. **Where are the weakest points?**
5. **What controls reduce risk to acceptable levels?**
6. **What residual risks are we accepting?**

## Further Reading

- [OWASP Threat Modeling](https://owasp.org/www-community/Threat_Modeling)
- [Microsoft Threat Modeling Tool](https://docs.microsoft.com/en-us/azure/security/develop/threat-modeling-tool)
- [STRIDE per Element](https://docs.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [Attack Trees - Bruce Schneier](https://www.schneier.com/academic/archives/1999/12/attack_trees.html)

---

**Remember:** Very few candidates demonstrate this mindset, yet this is exactly how senior security engineers think. You're showing structured thinking about what could go wrong, how an attacker would move, and where your weakest points are.
