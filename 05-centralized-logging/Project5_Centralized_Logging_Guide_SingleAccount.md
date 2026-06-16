# Project 5: Centralized Logging — Complete Step-by-Step Guide (Single AWS Account)

---

## Before You Start

### What You're Building

A centralized logging pipeline using one AWS account that simulates a multi-account
architecture by separating log storage into a dedicated, locked-down S3 bucket. You will:

- Collect CloudTrail, VPC Flow Logs, and AWS Config from your account
- Ship everything into an isolated "log archive" S3 bucket (primary region)
- Replicate that bucket to a second region for resilience
- Encrypt at rest with a Customer Managed KMS Key
- Make logs immutable via S3 Object Lock (Governance mode)
- Alert on tampering, failures, and security events via CloudWatch

### Single-Account Architecture Trade-Off

In a real enterprise, the log archive lives in a completely separate AWS account. This
means a compromised workload account cannot reach the logs — they are in a different
account the attacker has no access to.

With one account, you simulate this by using:
- Strict IAM boundaries (a dedicated read-only role for log access)
- A separate S3 bucket treated as the "archive" with no-delete policy
- Cross-region replication for resilience

**Document this limitation in your architecture.md.** Interviewers will ask about it,
and being able to explain the trade-off clearly is more impressive than pretending it
does not exist.

### Prerequisites

- One AWS account with admin access
- AWS CLI configured
- Terraform >= 1.0 installed
- A VPC already created in your account
- Two AWS regions chosen (e.g. us-east-1 as primary, us-west-2 as secondary)

---

## Terraform File Structure

Create this layout before writing any code:

```
05-centralized-logging/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── kms.tf
│   ├── log-archive-bucket.tf
│   ├── cloudtrail.tf
│   ├── vpc-flow-logs.tf
│   ├── iam.tf
│   └── cloudwatch-alarms.tf
└── docs/
    ├── architecture.md
    ├── incident-response.md
    └── compliance-mapping.md
```

---

## Step 1 — Provider and Variables (main.tf + variables.tf)

Everything runs in one account. You use two provider aliases purely to manage
resources in two different regions — primary for the main log bucket, secondary
for the replica bucket.

**terraform/main.tf**
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary region — CloudTrail, CloudWatch, main log bucket
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

# Secondary region — replica bucket only
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}
```

**terraform/variables.tf**
```hcl
variable "primary_region" {
  default = "us-east-1"
}

variable "secondary_region" {
  default = "us-west-2"
}

variable "account_id" {
  description = "Your AWS account ID"
}

variable "log_bucket_name" {
  description = "Name for the primary log archive bucket — must be globally unique"
  default     = "central-log-archive-primary"
}

variable "replica_bucket_name" {
  description = "Name for the replica bucket in the secondary region"
  default     = "central-log-archive-replica"
}

variable "vpc_id" {
  description = "VPC ID to enable flow logs on"
}

