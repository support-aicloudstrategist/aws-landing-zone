output "config_rule_arns" {
  description = "ARNs of all Config rules"
  value = {
    root_mfa              = aws_config_config_rule.root_mfa.arn
    iam_password_policy   = aws_config_config_rule.iam_password_policy.arn
    cloudtrail_enabled    = aws_config_config_rule.cloudtrail_enabled.arn
    s3_encryption         = aws_config_config_rule.s3_encryption.arn
    s3_public_read        = aws_config_config_rule.s3_public_read.arn
    s3_public_write       = aws_config_config_rule.s3_public_write.arn
    ebs_encrypted         = aws_config_config_rule.ebs_encrypted.arn
    rds_encrypted         = aws_config_config_rule.rds_encrypted.arn
    vpc_flow_logs         = aws_config_config_rule.vpc_flow_logs.arn
    multi_region_trail    = aws_config_config_rule.multi_region_cloudtrail.arn
    restricted_ssh        = aws_config_config_rule.restricted_ssh.arn
    restricted_ports      = aws_config_config_rule.restricted_common_ports.arn
  }
}
