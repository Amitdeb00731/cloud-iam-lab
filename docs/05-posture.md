# Phase 5: Posture and access review (days 17 to 18)

**Goal:** measure the account's security posture before and after remediation, and
run one access review, so the build shows the governance half of cloud security,
not just detections. Same honesty rule as Build 1: the figures show improvement,
not formal compliance.

## 5.1 Baseline the scores

1. **Security Hub security score:** enable AWS Security Hub in `eu-west-2` with the
   AWS Foundational Security Best Practices standard (and CIS if you want a second
   view). Security Hub depends on AWS Config, so confirm Config is on and scoped as
   in Phase 3.4. Record the starting score and the top failed controls.
2. **IAM Access Analyzer and the credential report:** run an account credential
   report and an Access Analyzer scan for external access. Record unused
   credentials, over-broad policies and any resource shared outside the account.

Screenshot both before you change anything. Security Hub has a 30-day free trial;
GuardDuty's findings feed into it.

## 5.2 Remediate the top items

Work the highest-weight findings that fit the lab, for example:

- MFA enforced for all human access (handled by the G1 guardrail).
- No long-lived access keys on human identities (Identity Center only).
- Least privilege on permission sets, no standing `AdministratorAccess`.
- S3 Block Public Access and secure-transport (already set in Phase 2).
- Root user access keys absent, root MFA on.

Record each change and why. Re-run the Security Hub score and the Access Analyzer
scan and capture the after figures.

## 5.3 Access review

1. Use the account credential report and IAM Access Analyzer to list every human
   identity and its permission-set assignments.
2. Review the members of your privileged permission sets (or the `IT-Admins`
   group).
3. As the reviewer, approve or remove each, record the outcome.

This demonstrates the periodic-review control a bank's IAM function runs, and it
ties back to the joiner-mover-leaver story in the report. AWS has no single
packaged "access review" like Entra, so the review is the documented, repeatable
use of Access Analyzer plus the credential report, which is itself a good talking
point.

## Phase 5 deliverables

- `docs/05-posture.md` with before and after scores and a table of fixes.
- `evidence/phase5/`: Security Hub score before and after, Access Analyzer and
  credential-report results, access-review decisions.
- Commit: `Phase 5: posture improvement and access review`.

## Checks before moving on

- The Security Hub score improved, with no new high-severity finding introduced.
- The write-up states plainly that the score measures improvement, not compliance
  or certification.
- The access review has a recorded decision for every reviewed identity.
