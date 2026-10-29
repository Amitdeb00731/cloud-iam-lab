# Phase 1 evidence

Evidence for the identity and access model built in Curiosity Unlocked
(963910216975). File names are suggestions; keep them descriptive. Never include
a password or an MFA secret in any screenshot or export.

| Evidence | What it shows | Suggested file |
| --- | --- | --- |
| Roles list | `ReadOnlyRole`, `ContributorRole`, `AdminJITRole` all present | `roles-list.png` |
| AdminJITRole summary | Maximum session duration set to 1 hour | `adminjit-session-1h.png` |
| Operator permissions | Single inline policy `assume-lab-roles`, no managed policies | `operator-permissions.png` |
| Operator MFA | MFA device assigned on Security credentials | `operator-mfa.png` |
| Denied state | Operator signed in, Access denied on S3 or IAM | `operator-denied.png` |
| Read-only state | After assuming `ReadOnlyRole`, S3 readable, write denied | `readonly-after-switch.png` |
| Admin state | After assuming `AdminJITRole`, admin available, 1 hour session banner | `adminjit-elevated.png` |
| Audit trail | CloudTrail Event history filtered by user name `operator`, showing `AssumeRole` for both roles | `cloudtrail-assumerole.png` and optional `cloudtrail-assumerole.csv` |
| SCP guardrail (Step 6) | A denied action outside `us-east-1`, or an IAM policy simulator result | `scp-region-deny.png` |

Capture the CloudTrail rows by filtering on **User name = operator** (not Event
name), since Event history also contains hundreds of unrelated AWS service-role
assumptions. Event history can lag up to about 15 minutes after the action.
