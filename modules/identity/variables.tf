variable "environment" {
  description = "Nombre del entorno de despliegue."
  type        = string
}

variable "data_bucket_name" {
  description = "Nombre del bucket de datos al que tendrá acceso el rol."
  type        = string
}