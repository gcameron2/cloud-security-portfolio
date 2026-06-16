# Project 3: CI/CD Pipelines With Security Built In

## Overview

Modern cloud security lives inside pipelines, not after deployment. This project demonstrates how to build a CI/CD pipeline that embeds security checks early in the development process—catching issues before they reach production.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         SECURE CI/CD PIPELINE                                   │
└─────────────────────────────────────────────────────────────────────────────────┘

 Developer                                                              Production
    │                                                                       │
    ▼                                                                       │
┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐│
│  Code  │──▶│  Build │──▶│Security│──▶│  Test  │──▶│ Deploy │──▶│  Prod  ││
│ Commit │   │        │   │ Checks │   │        │   │Staging │   │        ││
└────────┘   └────────┘   └────────┘   └────────┘   └────────┘   └────────┘│
    │            │            │            │            │            │      │
    │            │            │            │            │            │      │
    ▼            ▼            ▼            ▼            ▼            ▼      │
┌────────────────────────────────────────────────────────────────────────────┐
│                        SECURITY GATES AT EACH STAGE                       │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Pre-Commit    Build         Security       Test          Deploy    Prod  │
│  ──────────    ─────         ────────       ────          ──────    ────  │
│  • Secrets     • SAST        • IaC Scan     • DAST        • Approval • WAF│
│    scanning    • Dep scan    • Policy       • Pen test    • Canary   • IDS│
│  • Linting     • Container   • Compliance   • Fuzzing     • Rollback │    │
│  • Hooks         scan        • Threat                                │    │
│                                model                                 │    │
│                                                                      │    │
└──────────────────────────────────────────────────────────────────────┴────┘
```

## Shift-Left Security Model

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      COST OF FIXING SECURITY ISSUES                             │
└─────────────────────────────────────────────────────────────────────────────────┘

                                                                           ┌───┐
                                                                           │   │
                                                                     ┌───┐ │   │
                                                               ┌───┐ │   │ │   │
                                                         ┌───┐ │   │ │   │ │   │
  Cost to                                          ┌───┐ │   │ │   │ │   │ │   │
   Fix ($)                                   ┌───┐ │   │ │   │ │   │ │   │ │   │
                                       ┌───┐ │   │ │   │ │   │ │   │ │   │ │   │
                                 ┌───┐ │   │ │   │ │   │ │   │ │   │ │   │ │   │
                           ┌───┐ │   │ │   │ │   │ │   │ │   │ │   │ │   │ │   │
                     ┌───┐ │   │ │   │ │   │ │   │ │   │ │   │ │   │ │   │ │   │
    ─────────────────┴───┴─┴───┴─┴───┴─┴───┴─┴───┴─┴───┴─┴───┴─┴───┴─┴───┴─┴───┴────▶
                     Code   Build  Test  Deploy  Staging  Prod  Incident  Breach
                    ◀───────────────────────────────────────────────────────────▶
                              Time in Development Lifecycle

    ═══════════════════════════════════════════════════════════════════════════
    │                                                                         │
    │   Catching issues HERE (left)         vs    HERE (right)                │
    │   $100 to fix                               $1,000,000+ to fix          │
    │                                                                         │
    ═══════════════════════════════════════════════════════════════════════════
```

## What You'll Build