variable "alert_email" {
  description = "Email address for security alerts"
}
```

---

## Step 2 — KMS Customer Managed Key (kms.tf)

This key encrypts all logs at rest. Using a CMK rather than the default S3
encryption gives you control over who can decrypt — you decide, not AWS.

**terraform/kms.tf**
```hcl
resource "aws_kms_key" "log_encryption" {
  provider                = aws.primary
  description             = "CMK for centralized log archive encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true  # Automatically rotates the key annually

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Account root has full admin over the key
      {
        Sid    = "EnableAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # CloudTrail service can use the key to encrypt logs it writes
      {
        Sid    = "AllowCloudTrailEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      # VPC Flow Logs delivery service can use the key
      {
        Sid    = "AllowFlowLogsEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      # Security reader role can decrypt to read logs
      {
        Sid    = "AllowSecurityTeamDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.security_reader.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose = "log-encryption"
    Project = "centralized-logging"
  }
}

resource "aws_kms_alias" "log_encryption" {
  provider      = aws.primary
  name          = "alias/central-log-encryption"
  target_key_id = aws_kms_key.log_encryption.key_id
}
```

> **Note:** The `security_reader` role is defined in Step 4 (iam.tf). Terraform resolves
> this reference at plan time — you do not need to create the role first manually.

---

## Step 3 — Log Archive S3 Buckets (log-archive-bucket.tf)

Two buckets: a primary archive and a cross-region replica. The primary bucket is
where all logs land. The replica protects against regional outage or a targeted
attack on one region.

**terraform/log-archive-bucket.tf**
```hcl
# ============================================================
# PRIMARY LOG ARCHIVE BUCKET
# ============================================================

resource "aws_s3_bucket" "log_archive" {
  provider = aws.primary
  bucket   = var.log_bucket_name

  lifecycle {
    prevent_destroy = true  # Terraform will refuse to delete this bucket
  }

  tags = {
    Purpose = "central-log-archive"
    Project = "centralized-logging"
  }
}

# Block ALL public access — no exceptions
resource "aws_s3_bucket_public_access_block" "log_archive" {
  provider                = aws.primary
  bucket                  = aws_s3_bucket.log_archive.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Versioning is required before Object Lock can be enabled
resource "aws_s3_bucket_versioning" "log_archive" {
  provider = aws.primary
  bucket   = aws_s3_bucket.log_archive.id
  versioning_configuration {
    status = "Enabled"
    # MFA Delete adds a second factor requirement to delete object versions
    # Requires MFA device serial + code via AWS CLI — cannot be set via Terraform
    # Enable manually after deploy:
    # aws s3api put-bucket-versioning \
    #   --bucket central-log-archive-primary \
    #   --versioning-configuration Status=Enabled,MFADelete=Enabled \
    #   --mfa "arn:aws:iam::ACCOUNT:mfa/DEVICE TOKEN"
  }
}

# Object Lock — Governance mode
# Governance: a user with s3:BypassGovernanceRetention CAN override the lock
# Use this for a lab — safe to clean up if needed
# COMPLIANCE mode: nobody can override, ever — use in production/regulated environments
resource "aws_s3_bucket_object_lock_configuration" "log_archive" {
  provider = aws.primary
  bucket   = aws_s3_bucket.log_archive.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 90
      # For compliance frameworks increase to:
      # 365  days = 1 year  (SOC 2)
      # 2555 days = 7 years (PCI-DSS, HIPAA)
    }
  }

  depends_on = [aws_s3_bucket_versioning.log_archive]
}

# SSE-KMS encryption — every object encrypted with your CMK
resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  provider = aws.primary
  bucket   = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.log_encryption.arn
    }
    # Bucket key reduces the number of KMS API calls — significant cost saving
    # at scale without any security trade-off
    bucket_key_enabled = true
  }
}

