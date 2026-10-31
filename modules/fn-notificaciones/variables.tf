variable "project_id" {
  description = "ID del proyecto de GCP donde corre la función."
  type        = string
}

variable "region" {
  description = "Región de Cloud Run (la misma que el tópico: DI-002)."
  type        = string
}

variable "topic_name" {
  description = "Tópico compartido de eventos de dominio (salida de modules/pubsub)."
  type        = string
}

variable "image" {
  description = "Imagen completa de fn-notificaciones en Artifact Registry, con tag (por ejemplo `.../solventa/fn-notificaciones:sha-1a2b3c4`). La construye el CI del repo fn-notificaciones."
  type        = string
}

variable "artifact_registry_project" {
  description = "Proyecto dueño del repositorio de Artifact Registry compartido (admin, DI-004)."
  type        = string
}

variable "artifact_registry_repository" {
  description = "Repositorio de Artifact Registry del que Cloud Run lee la imagen."
  type        = string
}

variable "remitente" {
  description = "Remitente de los correos (dominio verificado en Resend)."
  type        = string
  default     = "Solventa <no-reply@notificaciones.solventa4bits.com>"
}

variable "reply_to" {
  description = "Dirección a la que responde quien contesta el correo (alias de reenvío del dominio). Vacío = sin Reply-To."
  type        = string
  default     = ""
}

variable "sender_backend" {
  description = "`resend` envía de verdad; `logging` solo registra (útil mientras no exista la clave de Resend)."
  type        = string
  default     = "resend"
}

variable "push_backend" {
  description = "`fcm` entrega los avisos push por Firebase Cloud Messaging; `logging` solo registra."
  type        = string
  default     = "fcm"
}

variable "otlp_endpoint" {
  description = "Endpoint OTLP/HTTP de Grafana Cloud (el mismo del módulo observability)."
  type        = string
}

variable "adjuntos_bucket" {
  description = "Bucket del que la función puede leer los archivos que los correos llevan adjuntos (el de los PDF de fn-documentos). Vacío = sin adjuntos."
  type        = string
  default     = ""
}

variable "max_instances" {
  description = "Tope de instancias. El volumen de correos es bajo; el tope también protege el límite diario del plan gratuito de Resend."
  type        = number
  default     = 2
}

variable "max_delivery_attempts" {
  description = "Entregas fallidas de Pub/Sub antes de mandar el mensaje a la cola de mensajes fallidos (mínimo 5 en Pub/Sub). Cada entrega ya incluye hasta 3 intentos de envío dentro de la función."
  type        = number
  default     = 5
}

variable "ci_service_account" {
  description = "Cuenta de servicio del CI (Workload Identity Federation de GitHub) que despliega nuevas imágenes de la función desde la rama develop. Solo puede actualizar este servicio de Cloud Run."
  type        = string
  default     = "ci-image-publisher@solventa-admin.iam.gserviceaccount.com"
}
