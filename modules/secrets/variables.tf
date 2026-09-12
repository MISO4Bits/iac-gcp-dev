variable "project_id" {
  description = "ID del proyecto de GCP donde se crean los secretos."
  type        = string
}

variable "secrets" {
  description = <<-EOT
    Un secreto de Secret Manager por entrada, con la cuenta de Kubernetes
    (KSA) autorizada a leerlo vía Workload Identity Federation.

    La clave del mapa se usa tal cual como `account_id` de la cuenta de
    servicio de Google (GSA) dedicada a ese secreto — debe cumplir las
    reglas de GCP para account_id: minúsculas, dígitos y guiones, 6-30
    caracteres.
  EOT
  type = map(object({
    secret_id     = string
    ksa_namespace = string
    ksa_name      = string
  }))
  default = {}
}
