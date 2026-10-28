variable "environment" {
  description = "Nombre del entorno de despliegue."
  type        = string
}

variable "data_bucket_arn_s3" {
  description = "ARN del bucket S3 Bronze."
  type        = string
}