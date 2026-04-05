output "security_hub_arn" {
  value = var.enable_security_hub ? aws_securityhub_account.main[0].arn : ""
}

output "access_analyzer_arn" {
  value = aws_accessanalyzer_analyzer.org_analyzer.arn
}

output "security_findings_topic_arn" {
  value = aws_sns_topic.security_findings.arn
}
