resource "aws_flow_log" "main" {
  provider             = aws.primary
  vpc_id               = var.vpc_id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "${aws_s3_bucket.log_archive.arn}/vpc-flow-logs/"

  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${traffic-path} $${flow-direction}"

  tags = {
    Project = "centralized-logging"
  }
}
