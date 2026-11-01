variable "region" {
  description = "AWS Region for all lab resources. eu-north-1 is the workload region the account's AWS-managed region policy leaves open (us-east-1 is global-services only there)."
  type        = string
  default     = "eu-north-1"
}

variable "account_id" {
  description = "The workload account ID (Curiosity Unlocked)."
  type        = string
  default     = "963910216975"
}

variable "bucket_name" {
  description = "Globally unique name for the data bucket."
  type        = string
  default     = "cloud-iam-lab-data-963910216975"
}

# The roles allowed to use the KMS key and read the bucket. These are the Phase 1
# roles. ReadOnlyRole and ContributorRole get general access; the confidential
# prefix is restricted further in the bucket policy.
variable "key_user_role_arns" {
  description = "Role ARNs permitted to use the CMK for encrypt and decrypt."
  type        = list(string)
  default = [
    "arn:aws:iam::963910216975:role/ReadOnlyRole",
    "arn:aws:iam::963910216975:role/ContributorRole",
    "arn:aws:iam::963910216975:role/AdminJITRole"
  ]
}

# Only sessions of this role may read objects under confidential/. Everything else
# is denied on that prefix by the bucket policy, which demonstrates classification
# without creating extra IAM principals.
variable "confidential_reader_role" {
  description = "Role whose sessions may read confidential/ objects."
  type        = string
  default     = "AdminJITRole"
}

# Guardrail toggle. Apply first with false to seed data and run the baseline and
# cross-prefix tests, then set true to enforce the VPC endpoint and run the
# off-path negative test. This isolates each control cleanly.
variable "enforce_vpce" {
  description = "When true, object access must come through the S3 VPC endpoint."
  type        = bool
  default     = false
}
