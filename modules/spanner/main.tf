# Motor de datos único para los 5 servicios síncronos, en dos instancias
# separadas (DI-009). En dev ambas son regionales (southamerica-east1) —
# la réplica multi-región SP+Santiago del Core es una decisión solo de
# prod (DI-002), acá no aplica.

resource "google_project_service" "spanner" {
  project = var.project_id
  service = "spanner.googleapis.com"

  disable_on_destroy = true
}

# Instancia de CoreTransaccional (identidad, suscripción, pólizas, pagos y
# recaudo, siniestros y asistencia) — una sola base de datos, consistencia
# transaccional fuerte entre sus submódulos.
resource "google_spanner_instance" "core" {
  project      = var.project_id
  name         = "solventa-core"
  display_name = "Solventa Core (dev)"
  config       = "regional-${var.region}"

  processing_units = var.processing_units

  depends_on = [google_project_service.spanner]
}

resource "google_spanner_database" "core" {
  project  = var.project_id
  instance = google_spanner_instance.core.name
  name     = "core"

  deletion_protection = false
}

# Instancia compartida para los 4 servicios que no son Core — comparten
# cómputo (processing units), no esquema: una base de datos por servicio.
resource "google_spanner_instance" "services" {
  project      = var.project_id
  name         = "solventa-services"
  display_name = "Solventa Services (dev)"
  config       = "regional-${var.region}"

  processing_units = var.processing_units

  depends_on = [google_project_service.spanner]
}

resource "google_spanner_database" "services" {
  for_each = toset(var.service_database_names)

  project  = var.project_id
  instance = google_spanner_instance.services.name
  name     = each.value

  deletion_protection = false
}
