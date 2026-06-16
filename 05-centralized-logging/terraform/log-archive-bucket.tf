# ============================================================
# PRIMARY LOG ARCHIVE BUCKET
# ============================================================

resource "aws_s3_bucket" "log_archive" {
  provider = aws.primary
  bucket   = var.log_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Purpose = "central-log-archive"
    Project = "centralized-logging"
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive" {
  provider                = aws.primary
  bucket                  = aws_s3_bucket.log_archive.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "log_archive" {
  provider = aws.primary
  bucket   = aws_s3_bucket.log_archive.id
  versioning_configuration {
    status = "Enabled"
    # MFA Delete cannot be set via Terraform — enable manually after deploy:
    # aws s3api put-bucket-versioning \
    #   --bucket central-log-archive-primary-092645363677 \
    #   --versioning-configuration Status=Enabled,MFADelete=Enabled \
    #   --mfa "arn:aws:iam::092645363677:mfa/root-account-mfa-device TOKEN"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "log_archive" {
  provider = aws.primary
  bucket   = aws_s3_bucket.log_archive.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.log_archive]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  provider = aws.primary
  bucket   = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.log_encryption.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  provider = aws.primary
  bucket   = aws_s3_bucket.log_archive.id

  rule {
    id     = "log-archive-lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    transition {
      days          = 1095
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "log_archive" {
  provider   = aws.primary
  bucket     = aws_s3_bucket.log_archive.id
  role       = aws_iam_role.s3_replication.arn

  depends_on = [aws_s3_bucket_versioning.log_archive]

  rule {
    id     = "replicate-all-logs"
    status = "Enabled"

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.log_archive_replica.arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.log_encryption_replica.arn
      }
    }
  }
}

# ============================================================
# BUCKET POLICY
# ============================================================

resource "aws_s3_bucket_policy" "log_archive" {
  provider = aws.primary
  bucket   = aws_s3_bucket.log_archive.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudTrailACLCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${var.log_bucket_name}"
      },
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
      {
        Sid    = "FlowLogsAclCheck"
        Effect = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${var.log_bucket_name}"
      },
      {
        Sid    = "FlowLogsPut"
        Effect = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.log_bucket_name}/vpc-flow-logs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "SimulatedWorkloadWrite"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.simulated_workload.arn
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.log_bucket_name}/workload-logs/*"
      },
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
      {
        Sid    = "DenyUnencryptedUploads"
        Effect = "Deny"
        Principal = { AWS = "*" }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.log_bucket_name}/*"
        Condition = {
          StringNotEqualsIfExists = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# ============================================================
# REPLICA BUCKET — us-west-2
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

resource "aws_s3_bucket_versioning" "log_archive_replica" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.log_archive_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive_replica" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.log_archive_replica.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.log_encryption_replica.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_object_lock_configuration" "log_archive_replica" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.log_archive_replica.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 90
    }
  }
}
