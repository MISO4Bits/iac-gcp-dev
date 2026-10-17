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

# Desactivado para las pruebas E2E (2026-10-10): los servicios usan su
# almacenamiento local (SQLite). Descomentar junto con los outputs de Spanner.
# module "spanner" {
#   source = "./modules/spanner"
#
#   project_id = var.project_id
#   region     = var.region
# }

# API Gateway del ambiente (DI-011) — Apache APISIX dentro del cluster.
# depends_on explícito porque el módulo solo usa el provider de helm (no
# referencia ninguna salida de module.gke), y ese provider se configura
# contra el endpoint del cluster — sin el cluster creado, el provider de
# helm no tiene contra qué autenticar.
module "api_gateway" {
  source = "./modules/api-gateway"

  depends_on = [module.gke]
}

# WAF delante del API Gateway (DI-011) — sin dependencia de GKE, es un
# recurso global de Compute Engine independiente del cluster.
module "waf" {
  source = "./modules/waf"

  project_id = var.project_id
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
      crear_secreto = false # el contenedor vive en persistent/secretos.tf
    }
    # Mismo secreto que bff-web (la API key es del proyecto de Identity
    # Platform, no de un canal): solo agrega su propia GSA + enlace de KSA.
    bff-mobile-secrets = {
      secret_id     = "identity-platform-api-key"
      ksa_namespace = "bff-mobile"
      ksa_name      = "bff-mobile"
      crear_secreto = false
    }
  }
}

# Bus de eventos de dominio (mensajería, ver CLAUDE.md): tópico compartido
# "solventa-dominio" + una suscripción de pull por consumidor. Hoy: Core
# publica ClienteRegistrado (con el consentimiento de cada fuente) al
# registrarse y ConsentimientoOtorgado/ConsentimientoRevocado (de una sola
# fuente) al cambiar un consentimiento; Perfilamiento los consume para
# consultar, guardar o borrar los datos de esa fuente y recalcular el perfil de
# riesgo de forma asíncrona (Confluence, página Perfilamiento, Sección 8,
# decisión 2026-09-18) y publica PerfilCalculado/PerfilInvalidado; Cotización
# consume ConsentimientoRevocado y esos dos para invalidar su caché de perfiles
# (Redis, ver deploy/apps/redis — decisión 2026-09-19): invalidar también al
# terminar Perfilamiento evita volver a guardar un perfil viejo si Cotización lo
# leyó antes de que se recalculara.
module "pubsub" {
  source = "./modules/pubsub"

  project_id = var.project_id
  topic_name = "solventa-dominio"

  service_accounts = {
    svc-core = {
      ksa_namespace = "svc-core"
      ksa_name      = "svc-core"
      publica       = true
    }
    # Perfilamiento publica (PerfilCalculado/PerfilInvalidado) y además
    # consume ClienteRegistrado/ConsentimientoOtorgado/ConsentimientoRevocado — las dos
    # cosas en la misma GSA (una KSA solo se federa con una GSA a la vez).
    svc-perfilamiento = {
      ksa_namespace = "svc-perfilamiento"
      ksa_name      = "svc-perfilamiento"
      publica       = true
      suscripciones = {
        consentimiento = {
          subscription_id = "perfilamiento-consentimiento"
          # OR de atributos (sintaxis de filtro de Pub/Sub) — una sola
          # suscripción para los tipos de evento que le importan a
          # Perfilamiento, en vez de una por tipo de evento.
          filter = "attributes.tipo = \"ClienteRegistrado\" OR attributes.tipo = \"ConsentimientoOtorgado\" OR attributes.tipo = \"ConsentimientoRevocado\""
        }
      }
    }
    # Solo invalidación de caché — Cotización nunca publica en este tópico.
    # Cambiar el filtro de una suscripción existente obliga a recrearla.
    svc-cotizacion = {
      ksa_namespace = "svc-cotizacion"
      ksa_name      = "svc-cotizacion"
      suscripciones = {
        revocacion = {
          subscription_id = "cotizacion-consentimiento-revocado"
          filter          = "attributes.tipo = \"ConsentimientoRevocado\" OR attributes.tipo = \"PerfilCalculado\" OR attributes.tipo = \"PerfilInvalidado\""
        }
      }
    }
  }
}

# Función de envío de correos (Cloud Run, fuera del cluster): suscripción push al
# tópico con filtro `tipo = EnviarCorreo`, cola de mensajes fallidos y sus secretos.
# depends_on module.secrets porque ese módulo habilita la API de Secret Manager.
module "fn_notificaciones" {
  source = "./modules/fn-notificaciones"

  project_id                   = var.project_id
  region                       = var.region
  topic_name                   = module.pubsub.topic_name
  image                        = "${var.region}-docker.pkg.dev/${var.admin_project_id}/${var.artifact_registry_repository_id}/fn-notificaciones:${var.fn_notificaciones_image_tag}"
  artifact_registry_project    = var.admin_project_id
  artifact_registry_repository = var.artifact_registry_repository_id
  sender_backend               = var.fn_notificaciones_sender_backend
  reply_to                     = var.fn_notificaciones_reply_to
  otlp_endpoint                = "https://otlp-gateway-prod-sa-east-1.grafana.net/otlp"

  depends_on = [module.secrets]
}

# Core genera el enlace de verificación de correo con la API de administración de
# Identity Platform (accounts:sendOobCode con returnOobLink). Reutiliza la cuenta de
# servicio que ya tiene federada su KSA (una KSA solo se federa con una GSA a la vez).
# Rol por confirmar contra el permiso mínimo exacto al probar con Identity Platform real.
resource "google_project_iam_member" "core_identity_platform_admin" {
  project = var.project_id
  role    = "roles/firebaseauth.admin"
  member  = "serviceAccount:${module.pubsub.service_account_emails["svc-core"]}"
}

# Observabilidad del ambiente (DI-008): Alloy dentro del cluster reenviando
# a Grafana Cloud. depends_on module.gke por el mismo motivo que
# module.api_gateway (necesita el cluster para el provider de helm); además
# depende de module.secrets porque ese módulo es quien habilita la API de
# Secret Manager que este también usa.
module "observability" {
  source = "./modules/observability"

  project_id                  = var.project_id
  cluster_name                = var.project_id
  grafana_cloud_otlp_endpoint = "https://otlp-gateway-prod-sa-east-1.grafana.net/otlp"
  grafana_cloud_instance_id   = "1819034"

  depends_on = [module.gke, module.secrets]
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
