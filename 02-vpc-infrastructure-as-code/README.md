# Project 2: Building a VPC Using Infrastructure as Code

## Overview

Infrastructure as Code is not optional anymore. If your cloud security project involves clicking around the console, it already looks outdated. This project demonstrates how to design and implement a production-grade VPC using Terraform, with security as a first-class concern.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AWS REGION (us-east-1)                             │
│                                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                           VPC (10.0.0.0/16)                               │  │
│  │                                                                           │  │
│  │   ┌─────────────────────────────────────────────────────────────────┐     │  │
│  │   │                    AVAILABILITY ZONE A                          │     │  │
│  │   │  ┌─────────────────────┐      ┌─────────────────────┐          │     │  │
│  │   │  │   PUBLIC SUBNET     │      │   PRIVATE SUBNET    │          │     │  │
│  │   │  │   10.0.1.0/24       │      │   10.0.10.0/24      │          │     │  │
│  │   │  │                     │      │                     │          │     │  │
│  │   │  │  ┌───────────────┐  │      │  ┌───────────────┐  │          │     │  │
│  │   │  │  │  NAT Gateway  │──┼──────┼─▶│  App Servers  │  │          │     │  │
│  │   │  │  └───────────────┘  │      │  └───────────────┘  │          │     │  │
│  │   │  │  ┌───────────────┐  │      │  ┌───────────────┐  │          │     │  │
│  │   │  │  │  Bastion/ALB  │  │      │  │   Databases   │  │          │     │  │
│  │   │  │  └───────────────┘  │      │  └───────────────┘  │          │     │  │
│  │   │  └─────────────────────┘      └─────────────────────┘          │     │  │
│  │   └─────────────────────────────────────────────────────────────────┘     │  │
│  │                                                                           │  │
│  │   ┌─────────────────────────────────────────────────────────────────┐     │  │
│  │   │                    AVAILABILITY ZONE B                          │     │  │
│  │   │  ┌─────────────────────┐      ┌─────────────────────┐          │     │  │
│  │   │  │   PUBLIC SUBNET     │      │   PRIVATE SUBNET    │          │     │  │
│  │   │  │   10.0.2.0/24       │      │   10.0.20.0/24      │          │     │  │
│  │   │  │                     │      │                     │          │     │  │
│  │   │  │  ┌───────────────┐  │      │  ┌───────────────┐  │          │     │  │
│  │   │  │  │  NAT Gateway  │──┼──────┼─▶│  App Servers  │  │          │     │  │
│  │   │  │  └───────────────┘  │      │  └───────────────┘  │          │     │  │
│  │   │  └─────────────────────┘      └─────────────────────┘          │     │  │
│  │   └─────────────────────────────────────────────────────────────────┘     │  │
│  │                                                                           │  │
│  │   ┌─────────────────────────────────────────────────────────────────┐     │  │
│  │   │                      DATA SUBNET TIER                           │     │  │
│  │   │  ┌─────────────────────┐      ┌─────────────────────┐          │     │  │
│  │   │  │   DATA SUBNET A     │      │   DATA SUBNET B     │          │     │  │
│  │   │  │   10.0.100.0/24     │      │   10.0.200.0/24     │          │     │  │
│  │   │  │   (No NAT access)   │      │   (No NAT access)   │          │     │  │
│  │   │  └─────────────────────┘      └─────────────────────┘          │     │  │
│  │   └─────────────────────────────────────────────────────────────────┘     │  │
│  │                                                                           │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
│       ┌─────────────┐                                                          │
│       │   Internet  │                                                          │
│       │   Gateway   │◀──── Public internet access                              │
│       └─────────────┘                                                          │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           NETWORK TRAFFIC FLOWS                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

INBOUND (User Request):
═══════════════════════

    Internet
       │
       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Internet   │────▶│     ALB      │────▶│  App Server  │────▶│   Database   │
│   Gateway    │     │  (Public)    │     │  (Private)   │     │    (Data)    │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                           │                    │                     │
                           ▼                    ▼                     ▼
                     SG: 443 only         SG: ALB only          SG: App only
                     from internet        on port 8080          on port 5432


OUTBOUND (Server Updates):
══════════════════════════

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  App Server  │────▶│ NAT Gateway  │────▶│   Internet   │
│  (Private)   │     │  (Public)    │     │   Gateway    │──────▶ Internet
└──────────────┘     └──────────────┘     └──────────────┘

    Route table:                Route table:
    0.0.0.0/0 → NAT             0.0.0.0/0 → IGW


DATA TIER (Isolated):
═════════════════════

