variable "project_id" {
  description = "ID del proyecto de GCP donde corre la función."
  type        = string
}

variable "region" {
  description = "Región de Cloud Run y del bucket (la misma que el tópico: DI-002)."
  type        = string
}

variable "topic_name" {
  description = "Tópico compartido de eventos de dominio (salida de modules/pubsub)."
  type        = string
}

variable "image" {
  description = "Imagen completa de fn-documentos en Artifact Registry, con tag. La construye el CI del repo fn-documentos."
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

variable "otlp_endpoint" {
  description = "Endpoint OTLP/HTTP de Grafana Cloud (el mismo del módulo observability)."
  type        = string
}

variable "otlp_headers_secret" {
  description = "Secreto con los encabezados OTLP (credenciales de Grafana Cloud). Se reutiliza el de fn-notificaciones: son las mismas credenciales."
  type        = string
  default     = "fn-notificaciones-otlp-headers"
}

variable "invoker_service_accounts" {
  description = "Cuentas de servicio que pueden llamar a la función por HTTP (CoreTransaccional, para pedir el enlace del documento)."
  type        = list(string)
  default     = []
}

variable "web_origins" {
  description = "Orígenes de la web que pueden cargar el PDF con fetch desde el enlace firmado (CORS del bucket)."
  type        = list(string)
  default     = ["https://solventa4bits.com", "https://dev.solventa4bits.com"]
}

variable "max_instances" {
  description = "Tope de instancias. Generar un PDF es breve y el volumen es bajo."
  type        = number
  default     = 2
}

variable "max_delivery_attempts" {
  description = "Entregas fallidas de Pub/Sub antes de mandar el mensaje a la cola de mensajes fallidos (mínimo 5 en Pub/Sub)."
  type        = number
  default     = 5
}

variable "ci_service_account" {
  description = "Cuenta de servicio del CI (Workload Identity Federation de GitHub) que despliega nuevas imágenes de la función desde la rama develop. Solo puede actualizar este servicio de Cloud Run."
  type        = string
  default     = "ci-image-publisher@solventa-admin.iam.gserviceaccount.com"
}
