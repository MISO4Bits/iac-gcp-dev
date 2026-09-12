# IP estática y certificado gestionado para el punto de entrada único del
# ambiente (el API Gateway/APISIX, DI-011 — corre dentro del cluster, no es
# un producto gestionado). Ver README.md de esta carpeta: nunca se destruye
# por sesión, a diferencia de todo lo demás en este repo.
#
# Nombre físico heredado: el recurso de IP se llama "bff-web-dev" en GCP
# porque se creó originalmente pensando en una dirección propia para
# bff-web (antes de DI-011). Cambiar ese nombre forzaría destruir y crear
# una IP nueva — se decidió conservar el nombre físico y solo corregir su
# propósito real (ahora es la IP del API Gateway, compartida por todos los
# BFF) en el nombre de los recursos de Terraform y en el dominio.

resource "google_project_service" "certificatemanager" {
  project = var.project_id
  service = "certificatemanager.googleapis.com"

  # Este estado no se destruye por sesión — no aplica el criterio de
  # "dejar el proyecto en cero" que sí usa la raíz del repo.
  disable_on_destroy = false
}

resource "google_compute_global_address" "edge" {
  project = var.project_id
  name    = "bff-web-dev" # nombre físico heredado, ver nota de arriba
}

# Certificado gestionado por Google, autorizado por balanceador de carga
# (sin dns_authorizations): exige que el registro DNS del dominio ya
# apunte a la IP de arriba y que un Gateway real la esté sirviendo antes
# de pasar de PROVISIONING a ACTIVE.
resource "google_certificate_manager_certificate" "edge" {
  project     = var.project_id
  name        = "edge-dev"
  description = "Certificado gestionado para ${var.edge_domain}"

  managed {
    domains = [var.edge_domain]
  }

  depends_on = [google_project_service.certificatemanager]
}

# El Gateway de Kubernetes NO referencia el certificado directamente
# (tls.certificateRefs) — usa la anotación networking.gke.io/certmap
# apuntando a este mapa. Son mecanismos mutuamente excluyentes.
resource "google_certificate_manager_certificate_map" "edge" {
  project = var.project_id
  name    = "edge-dev-map"

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate_map_entry" "edge" {
  project      = var.project_id
  name         = "edge-dev"
  map          = google_certificate_manager_certificate_map.edge.name
  hostname     = var.edge_domain
  certificates = [google_certificate_manager_certificate.edge.id]
}
