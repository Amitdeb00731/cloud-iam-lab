# Phase 6: Report (days 19 to 21)

**Goal:** turn the build into the three artefacts a security and controls function
produces: a technical incident report, an IAM control write-up for a risk reader,
and a one-page business summary. Same structure and house style as Build 1, and
the same teardown discipline at the end.

## 6.1 Incident report

`report/incident-report.md`, written as if the five techniques were one
intrusion: a stolen or sprayed credential, an unusual valid sign-in, an admin
policy attached outside the just-in-time path, an access key created for
persistence, and data read from the exposed S3 bucket. Include:

- Incident window and timeline, taken from the real CloudTrail and GuardDuty
  timestamps.
- Per-stage findings against the captured events, with the alert record cited.
- MITRE ATT&CK mapping (the five technique IDs).
- Root cause: the controls that would have stopped each stage (MFA guardrail,
  just-in-time elevation, S3 Block Public Access and the VPC-endpoint condition),
  and which held.
- Containment, recovery and recommendations.

## 6.2 IAM control write-up

`report/iam-model.md`, for a technology-risk reader. Map each control you built to
the access-management expectations a bank's controls team checks:

- Joiner-mover-leaver (provisioning through Identity Center, group changes, access
  review).
- Privileged access management (just-in-time elevation, short sessions, root as
  break-glass).
- Least privilege and segregation of duties (permission-set scope, prefix-level
  data separation, SCP guardrails).
- Monitoring and detection (CloudTrail, GuardDuty, the Athena detections and the
  coverage matrix).

## 6.3 Business summary

`report/business-companion.md`, one page, plain language, framed against UK
operational resilience (PRA and FCA important business services and impact
tolerances): what an identity compromise in a cloud account would mean for a
service that depends on it, and which controls hold the impact inside tolerance.

## 6.4 Teardown

- Destroy the Terraform stack (`terraform destroy`) to remove the bucket, KMS key
  and VPC.
- Disable GuardDuty, Security Hub and AWS Config so no trial or per-item charges
  continue.
- Delete the CloudTrail trail and its log bucket if you are not reusing them.
- Record the final cost from Cost Explorer or the Billing console in
  `lab-notes.md`.
- Remove the lab's IAM Identity Center users if you are not reusing the account.

## Phase 6 deliverables

- `report/incident-report.md`, `report/iam-model.md`,
  `report/business-companion.md`, `report/README.md` index.
- Commit: `Phase 6: incident report, IAM model and business summary`.

## House style (carried from Build 1)

- No em or en dashes; plain professional prose.
- Every result claim carries its evidence.
- No placeholder text committed.
- British spelling in prose; keep identifiers and commands as they are.
