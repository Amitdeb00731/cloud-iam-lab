terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Terraform runs under ContributorRole, assumed with MFA. The AWS provider cannot
# prompt for an MFA code itself, so the assume-with-MFA is done by the AWS CLI
# (scripts/assume-role.sh), which exports temporary credentials as environment
# variables. The provider then picks those up from the standard credential chain,
# so no "profile" is set here.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "cloud-iam-lab"
      phase   = "2-data-protection"
    }
  }
}
