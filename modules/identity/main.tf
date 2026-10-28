resource "aws_iam_role" "streaming_processor_role" {
  name = "${var.environment}-streaming-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "kinesisanalytics.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "streaming_processor_policy" {
  name = "${var.environment}-streaming-processor-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = "arn:aws:s3:::${var.data_bucket_name}"

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "datos/streaming",
              "datos/streaming/*"
            ]
          }
        }
      },
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = "arn:aws:s3:::${var.data_bucket_name}/datos/streaming/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "streaming_processor" {
  role       = aws_iam_role.streaming_processor_role.name
  policy_arn = aws_iam_policy.streaming_processor_policy.arn
}

resource "aws_iam_role" "audit_role" {
  name = "${var.environment}-audit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy_attachment" "audit_readonly" {
  role       = aws_iam_role.audit_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}