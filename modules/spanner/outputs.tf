output "core_instance_name" {
  description = "Nombre de la instancia de Spanner de CoreTransaccional."
  value       = google_spanner_instance.core.name
}

output "core_database_name" {
  description = "Nombre de la base de datos de CoreTransaccional."
  value       = google_spanner_database.core.name
}

output "services_instance_name" {
  description = "Nombre de la instancia compartida de Spanner para Cotización, Perfilamiento, Productos y Distribución."
  value       = google_spanner_instance.services.name
}

output "services_database_names" {
  description = "Nombres de las bases de datos de la instancia compartida, una por servicio."
  value       = [for db in google_spanner_database.services : db.name]
}
