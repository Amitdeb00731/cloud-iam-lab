# Phase 1 walkthrough: exact steps for your organisation

This is the hands-on version of [01-identity.md](01-identity.md), tailored to the
organisation you actually built. Work top to bottom. Everything here is free
(Identity Center, IAM and SCPs cost nothing). Region is **Europe (London)
eu-west-2** throughout; check the Region selector top-right before each step.

## Your accounts (where each step runs)

| Account | ID | Role in the lab | What you do here |
| --- | --- | --- | --- |
| Cloud-Corp Management Account | 618790904616 | Organisation admin and payer | Org structure, SCPs, Identity Center |
| Curiosity Unlocked | 963910216975 | Workload (member) account, holds the credit | Nothing yet; Phase 2 onward builds here |
| Cloud-Corp Identity Delegated Admin | 795804715588 | Auto-created Identity Center admin | Leave as is |

Rule of thumb: **identity and guardrails are set in the management account; the
lab's resources live in Curiosity Unlocked.** Do every step below while signed
into the **management account** unless it says otherwise.

## Step 1: Lock down the root user (management account)

The root user is your break-glass account, so it gets the strongest protection
and is then left unused.

1. Top-right account menu > **Security credentials**.
2. Under **Multi-factor authentication (MFA)** > **Assign MFA device** > choose an
   authenticator app (or a passkey) > follow the prompts to register it.
3. Under **Access keys**: if any root access keys exist, **delete them**. The root
   user should have no access keys.
4. Do the same MFA step for the Curiosity Unlocked root user later, when you first
   sign into it for Phase 2.

**Evidence:** screenshot the Security credentials page showing MFA enabled and no
access keys. Save to `evidence/phase1/`.

## Step 2: Put the workload account in an Organizational Unit (management account)

An OU lets you attach guardrails to the workload account cleanly, which is how a
real landing zone is structured.

1. Search **Organizations** > open it.
2. **Root** > **Actions** > **Create new** (Organizational unit) > name it
   `Workloads` > create.
3. Tick **Curiosity Unlocked** (963910216975) > **Actions** > **Move** > choose the
   `Workloads` OU > **Move AWS account**.
4. Leave the management account directly under Root (never inside an OU that gets
   restrictive SCPs, so you can never lock yourself out of administration).

**Evidence:** screenshot the org tree showing Curiosity Unlocked inside
`Workloads`.

## Step 3: Create personas and groups (Identity Center, management account)

1. Search **IAM Identity Center** > confirm the instance `Cloud-Corp` and Region
   eu-west-2.
2. **Groups** > **Create group**, three times: `Helpdesk`, `Finance`, `IT-Admins`.
3. **Users** > **Add user**, for each row below. Set a strong passphrase (or let
   AWS email a setup link to the plus-alias of your Gmail, for example
   `amitdebrnp380+helpdesk1@gmail.com`). **Never record a password in the repo,
   notes, or anywhere shared.**

| Username | Represents | Group |
| --- | --- | --- |
| `helpdesk1` | First-line support | Helpdesk |
| `finance1` | Business user | Finance |
| `itadmin1` | IT staff, daily account | IT-Admins |
| `adm-itadmin1` | IT staff, admin identity | (no group; gets JIT access in step 5) |
| `guest1` | External collaborator | Helpdesk (read-only) |

4. Add each user to its group as you create it (or **Groups** > group > **Add
   users**).

The split between `itadmin1` (daily) and `adm-itadmin1` (privileged) mirrors the
Tier 0 / Tier 2 separation from Build 1: daily work and admin work never share an
identity.

**Evidence:** screenshot the Users and Groups lists.

## Step 4: Permission sets and assignments (Identity Center, management account)

Permission sets are the roles people assume in an account. Create them once, then
assign group-to-account.

1. **IAM Identity Center** > **Permission sets** > **Create permission set**.
2. Create these three:

| Permission set | Policy | Session | Purpose |
| --- | --- | --- | --- |
| `ReadOnly` | AWS managed `ReadOnlyAccess` | 1 hour | Baseline for Helpdesk, Finance, guest |
| `Contributor` | AWS managed `PowerUserAccess` (or a scoped policy later) | 1 hour | IT-Admins day-to-day work |
| `Admin-JIT` | AWS managed `AdministratorAccess` | 1 hour | Elevation only; assigned to nobody by default |

   For each: choose the policy, set **session duration = 1 hour**, name it, create.

