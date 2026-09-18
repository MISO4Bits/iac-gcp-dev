variable "project_id" {
  description = "ID del proyecto de GCP donde se crean el tópico y las suscripciones."
  type        = string
}

variable "topic_name" {
  description = "Nombre del tópico compartido de eventos de dominio."
  type        = string
  default     = "solventa-dominio"
}

variable "service_accounts" {
  description = <<-EOT
    Una cuenta de servicio de Google (GSA) de mínimo privilegio por
    componente que habla con el tópico compartido, enlazada por Workload
    Identity Federation a su cuenta de Kubernetes (KSA) — una GSA por
    componente, no por rol: un componente que publica y además consume
    (como Perfilamiento) usa la MISMA GSA para las dos cosas, porque una
    KSA solo puede federarse con una GSA a la vez. La GSA solo recibe los
    roles de IAM que efectivamente necesita (`publica`, y/o una entrada en
    `suscripciones`).

    La clave del mapa se usa como parte del `account_id` de la GSA (sufijo
    `-pubsub`) — debe cumplir las reglas de GCP para account_id:
    minúsculas, dígitos y guiones, resultado final 6-30 caracteres.
  EOT
  type = map(object({
    ksa_namespace = string
    ksa_name      = string
    publica       = optional(bool, false)
    suscripciones = optional(map(object({
      subscription_id      = string
      filter               = optional(string)
      ack_deadline_seconds = optional(number, 20)
    })), {})
  }))
  default = {}
}
