# High Findings — Remediation This Sprint

**Account:** 092645363677
**Target:** Resolve within 2 weeks of audit date (by July 2, 2026)

---

## FINDING-003: Stop Using Root for Day-to-Day Operations

**Current State:** Root account was used 1 day ago to run a security audit.
**Target State:** Root account is only used for root-only tasks (< once per quarter).

### Why Root Should Stay Locked Away

Root bypasses every IAM control. You cannot:
- Restrict root with an SCP
- Require MFA via an IAM policy condition
- Audit root's actions differently from any other admin
- Scope root to specific services or regions

Any mistake made as root — or any compromise during a root session — has unlimited blast radius.

### Step 1: Create a Dedicated Admin IAM User

```bash
# Create an admin IAM user for day-to-day work
aws iam create-user --user-name gcam4-admin

# Attach AdministratorAccess policy
aws iam attach-user-policy \
  --user-name gcam4-admin \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create console password
aws iam create-login-profile \
  --user-name gcam4-admin \
  --password "ChangeMe123!@#" \
  --password-reset-required

# Create access keys for CLI use
aws iam create-access-key --user-name gcam4-admin
```

### Step 2: Enable MFA on the New IAM User
1. Log into console as the new IAM user
2. IAM → Users → gcam4-admin → Security credentials → Assign MFA device
3. Set up virtual or hardware MFA

### Step 3: Create a ProwlerAuditRole for Security Scans

```bash
# Create the role with a trust policy for the admin user
cat > prowler-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::092645363677:user/gcam4-admin"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name ProwlerAuditRole \
  --assume-role-policy-document file://prowler-trust-policy.json

# Attach read-only audit policies
aws iam attach-role-policy \
  --role-name ProwlerAuditRole \
  --policy-arn arn:aws:iam::aws:policy/SecurityAudit

aws iam attach-role-policy \
  --role-name ProwlerAuditRole \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
```

### Step 4: Run Future Prowler Scans via the Audit Role

```bash
prowler aws --role arn:aws:iam::092645363677:role/ProwlerAuditRole \
  --service iam s3 \
  --output-formats json-ocsf html \
  --output-directory reports/
```

### Step 5: Set a CloudTrail Alert for Root Logins

```bash
# Create a CloudWatch metric filter on CloudTrail logs
# that fires an SNS alert whenever root signs in
aws cloudwatch put-metric-alarm \
  --alarm-name "RootAccountUsage" \
  --alarm-description "Alert when root account is used" \
  --metric-name "RootAccountUsageCount" \
  --namespace "CloudTrailMetrics" \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1
```

### Verification

After switching to the IAM user for all operations:
- Re-run Prowler in 7+ days
- `iam_avoid_root_usage` should PASS (no root usage in the past 7 days)
