# Portal web de clientes (fe-web, Angular estático) — alojado FUERA del cluster:
# bucket de Cloud Storage detrás de un balanceador HTTPS global con Cloud CDN.
# Vive en este estado (no se destruye por sesión) porque el portal debe estar
# en línea aunque el cluster esté apagado. Decisión: DI-012.
#
# Despliegue: el CI de fe-web (rama develop) hace `ng build` y sincroniza la
# salida al bucket. index.html se sube con Cache-Control: no-cache y los assets
# con hash como immutable — por eso no hace falta invalidar la caché de la CDN.

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

# --- Almacenamiento ---------------------------------------------------------

resource "google_storage_bucket" "portal" {
  project  = var.project_id
  name     = "${var.project_id}-portal"
  location = var.region

  uniform_bucket_level_access = true
  # Se puede recrear desde el CI en cualquier momento: no hay datos que proteger.
  force_destroy = true

  website {
    main_page_suffix = "index.html"
  }
}

resource "google_storage_bucket_iam_member" "portal_public_read" {
  bucket = google_storage_bucket.portal.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# El CI de fe-web (Workload Identity Federation, repo MISO4Bits/fe-web) publica
# el build. Permiso solo sobre este bucket.
resource "google_storage_bucket_iam_member" "portal_ci_writer" {
  bucket = google_storage_bucket.portal.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.portal_ci_service_account}"
}

resource "google_compute_backend_bucket" "portal" {
  project     = var.project_id
  name        = "portal"
  bucket_name = google_storage_bucket.portal.name
  enable_cdn  = true

  cdn_policy {
    # Respeta el Cache-Control que pone el CI (ver arriba).
    cache_mode = "USE_ORIGIN_HEADERS"
  }

  depends_on = [google_project_service.compute]
}

# --- IP y certificado -------------------------------------------------------

resource "google_compute_global_address" "portal" {
  project = var.project_id
  name    = "portal"

  depends_on = [google_project_service.compute]
}

resource "google_certificate_manager_certificate" "portal" {
  project     = var.project_id
  name        = "portal"
  description = "Certificado gestionado del portal: ${join(", ", var.portal_domains)}"

  managed {
    domains = var.portal_domains
  }

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate_map" "portal" {
  project = var.project_id
  name    = "portal-map"

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate_map_entry" "portal" {
  for_each = toset(var.portal_domains)

  project      = var.project_id
  name         = "portal-${replace(each.value, ".", "-")}"
  map          = google_certificate_manager_certificate_map.portal.name
  hostname     = each.value
  certificates = [google_certificate_manager_certificate.portal.id]
}

# --- Balanceador ------------------------------------------------------------

resource "google_compute_url_map" "portal" {
  project         = var.project_id
  name            = "portal"
  default_service = google_compute_backend_bucket.portal.id

  # SPA: una ruta profunda (/cotizar/paso-2) no existe como objeto en el bucket;
  # se responde index.html con 200 para que el enrutador de Angular la resuelva.
  default_custom_error_response_policy {
    error_service = google_compute_backend_bucket.portal.id

    error_response_rule {
      match_response_codes   = ["404"]
      path                   = "/index.html"
      override_response_code = 200
    }
  }
}

resource "google_compute_target_https_proxy" "portal" {
  project         = var.project_id
  name            = "portal"
  url_map         = google_compute_url_map.portal.id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.portal.id}"
}

resource "google_compute_global_forwarding_rule" "portal_https" {
  project               = var.project_id
  name                  = "portal-https"
  ip_address            = google_compute_global_address.portal.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.portal.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# HTTP -> HTTPS
resource "google_compute_url_map" "portal_redirect" {
  project = var.project_id
  name    = "portal-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "portal" {
  project = var.project_id
  name    = "portal-http"
  url_map = google_compute_url_map.portal_redirect.id
}

resource "google_compute_global_forwarding_rule" "portal_http" {
  project               = var.project_id
  name                  = "portal-http"
  ip_address            = google_compute_global_address.portal.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.portal.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
