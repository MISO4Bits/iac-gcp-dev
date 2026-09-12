variable "project_id" {
  description = "ID del proyecto de Google Cloud Platform (GCP) del ambiente dev (DI-003)."
  type        = string
  default     = "solventa-dev"
}

variable "region" {
  description = "Región primaria de GCP para los recursos de dev (DI-002: São Paulo). A diferencia de prod, dev no replica a Santiago — es un ambiente regional, ligero y económico."
  type        = string
  default     = "southamerica-east1"
}

variable "admin_project_id" {
  description = "ID del proyecto admin, dueño de los recursos compartidos entre ambientes (Artifact Registry, DI-004)."
  type        = string
  default     = "solventa-admin"
}

variable "artifact_registry_repository_id" {
  description = "Nombre del repositorio de Artifact Registry compartido en admin (DI-004)."
  type        = string
  default     = "solventa"
}
