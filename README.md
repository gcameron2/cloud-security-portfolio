# Cloud Security Portfolio

A collection of production-grade cloud security projects designed to demonstrate real-world expertise. These projects go beyond tutorials to showcase the thinking, trade-offs, and decision-making that define professional cloud security work.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CLOUD SECURITY PORTFOLIO                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│   │   Identity  │  │   Network   │  │   DevSecOps │  │  Compliance │       │
│   │     & AM    │  │   Security  │  │             │  │   & Audit   │       │
│   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘       │
│          │                │                │                │              │
│          ▼                ▼                ▼                ▼              │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│   │  Project 1  │  │  Project 2  │  │  Project 3  │  │  Project 4  │       │
│   │ Cross-Acct  │  │  VPC + IaC  │  │   CI/CD     │  │   Prowler   │       │
│   │    IAM      │  │             │  │  Security   │  │    Audit    │       │
│   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                             │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│   │  Visibility │  │ Operations  │  │   Secrets   │  │   Threat    │       │
│   │  & Logging  │  │ & Recovery  │  │   Hygiene   │  │  Modeling   │       │
│   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘       │
│          │                │                │                │              │
│          ▼                ▼                ▼                ▼              │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│   │  Project 5  │  │  Project 6  │  │  Project 7  │  │  Project 8  │       │
│   │ Centralized │  │ Break-Glass │  │  Secrets    │  │   Threat    │       │
│   │   Logging   │  │   Access    │  │ Management  │  │   Models    │       │
│   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Why These Projects Matter

The cloud security market has matured. Employers are no longer impressed by tool lists or certifications alone. They want evidence that you understand **real systems**, **real risks**, and **real trade-offs**.

These projects work because they mirror how cloud security is practiced in the real world:
- They show you can think beyond tutorials
- They demonstrate understanding of scale and complexity
- They prove you can communicate reasoning clearly

> **If you do just one or two projects at this depth, they will carry more weight than ten shallow labs.**

## Projects Overview

| # | Project | Domain | Key Skills Demonstrated |
|---|---------|--------|------------------------|
| 1 | [IAM Cross-Account Access](./01-iam-cross-account-access/) | Identity | Multi-account architecture, least privilege, role assumption |
| 2 | [VPC Infrastructure as Code](./02-vpc-infrastructure-as-code/) | Network | Terraform, network segmentation, security groups |
| 3 | [CI/CD Security Pipeline](./03-cicd-security-pipeline/) | DevSecOps | Shift-left security, policy as code, automation |
| 4 | [Cloud Security Audit](./04-cloud-security-audit/) | Compliance | Prowler, risk prioritization, remediation planning |
| 5 | [Centralized Logging](./05-centralized-logging/) | Visibility | Log architecture, immutability, incident response |
| 6 | [Break-Glass Access](./06-break-glass-access/) | Operations | Emergency procedures, governance, audit trails |
| 7 | [Secrets Management](./07-secrets-management/) | Credential Hygiene | Vault patterns, rotation, blast radius reduction |
| 8 | [Threat Modeling](./08-threat-modeling/) | Risk Analysis | STRIDE, attack paths, control mapping |

## How to Use This Repository

### For Learning
1. Start with projects that align with your current skill level
2. Read through the documentation before implementing
3. Focus on understanding the "why" behind each decision
4. Document your own thinking as you build

### For Portfolio Building
1. Fork this repository
2. Implement each project in your own AWS/cloud environment
3. Add your own documentation explaining your decisions
4. Record a Loom walkthrough explaining your work

### For Interview Preparation
1. Be ready to explain trade-offs in each design
2. Understand how each project would scale
3. Know the security implications of alternative approaches
4. Practice explaining complex concepts simply

## Repository Structure

```
cloud-security-portfolio/
├── README.md                          # This file
├── 01-iam-cross-account-access/
│   ├── README.md                      # Project documentation
│   ├── terraform/                     # Infrastructure code
│   └── docs/                          # Additional documentation
├── 02-vpc-infrastructure-as-code/
│   ├── README.md
│   ├── terraform/
│   └── docs/
├── 03-cicd-security-pipeline/
│   ├── README.md
│   ├── .github/workflows/             # Pipeline configurations
│   └── policies/                      # Security policies
├── 04-cloud-security-audit/
│   ├── README.md
│   ├── reports/                       # Sample audit outputs
│   └── remediation/                   # Remediation guides
├── 05-centralized-logging/
│   ├── README.md
│   ├── terraform/
│   └── docs/
├── 06-break-glass-access/
│   ├── README.md
│   ├── terraform/
│   └── runbooks/                      # Operational procedures
├── 07-secrets-management/
│   ├── README.md
│   ├── examples/                      # Good vs bad patterns
│   └── terraform/
└── 08-threat-modeling/
    ├── README.md
    ├── models/                        # Threat model documents
    └── diagrams/                      # Architecture diagrams
```

## Presenting Your Work

### GitHub Best Practices
- Write clear commit messages explaining your reasoning
- Use pull requests even for personal projects to show workflow
- Include relevant badges (Terraform validated, security scanned, etc.)

### Video Walkthroughs
Record a short Loom video where you:
- Explain the scenario you're emulating
- Walk through your key decisions
- Discuss what you'd do differently in a real enterprise
- Demonstrate the working implementation

> This is incredibly powerful. You're no longer just a CV on a screen. You're demonstrating how you think, how you communicate, and how you reason about security under realistic constraints.

## Prerequisites

- AWS Account (free tier works for most projects)
- Terraform >= 1.0
- AWS CLI configured
- Basic understanding of cloud concepts
- Git for version control

## Contributing

Found an improvement? Have a suggestion? Contributions are welcome!

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with clear description

## License

MIT License - Feel free to use these projects for learning and portfolio building.

---

**Remember:** You are not trying to prove that you can follow instructions. You are proving that you can operate as a cloud security professional. That is what makes a profile stand out.
