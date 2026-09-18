# Bus de eventos de dominio (mensajería confirmada en CLAUDE.md — múltiples
# productores y consumidores, no una cola simple). Un único tópico
# compartido ("solventa-dominio"), igual que `svc-core/app/adapters/pubsub.py`
# ya asume por defecto: cada evento se publica con el tipo de evento como
# atributo del mensaje (`tipo`), y cada consumidor filtra por ese atributo
# en su propia suscripción en vez de tener un tópico por tipo de evento —
# menos infraestructura que administrar, mismo patrón que Grafana Cloud usa
# para logs/métricas (un canal, filtrado por metadata).
#
# Una GSA de mínimo privilegio por componente (no por rol) enlazada por
# Workload Identity Federation a la KSA del pod — mismo patrón que
# modules/secrets. Una GSA por componente y no por rol porque una KSA solo
# puede federarse con una GSA a la vez: un componente que publica y además
# consume (Perfilamiento) necesita las dos cosas en la MISMA GSA.

resource "google_project_service" "pubsub" {
  project = var.project_id
  service = "pubsub.googleapis.com"

  disable_on_destroy = true
}

resource "google_pubsub_topic" "domain_events" {
  project = var.project_id
  name    = var.topic_name

  depends_on = [google_project_service.pubsub]
}

resource "google_service_account" "this" {
  for_each = var.service_accounts

  project      = var.project_id
  account_id   = "${each.key}-pubsub"
  display_name = "Pub/Sub de ${each.key}"
  description  = "Cuenta de servicio de mínimo privilegio: solo los roles de Pub/Sub que ${each.key} efectivamente necesita sobre el tópico ${var.topic_name}."
}

resource "google_service_account_iam_member" "workload_identity" {
  for_each = var.service_accounts

  service_account_id = google_service_account.this[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.ksa_namespace}/${each.value.ksa_name}]"
}

resource "google_pubsub_topic_iam_member" "publisher" {
  for_each = { for k, sa in var.service_accounts : k => sa if sa.publica }

  project = var.project_id
  topic   = google_pubsub_topic.domain_events.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.this[each.key].email}"
}

locals {
  # Aplana el mapa anidado (componente -> suscripciones) a un mapa plano
  # "componente.suscripcion" -> {..., sa_key}, para poder usar for_each
  # sobre las suscripciones individuales sin perder de qué componente es
  # cada una (necesario para el IAM binding de abajo).
  suscripciones = merge([
    for sa_key, sa in var.service_accounts : {
      for sub_key, sub in sa.suscripciones :
      "${sa_key}.${sub_key}" => merge(sub, { sa_key = sa_key })
    }
  ]...)
}

resource "google_pubsub_subscription" "this" {
  for_each = local.suscripciones

  project = var.project_id
  name    = each.value.subscription_id
  topic   = google_pubsub_topic.domain_events.name

  filter                = try(each.value.filter, null)
  ack_deadline_seconds  = try(each.value.ack_deadline_seconds, 20)
  retain_acked_messages = false
  # 1 día de retención de mensajes no confirmados — suficiente para que el
  # servicio se recupere de un reinicio/incidente sin perder eventos, sin
  # acumular costo de retención indefinido.
  message_retention_duration = "86400s"

  # Sin política de expiración: una suscripción de un servicio productivo no
  # debe desaparecer sola por inactividad (default de Pub/Sub: 31 días).
  expiration_policy {
    ttl = ""
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

resource "google_pubsub_subscription_iam_member" "subscriber" {
  for_each = local.suscripciones

  project      = var.project_id
  subscription = google_pubsub_subscription.this[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.this[each.value.sa_key].email}"
}
