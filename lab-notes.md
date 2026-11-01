# Lab notes

A running log of what broke and how it was fixed, kept from day one. These become
the STAR stories for interviews.

## Format

Each entry: date, what happened, what fixed it, what it taught.

## Entries

### 2026-10-30: Phase 1 complete, identity and access model

The organisation (Cloud-Corp, three accounts) is live, with the access model and
guardrails built and evidenced. Workload account "Curiosity Unlocked" holds all
lab resources; the management account holds organisation, billing and SCPs.

### 2026-10-29: Identity Center could not do multi-account permission sets

**What happened:** the plan was IAM Identity Center permission sets assigned to
groups. The "Multi-account permissions" and "Permission sets" menus never
appeared, in both the management and delegated-admin accounts, in the instance's
home Region, as a confirmed organisation instance. Changing the identity source
did not surface them.

**What fixed it:** rather than stall, the access model was rebuilt with IAM roles
in the workload account: one powerless `operator` user and three roles
(`ReadOnlyRole`, `ContributorRole`, `AdminJITRole`) assumable only with MFA, with
`AdminJITRole` capped at a one hour session. Same controls, delivered a different
way.

**What it taught:** least privilege, just-in-time elevation and a full audit
trail are the goal; the service that delivers them is secondary. A reviewer reads
IAM roles with an MFA-conditional trust policy as the same pattern as SSO
permission sets, and a production landing zone would simply front these roles
with an IdP.

### 2026-10-29: the new AWS console applies its own baseline guardrails

**What happened:** on the paid-plan upgrade, AWS auto-attached SCPs at the
organisation Root: an `AdvancedModeRegionRestrictionSecurityControlPolicy` and a
`ManagedAccountSecurityControlPolicy`. The second is the one that denied
`sso:CreateInstance` when we tried to spin up a second Identity Center instance.

**What fixed it:** nothing needed fixing; these are AWS baseline protections. The
lab's own SCPs (`deny-outside-us-east-1`, `deny-disable-security`,
`require-mfa-sensitive`) were attached at the Workloads OU, which layers
account-scoped guardrails under the Root-level baseline. The important lesson for
the deny model: a `FullAWSAccess` allow must stay attached alongside the deny
SCPs, because attaching any SCP switches the node to deny-by-default.

**What it taught:** know which guardrails the platform already enforces before
adding your own, and understand that SCPs are allow-list gates once present, not
just a stack of denies.

### 2026-11-01: Phase 2 complete, data protection on S3 with KMS

The lab bucket in Curiosity Unlocked is locked down end to end with Terraform:
block public access, no ACLs, versioning, SSE-KMS on a customer-managed key with
rotation, a TLS-only bucket policy, classification by prefix, and a toggleable
VPC-endpoint requirement backed by an S3 gateway endpoint. Every control was
proven from the laptop against the live bucket; the output is in
`evidence/phase2/`.

### 2026-10-31: seed objects were encrypted with SSE-S3, not the key

**What happened:** the bucket default encryption was set to SSE-KMS with the
customer-managed key, yet the first read of a seeded object came back
`ServerSideEncryption: AES256`. The object had been stored under SSE-S3, not the
intended key.

**What fixed it:** a Terraform `aws_s3_object` depends only on the bucket, not on
the separate `aws_s3_bucket_server_side_encryption_configuration` resource, so
the seed objects were uploaded a moment before the SSE-KMS default took effect
and landed under SSE-S3. Pinning `server_side_encryption = "aws:kms"` and
`kms_key_id` on each object, with an explicit `depends_on` the encryption
configuration, made every object use the key and removed the race.

**What it taught:** a bucket default is a fallback, not a guarantee, and resource
ordering in infrastructure as code is a correctness property. If a control must
hold on every object, assert it on the object rather than trusting it to be
inherited.

### 2026-10-31: a prefix policy that locked out its own reader

**What happened:** the bucket policy was meant to let only `AdminJITRole` read the
`confidential/` prefix and deny everyone else. Testing the allowed case, even
`AdminJITRole` was denied with a 403, and Terraform itself could no longer refresh
the confidential object.

**What fixed it:** the deny condition allowed only the `sts` assumed-role session
ARN (`arn:aws:sts::...:assumed-role/AdminJITRole/*`). For a role session,
`aws:PrincipalArn` resolves to the role ARN
(`arn:aws:iam::...:role/AdminJITRole`), not the session form, so the allow matched
no one and the deny caught the intended reader too. Adding the role ARN form to
the condition fixed it. Because the live policy had already blocked the runner's
own refresh, the corrected policy had to be applied in isolation first with
`-target`, before a full apply could read the object again.

**What it taught:** know exactly what each condition key resolves to before you
rely on it; `aws:PrincipalArn` is the role, not the session. A restrictive
resource policy also applies to the identity that deploys it, so the deployment
role has to be a principal the policy admits, which is why applies now run as the
just-in-time admin role.
