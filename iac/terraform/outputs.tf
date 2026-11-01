output "bucket_name" {
  description = "The data bucket name."
  value       = aws_s3_bucket.data.id
}

output "bucket_arn" {
  description = "The data bucket ARN."
  value       = aws_s3_bucket.data.arn
}

output "kms_key_arn" {
  description = "The customer-managed key ARN."
  value       = aws_kms_key.data.arn
}

output "s3_vpc_endpoint_id" {
  description = "The S3 gateway VPC endpoint ID (used by the enforce_vpce guardrail)."
  value       = aws_vpc_endpoint.s3.id
}
