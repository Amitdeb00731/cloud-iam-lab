# IAM roles: the access model (Curiosity Unlocked, 963910216975)

The access model is built from one powerless daily user and three roles it can
assume only with MFA. This is the as-built record; the design rationale is in
[../../docs/01-identity.md](../../docs/01-identity.md) and the hands-on steps are
in [../../docs/phase1-walkthrough.md](../../docs/phase1-walkthrough.md).

## Roles

All three share the trust policy in
[`trust-policy-mfa.json`](trust-policy-mfa.json): any principal in account
963910216975 may assume the role, but only when `aws:MultiFactorAuthPresent` is
`true`.

| Role | Permissions policy | Maximum session | Purpose |
| --- | --- | --- | --- |
| `ReadOnlyRole` | AWS managed `ReadOnlyAccess` | default (1 hour) | Baseline read access for support and business roles |
| `ContributorRole` | AWS managed `PowerUserAccess` | default (1 hour) | Day-to-day build and operate, no IAM or account changes |
| `AdminJITRole` | AWS managed `AdministratorAccess` | 1 hour (set explicitly) | Just-in-time administration, assumed only when needed |

`PowerUserAccess` is deliberate for the contributor: it grants broad service
access while withholding IAM and Organizations changes, so a contributor cannot
grant itself privilege. Privilege changes require `AdminJITRole`, which is
time-boxed and logged.

## The daily user

`operator` is an IAM user with console access, an MFA device, and a single inline
policy, [`operator-assume-lab-roles.json`](operator-assume-lab-roles.json), that
permits only `sts:AssumeRole` on the three roles. It has no other standing
permission, so without assuming a role it can neither read nor change anything.

## Why this maps to the Identity Center design

In a production landing zone the three roles would be Identity Center permission
sets assigned to groups, and `operator` would be a federated identity rather than
an IAM user. The controls are the same: no standing privilege, MFA-gated access,
just-in-time admin with a short session, and every assumption recorded in
CloudTrail. The instance available for this lab could not expose multi-account
permission sets, so the model was delivered with IAM roles, which a reviewer
reads as the same pattern.

## Break-glass

The account root user is the one intentional standing-privilege exception. It has
MFA enabled and is otherwise unused, exactly as a break-glass account should be.
