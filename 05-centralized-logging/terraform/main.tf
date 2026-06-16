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