3. Assign access: **IAM Identity Center** > **AWS accounts** > tick **Curiosity
   Unlocked** (963910216975) > **Assign users or groups**:
   - `Helpdesk`, `Finance`, `guest1` > `ReadOnly`.
   - `IT-Admins` > `Contributor`.
   - Do **not** assign `Admin-JIT` to anyone yet.

4. Note your Identity Center sign-in URL (the AWS access portal,
   `https://d-xxxx.awsapps.com/start`). That is how the personas sign in, not the
   root console.

**Evidence:** export each permission set's policy JSON to `config/permission-sets/`
and screenshot the assignments on Curiosity Unlocked.

## Step 5: Just-in-time elevation and test (Identity Center)

The point: `adm-itadmin1` holds no admin access until it is granted for a short
window.

1. Confirm `adm-itadmin1` has **no** assignment on Curiosity Unlocked.
2. To elevate: **AWS accounts** > Curiosity Unlocked > **Assign users or groups**
   > `adm-itadmin1` > `Admin-JIT`.
3. Sign into the access portal as `adm-itadmin1`, confirm the `Admin-JIT` role now
   appears and works (session lasts 1 hour).
4. To de-elevate: remove that assignment. Confirm the access is gone.
5. Script the assign/remove with the AWS CLI into `scripts/` so the elevation is
   repeatable and auditable. The CloudTrail `CreateAccountAssignment` and
   `DeleteAccountAssignment` records are the proof it was explicit and time-boxed.

**Evidence:** the before (no access), elevated (access works), and after (removed)
states, plus the two CloudTrail records.

## Step 6: Guardrails with SCPs (Organizations, management account)

Service control policies are the organisation-wide "deny" guardrails. Attach them
to the `Workloads` OU so they bind Curiosity Unlocked but never the management
account.

1. **Organizations** > **Policies** > **Service control policies** > if disabled,
   **Enable**.
2. Create each policy below (**Create policy**, paste the statement, name it), then
   **attach** it to the `Workloads` OU.

| Policy | What it denies | Key condition |
| --- | --- | --- |
| `deny-outside-eu-west-2` | Any action in another Region | `aws:RequestedRegion` not `eu-west-2` (allow global services like IAM) |
| `deny-disable-security` | Turning off the audit path | `cloudtrail:StopLogging`, `guardduty:Delete*`, `config:Delete*`, `s3:PutBucketPublicAccessBlock` loosening |
| `require-mfa-sensitive` | Sensitive actions without MFA | `aws:MultiFactorAuthPresent` = false on chosen actions |

   Start with `deny-outside-eu-west-2` only, confirm you can still work, then add
   the others one at a time. Keep IAM, STS, Organizations and CloudFront actions
   out of the Region deny (they are global).

3. Validate the effect with the **IAM policy simulator** (search "IAM" > **Policy
   simulator**) or by attempting a denied action and reading the deny in
   CloudTrail. The simulator is the safe "report-only" equivalent.

**Evidence:** export each SCP JSON to `config/scp/`, and capture a simulator
result or a denied CloudTrail event showing a guardrail applied.

## Phase 1 deliverables

- `docs/phase1-walkthrough.md` (this file) and the access model table in
  `docs/01-identity.md` (permission set, holder, standing or elevated,
  justification).
- `config/permission-sets/*.json` and `config/scp/*.json`.
- `evidence/phase1/`: root MFA, org tree, users and groups, assignments, the JIT
  before/elevated/after, a denied-action or simulator result.
- Commit: `Phase 1: identity and access model (Identity Center, JIT, SCP)`.

## Checks before moving on

- Root user has MFA and no access keys.
- `finance1` signs into the access portal and gets read-only, nothing more.
- `adm-itadmin1` has no admin access until elevated, and it lapses.
- An action outside eu-west-2 is denied on Curiosity Unlocked (simulator or
  CloudTrail), while the management account is unaffected.
