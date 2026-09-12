variable "project_id" {
  description = "ID del proyecto de GCP donde se crean las instancias de Spanner."
  type        = string
}

variable "region" {
  description = "Región de ambas instancias de Spanner (config regional, sin réplica multi-región en dev)."
  type        = string
}

variable "processing_units" {
  description = "Processing units (PU) de cada instancia — mínimo de Spanner regional, DI-009."
  type        = number
  default     = 100
}

variable "service_database_names" {
  description = "Bases de datos de la instancia compartida `solventa-services`, una por servicio (DI-009)."
  type        = list(string)
  default = [
    "cotizacion",
    "perfilamiento",
    "productos",
    "distribucion",
  ]
}
