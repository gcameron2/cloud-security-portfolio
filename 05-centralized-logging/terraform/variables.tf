variable "primary_region" {
  default = "us-east-2"
}

variable "secondary_region" {
  default = "us-west-2"
}

variable "account_id" {
  description = "Your AWS account ID"
}

variable "log_bucket_name" {
  description = "Name for the primary log archive bucket — must be globally unique"
  default     = "central-log-archive-primary-092645363677"
}

variable "replica_bucket_name" {
  description = "Name for the replica bucket in the secondary region"
  default     = "central-log-archive-replica-092645363677"
}

variable "vpc_id" {
  description = "VPC ID to enable flow logs on"
}

variable "alert_email" {
  description = "Email address for security alerts"
}
