output "kinesis_ingest_stream_arn" {
  description = "ARN del stream de Kinesis"
  value       = aws_kinesis_stream.kinesis_ingest_stream.arn
}

output "kinesis_ingest_stream_name" {
  description = "Nombre del stream de Kinesis"
  value       = aws_kinesis_stream.kinesis_ingest_stream.name
}

output "firehose_delivery_stream_arn" {
  description = "ARN del stream de entrega de Firehose"
  value       = aws_kinesis_firehose_delivery_stream.firehose_delivery_stream.arn
}

