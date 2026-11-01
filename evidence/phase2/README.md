# Phase 2 evidence

Evidence for the data-protection controls on the lab bucket
`cloud-iam-lab-data-963910216975` in Curiosity Unlocked (963910216975), Region
`eu-north-1`. Every control below was proven with a command run from the laptop
against the live bucket. Command output is reproduced here with request and host
identifiers trimmed; nothing secret appears in any capture.

## Controls implemented

| Control | Mechanism | Terraform |
| --- | --- | --- |
| Block all public access | Public access block, all four flags on | `s3.tf` |
| No ACLs | Object ownership set to `BucketOwnerEnforced` | `s3.tf` |
| Versioning | Bucket versioning enabled | `s3.tf` |
| Encryption at rest | SSE-KMS default with a customer-managed key, bucket key on; each object pinned to the CMK | `kms.tf`, `s3.tf` |
| Key control | Key policy grants use to the account root and the three lab roles only; key rotation on | `kms.tf` |
| TLS only | Bucket policy `DenyInsecureTransport` (`aws:SecureTransport` false) | `s3.tf` |
| Classification by prefix | Bucket policy `RestrictConfidentialPrefix` denies `confidential/` reads to all but `AdminJITRole` and root | `s3.tf` |
| Private path (toggle) | Bucket policy `RequireVpcEndpointForObjects` (`aws:SourceVpce`), fed by an S3 gateway endpoint | `s3.tf`, `vpc.tf` |

## Tests run and results

| # | Test | Expected | Result |
| --- | --- | --- | --- |
| 1 | Anonymous read of `public/notice.txt` | Denied | AccessDenied |
| 2 | Read over a non-TLS endpoint | Denied | AccessDenied (explicit deny) |
| 3 | `ContributorRole` reads `internal/` and `confidential/` | internal allowed, confidential denied | internal succeeded, confidential AccessDenied |
| 4 | Object encryption on `internal/runbook.txt` | SSE-KMS with the CMK | `aws:kms`, CMK key id, bucket key on |
| 5 | Bucket default encryption and public-access block | `aws:kms` with CMK, all four flags true | confirmed |
| 6 | `AdminJITRole` reads `confidential/` | Allowed | file contents returned |
| 7 | `ContributorRole` reads `confidential/` under the final policy | Denied | 403 Forbidden |
| 8 | Off-path read with the VPC endpoint enforced | Denied | 403 Forbidden (`aws:SourceVpce`) |

Tests 6 and 7 are a matched pair on the same object under the same policy: the
one role the policy admits can read it, every other principal cannot. Test 8
isolates the VPC-endpoint control on the least-restricted prefix (`public/`) so
the only reason for the denial is `aws:SourceVpce`.

## Captured output

### Test 4 and 5: encryption and public access

```
$ aws s3api head-object --bucket cloud-iam-lab-data-963910216975 --key internal/runbook.txt
{
    "ContentLength": 64,
    "ContentType": "application/octet-stream",
    "ServerSideEncryption": "aws:kms",
    "SSEKMSKeyId": "arn:aws:kms:eu-north-1:963910216975:key/132c48c2-c167-4def-96a8-20e16b6856f0",
    "BucketKeyEnabled": true
}

$ aws s3api get-bucket-encryption --bucket cloud-iam-lab-data-963910216975
{
    "ServerSideEncryptionConfiguration": {
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "aws:kms",
                    "KMSMasterKeyID": "arn:aws:kms:eu-north-1:963910216975:key/132c48c2-c167-4def-96a8-20e16b6856f0"
                },
                "BucketKeyEnabled": true,
                "BlockedEncryptionTypes": { "EncryptionType": [ "SSE-C" ] }
            }
        ]
    }
}

$ aws s3api get-public-access-block --bucket cloud-iam-lab-data-963910216975
{
    "PublicAccessBlockConfiguration": {
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }
}
```

The bucket default is SSE-KMS on the customer-managed key, and S3 additionally
reports a block on SSE-C, so customer-supplied-key writes are refused as well:
all objects are encrypted with the lab's own key.

### Test 6 and 7: classification by prefix

```
# As AdminJITRole (the confidential reader)
$ aws s3 cp s3://cloud-iam-lab-data-963910216975/confidential/customer-records.txt -
Confidential classification sample. Lorem ipsum. Synthetic records only.

# As ContributorRole (any non-admin principal)
$ aws s3 cp s3://cloud-iam-lab-data-963910216975/confidential/customer-records.txt -
download failed: ... An error occurred (403) when calling the HeadObject operation: Forbidden
```

### Test 8: VPC-endpoint enforcement

```
# enforce_vpce toggled on (bucket policy gains RequireVpcEndpointForObjects)
$ terraform apply -var="enforce_vpce=true" -target=aws_s3_bucket_policy.data
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.

# Read from the laptop, over the internet rather than through the endpoint
$ aws s3 cp s3://cloud-iam-lab-data-963910216975/public/notice.txt -
download failed: ... An error occurred (403) when calling the HeadObject operation: Forbidden
```

The negative case is proven directly. The positive case, a read from inside the
VPC through the gateway endpoint, is documented by design rather than run,
because the lab keeps to its no-EC2 cost guardrail and has no in-VPC consumer.
The control is left toggled off at rest (`enforce_vpce = false`) so the lab
stays operable; a production account would keep it on with its workloads inside
the VPC.

## Suggested screenshots

File names are suggestions; keep them descriptive and sanitised (no request IDs,
no source IP, no secrets).

| Evidence | What it shows | Suggested file |
| --- | --- | --- |
| Encryption | `head-object` and `get-bucket-encryption` showing `aws:kms` and the CMK | `encryption-kms.png` |
| Public access | `get-public-access-block` all four true | `public-access-block.png` |
| Classification allowed | `AdminJITRole` reading `confidential/` | `confidential-allowed.png` |
| Classification denied | `ContributorRole` 403 on `confidential/` | `confidential-denied.png` |
| TLS and anonymous | AccessDenied for the anonymous and non-TLS reads | `anonymous-and-tls-denied.png` |
| VPC endpoint | Off-path 403 with `enforce_vpce = true` | `vpce-offpath-denied.png` |

## Findings corrected during the build

Two issues were found and fixed while proving the controls. Both are written up
in `../../lab-notes.md`.

1. **Seed objects were encrypted with SSE-S3, not the CMK.** A Terraform
   `aws_s3_object` waits only for the bucket, not for the separate
   encryption-configuration resource, so the seed objects were uploaded a moment
   before the SSE-KMS default took effect. Fixed by pinning
   `server_side_encryption` and `kms_key_id` on each object.

2. **The confidential-prefix policy locked out its own intended reader.** The
   deny condition allowed only the `sts` assumed-role session ARN, but for a role
   session `aws:PrincipalArn` resolves to the role ARN
   (`arn:aws:iam::...:role/AdminJITRole`), so even `AdminJITRole` was denied.
   Fixed by allowing the role ARN form.

## Sanitisation note

Account IDs and the KMS key ARN appear throughout the Terraform and are not
secret. Before committing any raw capture, remove request IDs, host IDs and any
source IP. Raw captures, if kept, go under a git-ignored `raw/` subfolder.
