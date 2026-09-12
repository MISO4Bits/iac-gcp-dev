# Raíz de composición: solo instancia módulos y conecta sus salidas. La
# lógica de cada recurso vive dentro de modules/.

module "gke" {
  source = "./modules/gke"

  project_id = var.project_id
  region     = var.region
}

module "argocd" {
  source = "./modules/argocd"

  depends_on = [module.gke]
}

module "spanner" {
  source = "./modules/spanner"

  project_id = var.project_id
  region     = var.region
}

# API Gateway del ambiente (DI-011) — Apache APISIX dentro del cluster.
# depends_on explícito porque el módulo solo usa el provider de helm (no
# referencia ninguna salida de module.gke), y ese provider se configura
# contra el endpoint del cluster — sin el cluster creado, el provider de
# helm no tiene contra qué autenticar.
module "api_gateway" {
  source = "./modules/api-gateway"

  depends_on = [module.gke]
}

# Identity Platform real (no el emulador local de Firebase Auth que usa
# bff-web por defecto en desarrollo) — necesario para que BFF Web autentique
# clientes de verdad. La API key resultante la genera Google; Terraform no
# la expone de forma confiable todavía (ver README), así que se sube a mano
# a Secret Manager después de aplicar.
resource "google_project_service" "identitytoolkit" {
  project = var.project_id
  service = "identitytoolkit.googleapis.com"

  disable_on_destroy = true
}

resource "google_identity_platform_config" "this" {
  project = var.project_id

  sign_in {
    email {
      enabled = true
    }
  }

  depends_on = [google_project_service.identitytoolkit]
}

# Secretos consumidos por pods vía el add-on de Secret Manager de GKE
# (módulo secrets). Hoy solo la API key de Identity Platform, para bff-web.
module "secrets" {
  source = "./modules/secrets"

  project_id = var.project_id

  secrets = {
    bff-web-secrets = {
      secret_id     = "identity-platform-api-key"
      ksa_namespace = "bff-web"
      ksa_name      = "bff-web"
    }
  }
}

# Único permiso cruzado con el proyecto admin: los nodos de este cluster
# necesitan leer imágenes del repositorio compartido de Artifact Registry
# (pendiente que había quedado abierto en DI-004 hasta que existiera el
# cluster). Vive aquí, no en el módulo, porque conecta un recurso de este
# proyecto con un recurso de `admin`.
resource "google_artifact_registry_repository_iam_member" "gke_nodes_image_reader" {
  project    = var.admin_project_id
  location   = var.region
  repository = var.artifact_registry_repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${module.gke.node_service_account_email}"
}
