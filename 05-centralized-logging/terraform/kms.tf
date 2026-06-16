resource "aws_kms_key" "log_encryption" {
  provider                = aws.primary
  description             = "CMK for centralized log archive encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
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

# Secondary region KMS key — required for replicating SSE-KMS objects cross-region
resource "aws_kms_key" "log_encryption_replica" {
  provider                = aws.secondary
  description             = "CMK for centralized log archive replica encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowReplicationEncrypt"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.s3_replication.arn
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose = "log-encryption-replica"
    Project = "centralized-logging"
  }
}

resource "aws_kms_alias" "log_encryption_replica" {
  provider      = aws.secondary
  name          = "alias/central-log-encryption-replica"
  target_key_id = aws_kms_key.log_encryption_replica.key_id
}
