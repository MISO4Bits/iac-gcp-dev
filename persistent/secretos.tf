# Contenedores de los secretos cuyo VALOR se sube a mano (`gcloud secrets versions add`).
# Viven aquí, en el estado que nunca se destruye por sesión, para no tener que volver a
# subirlos (ni dudar si quedaron bien) cada vez que se recrea el ambiente. Los módulos de la
# raíz (`secrets`, `fn-notificaciones`, `observability`) solo los referencian por nombre y
# les dan acceso; ninguno los crea.
#
# Orden en un proyecto nuevo: aplicar esto, subir los valores, y luego aplicar la raíz.

resource "google_project_service" "secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  # La raíz también la habilita (módulo secrets); ninguno de los dos la deshabilita al destruir.
  disable_on_destroy = false
}

locals {
  secretos_manuales = toset([
    "identity-platform-api-key",
    "grafana-cloud-otlp-token",
    "resend-api-key",
    "fn-notificaciones-otlp-headers",
  ])
}

resource "google_secret_manager_secret" "manual" {
  for_each = local.secretos_manuales

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}
