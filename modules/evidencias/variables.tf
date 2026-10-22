variable "project_id" {
  description = "ID del proyecto de Google Cloud Platform (GCP) del ambiente."
  type        = string
}

variable "region" {
  description = "Región del bucket. Debe ser la del clúster para no pagar tráfico entre regiones ni sumar latencia a cada foto."
  type        = string
}

variable "service_account_email" {
  description = "Correo de la cuenta de servicio de GCP (GSA) con la que svc-core accede al bucket mediante federación de identidades de carga de trabajo (Workload Identity Federation)."
  type        = string
}

variable "force_destroy" {
  description = "Permite destruir el bucket aunque tenga fotos. `true` en dev (se destruye con el clúster en cada sesión); `false` en prod."
  type        = bool
  default     = false
}