### Security Checks to Implement

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          SECURITY CHECK TYPES                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  1. SECRET SCANNING                                                             │
│     ┌─────────────────────────────────────────────────────────────────────┐    │
│     │  Tool: git-secrets, truffleHog, Gitleaks                            │    │
│     │  When: Pre-commit hook + CI                                         │    │
│     │  Block: Yes - never allow secrets in repo                           │    │
│     └─────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  2. STATIC ANALYSIS (SAST)                                                      │
│     ┌─────────────────────────────────────────────────────────────────────┐    │
│     │  Tool: Semgrep, SonarQube, CodeQL                                   │    │
│     │  When: On every PR                                                  │    │
│     │  Block: High/Critical findings                                      │    │
│     └─────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  3. DEPENDENCY SCANNING                                                         │
│     ┌─────────────────────────────────────────────────────────────────────┐    │
│     │  Tool: Dependabot, Snyk, OWASP Dependency-Check                     │    │
│     │  When: On every build + scheduled                                   │    │
│     │  Block: Critical CVEs with exploit available                        │    │
│     └─────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  4. INFRASTRUCTURE AS CODE SCANNING                                             │
│     ┌─────────────────────────────────────────────────────────────────────┐    │
│     │  Tool: Checkov, tfsec, Terrascan                                    │    │
│     │  When: On PR for infrastructure changes                             │    │
│     │  Block: S3 public, security group 0.0.0.0/0, etc.                   │    │
│     └─────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│  5. CONTAINER SCANNING                                                          │
│     ┌─────────────────────────────────────────────────────────────────────┐    │
│     │  Tool: Trivy, Clair, AWS ECR scanning                               │    │
│     │  When: On image build                                               │    │
│     │  Block: Critical OS vulnerabilities, root user                      │    │
│     └─────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         GITHUB ACTIONS PIPELINE FLOW                            │
└─────────────────────────────────────────────────────────────────────────────────┘

                    ┌──────────────────────────────────────┐
                    │         on: [push, pull_request]     │
                    └──────────────────┬───────────────────┘
                                       │
                    ┌──────────────────▼───────────────────┐
                    │         JOB: Security Scan           │
                    ├──────────────────────────────────────┤
                    │  ┌────────────────────────────────┐  │
                    │  │ Step 1: Checkout code          │  │
                    │  └────────────────────────────────┘  │
                    │  ┌────────────────────────────────┐  │
                    │  │ Step 2: Secret scanning        │──┼──▶ FAIL = Block PR
                    │  └────────────────────────────────┘  │
                    │  ┌────────────────────────────────┐  │
                    │  │ Step 3: SAST (Semgrep)         │──┼──▶ High = Block PR
                    │  └────────────────────────────────┘  │
                    │  ┌────────────────────────────────┐  │
                    │  │ Step 4: Dependency scan        │──┼──▶ Critical = Block
                    │  └────────────────────────────────┘  │
                    │  ┌────────────────────────────────┐  │
                    │  │ Step 5: IaC scan (Checkov)     │──┼──▶ Failed checks
                    │  └────────────────────────────────┘  │       = Block PR
                    └──────────────────┬───────────────────┘
                                       │
                    ┌──────────────────▼───────────────────┐
                    │    All Checks Pass?                  │
                    └──────────────────┬───────────────────┘
                              ┌────────┴────────┐
                              │                 │
                         ┌────▼────┐       ┌────▼────┐
                         │   YES   │       │   NO    │
                         └────┬────┘       └────┬────┘
                              │                 │
                    ┌─────────▼─────────┐  ┌────▼─────────────────┐
                    │ Continue to       │  │ Block merge         │
                    │ Build & Deploy    │  │ Show findings in PR │
                    └───────────────────┘  └──────────────────────┘
```

## Block vs Warn Decision Matrix

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    WHEN TO BLOCK vs WARN                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│                        BLOCK (Pipeline Fails)                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  • Secrets in code (API keys, passwords, tokens)                        │   │
│  │  • SQL injection vulnerabilities                                        │   │
│  │  • Command injection vulnerabilities                                    │   │
│  │  • S3 bucket public access                                              │   │
│  │  • Security group open to 0.0.0.0/0 on sensitive ports                  │   │
│  │  • Critical CVE with known exploit                                      │   │
│  │  • Container running as root with sensitive mounts                      │   │
│  │  • Missing encryption on data stores                                    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│                        WARN (Let Pipeline Continue)                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  • Medium-severity dependency vulnerabilities                           │   │
│  │  • Code quality issues (complexity, duplication)                        │   │
│  │  • Missing security headers (can be added at ALB/CDN)                   │   │
│  │  • Informational findings                                               │   │
│  │  • Known false positives (with documented exception)                    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│                        CONTEXT MATTERS                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  • Internal tool vs customer-facing: different thresholds               │   │
│  │  • Regulated industry: stricter controls                                │   │
│  │  • Emergency fix: may need exception process                            │   │
│  │  • New repo vs established: different baseline expectations             │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
03-cicd-security-pipeline/
├── README.md
├── .github/
│   └── workflows/
│       ├── security-scan.yml       # Main security scanning workflow
│       ├── terraform-check.yml     # IaC-specific checks
│       └── container-scan.yml      # Container image scanning
├── policies/
│   ├── semgrep-rules/              # Custom SAST rules
│   ├── checkov-config/             # IaC policy configuration
│   └── exceptions/                 # Documented false positive exceptions
├── scripts/
│   ├── pre-commit-hook.sh          # Local pre-commit security checks
│   └── scan-results-parser.sh      # Parse and format scan results
└── docs/
    ├── adding-exceptions.md        # How to add security exceptions
    ├── tool-configuration.md       # How each tool is configured
    └── escalation-process.md       # What to do when blocked
```

## Trade-off Discussions

