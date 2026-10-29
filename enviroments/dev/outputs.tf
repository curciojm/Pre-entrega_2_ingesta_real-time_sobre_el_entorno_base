output "vpc_id" {
  description = "ID de la VPC del entorno de desarrollo."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas."
  value       = module.network.private_subnet_ids
}

output "streaming_processor_role_arn" {
  description = "ARN del rol de ejecución de Flink."
  value       = module.identity.streaming_processor_role_arn
}

output "audit_role_arn" {
  description = "ARN del rol de auditoría."
  value       = module.identity.audit_role_arn
}

output "kinesis_ingest_stream_arn" {
  description = "ARN del stream de Kinesis"
  value       = module.ingestion.kinesis_ingest_stream_arn
}

output "firehose_delivery_stream_arn" {
  description = "ARN del delivery stream de Firehose"
  value       = module.ingestion.firehose_delivery_stream_arn
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3 Data Lake Bronze"
  value       = aws_s3_bucket.bronze.arn
}

output "cloudwatch_metric_alarm_arn" {
  description = "ARN de la alarma de throttling de escritura de Kinesis"
  value       = aws_cloudwatch_metric_alarm.kinesis_write_throttling.arn
}

output "cloudwatch_metric_alarm_read_arn" {
  description = "ARN de la alarma de throttling de lectura de Kinesis"
  value       = aws_cloudwatch_metric_alarm.kinesis_read_throttling.arn
}