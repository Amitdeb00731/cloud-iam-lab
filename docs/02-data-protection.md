# Phase 2: Data protection (days 5 to 7)

**Goal:** deploy an S3 bucket that holds "customer" data and lock it so that only
an IAM principal, over a private path, with a customer-managed key, can reach it.
Everything is deployed from Terraform so the environment is reproducible and
Build 3 can scan the same code.

## 2.1 Terraform baseline

1. Install Terraform and the AWS CLI; configure the CLI to assume a lab role via
   IAM Identity Center (`aws configure sso`) and set the Region to `eu-west-2`.
2. In `iac/terraform/`, create `providers.tf` pinning the `aws` provider (use the
   current major version) with the Region and default tags
   (`project = cloud-iam-lab`), and `variables.tf` for Region, bucket name prefix
   and account ID.
3. Keep state local for the lab (`*.tfstate` is git-ignored); note in the README
   that production would use an S3 remote backend with state locking.

## 2.2 KMS customer-managed key

In `kms.tf`:

- A KMS customer-managed key (CMK) for S3 encryption, with key rotation enabled.
- A key policy that grants use only to the bucket's expected principals and denies
  everything else, so the key is the control point for decryption.
- Record the key ARN; the bucket's default encryption will reference it.

Enabling rotation and a tight key policy is the AWS equivalent of Key Vault purge
protection and the CMK grant: control of the encryption key stays with you.

## 2.3 S3 bucket, locked down

In `s3.tf`, set on the bucket:

| Setting | Value | Risk it addresses |
| --- | --- | --- |
| S3 Block Public Access (all four) | enabled | Anonymous data exposure |
| Bucket policy: deny non-TLS | `aws:SecureTransport = false` denied | Weak transport |
| Default encryption | SSE-KMS with the CMK | Control of the encryption key |
| Bucket key | enabled | Lower KMS request cost at rest |
| Versioning | enabled | Recover from overwrite or delete |
| Bucket policy: require the VPC endpoint | `aws:SourceVpce` condition | Only the private path reaches it |
| Public access via ACLs | disabled (bucket owner enforced) | No ACL-based exposure |

Create a VPC with no internet gateway and an S3 gateway VPC endpoint, so access to
the bucket stays on the private AWS network and name resolution never leaves it.
This is the AWS equivalent of the Azure private endpoint and private DNS zone.

## 2.4 Classification model

Model data classification with three prefixes (or three buckets if you prefer a
hard boundary), each with its own access statement:

| Prefix | Classification | Who can read |
| --- | --- | --- |
| `public/` | Public | A broad read-only group |
| `internal/` | Internal | `IT-Admins`, `Finance` |
| `confidential/` | Confidential | A named principal only, via a bucket-policy statement scoped to that prefix |

Scope the IAM and bucket-policy permissions to the prefix (the `s3:prefix`
condition and resource ARNs ending in `/confidential/*`), not the whole bucket, so
each classification has its own boundary.

## 2.5 Prove the controls

Run and record each negative test; the failures are the evidence:

1. **Anonymous access fails:** an unauthenticated `curl` of an object URL returns
   `AccessDenied`.
2. **Non-TLS access fails:** a request forced over HTTP is denied by the
   `aws:SecureTransport` bucket-policy statement.
3. **Off-path access fails:** a `get-object` from outside the VPC endpoint is
   denied by the `aws:SourceVpce` condition; the same read through the private path
   with an IAM token succeeds.
4. **Cross-prefix access fails:** a principal allowed on `internal/` is denied on
   `confidential/`.

Upload a dummy file (lorem-ipsum "customer records", never real data) to
`confidential/` for the Phase 4 exfiltration test.

## Phase 2 deliverables

- `iac/terraform/*.tf`: the whole environment as code.
- `docs/02-data-protection.md` with the configuration table and the risk rationale.
- `evidence/phase2/`: the four failed-access test outputs and the successful
  private read.
- Commit: `Phase 2: locked-down S3 with KMS CMK and VPC endpoint (Terraform)`.

## Checks before moving on

- `terraform plan` is clean (no drift) after apply.
- All four negative tests fail as expected and are saved.
- `aws s3api get-bucket-encryption` and `get-public-access-block` confirm SSE-KMS
  with the CMK and all public access blocked.
