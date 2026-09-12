variable "project_id" {
  description = "ID del proyecto de GCP donde se crea el cluster."
  type        = string
}

variable "region" {
  description = "Región del cluster de GKE Autopilot."
  type        = string
}

variable "cluster_name" {
  description = "Nombre del cluster de GKE Autopilot."
  type        = string
  default     = "solventa-dev"
}
