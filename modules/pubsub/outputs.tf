output "topic_name" {
  description = "Nombre del tópico compartido de eventos de dominio."
  value       = google_pubsub_topic.domain_events.name
}

output "service_account_emails" {
  description = "Correo de la GSA dedicada a cada componente, por clave del mapa `service_accounts` — es el valor que va en la anotación `iam.gke.io/gcp-service-account` de la KSA correspondiente, en el repo `deploy`."
  value       = { for k, sa in google_service_account.this : k => sa.email }
}

output "subscription_names" {
  description = "Nombre de cada suscripción creada, por clave plana \"componente.suscripción\" (ver local.suscripciones)."
  value       = { for k, s in google_pubsub_subscription.this : k => s.name }
}
