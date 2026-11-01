# Infrastructure as code (Terraform)

The lab environment as code: the KMS customer-managed key, the locked-down S3
bucket, the VPC and S3 gateway endpoint, and the data-classification prefixes.
Region is `eu-north-1`, the workload Region the account's AWS-managed region
policy leaves open (`us-east-1` is global-services only there).

State is kept local for the lab and git-ignored; production would use an S3 remote
backend with state locking.

## Files

| File | What it creates |
| --- | --- |
| `providers.tf` | AWS provider, pinned, no profile (uses the short-lived credentials exported by `assume-role.sh`) |
| `variables.tf` | Region, account, bucket name, key users, confidential reader, the `enforce_vpce` toggle |
| `kms.tf` | Customer-managed key with rotation and a tight key policy, plus an alias |
| `s3.tf` | The bucket with Block Public Access, ownership enforced, versioning, SSE-KMS, the bucket policy, and three seed objects pinned to the CMK |
| `vpc.tf` | A VPC with no internet gateway and an S3 gateway endpoint |
| `outputs.tf` | Bucket name and ARN, key ARN, VPC endpoint ID |

## Prerequisites

The AWS provider cannot prompt for an MFA code, so the assume-with-MFA is done by
the AWS CLI through [`../../scripts/assume-role.sh`](../../scripts/assume-role.sh),
which exports short-lived credentials into your shell. The provider then uses the
standard credential chain, so `providers.tf` sets no profile.

The only local setup is an `operator` CLI profile holding the operator user's
access key, which the helper uses as its source:

```
[profile operator]
region = eu-north-1
# access key stored by `aws configure --profile operator`
```

The helper takes an optional role name (default `ContributorRole`):

```
source ../../scripts/assume-role.sh <6-digit-MFA-code>              # ContributorRole
source ../../scripts/assume-role.sh <6-digit-MFA-code> AdminJITRole # elevated
```

`ContributorRole` uses `PowerUserAccess`, which covers KMS, S3 and VPC but not
IAM, so nothing here creates IAM principals; classification is enforced entirely
through the bucket policy. Applies that touch objects run as `AdminJITRole`,
because the `confidential/` deny blocks any non-admin read, including Terraform's
own refresh `HeadObject`. In production a dedicated deployment role admitted on
every prefix would fill that seat.

## Run

Source the helper, then run Terraform in the same shell (credentials last about an
hour; re-source with a fresh MFA code if they expire):

```
source ../../scripts/assume-role.sh <6-digit-MFA-code> AdminJITRole
terraform init
terraform plan
terraform apply
```

The committed default is `enforce_vpce = false`, which seeds the sample objects
and lets the baseline and cross-prefix tests run from your workstation.

## Two-pass test plan

Each negative test is evidence. The recorded output is in
[`../../evidence/phase2/README.md`](../../evidence/phase2/README.md).

Pass A, with `enforce_vpce = false` (the default):
1. **Anonymous access fails:** `curl` the object URL, expect `AccessDenied`.
2. **Non-TLS fails:** an `http://` request to the object is denied by
   `DenyInsecureTransport`.
3. **Cross-prefix fails:** as `ContributorRole`, `get-object` on
   `confidential/customer-records.txt` is denied while `internal/runbook.txt`
   succeeds; as `AdminJITRole` the confidential read succeeds. That matched pair
   is the classification proof.

Pass B, enforce the endpoint with `-target` so the policy changes without a full
object refresh:

```
terraform apply -var="enforce_vpce=true"  -target=aws_s3_bucket_policy.data
# off-path read from the workstation is denied by aws:SourceVpce
terraform apply -var="enforce_vpce=false" -target=aws_s3_bucket_policy.data
```

4. **Off-path fails:** a `get-object` from your workstation (outside the VPC) is
   denied by the `aws:SourceVpce` condition. A read from inside the VPC would
   succeed; without lab compute, the deny is the evidence and the successful
   private path is documented as the design. The toggle is left off at rest so the
   lab stays usable without in-VPC compute.

Confirm the hard settings too:
```
aws s3api get-bucket-encryption   --bucket cloud-iam-lab-data-963910216975
aws s3api get-public-access-block --bucket cloud-iam-lab-data-963910216975
```

## Teardown

`terraform destroy` removes everything (run it as `AdminJITRole`). The KMS key has
a 7 day deletion window.
