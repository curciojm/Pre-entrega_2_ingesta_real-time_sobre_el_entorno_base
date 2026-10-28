terraform {
  backend "s3" {
    bucket         = "data-engineering-state-bucket"
    key            = "Pre-entrega_2_ingesta_real-time_sobre_el_entorno_base/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}