### What happens if a security check is too strict?

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    STRICTNESS TRADE-OFF ANALYSIS                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  TOO STRICT                              TOO LENIENT                            │
│  ══════════                              ════════════                           │
│                                                                                 │
│  ┌────────────────────────┐              ┌────────────────────────┐             │
│  │ • Developers bypass    │              │ • Real vulnerabilities │             │
│  │   the process          │              │   reach production     │             │
│  │ • False positives      │              │ • Security debt grows  │             │
│  │   cause alert fatigue  │              │ • Trust in tools       │             │
│  │ • Productivity drops   │              │   diminishes           │             │
│  │ • Security becomes     │              │ • Incidents more       │             │
│  │   "the enemy"          │              │   likely               │             │
│  └────────────────────────┘              └────────────────────────┘             │
│                                                                                 │
│                          BALANCED APPROACH                                      │
│                          ═════════════════                                      │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │  1. Start with high-confidence rules only                                │  │
│  │  2. Track false positive rate - if > 10%, tune the rule                  │  │
│  │  3. Make exceptions easy to request (but require justification)          │  │
│  │  4. Review exceptions quarterly                                          │  │
│  │  5. Gradually increase coverage as developers trust the system           │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Regulated Environment Considerations

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    COMPLIANCE REQUIREMENTS BY INDUSTRY                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  FINANCE (PCI-DSS)                HEALTHCARE (HIPAA)                            │
│  ─────────────────                ──────────────────                            │
│  • Code review required           • Audit logging mandatory                     │
│  • Vulnerability scan             • Access control review                       │
│    before deployment              • Encryption verification                     │
│  • Change management              • PHI data handling checks                    │
│    approval                                                                     │
│                                                                                 │
│  GOVERNMENT (FedRAMP)             GENERAL (SOC 2)                               │
│  ────────────────────             ───────────────                               │
│  • Approved tool list             • Change management                           │
│  • Continuous monitoring          • Evidence of security                        │
│  • Boundary protection              testing                                     │
│  • Supply chain controls          • Vulnerability management                    │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════  │
│  │  In regulated environments:                                               │  │
│  │  • Every exception needs documented justification                         │  │
│  │  • Audit trails are mandatory                                             │  │
│  │  • Time-bound exceptions only                                             │  │
│  │  • Regular compliance reporting from pipeline                             │  │
│  ════════════════════════════════════════════════════════════════════════════  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Deliverables Checklist

- [ ] GitHub Actions workflow for security scanning
- [ ] Secret scanning with pre-commit hooks
- [ ] SAST integration (Semgrep or similar)
- [ ] Dependency scanning configuration
- [ ] IaC scanning for Terraform (Checkov)
- [ ] Container scanning for Docker images
- [ ] Exception/override process documentation
- [ ] Block vs warn threshold documentation
- [ ] Sample PR showing blocked deployment

## Questions to Answer in Your Documentation

1. **What checks are included in your pipeline?**
2. **When should a pipeline block vs warn?**
3. **What happens if a security check is too strict?**
4. **How would you handle false positives?**
5. **How would this change in a regulated environment?**
6. **How do you balance security with developer productivity?**

## The Developer Experience Matters

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    DEVELOPER-FRIENDLY SECURITY                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  WHAT DEVELOPERS HATE:              WHAT DEVELOPERS APPRECIATE:                 │
│  ─────────────────────              ────────────────────────────                │
│                                                                                 │
│  ✗ Vague error messages             ✓ Clear, actionable findings                │
│    "Security check failed"            "Line 42: SQL injection - use            │
│                                        parameterized query instead"            │
│                                                                                 │
│  ✗ False positives                  ✓ High signal-to-noise ratio               │
│    with no way to override            with easy exception process              │
│                                                                                 │
│  ✗ Slow feedback loop               ✓ Results in < 5 minutes                   │
│    (hour-long scans)                                                           │
│                                                                                 │
│  ✗ Security as gatekeeper           ✓ Security as enabler                      │
│    "You can't deploy"                 "Here's how to fix it"                   │
│                                                                                 │
│  ✗ No context                       ✓ Links to remediation docs                │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Further Reading

- [GitHub Advanced Security](https://docs.github.com/en/code-security)
- [Semgrep Rules Registry](https://semgrep.dev/r)
- [Checkov Policies](https://www.checkov.io/5.Policy%20Index/all.html)
- [OWASP DevSecOps Guidelines](https://owasp.org/www-project-devsecops-guideline/)

---

**Remember:** The important part is not the tool you use, but the mindset you demonstrate. You are showing that security is something engineers encounter early, automatically, and repeatedly.
