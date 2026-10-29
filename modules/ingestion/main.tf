
resource "aws_iam_role" "firehose_role" {
  name = "${var.environment}-firehose-delivery-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "firehose_policy" {
  name = "${var.environment}-firehose-kinesis-s3-policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      # Firehose puede leer del stream de Kinesis
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.kinesis_ingest_stream.arn
      },

      # Permisos sobre el bucket S3 Bronze
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = var.data_bucket_arn_s3
      },

      # Permisos sobre los objetos del bucket
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetObject", # s el permiso para leer u obtener un objeto almacenado en S3. Por ejemplo, descargar un archivo JSON o Parquet de un bucket
          "s3:PutObject"
        ]
        Resource = "${var.data_bucket_arn_s3}/*"
      },

      # Permiso para publicar eventos en el stream de logs
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = aws_cloudwatch_log_stream.firehose.arn
      },

      # Permiso para describir streams de logs del grupo
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogStreams"
        ]
        Resource = aws_cloudwatch_log_group.firehose.arn
      }
    ]
  })
}

resource "aws_kinesis_stream" "kinesis_ingest_stream" {
  name             = "${var.environment}-kinesis-ingest-stream"
  shard_count      = 2
  retention_period = 48
  encryption_type  = "KMS"
  kms_key_id = "alias/aws/kinesis"

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.environment}-firehose-delivery-stream"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_stream" "firehose" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

resource "aws_kinesis_firehose_delivery_stream" "firehose_delivery_stream" {
  name        = "${var.environment}-firehose-delivery-stream"
  destination = "extended_s3"

  # Origen: Kinesis Data Streams
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.kinesis_ingest_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  # Destino: S3 Bronze
  extended_s3_configuration {
    bucket_arn = var.data_bucket_arn_s3
    role_arn   = aws_iam_role.firehose_role.arn
    # esto define la estructura del lake
    prefix = "bronze/ingestion/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    error_output_prefix = "bronze/errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"


    buffering_size     = 5
    buffering_interval = 60

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose.name
    }
  }

  # Asegura que la política esté asociada antes de crear Firehose
  depends_on = [
    aws_iam_role_policy.firehose_policy
  ]
}