┌──────────────┐     ┌──────────────┐
│   Database   │  ✗  │   Internet   │    NO outbound internet access
│   (Data)     │─────│              │    Must use VPC endpoints for
└──────────────┘     └──────────────┘    AWS service access
```

## Security Layers

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        DEFENSE IN DEPTH LAYERS                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

     LAYER 1: Network ACLs (Subnet Level - Stateless)
     ═════════════════════════════════════════════════
     ┌─────────────────────────────────────────────────────────────────┐
     │  NACL: Default deny + explicit allows                          │
     │  • Inbound: Allow 443 from 0.0.0.0/0 to public subnets        │
     │  • Inbound: Allow ephemeral ports for return traffic           │
     │  • Outbound: Allow all to 0.0.0.0/0 (stateless, need return)  │
     └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
     LAYER 2: Security Groups (Instance Level - Stateful)
     ═════════════════════════════════════════════════════
     ┌─────────────────────────────────────────────────────────────────┐
     │  SG: Reference other SGs, not CIDR blocks                      │
     │                                                                 │
     │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
     │  │   ALB-SG    │───▶│   App-SG    │───▶│   DB-SG     │         │
     │  │ In: 443/any │    │ In: 8080    │    │ In: 5432    │         │
     │  │             │    │    from     │    │    from     │         │
     │  │             │    │   ALB-SG    │    │   App-SG    │         │
     │  └─────────────┘    └─────────────┘    └─────────────┘         │
     └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
     LAYER 3: Host-Based Controls (OS Level)
     ═════════════════════════════════════════
     ┌─────────────────────────────────────────────────────────────────┐
     │  • iptables/nftables on Linux                                  │
     │  • Application-level authentication                            │
     │  • TLS everywhere                                              │
     └─────────────────────────────────────────────────────────────────┘
```

## What You'll Build

### Subnet Design

| Subnet Type | CIDR Range | Internet Access | Purpose |
|-------------|------------|-----------------|---------|
| Public A | 10.0.1.0/24 | Direct (IGW) | ALB, NAT Gateway, Bastion |
| Public B | 10.0.2.0/24 | Direct (IGW) | ALB, NAT Gateway (HA) |
| Private A | 10.0.10.0/24 | Outbound only (NAT) | Application servers |
| Private B | 10.0.20.0/24 | Outbound only (NAT) | Application servers |
| Data A | 10.0.100.0/24 | None | Databases, sensitive data |
| Data B | 10.0.200.0/24 | None | Databases, sensitive data |

### Route Tables

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            ROUTE TABLE DESIGN                                   │
└─────────────────────────────────────────────────────────────────────────────────┘

PUBLIC ROUTE TABLE:                    PRIVATE ROUTE TABLE:
══════════════════                     ═══════════════════
┌────────────────────────────┐         ┌────────────────────────────┐
│ Destination │    Target    │         │ Destination │    Target    │
├─────────────┼──────────────┤         ├─────────────┼──────────────┤
│ 10.0.0.0/16 │    local     │         │ 10.0.0.0/16 │    local     │
│ 0.0.0.0/0   │    igw-xxx   │         │ 0.0.0.0/0   │   nat-xxx    │
└────────────────────────────┘         └────────────────────────────┘
      │                                       │
      │ Internet access                       │ Updates, external APIs
      ▼                                       ▼

DATA ROUTE TABLE:
═════════════════
┌────────────────────────────┐
│ Destination │    Target    │
├─────────────┼──────────────┤
│ 10.0.0.0/16 │    local     │
│             │ (NO DEFAULT) │◄── No internet route!
└────────────────────────────┘
      │
      │ VPC Endpoints for AWS services
      ▼
```

## Security Groups vs NACLs

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    SECURITY GROUPS vs NETWORK ACLs                              │
├────────────────────────────────────┬────────────────────────────────────────────┤
│         SECURITY GROUPS            │              NETWORK ACLs                  │
├────────────────────────────────────┼────────────────────────────────────────────┤
│ • Instance/ENI level               │ • Subnet level                             │
│ • Stateful (return auto-allowed)   │ • Stateless (explicit return rules)       │
│ • Allow rules only                 │ • Allow AND deny rules                     │
│ • Evaluated as a whole             │ • Evaluated in order (rule numbers)       │
│ • Can reference other SGs          │ • CIDR blocks only                         │
├────────────────────────────────────┼────────────────────────────────────────────┤
│                                    │                                            │
│  USE FOR:                          │  USE FOR:                                  │
│  • Fine-grained app access         │  • Subnet-wide blocks                      │
│  • Dynamic references              │  • Explicit denies                         │
│  • Most access control             │  • Compliance requirements                 │
│                                    │  • Emergency blocks                        │
│                                    │                                            │
└────────────────────────────────────┴────────────────────────────────────────────┘
```

## Implementation with Terraform

### Project Structure

```
02-vpc-infrastructure-as-code/
├── README.md
├── terraform/
│   ├── main.tf              # Provider and backend config
│   ├── vpc.tf               # VPC and subnets
│   ├── routing.tf           # Route tables and associations
│   ├── security_groups.tf   # Security group definitions
│   ├── nacls.tf             # Network ACL rules
│   ├── nat.tf               # NAT Gateway configuration
│   ├── endpoints.tf         # VPC Endpoints for AWS services
│   ├── flow_logs.tf         # VPC Flow Logs configuration
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values
│   └── terraform.tfvars     # Variable values
└── docs/
    ├── architecture.md      # Detailed architecture explanation
    └── security-decisions.md # Why each decision was made
```

