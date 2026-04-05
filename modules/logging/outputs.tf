output "cloudtrail_arn" {
  value = aws_cloudtrail.org_trail.arn
}

output "cloudtrail_s3_bucket_name" {
  value = aws_s3_bucket.cloudtrail_logs.id
}

output "cloudtrail_s3_bucket_arn" {
  value = aws_s3_bucket.cloudtrail_logs.arn
}

output "config_s3_bucket_name" {
  value = aws_s3_bucket.config_logs.id
}

output "config_s3_bucket_arn" {
  value = aws_s3_bucket.config_logs.arn
}

output "access_logs_bucket_name" {
  value = aws_s3_bucket.access_logs.id
}

output "config_recorder_id" {
  value = var.enable_config_recorder ? aws_config_configuration_recorder.main[0].id : ""
}