# Lifecycle — automatically move logs to cheaper storage tiers over time
resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  provider = aws.primary
  bucket   = aws_s3_bucket.log_archive.id

  rule {
    id     = "log-archive-lifecycle"
    status = "Enabled"

    filter {
      prefix = ""  # Applies to all objects
    }

    # After 90 days: move to Infrequent Access (less expensive, same durability)
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    # After 1 year: move to Glacier (cold archive, minutes to restore)
    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    # After 3 years: move to Deep Archive (cheapest, 12 hours to restore)
    transition {
      days          = 1095
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# Cross-region replication — copies every new object to secondary region
resource "aws_s3_bucket_replication_configuration" "log_archive" {
  provider   = aws.primary
  bucket     = aws_s3_bucket.log_archive.id
  role       = aws_iam_role.s3_replication.arn

  depends_on = [aws_s3_bucket_versioning.log_archive]

  rule {
    id     = "replicate-all-logs"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.log_archive_replica.arn
      storage_class = "STANDARD_IA"  # Replica goes straight to cheaper tier
    }
  }
}

# ============================================================
# BUCKET POLICY — WHO CAN DO WHAT
#
# Write:  CloudTrail service, VPC Flow Logs service,
#         SimulatedWorkload role (represents a workload account)
# Read:   SecurityReader role only
# Delete: NOBODY — explicit deny overrides everything
# ============================================================

resource "aws_s3_bucket_policy" "log_archive" {
  provider = aws.primary
  bucket   = aws_s3_bucket.log_archive.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # CloudTrail checks bucket ACL before writing — this is required
      {
        Sid    = "CloudTrailACLCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${var.log_bucket_name}"
      },

      # CloudTrail writes log files
      {
        Sid    = "CloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.log_bucket_name}/cloudtrail/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },

      # VPC Flow Logs delivery service writes to a separate prefix
      {
        Sid    = "FlowLogsWrite"
        Effect = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.log_bucket_name}",
          "arn:aws:s3:::${var.log_bucket_name}/vpc-flow-logs/*"
        ]
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },

      # SimulatedWorkload role can write — represents what a separate
      # workload account would do in a real multi-account setup
      {
        Sid    = "SimulatedWorkloadWrite"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.simulated_workload.arn
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.log_bucket_name}/workload-logs/*"
      },

      # SecurityReader role can read and list — nothing else
      {
        Sid    = "SecurityReaderAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.security_reader.arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.log_bucket_name}",
          "arn:aws:s3:::${var.log_bucket_name}/*"
        ]
      },

      # EXPLICIT DENY on all deletes — applies to everyone including account root
      # An explicit deny cannot be overridden by any allow statement
      {
        Sid    = "DenyAllDeletes"
        Effect = "Deny"
        Principal = { AWS = "*" }
        Action = [
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.log_bucket_name}",
          "arn:aws:s3:::${var.log_bucket_name}/*"
        ]
      },

      # Deny any upload not using KMS encryption
      # Prevents accidental plaintext log storage
      {
        Sid    = "DenyUnencryptedUploads"
        Effect = "Deny"
        Principal = { AWS = "*" }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.log_bucket_name}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# ============================================================
# REPLICA BUCKET — secondary region
# ============================================================

resource "aws_s3_bucket" "log_archive_replica" {
  provider = aws.secondary
  bucket   = var.replica_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Purpose = "central-log-archive-replica"
    Project = "centralized-logging"
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive_replica" {
  provider                = aws.secondary
  bucket                  = aws_s3_bucket.log_archive_replica.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Versioning required on destination bucket for replication to work
resource "aws_s3_bucket_versioning" "log_archive_replica" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.log_archive_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

---

## Step 4 — IAM Roles (iam.tf)

Three roles: one that simulates a workload account writing logs, one for the
security team to read logs, and one for S3 replication.

**terraform/iam.tf**
```hcl
# ============================================================
# SIMULATED WORKLOAD ROLE
# In a real multi-account setup this would be a separate AWS account.
# Here it is an IAM role with write-only access to the log bucket.
# Assume this role to test cross-account write simulation.
# ============================================================

resource "aws_iam_role" "simulated_workload" {
  provider = aws.primary
  name     = "SimulatedWorkloadRole"

  # Only principals in this account can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Purpose = "simulates-workload-account"
    Project = "centralized-logging"
  }
}

resource "aws_iam_role_policy" "simulated_workload" {
  provider = aws.primary
  role     = aws_iam_role.simulated_workload.id
  name     = "WorkloadWriteOnly"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Can write to its own prefix only
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.log_bucket_name}/workload-logs/*"
      },
      # Can use the KMS key to encrypt what it writes
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource = aws_kms_key.log_encryption.arn
      }
    ]
  })
}

# ============================================================
# SECURITY READER ROLE
# Read-only access to logs. No write. No delete.
# Assume this role when investigating an incident.
# ============================================================

resource "aws_iam_role" "security_reader" {
  provider = aws.primary
  name     = "SecurityLogReader"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
      Action    = "sts:AssumeRole"
      # Require MFA to assume this role — extra protection for log access
      Condition = {
        Bool = { "aws:MultiFactorAuthPresent" = "true" }
      }
    }]
  })

  tags = {
    Purpose = "security-log-reader"
    Project = "centralized-logging"
  }
}

resource "aws_iam_role_policy" "security_reader" {
  provider = aws.primary
  role     = aws_iam_role.security_reader.id
  name     = "LogReadOnly"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.log_bucket_name}",
          "arn:aws:s3:::${var.log_bucket_name}/*"
        ]
      },
      # Can decrypt logs using the CMK
      {
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = aws_kms_key.log_encryption.arn
      },
      # Can run Athena queries for incident investigation
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================
# CLOUDTRAIL → CLOUDWATCH ROLE
# Allows CloudTrail to stream events to CloudWatch Logs
# ============================================================

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  provider = aws.primary
  name     = "CloudTrailToCloudWatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  provider = aws.primary
  role     = aws_iam_role.cloudtrail_cloudwatch.id
  name     = "CloudTrailCloudWatchWrite"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# ============================================================
# VPC FLOW LOGS ROLE
# Allows the Flow Logs service to write to S3
# ============================================================

resource "aws_iam_role" "flow_logs" {
  provider = aws.primary
  name     = "VPCFlowLogsToS3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  provider = aws.primary
  role     = aws_iam_role.flow_logs.id
  name     = "FlowLogsS3Write"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetBucketAcl"
      ]
      Resource = [
        "arn:aws:s3:::${var.log_bucket_name}",
        "arn:aws:s3:::${var.log_bucket_name}/vpc-flow-logs/*"
      ]
    }]
  })
}

# ============================================================
# S3 REPLICATION ROLE
# Allows S3 to copy objects from primary to replica bucket
# ============================================================

resource "aws_iam_role" "s3_replication" {
  provider = aws.primary
  name     = "S3LogReplication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "s3_replication" {
  provider = aws.primary
  role     = aws_iam_role.s3_replication.id
  name     = "S3ReplicationPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.log_archive.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.log_archive.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.log_archive_replica.arn}/*"
      },
      # Allow replication to use the KMS key for encryption
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.log_encryption.arn
      }
    ]
  })
}
```

---

## Step 5 — CloudTrail (cloudtrail.tf)

A standard multi-region trail covering all regions in your account. The
`is_organization_trail` line is removed since you have a single account.

**terraform/cloudtrail.tf**
```hcl
# CloudWatch Log Group receives CloudTrail events for real-time alerting
resource "aws_cloudwatch_log_group" "cloudtrail" {
  provider          = aws.primary
  name              = "/aws/cloudtrail/central"
  retention_in_days = 90  # Hot storage — quick querying for active investigations

  tags = {
    Project = "centralized-logging"
  }
}

resource "aws_cloudtrail" "central" {
  provider                   = aws.primary
  name                       = "central-trail"
  s3_bucket_name             = var.log_bucket_name
  s3_key_prefix              = "cloudtrail"

  # Captures API activity in every region, not just the one you deploy in
  is_multi_region_trail      = true

  # NOT setting is_organization_trail — single account only
  # Document this in architecture.md as a known limitation

  # Creates SHA-256 hash chain — enables tamper detection
  enable_log_file_validation = true

  # Stream to CloudWatch for real-time metric filters and alarms
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  # Encrypt log files with your CMK
  kms_key_id                 = aws_kms_key.log_encryption.arn

  # Management events: all console, CLI, and SDK API calls
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Data events: S3 object-level reads and writes
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]  # All buckets
    }

    # Data events: Lambda function invocations
    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  # Insight events: detects unusual spikes in API call rates
  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = {
    Project = "centralized-logging"
  }
}
```

---

## Step 6 — VPC Flow Logs (vpc-flow-logs.tf)

CloudTrail captures API calls. Flow Logs capture actual network traffic —
connections in and out of your VPC. Together they give you the full picture
during an incident.

**terraform/vpc-flow-logs.tf**
```hcl
resource "aws_flow_log" "main" {
  provider             = aws.primary
  vpc_id               = var.vpc_id
  traffic_type         = "ALL"  # Capture both ACCEPT and REJECT decisions
  log_destination_type = "s3"
  log_destination      = "${aws_s3_bucket.log_archive.arn}/vpc-flow-logs/"
  iam_role_arn         = aws_iam_role.flow_logs.arn

  # Custom format captures more fields than the default 14-field format
  # Adds traffic-path, flow-direction, and pkt-src/dst for richer analysis
  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${traffic-path} $${flow-direction}"

  tags = {
    Project = "centralized-logging"
  }
}
```

---

## Step 7 — CloudWatch Alarms (cloudwatch-alarms.tf)

Two tiers of alarms: **logging infrastructure** (P1 — someone may be trying to
blind your logging) and **security events** (P1/P2 — suspicious activity in
your account).

**terraform/cloudwatch-alarms.tf**
```hcl
# ============================================================
# SNS TOPIC — receives all alarm notifications
# ============================================================

resource "aws_sns_topic" "security_alerts" {
  provider = aws.primary
  name     = "security-alerts"
}

resource "aws_sns_topic_subscription" "security_email" {
  provider  = aws.primary
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================
# LOGGING INFRASTRUCTURE ALERTS — P1
# These fire if someone is disabling or tampering with logging
# ============================================================

# Filter: CloudTrail stopped, deleted, or modified
resource "aws_cloudwatch_log_metric_filter" "cloudtrail_changes" {
  provider       = aws.primary
  name           = "CloudTrailChanges"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging) }"

  metric_transformation {
    name      = "CloudTrailChanges"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudtrail_changes" {
  provider            = aws.primary
  alarm_name          = "P1-CloudTrail-Config-Changed"
  alarm_description   = "CRITICAL: CloudTrail was stopped, deleted, or modified"
  metric_name         = "CloudTrailChanges"
  namespace           = "CloudTrailMetrics"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# Filter: Log bucket policy modified
resource "aws_cloudwatch_log_metric_filter" "s3_bucket_policy_changes" {
  provider       = aws.primary
  name           = "S3BucketPolicyChanges"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy)) }"

  metric_transformation {
    name      = "S3BucketPolicyChanges"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_bucket_policy_changes" {
  provider            = aws.primary
  alarm_name          = "P1-S3-Log-Bucket-Policy-Changed"
  alarm_description   = "CRITICAL: Log bucket policy was modified — potential tamper attempt"
  metric_name         = "S3BucketPolicyChanges"
  namespace           = "CloudTrailMetrics"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# ============================================================
# SECURITY EVENT ALERTS — P1 / P2
# ============================================================

# Root account login — should almost never happen
resource "aws_cloudwatch_log_metric_filter" "root_account_usage" {
  provider       = aws.primary
  name           = "RootAccountUsage"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_account_usage" {
  provider            = aws.primary
  alarm_name          = "P1-Root-Account-Usage"
  alarm_description   = "CRITICAL: Root account was used — immediate investigation required"
  metric_name         = "RootAccountUsage"
  namespace           = "CloudTrailMetrics"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# Console login without MFA
resource "aws_cloudwatch_log_metric_filter" "console_login_no_mfa" {
  provider       = aws.primary
  name           = "ConsoleLoginNoMFA"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.userIdentity.type != \"AssumedRole\") }"

  metric_transformation {
    name      = "ConsoleLoginNoMFA"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "console_login_no_mfa" {
  provider            = aws.primary
  alarm_name          = "P2-Console-Login-No-MFA"
  alarm_description   = "Console login without MFA — account may lack MFA enforcement"
  metric_name         = "ConsoleLoginNoMFA"
  namespace           = "CloudTrailMetrics"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# IAM policy changes
resource "aws_cloudwatch_log_metric_filter" "iam_changes" {
  provider       = aws.primary
  name           = "IAMPolicyChanges"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{($.eventName=DeleteGroupPolicy)||($.eventName=DeleteRolePolicy)||($.eventName=DeleteUserPolicy)||($.eventName=PutGroupPolicy)||($.eventName=PutRolePolicy)||($.eventName=PutUserPolicy)||($.eventName=CreatePolicy)||($.eventName=DeletePolicy)||($.eventName=CreatePolicyVersion)||($.eventName=DeletePolicyVersion)||($.eventName=SetDefaultPolicyVersion)||($.eventName=AttachRolePolicy)||($.eventName=DetachRolePolicy)||($.eventName=AttachUserPolicy)||($.eventName=DetachUserPolicy)}"

  metric_transformation {
    name      = "IAMPolicyChanges"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_changes" {
  provider            = aws.primary
  alarm_name          = "P2-IAM-Policy-Changes"
  alarm_description   = "IAM policy was created, modified, or deleted"
  metric_name         = "IAMPolicyChanges"
  namespace           = "CloudTrailMetrics"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# Security group changes
resource "aws_cloudwatch_log_metric_filter" "security_group_changes" {
  provider       = aws.primary
  name           = "SecurityGroupChanges"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"

  metric_transformation {
    name      = "SecurityGroupChanges"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  provider            = aws.primary
  alarm_name          = "P2-Security-Group-Changes"
  alarm_description   = "Security group rule added, removed, or group deleted"
  metric_name         = "SecurityGroupChanges"
  namespace           = "CloudTrailMetrics"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# Network ACL changes
resource "aws_cloudwatch_log_metric_filter" "nacl_changes" {
  provider       = aws.primary
  name           = "NACLChanges"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation) }"

  metric_transformation {
    name      = "NACLChanges"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "nacl_changes" {
  provider            = aws.primary
  alarm_name          = "P2-NACL-Changes"
  alarm_description   = "Network ACL was created or modified"
  metric_name         = "NACLChanges"
  namespace           = "CloudTrailMetrics"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# Unauthorized API calls — threshold of 5 to reduce false positives
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api" {
  provider       = aws.primary
  name           = "UnauthorizedAPICalls"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.errorCode = \"AccessDenied\") || ($.errorCode = \"UnauthorizedOperation\") }"

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api" {
  provider            = aws.primary
  alarm_name          = "P3-Unauthorized-API-Calls"
  alarm_description   = "More than 5 unauthorized API calls in 10 minutes — possible credential abuse"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "CloudTrailMetrics"
  statistic           = "Sum"
  period              = 600   # 10-minute window
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
```

---

## Step 8 — Deploy

```bash
cd terraform

# Initialize — downloads providers
terraform init

# Review the plan — read this output before applying
terraform plan \
  -var="account_id=YOUR_ACCOUNT_ID" \
  -var="vpc_id=vpc-xxxxxxxx" \
  -var="alert_email=you@example.com"

# Deploy everything
terraform apply \
  -var="account_id=YOUR_ACCOUNT_ID" \
  -var="vpc_id=vpc-xxxxxxxx" \
  -var="alert_email=you@example.com"
```

After apply completes, check your email and **confirm the SNS subscription** — alarms
will not deliver until you click the confirmation link.

---

## Step 9 — Enable MFA Delete Manually

MFA Delete cannot be enabled via Terraform — it must be done via the AWS CLI
using your root account credentials and MFA device.

```bash
# Get your MFA device ARN
aws iam list-mfa-devices --user-name root

# Enable MFA Delete (replace TOKEN with your 6-digit MFA code)
aws s3api put-bucket-versioning \
  --bucket central-log-archive-primary \
  --versioning-configuration Status=Enabled,MFADelete=Enabled \
  --mfa "arn:aws:iam::YOUR_ACCOUNT_ID:mfa/root-account-mfa-device TOKEN"
```

Document in your architecture.md that this step is done manually and why
(Terraform does not support MFA Delete because it cannot interactively
prompt for an MFA token during a plan/apply run).

---

## Step 10 — Verify Everything Is Working

```bash
# 1. Confirm CloudTrail is active
aws cloudtrail get-trail-status --name central-trail

# Expected output includes:
# "IsLogging": true

# 2. Confirm log file validation is on
aws cloudtrail describe-trails | grep LogFileValidationEnabled
# Expected: "LogFileValidationEnabled": true

# 3. Check logs are landing in S3 (wait ~5 minutes after deploy)
aws s3 ls s3://central-log-archive-primary/cloudtrail/ --recursive | head -20

# 4. Validate the hash chain — detects any tampering
aws cloudtrail validate-logs \
  --trail-arn arn:aws:cloudtrail:us-east-1:YOUR_ACCOUNT_ID:trail/central-trail \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
# Expected: "Logs validated. No log file validation failures detected."

# 5. Test that delete is denied — this MUST fail
aws s3 rm s3://central-log-archive-primary/cloudtrail/ --recursive
# Expected: An error occurred (AccessDenied)

# 6. Test that the simulated workload role can write but not read
aws sts assume-role \
  --role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/SimulatedWorkloadRole \
  --role-session-name test-write

# Then using those temporary credentials:
aws s3 cp test.log s3://central-log-archive-primary/workload-logs/test.log
# Expected: upload success

aws s3 ls s3://central-log-archive-primary/
# Expected: AccessDenied — the role can write but not list

# 7. Check replication is working
aws s3 ls s3://central-log-archive-replica/ --recursive | head -10
# Should show the same objects appearing in us-west-2
```

---

## Step 11 — Set Up Athena for Log Querying

1. In the AWS Console, go to Athena in your primary region
2. Create a results bucket: `athena-query-results-YOUR_ACCOUNT_ID`
3. Under Settings, set that bucket as the query result location
4. Run this DDL to create a table over your CloudTrail logs:

```sql
CREATE EXTERNAL TABLE cloudtrail_logs (
  eventversion       STRING,
  useridentity       STRUCT<
                       type:STRING,
                       principalid:STRING,
                       arn:STRING,
                       accountid:STRING,
                       invokedby:STRING,
                       accesskeyid:STRING,
                       userName:STRING,
                       sessioncontext:STRUCT<
                         attributes:STRUCT<
                           mfaauthenticated:STRING,
                           creationdate:STRING>,
                         sessionissuer:STRUCT<
                           type:STRING,
                           principalId:STRING,
                           arn:STRING,
                           accountId:STRING,
                           userName:STRING>>>,
  eventtime          STRING,
  eventsource        STRING,
  eventname          STRING,
  awsregion          STRING,
  sourceipaddress    STRING,
  useragent          STRING,
  errorcode          STRING,
  errormessage       STRING,
  requestparameters  STRING,
  responseelements   STRING,
  requestid          STRING,
  eventid            STRING,
  eventtype          STRING,
  apiversion         STRING,
  readonly           STRING,
  recipientaccountid STRING
)
ROW FORMAT SERDE 'com.amazon.emr.hive.serde.CloudTrailSerde'
STORED AS INPUTFORMAT 'com.amazon.emr.cloudtrail.CloudTrailInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://central-log-archive-primary/cloudtrail/AWSLogs/YOUR_ACCOUNT_ID/CloudTrail/';
```

**Key investigation queries to test and save:**

```sql
-- All root account activity
SELECT eventtime, eventname, sourceipaddress, awsregion
FROM cloudtrail_logs
WHERE useridentity.type = 'Root'
ORDER BY eventtime DESC
LIMIT 50;

-- Console logins without MFA
SELECT eventtime, useridentity.username, sourceipaddress
FROM cloudtrail_logs
WHERE eventname = 'ConsoleLogin'
  AND responseelements LIKE '%Success%'
ORDER BY eventtime DESC;

-- All IAM changes in the last 24 hours
SELECT eventtime, eventname, useridentity.arn, requestparameters
FROM cloudtrail_logs
WHERE eventsource = 'iam.amazonaws.com'
  AND eventtime > to_iso8601(current_timestamp - interval '1' day)
ORDER BY eventtime DESC;

-- Failed API calls by source IP — useful for spotting credential stuffing
SELECT sourceipaddress,
       COUNT(*) AS failure_count,
       array_agg(DISTINCT eventname) AS events_attempted
FROM cloudtrail_logs
WHERE errorcode IN ('AccessDenied', 'UnauthorizedOperation')
  AND eventtime > to_iso8601(current_timestamp - interval '1' day)
GROUP BY sourceipaddress
ORDER BY failure_count DESC;
```

---

## Step 12 — Write Your Three Docs Files

These are required deliverables and are what turn this from a lab into a portfolio piece.

---

### docs/architecture.md

Answer these questions in your own words:

**Why is the log bucket isolated with strict IAM instead of a separate account?**
Single-account limitation. In a real enterprise the log archive would be a completely
separate AWS account — a compromised workload account cannot reach logs in another
account. With one account, you simulate this isolation using IAM roles and an explicit
deny bucket policy. The security gap is real and should be acknowledged.

**Why Governance mode Object Lock instead of Compliance?**
Compliance mode is permanent — even AWS support cannot remove it during the retention
period. For a lab environment that is impractical. Governance mode still demonstrates
immutability while allowing cleanup if you make a mistake. In production with regulated
data, Compliance mode is the correct choice.

**Why SSE-KMS over the default SSE-S3?**
SSE-S3 means AWS manages the encryption keys. SSE-KMS with a CMK means you manage them.
You can restrict who can decrypt, audit every decryption attempt via CloudTrail, and as
a last resort revoke the key. SSE-S3 gives you none of that control.

**Why cross-region replication?**
A regional outage, a regional attack, or an accidental bucket deletion in one region
should not destroy your audit trail. The replica in a second region is independent and
subject to the same delete deny policy.

**Why two S3 buckets instead of one?**
Separation of concern. The primary bucket receives all writes. The replica exists purely
as a disaster recovery copy. In a real multi-account setup these would be in different
accounts entirely.

---

### docs/incident-response.md

Write a step-by-step playbook for at least these two scenarios:

**Scenario 1: P1 Alarm — CloudTrail configuration changed**

1. Immediately check if logging is still active:
   `aws cloudtrail get-trail-status --name central-trail`
2. If `IsLogging` is false, restart immediately:
   `aws cloudtrail start-logging --name central-trail`
3. Identify who made the change — run this Athena query:
   ```sql
   SELECT eventtime, useridentity.arn, sourceipaddress, requestparameters
   FROM cloudtrail_logs
   WHERE eventname IN ('UpdateTrail','StopLogging','DeleteTrail')
   ORDER BY eventtime DESC LIMIT 10;
   ```
4. Review all actions taken by that identity in the 30 minutes before the event
5. Check for new IAM users, roles, or access keys created in the same window
6. If the identity is unexpected, treat as a compromised credential — revoke access
   keys, invalidate sessions, and escalate

**Scenario 2: P1 Alarm — Root account usage**

1. Run the root activity Athena query to see what was done:
   ```sql
   SELECT eventtime, eventname, sourceipaddress, requestparameters
   FROM cloudtrail_logs
   WHERE useridentity.type = 'Root'
   ORDER BY eventtime DESC LIMIT 20;
   ```
2. Identify if it was planned activity — if not, treat as compromise
3. Immediately rotate root credentials and verify MFA device is still yours
4. Review every action taken during the root session
5. Check for new IAM users, policies, or cross-account roles created
6. Enable an SCP (Service Control Policy) via Organizations to block future
   root API usage if your environment allows it
7. Notify security leadership — root usage is a P1 in almost every framework

---

### docs/compliance-mapping.md

Map your controls to CIS AWS Foundations Benchmark:

| CIS Control | Requirement | Implementation |
|---|---|---|
| 2.1 | CloudTrail enabled in all regions | `is_multi_region_trail = true` |
| 2.2 | Log file validation enabled | `enable_log_file_validation = true` |
| 2.3 | CloudTrail S3 bucket not publicly accessible | Public access block on both buckets |
| 2.4 | CloudTrail integrated with CloudWatch Logs | `cloud_watch_logs_group_arn` set |
| 2.6 | S3 bucket access logging enabled | Access logs prefix in lifecycle config |
| 2.7 | CloudTrail logs encrypted at rest | SSE-KMS with CMK |
| 3.1 | Unauthorized API calls alarm | P3-Unauthorized-API-Calls alarm |
| 3.3 | Root account usage alarm | P1-Root-Account-Usage alarm |
| 3.4 | IAM policy changes alarm | P2-IAM-Policy-Changes alarm |
| 3.10 | Security group changes alarm | P2-Security-Group-Changes alarm |
| 3.11 | NACL changes alarm | P2-NACL-Changes alarm |

**Known gaps vs full CIS compliance:**
- CIS recommends a separate dedicated logging account — simulated here with IAM isolation
- CIS 2.6 (access logging on the log bucket itself) not implemented — add as a stretch goal
- CIS recommends AWS Config rules enabled — not covered in this project but covered in Project 4

---

## Deliverables Checklist

- [ ] `terraform/main.tf` — dual-region providers, single account
- [ ] `terraform/variables.tf` — all variables defined
- [ ] `terraform/kms.tf` — CMK with key policy for CloudTrail, Flow Logs, SecurityReader
- [ ] `terraform/log-archive-bucket.tf` — primary + replica buckets, Object Lock, SSE-KMS, lifecycle, replication, bucket policy
- [ ] `terraform/iam.tf` — SimulatedWorkload, SecurityReader, CloudTrail→CW, FlowLogs, S3Replication roles
- [ ] `terraform/cloudtrail.tf` — multi-region trail with log validation, CloudWatch integration, KMS
- [ ] `terraform/vpc-flow-logs.tf` — flow logs shipping to primary bucket
- [ ] `terraform/cloudwatch-alarms.tf` — SNS topic + 8 alarms
- [ ] `terraform apply` completed successfully
- [ ] SNS email subscription confirmed
- [ ] CloudTrail logs visible in S3
- [ ] `validate-logs` command passes (no tampering detected)
- [ ] Delete operation tested and denied
- [ ] SimulatedWorkload role can write but not read or delete
- [ ] SecurityReader role can read but not write or delete
- [ ] Replica bucket receiving objects in secondary region
- [ ] MFA Delete enabled manually via CLI
- [ ] Athena table created and all four queries tested
- [ ] `docs/architecture.md` — design decisions + single-account trade-off documented
- [ ] `docs/incident-response.md` — two playbooks written
- [ ] `docs/compliance-mapping.md` — CIS mapping with known gaps noted
