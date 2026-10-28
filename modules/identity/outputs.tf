output "streaming_processor_role_arn" {
  description = "ARN del rol de ejecución de Flink."
  value       = aws_iam_role.streaming_processor_role.arn
}

output "audit_role_arn" {
  description = "ARN del rol de auditoría."
  value       = aws_iam_role.audit_role.arn
}