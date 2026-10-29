# Build 2 execution guides: AWS cloud security and identity

Step-by-step guides for each phase of the `cloud-iam-lab-aws` build. The plan and
rationale behind them is in the Build 2 on AWS plan document; these are the
how-to. This is the AWS counterpart of the Azure `cloud-iam-lab` build, stage for
stage, to show the same controls across two clouds.

| Phase | Guide | Output |
| --- | --- | --- |
| 1 | [Identity and access model](01-identity.md) | Identity Center, just-in-time elevation, SCPs, least privilege |
| 2 | [Data protection](02-data-protection.md) | Locked-down S3, KMS CMK, VPC endpoint (Terraform) |
| 3 | [Visibility](03-visibility.md) | CloudTrail, Athena, GuardDuty, telemetry coverage |
| 4 | [Simulate and detect](04-detections.md) | Five cloud detections, Athena SQL + Sigma, coverage matrix |
| 5 | [Posture and access review](05-posture.md) | Security Hub before/after, access review |
| 6 | [Report](06-report.md) | Incident report, IAM model, business summary |

Everything runs in an AWS account dedicated to this lab, with test identities
only, in the London Region (`eu-west-2`). No real credentials or production
systems are involved. Guardrails: a USD 10 budget with alerts, one Region, no EC2,
every resource tagged `project = cloud-iam-lab`, and GuardDuty, Security Hub and
Config enabled together at Phase 3 and torn down at Phase 6. Follow the phases in
order; each ends with evidence committed and a short list of checks before moving
on.
