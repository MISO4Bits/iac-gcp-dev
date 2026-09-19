# Cluster de GKE Autopilot del ambiente dev. Un solo cluster regional en la
# región primaria (DI-002: São Paulo) — dev no necesita alta disponibilidad
# multi-región, esa réplica es solo para prod.

resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"

  # El usuario quiere el proyecto en cero total al destruir (aceptando que
  # el próximo apply sea más lento por tener que re-habilitar APIs).
  disable_on_destroy = true
}

# Cuenta de servicio dedicada para los nodos administrados por Autopilot,
# en vez de la cuenta de servicio de Compute Engine por defecto (mínimo
# privilegio). El permiso roles/artifactregistry.reader sobre el repo de
# `admin` se otorga en el main.tf de la raíz, porque conecta un recurso de
# este módulo con un recurso de otro proyecto (DI-004, pendiente abierto).
resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "gke-autopilot-nodes"
  display_name = "GKE Autopilot - nodos"
  description  = "Cuenta de servicio de los nodos administrados por el cluster de GKE Autopilot de dev."
}

# Rol que GKE exige a una cuenta de servicio de nodos PERSONALIZADA (no a la
# de Compute Engine por defecto): logging, métricas y lo básico del nodo.
# Sin esto la consola de GKE marca el cluster como degradado ("Grant
# roles/container.defaultNodeServiceAccount role to Node service account to
# allow for non-degraded operations", visto 2026-09-19) — el módulo solo
# le daba lectura del Artifact Registry (root main.tf), nada más.
resource "google_project_iam_member" "gke_nodes_default_role" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.cluster_name
  location = var.region

  enable_autopilot = true

  # Requisito explícito del usuario: destruir el cluster sin protección.
  deletion_protection = false

  release_channel {
    channel = "REGULAR"
  }

  # Ya viene habilitada por defecto en Autopilot; explícita para que quede
  # documentado que BFF Web y los servicios de dominio se exponen dentro
  # del cluster vía Gateway API (recurso Gateway/HTTPRoute en el repo
  # `deploy`), no vía el Ingress clásico.
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  # Add-on de Secret Manager (interfaz de almacenamiento de contenedores,
  # CSI) — permite montar secretos como archivo dentro de los pods sin
  # instalar ni mantener un controlador aparte (decisión del usuario,
  # 2026-09-12, sobre External Secrets Operator y sobre HashiCorp Vault
  # propio). Rotación automática para que un pod recoja una versión nueva
  # del secreto sin necesidad de reiniciar.
  secret_manager_config {
    enabled = true

    rotation_config {
      enabled = true
    }
  }

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.gke_nodes.email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    }
  }

  depends_on = [google_project_service.container]
}
