data "aws_caller_identity" "current" {}

# Key policy: the account root keeps full administrative control so the key can
# never be orphaned, and the named lab roles may use it for encrypt and decrypt.
# Nothing else can touch the key, so the key is the real control point for reading
# the data.
data "aws_iam_policy_document" "cmk" {
  statement {
    sid    = "EnableRootAccountAdmin"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowLabRolesUse"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.key_user_role_arns
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "data" {
  description             = "CMK for the cloud-iam-lab data bucket (SSE-KMS)."
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.cmk.json
}

resource "aws_kms_alias" "data" {
  name          = "alias/cloud-iam-lab-data"
  target_key_id = aws_kms_key.data.key_id
}
