# IP estática y certificado gestionado para el Gateway de bff-web. Ver
# README.md de esta carpeta: nunca se destruye por sesión, a diferencia de
# todo lo demás en este repo.

resource "google_project_service" "certificatemanager" {
  project = var.project_id
  service = "certificatemanager.googleapis.com"

  # Este estado no se destruye por sesión — no aplica el criterio de
  # "dejar el proyecto en cero" que sí usa la raíz del repo.
  disable_on_destroy = false
}

resource "google_compute_global_address" "bff_web" {
  project = var.project_id
  name    = "bff-web-dev"
}

# Certificado gestionado por Google, autorizado por balanceador de carga
# (sin dns_authorizations): exige que el registro DNS del dominio ya
# apunte a la IP de arriba y que un Gateway real la esté sirviendo antes
# de pasar de PROVISIONING a ACTIVE.
resource "google_certificate_manager_certificate" "bff_web" {
  project     = var.project_id
  name        = "bff-web-dev"
  description = "Certificado gestionado para ${var.bff_web_domain}"

  managed {
    domains = [var.bff_web_domain]
  }

  depends_on = [google_project_service.certificatemanager]
}

# El Gateway de Kubernetes NO referencia el certificado directamente
# (tls.certificateRefs) — usa la anotación networking.gke.io/certmap
# apuntando a este mapa. Son mecanismos mutuamente excluyentes.
resource "google_certificate_manager_certificate_map" "bff_web" {
  project = var.project_id
  name    = "bff-web-dev-map"

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate_map_entry" "bff_web" {
  project      = var.project_id
  name         = "bff-web-dev"
  map          = google_certificate_manager_certificate_map.bff_web.name
  hostname     = var.bff_web_domain
  certificates = [google_certificate_manager_certificate.bff_web.id]
}
