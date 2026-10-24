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

variable "fn_notificaciones_image_tag" {
  description = "Tag de la imagen de fn-notificaciones a desplegar (`develop` o un `sha-<corto>` publicado por el CI de fn-notificaciones). Con un tag fijo como `develop`, Cloud Run no crea revisión nueva: para desplegar una build nueva pasa su `sha-...`."
  type        = string
  default     = "develop"
}

variable "fn_documentos_image_tag" {
  description = "Tag de la imagen de fn-documentos a desplegar (`develop` o un `sha-<corto>` publicado por el CI de fn-documentos)."
  type        = string
  default     = "develop"
}

variable "fn_notificaciones_reply_to" {
  description = "Alias al que responde quien contesta los correos (Reply-To). Vacío = sin Reply-To."
  type        = string
  default     = ""
}

variable "fn_notificaciones_sender_backend" {
  description = "`resend` envía correos reales; `logging` solo registra que los habría enviado."
  type        = string
  default     = "resend"
}

variable "artifact_registry_repository_id" {
  description = "Nombre del repositorio de Artifact Registry compartido en admin (DI-004)."
  type        = string
  default     = "solventa"
}
