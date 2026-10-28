module "network" {
  source = "../../modules/network"

  environment = var.environment
  region      = var.region
  cidr_vpc    = var.cidr_vpc
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr

}

module "identity" {
  source = "../../modules/identity"

  environment      = var.environment
  data_bucket_name = var.data_bucket_name
}
  
resource "aws_cloudwatch_metric_alarm" "kinesis_write_throttling" {
  alarm_name          = "kinesis-write-throughput-exceeded"
  alarm_description   = "Detecta exceso de capacidad de escritura en Kinesis"
  namespace           = "AWS/Kinesis"
  metric_name         = "WriteProvisionedThroughputExceeded"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    StreamName = module.ingestion.aws_kinesis_stream.kinesis_ingest_stream.name
  }
}

# Bronze datos puros, silver ya limpios
resource "aws_s3_bucket" "bronze" {
  bucket = var.data_bucket_name

  tags = {
    Name        = "${var.environment}-bronze"
    Environment = var.environment
    Layer       = "Bronze"
  }
}

module "ingestion" {
  source = "../../modules/ingestion"

  environment      = var.environment
  data_bucket_name = var.data_bucket_name
  data_bucket_arn_s3  = aws_s3_bucket.bronze.arn
}