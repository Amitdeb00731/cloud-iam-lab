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
