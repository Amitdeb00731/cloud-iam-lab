resource "aws_s3_bucket" "data" {
  bucket = var.bucket_name
}

# No ACLs: ownership is enforced to the bucket owner, so access is governed only by
# policy, never by legacy ACLs.
resource "aws_s3_bucket_ownership_controls" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# All four public-access-block settings on, so the bucket can never be made public.
resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Default encryption with the customer-managed key. The bucket key lowers KMS
# request cost for objects at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
    bucket_key_enabled = true
  }
}

# The bucket policy carries the access controls:
#  - deny any request not over TLS,
#  - restrict confidential/ to sessions of the confidential reader role,
#  - optionally require the S3 VPC endpoint for object access (toggle).
data "aws_iam_policy_document" "bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "RestrictConfidentialPrefix"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.data.arn}/confidential/*"]
    # Deny unless the caller is the confidential reader role, or the account root.
    # For a role session, aws:PrincipalArn resolves to the role ARN
    # (arn:aws:iam::acct:role/Name), not the sts assumed-role/session form, so the
    # role ARN is what must be allowed. The assumed-role wildcard is kept as a
    # belt-and-braces entry; because this is a negated match, the Deny is skipped
    # when the principal matches any listed value.
    condition {
      test     = "StringNotLike"
      variable = "aws:PrincipalArn"
      values = [
        "arn:aws:iam::${var.account_id}:role/${var.confidential_reader_role}",
        "arn:aws:sts::${var.account_id}:assumed-role/${var.confidential_reader_role}/*",
        "arn:aws:iam::${var.account_id}:root"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.enforce_vpce ? [1] : []
    content {
      sid    = "RequireVpcEndpointForObjects"
      effect = "Deny"
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      actions   = ["s3:GetObject", "s3:PutObject"]
      resources = ["${aws_s3_bucket.data.arn}/*"]
      condition {
        test     = "StringNotEquals"
        variable = "aws:SourceVpce"
        values   = [aws_vpc_endpoint.s3.id]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id
  policy = data.aws_iam_policy_document.bucket.json

  # The public-access-block must exist first or PutBucketPolicy can be rejected.
  depends_on = [aws_s3_bucket_public_access_block.data]
}

# Seed one dummy object per classification. Lorem text only, never real data. The
# confidential object is the target for the Phase 4 exfiltration test.
#
# Encryption is set explicitly on each object rather than left to the bucket
# default. The default is SSE-KMS, but aws_s3_object only waits for the bucket, not
# for the separate encryption-configuration resource, so a seed object can be
# written a moment before the default takes effect and land as SSE-S3. Pinning the
# CMK here removes that race and makes the control provable on every object.
resource "aws_s3_object" "public_sample" {
  bucket                 = aws_s3_bucket.data.id
  key                    = "public/notice.txt"
  content                = "Public classification sample. Lorem ipsum. No sensitive data.\n"
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.data.arn

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.data]
}

resource "aws_s3_object" "internal_sample" {
  bucket                 = aws_s3_bucket.data.id
  key                    = "internal/runbook.txt"
  content                = "Internal classification sample. Lorem ipsum. No sensitive data.\n"
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.data.arn

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.data]
}

resource "aws_s3_object" "confidential_sample" {
  bucket                 = aws_s3_bucket.data.id
  key                    = "confidential/customer-records.txt"
  content                = "Confidential classification sample. Lorem ipsum. Synthetic records only.\n"
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.data.arn

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.data]
}
