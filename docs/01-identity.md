# Phase 1: Identity and access model (days 1 to 4)

**Goal:** stand up an AWS account where identity is the control plane: no
standing privilege, every administrative action elevated just in time, and every
principal constrained by service control policies and IAM conditions. This is the
phase a technology-risk interviewer cares about most, so the evidence is an access
model, not screenshots.

All work is in an AWS account dedicated to this lab, using test identities only.
No real personal data and no production system is involved.

## 1.1 Create the account and the organisation

1. Sign up for a new AWS account. The current free tier gives a USD 100 signup
   credit (and up to a further USD 100 from guided activities); a free account
   plan runs at no cost for up to six months or until the credits are spent. Use
   an email not already tied to an AWS account.
2. Set the account's home Region to London (`eu-west-2`) and do all work there.
3. Enable AWS Organizations (one management account, this account as the only
   member for the lab). Organizations is what makes service control policies
   available, which this phase relies on.
4. Turn on IAM Identity Center (the successor to IAM users) in `eu-west-2`. All
   human access goes through Identity Center, never through long-lived IAM users
   with access keys.
5. Record the account ID, the Organizations ID and the Identity Center instance
   ARN in `lab-notes.md`.

## 1.2 Secure the root user and the management account

1. Enable MFA on the account root user, then lock the root user away: it is used
   only for the handful of tasks that require it.
2. Create a billing budget now (see 1.7) so cost is controlled from day one.
3. Confirm CloudTrail is on (it is by default for management events); you will
   build on it in Phase 3.

The root user is the one intentional standing-privilege exception, the AWS
equivalent of a break-glass account, so it gets the strongest MFA and is
otherwise unused.

## 1.3 Create personas

Create these users in IAM Identity Center (Identity Center > Users > Add user).
Give each a unique strong passphrase; **never record a password in the repo, in
notes, or in memory.** Keep them in a local password manager only.

| User | Represents | Notes |
| --- | --- | --- |
| `helpdesk1` | First-line support | Member of a Helpdesk group |
| `finance1` | Business user | Member of a Finance group |
| `itadmin1` | IT staff, daily account | Non-privileged day-to-day identity |
| `adm-itadmin1` | IT staff, admin identity | Separate identity for privileged access |
| `guest1` | External collaborator | Low-privilege, read-only group |

The split between `itadmin1` and `adm-itadmin1` mirrors the Tier 0 / Tier 2
separation from Build 1: daily work and privileged work never share an identity.

Create matching groups (Identity Center > Groups): `Helpdesk`, `Finance`,
`IT-Admins`. Assign the users. Use these groups for every permission-set
assignment, never individual users.

## 1.4 Permission sets and least privilege

Permission sets are the IAM Identity Center equivalent of role definitions; each
maps to an IAM role provisioned into the account.

1. Create a `ReadOnly` permission set (AWS managed `ReadOnlyAccess`) and assign it
   to `Helpdesk`, `Finance` and `guest1` as their baseline.
2. Create a `Contributor` permission set scoped to the lab's services (S3, KMS,
   CloudTrail read), assigned to `IT-Admins` for day-to-day work. No
   `AdministratorAccess` assignment to daily identities.
3. Set a short session duration (1 hour) on every permission set, so access is not
   open-ended.

**Evidence:** export each permission set's inline and managed policy into
`config/permission-sets/`.

## 1.5 Just-in-time elevation (PIM equivalent)

The objective: no identity holds standing administrative access. Elevation to an
admin permission set is requested, granted for a short window, and lapses.

1. Create an `Admin-JIT` permission set (`AdministratorAccess`, 1-hour session)
   but assign it to **no one** by default.
2. Model just-in-time elevation one of two ways, and document which you chose:
   - Temporary assignment: an elevation is an explicit, time-boxed assignment of
     `Admin-JIT` to `adm-itadmin1`, removed after use (scripted in `scripts/`), or
   - A role-assumption path where `adm-itadmin1` assumes an admin role whose trust
     policy requires `aws:MultiFactorAuthPresent` and a session tag, so the
     elevation is conditional and audited in CloudTrail.
3. Require MFA for the elevation in both models.
4. Test the flow: sign in as `adm-itadmin1`, confirm no admin access, perform the
   elevation, confirm admin access works only after it, and that it lapses.

**Evidence:** screenshot or export the elevation mechanism, and record the
standing-vs-elevated state of every privileged permission set in the access model
table. The CloudTrail `AssumeRole` or `CreateAccountAssignment` record is the
proof the elevation was explicit and time-boxed.

## 1.6 Service control policies and IAM conditions (Conditional Access equivalent)

Conditional Access in Azure becomes two AWS layers: service control policies
(organisation-wide guardrails) and IAM condition keys (per-policy constraints).
Author SCPs in `iac/terraform/` or `config/scp/`, attach them to the account, and
record the effect.

| # | Guardrail | Mechanism | Control |
| --- | --- | --- | --- |
| G1 | Require MFA for sensitive actions | IAM policy condition `aws:MultiFactorAuthPresent = true` | Deny the action without MFA |
| G2 | Block access from outside the UK | SCP or IAM condition `aws:SourceIp` (and `aws:RequestedRegion`) | Deny outside the allowed range |
| G3 | Confine to one Region | SCP condition `aws:RequestedRegion` not equal to `eu-west-2` | Deny actions in other Regions |
| G4 | Deny root for day-to-day | SCP denying most actions by the root principal | Root reserved for break-glass only |
| G5 | Deny disabling of security services | SCP denying `cloudtrail:StopLogging`, `guardduty:Delete*`, `config:Delete*` | Protect the audit path |

Validate each the safe way first: attach to a scratch non-production path or use
the IAM policy simulator, read the effect, then attach for real. The simulator is
the AWS analogue of Conditional Access report-only mode, so you can show the
impact before enforcing.

**Evidence:** export each SCP and the key IAM conditions as JSON into
`config/scp/`, and capture a policy-simulator result or a denied CloudTrail event
showing the guardrail applied.

## 1.7 Budget and tagging guardrails

1. Create an AWS Budget of USD 10 with alert thresholds (50%, 80%, 100%) to your
   email, so cost never runs away.
2. Tag every resource `project = cloud-iam-lab` so teardown and cost attribution
   are clean.
3. Keep everything in one Region (`eu-west-2`) and create no EC2 instances.

**Evidence:** `aws budgets describe-budgets` output saved to
`evidence/phase1/budget.txt`.

## Phase 1 deliverables

- `docs/01-identity.md` write-up with the access model table (permission set,
  holder, standing or elevated, justification).
- `config/permission-sets/*.json` and `config/scp/*.json`.
- `evidence/phase1/`: elevation mechanism, a policy-simulator or denied-action
  result, budget listing.
- Commit message suggestion: `Phase 1: identity and access model (Identity Center, JIT, SCP)`.

## Checks before moving on

- Signing in as `finance1` gives read-only access and nothing more.
- `adm-itadmin1` has no administrative access until it elevates.
- A simulated action from outside `eu-west-2`, or without MFA, is denied (confirm
  with the IAM policy simulator).
- The root user is MFA-protected and used by nothing day to day.
