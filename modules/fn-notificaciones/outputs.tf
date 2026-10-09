output "service_url" {
  description = "URL de Cloud Run de la función (sin acceso público)."
  value       = google_cloud_run_v2_service.this.uri
}

output "runtime_service_account_email" {
  description = "Cuenta de servicio con la que corre la función."
  value       = google_service_account.runtime.email
}

output "subscription_name" {
  description = "Suscripción push que invoca la función."
  value       = google_pubsub_subscription.this.name
}

output "dead_letter_subscription_name" {
  description = "Suscripción donde se retienen los mensajes que agotaron sus entregas."
  value       = google_pubsub_subscription.dlq.name
}

output "secret_ids" {
  description = "Secretos que hay que poblar a mano con `gcloud secrets versions add` (resend-api-key y fn-notificaciones-otlp-headers)."
  value       = [for s in google_secret_manager_secret.this : s.secret_id]
}
