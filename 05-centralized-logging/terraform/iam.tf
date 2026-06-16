# ============================================================
# SIMULATED WORKLOAD ROLE
# Represents what a separate workload account would do.
# Write-only access to the log bucket.
# ============================================================

resource "aws_iam_role" "simulated_workload" {
  provider = aws.primary
  name     = "SimulatedWorkloadRole"

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
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.log_bucket_name}/workload-logs/*"
      },
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
# Read-only access to logs. Requires MFA to assume.
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
      {
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = aws_kms_key.log_encryption.arn
      },
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
          "s3:GetObjectVersionTagging",
          "s3:GetObjectRetention",
          "s3:GetObjectLegalHold"
        ]
        Resource = "${aws_s3_bucket.log_archive.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner",
          "s3:GetObjectRetention",
          "s3:PutObjectRetention"
        ]
        Resource = "${aws_s3_bucket.log_archive_replica.arn}/*"
      },
      # Decrypt source objects using the primary region KMS key
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.log_encryption.arn
      },
      # Re-encrypt replicated objects using the secondary region KMS key
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Encrypt", "kms:ReEncrypt*", "kms:DescribeKey"]
        Resource = aws_kms_key.log_encryption_replica.arn
      }
    ]
  })
}