### VPC Flow Logs (Critical for Visibility)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           VPC FLOW LOGS ARCHITECTURE                            │
└─────────────────────────────────────────────────────────────────────────────────┘

     ┌─────────────┐
     │    VPC      │
     │  (Source)   │
     └──────┬──────┘
            │
            │ All traffic metadata
            ▼
     ┌─────────────┐         ┌─────────────┐         ┌─────────────┐
     │  Flow Logs  │────────▶│ CloudWatch  │────────▶│   Alerts    │
     │             │         │    Logs     │         │  (Anomaly)  │
     └─────────────┘         └─────────────┘         └─────────────┘
            │
            │ Long-term storage
            ▼
     ┌─────────────┐         ┌─────────────┐
     │     S3      │────────▶│   Athena    │
     │  (Archive)  │         │  (Analysis) │
     └─────────────┘         └─────────────┘

Log Format:
───────────
<version> <account-id> <interface-id> <srcaddr> <dstaddr>
<srcport> <dstport> <protocol> <packets> <bytes> <start>
<end> <action> <log-status>
```

## Key Questions to Address

### Why are certain resources in private subnets?

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        ATTACK SURFACE COMPARISON                                │
├────────────────────────────────────┬────────────────────────────────────────────┤
│    PUBLIC SUBNET RESOURCE          │    PRIVATE SUBNET RESOURCE                 │
├────────────────────────────────────┼────────────────────────────────────────────┤
│                                    │                                            │
│  Internet ────▶ Resource           │  Internet ───X──▶ Resource                 │
│                                    │        │                                   │
│  • Directly reachable              │        └───▶ ALB ────▶ Resource            │
│  • Can be port scanned             │                                            │
│  • Subject to DDoS                 │  • Not directly reachable                  │
│  • Needs constant patching         │  • Hidden from scanners                    │
│  • Any vuln = direct access        │  • ALB provides protection                 │
│                                    │  • Vuln requires pivot                     │
│                                    │                                            │
└────────────────────────────────────┴────────────────────────────────────────────┘
```

### Where would inspection live?

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    TRAFFIC INSPECTION OPTIONS                                   │
└─────────────────────────────────────────────────────────────────────────────────┘

OPTION 1: Gateway Load Balancer (Inline)
────────────────────────────────────────
    Internet ───▶ IGW ───▶ GWLB ───▶ Firewall ───▶ ALB ───▶ App
                             │
                             └── All traffic inspected

OPTION 2: VPC Traffic Mirroring (Passive)
─────────────────────────────────────────
    Internet ───▶ IGW ───▶ ALB ───▶ App
                             │
                             └── Copy to ───▶ IDS/Analysis

OPTION 3: AWS Network Firewall
──────────────────────────────
    Internet ───▶ IGW ───▶ Firewall Subnet ───▶ Protected Subnets
                                   │
                                   └── Stateful inspection
                                       Domain filtering
                                       IPS rules
```

## Deliverables Checklist

- [ ] Terraform code for complete VPC setup
- [ ] Public, private, and data subnet tiers
- [ ] NAT Gateway for private subnet outbound access
- [ ] Security groups with least-privilege rules
- [ ] Network ACLs for subnet-level controls
- [ ] VPC Flow Logs to CloudWatch and S3
- [ ] VPC Endpoints for common AWS services
- [ ] Architecture diagram with data flows
- [ ] Security decision documentation

## Questions to Answer in Your Documentation

1. **Why are certain resources in private subnets?**
2. **What traffic is allowed in and out?**
3. **How do security groups and NACLs complement each other?**
4. **Where would inspection or logging live in a real environment?**
5. **How does this design reduce attack surface?**
6. **How does it support future growth?**

## Common Mistakes to Avoid

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           COMMON VPC MISTAKES                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ✗ Opening 0.0.0.0/0 on security groups                                        │
│    └── Fix: Use specific CIDRs or SG references                                │
│                                                                                 │
│  ✗ Using /16 subnets (wastes IP space)                                         │
│    └── Fix: Use /24 for most subnets, plan for growth                          │
│                                                                                 │
│  ✗ Single AZ deployment                                                        │
│    └── Fix: Always deploy across at least 2 AZs                                │
│                                                                                 │
│  ✗ No VPC Flow Logs                                                            │
│    └── Fix: Enable flow logs to CloudWatch AND S3                              │
│                                                                                 │
│  ✗ Database in public subnet                                                   │
│    └── Fix: Data tier should have NO internet access                           │
│                                                                                 │
│  ✗ Hardcoded IPs in security groups                                            │
│    └── Fix: Use variables and SG references where possible                     │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Further Reading

- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [AWS Network Firewall](https://docs.aws.amazon.com/network-firewall/latest/developerguide/what-is-aws-network-firewall.html)

---

**Remember:** Security teams spend a huge amount of time reviewing architectures like this. Showing that you can think at this level immediately elevates your profile.
