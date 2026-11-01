# Scripts

Helper and validation scripts (AWS CLI / shell) for the lab.

- `assume-role.sh` (Phase 2): source it with a 6-digit MFA code to assume a lab
  role and export short-lived credentials, so Terraform runs under the
  least-privilege role. The provider cannot prompt for MFA itself, so the CLI does
  the assume. The role name is an optional second argument and defaults to
  `ContributorRole` (the role Terraform runs under); pass `AdminJITRole` to run
  the confidential-prefix read test, or `ReadOnlyRole` for read-only checks.

  ```
  source scripts/assume-role.sh 123456              # ContributorRole (default)
  source scripts/assume-role.sh 123456 AdminJITRole # confidential read test
  ```

The Phase 4 detection-validation scripts (benign, run against the lab's own test
identities, harmless by design and documented inline) land here during Phase 4
([docs/04-detections.md](../docs/04-detections.md)).
