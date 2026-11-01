# Phase 2: Data protection (days 5 to 7)

**Goal:** deploy an S3 bucket that holds "customer" data and lock it so that only
an IAM principal, over a private path, with a customer-managed key, can reach it.
Everything is deployed from Terraform so the environment is reproducible and
Build 3 can scan the same code.

## 2.1 Terraform baseline

As-built note: the lab uses the Phase 1 IAM-roles model, not Identity Center, and
the Region is `eu-north-1` (the workload Region the account's AWS-managed region
policy leaves open; `us-east-1` is global-services only there). Terraform runs
under short-lived credentials from an assumed lab role, so infrastructure is built
by a role with MFA behind it, never a standing admin.

1. Install Terraform and the AWS CLI. Create an access key for the `operator`
   user and store it in an `operator` CLI profile. The AWS provider cannot prompt
   for an MFA code, so a helper, `scripts/assume-role.sh`, does the
   assume-with-MFA and exports short-lived credentials into your shell; the
   provider then uses them from the standard credential chain. The exact setup is
   in [../iac/terraform/README.md](../iac/terraform/README.md).
2. The Terraform in `iac/terraform/` is already written: `providers.tf` pins the
   `aws` provider and sets default tags (`project = cloud-iam-lab`) with no
   profile, so it uses the credentials the helper exports; `variables.tf` holds
   Region, account, bucket name, the key-user roles, the confidential reader and
   the `enforce_vpce` toggle.
3. State is kept local for the lab (`*.tfstate` is git-ignored); production would
   use an S3 remote backend with state locking.

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

As-built: the full test output is in [../evidence/phase2/README.md](../evidence/phase2/README.md),
including the matched allowed-and-denied pair on `confidential/`. Note one
consequence of the confidential deny: because it blocks any non-admin read, it
also blocks Terraform's own refresh `HeadObject`, so applies run as `AdminJITRole`
(the one principal the prefix admits). A production account would use a dedicated
deployment role admitted on every prefix instead.

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
