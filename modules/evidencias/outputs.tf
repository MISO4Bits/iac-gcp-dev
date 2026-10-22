output "bucket_name" {
  description = "Nombre del bucket de evidencias: va en CORE_ALMACEN_BUCKET del despliegue de svc-core, en el repo `deploy`."
  value       = google_storage_bucket.evidencias.name
}
