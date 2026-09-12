output "secret_ids" {
  description = "Nombre de cada secreto creado, por clave del mapa de entrada."
  value       = { for k, s in google_secret_manager_secret.this : k => s.secret_id }
}

output "reader_service_account_emails" {
  description = "Correo de la cuenta de servicio de Google (GSA) dedicada a cada secreto, por clave del mapa de entrada — es el valor que va en la anotación `iam.gke.io/gcp-service-account` de la KSA correspondiente, en el repo `deploy`."
  value       = { for k, sa in google_service_account.reader : k => sa.email }
}
