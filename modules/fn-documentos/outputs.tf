output "service_url" {
  description = "URL de Cloud Run de la función (sin acceso público). Es la audiencia con la que Core firma su llamada: va en CORE_DOCUMENTO_BASE_URL."
  value       = google_cloud_run_v2_service.this.uri
}

output "runtime_service_account_email" {
  description = "Cuenta de servicio con la que corre la función."
  value       = google_service_account.runtime.email
}

output "bucket_name" {
  description = "Bucket privado donde quedan los PDF de las pólizas."
  value       = google_storage_bucket.polizas.name
}

output "subscription_name" {
  description = "Suscripción push que invoca la función con PolizaEmitida."
  value       = google_pubsub_subscription.this.name
}

output "dead_letter_subscription_name" {
  description = "Suscripción donde se retienen los mensajes que agotaron sus entregas."
  value       = google_pubsub_subscription.dlq.name
}
