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
  name = "${var.environment}-firehose-kinesis-s3-role"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:ListShards",
          "kinesis:SubscribeToShard"
        ]
        Resource = aws_kinesis_stream.kinesis_ingest_stream.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          var.data_bucket_arn_s3,
          "${var.data_bucket_arn_s3}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kinesis_stream" "kinesis_ingest_stream" {
  name = "${var.environment}-kinesis-ingest-stream"
  shard_count      = 2
  retention_period = 48

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
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

    prefix = "bronze/ingestion/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    buffering_size     = 5
    buffering_interval = 60
  }
}