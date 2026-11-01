#!/usr/bin/env bash
#
# Assume ContributorRole with MFA and export temporary credentials into the
# current shell, so Terraform (and the AWS CLI) run under the least-privilege
# role. The Terraform AWS provider cannot prompt for an MFA code, so this script
# does the assume and hands Terraform short-lived credentials instead.
#
# Usage (must be SOURCED so the exports persist in your shell):
#   source scripts/assume-role.sh <6-digit-MFA-code> [role-name]
#
# role-name is optional and defaults to ContributorRole, which is the role
# Terraform runs under. Pass AdminJITRole to run the confidential-prefix read
# test, or ReadOnlyRole for read-only checks. Then run your commands in the same
# shell. Credentials last one hour.
#
# This script is written to be sourced safely: it does not enable errexit, so a
# wrong MFA code reports an error without closing your terminal.

_assume_role() {
  local mfa_code="${1:-}"
  local role_name="${2:-ContributorRole}"
  if [ -z "$mfa_code" ]; then
    echo "Usage: source scripts/assume-role.sh <6-digit-MFA-code> [role-name]" >&2
    return 1
  fi

  local role_arn="arn:aws:iam::963910216975:role/${role_name}"
  local mfa_serial="arn:aws:iam::963910216975:mfa/operator-mfa"
  local source_profile="operator"

  local creds
  creds=$(aws sts assume-role \
    --role-arn "$role_arn" \
    --role-session-name terraform \
    --serial-number "$mfa_serial" \
    --token-code "$mfa_code" \
    --profile "$source_profile" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text) || {
      echo "assume-role failed. Check the MFA code and try again." >&2
      return 1
    }

  export AWS_ACCESS_KEY_ID="$(echo "$creds" | awk '{print $1}')"
  export AWS_SECRET_ACCESS_KEY="$(echo "$creds" | awk '{print $2}')"
  export AWS_SESSION_TOKEN="$(echo "$creds" | awk '{print $3}')"
  export AWS_DEFAULT_REGION="eu-north-1"

  echo "Assumed ${role_name}. Temporary credentials exported for this shell (valid ~1 hour)."
  aws sts get-caller-identity
}

_assume_role "$@"
