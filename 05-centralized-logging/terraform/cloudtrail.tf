resource "aws_cloudwatch_log_group" "cloudtrail" {
  provider          = aws.primary
  name              = "/aws/cloudtrail/central"
  retention_in_days = 90

  tags = {
    Project = "centralized-logging"
  }
}

resource "aws_cloudtrail" "central" {
  provider                   = aws.primary
  name                       = "central-trail"
  s3_bucket_name             = var.log_bucket_name
  s3_key_prefix              = "cloudtrail"

  is_multi_region_trail      = true

  enable_log_file_validation = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  kms_key_id                 = aws_kms_key.log_encryption.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = {
    Project = "centralized-logging"
  }
}
