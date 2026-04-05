output "budget_id" {
  value = aws_budgets_budget.monthly.id
}

output "budget_alerts_topic_arn" {
  value = aws_sns_topic.budget_alerts.arn
}
