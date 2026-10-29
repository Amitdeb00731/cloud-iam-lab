# Infrastructure as code (Terraform)

The lab environment as code: the KMS customer-managed key, the locked-down S3
bucket, the VPC and S3 gateway endpoint, and the data-classification prefixes.

State is kept local for the lab and git-ignored; production would use an S3
remote backend with state locking.

Lands during Phase 2 ([docs/02-data-protection.md](../../docs/02-data-protection.md)).
