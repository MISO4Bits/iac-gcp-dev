variable "project_id" {
  description = "ID del proyecto de GCP de dev — este estado vive aquí, no en admin (ver README: el Gateway de GKE no acepta direcciones de otro proyecto)."
  type        = string
  default     = "solventa-dev"
}

variable "region" {
  description = "Región del proyecto (solo para la configuración del provider — los recursos de este estado son globales)."
  type        = string
  default     = "southamerica-east1"
}

variable "edge_domain" {
  description = "Dominio público estable del punto de entrada único del ambiente (API Gateway/APISIX, DI-011) — dev.solventa4bits.com, asignado en DI-010. No es un dominio de bff-web: ningún BFF ni la API de socios tienen dirección pública propia."
  type        = string
  default     = "dev.solventa4bits.com"
}
