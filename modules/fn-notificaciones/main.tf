# Función de envío de correos (componente "Comunicaciones y Documentos", función por
# evento). Cloud Run sin acceso público: la única identidad que puede invocarla es la
# cuenta de servicio de la suscripción push de Pub/Sub.
#
#   Core --publica EnviarCorreo--> tópico solventa-dominio --push (OIDC)--> Cloud Run
#                                                                 | 5 entregas fallidas
#                                                                 v
#                                                   tópico de mensajes fallidos (DLQ)
#
# La función no lee Secret Manager por su cuenta: Cloud Run inyecta los dos secretos
# como variables de entorno al iniciar. Este módulo crea solo los contenedores de los
# secretos; los valores se suben a mano (`gcloud secrets versions add`), igual que en
# modules/secrets.

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  pubsub_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"

  # variable de entorno de la función -> secreto de Secret Manager
  secretos = {
    FN_RESEND_API_KEY          = "resend-api-key"
    OTEL_EXPORTER_OTLP_HEADERS = "fn-notificaciones-otlp-headers"
  }
}

resource "google_project_service" "run" {
  project = var.project_id
  service = "run.googleapis.com"

  disable_on_destroy = true
}

# Cloud Run lee la imagen del repositorio compartido del proyecto admin con su propio
# agente de servicio (no con la cuenta de la función): hay que darle lectura allí. El
# servicio depende de esta concesión para que el primer despliegue ya pueda descargar la imagen.
resource "google_project_service_identity" "run" {
  provider = google-beta

  project = var.project_id
  service = "run.googleapis.com"

  depends_on = [google_project_service.run]
}

resource "google_artifact_registry_repository_iam_member" "run_lee_imagenes" {
  project    = var.artifact_registry_project
  location   = var.region
  repository = var.artifact_registry_repository
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_project_service_identity.run.email}"
}

# --- identidades ---

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "fn-notificaciones"
  display_name = "fn-notificaciones (ejecución)"
  description  = "Identidad con la que corre la función de correos: solo lee sus dos secretos."
}

resource "google_service_account" "push" {
  project      = var.project_id
  account_id   = "fn-notificaciones-push"
  display_name = "Suscripción push hacia fn-notificaciones"
  description  = "Firma el token OIDC con el que Pub/Sub invoca la función. Único con permiso run.invoker."
}

# El agente de servicio de Pub/Sub firma el token OIDC en nombre de la cuenta push.
resource "google_service_account_iam_member" "pubsub_firma_oidc" {
  service_account_id = google_service_account.push.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.pubsub_agent
}

# --- secretos ---
# Los contenedores (y sus valores, subidos a mano con `gcloud secrets versions add`) viven fuera
# de este módulo, en persistent/secretos.tf, para sobrevivir al destroy del ambiente. Aquí solo
# se le da acceso a la función. Cloud Run falla si un secreto no tiene ninguna versión: en un
# proyecto nuevo, subir los valores antes de aplicar.

resource "google_secret_manager_secret_iam_member" "lector" {
  for_each = local.secretos

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

# --- Cloud Run ---

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = "fn-notificaciones"
  location = var.region

  # Sin acceso público: la autenticación la exige Cloud Run (IAM), no la aplicación. El
  # ingreso queda abierto a internet porque la suscripción push llega desde Google, no
  # desde una red privada propia, pero sin run.invoker nadie más puede llamarla.
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false # el equipo destruye y recrea el ambiente por sesión

  template {
    service_account = google_service_account.runtime.email
    timeout         = "30s"

    scaling {
      min_instance_count = 0 # escala a cero: costo cero sin correos
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "FN_ENVIRONMENT"
        value = "dev"
      }
      env {
        name  = "FN_SENDER_BACKEND"
        value = var.sender_backend
      }
      env {
        name  = "FN_REMITENTE"
        value = var.remitente
      }
      env {
        name  = "FN_REPLY_TO"
        value = var.reply_to
      }
      env {
        name  = "FN_OTEL_ENABLED"
        value = "true"
      }
      env {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = var.otlp_endpoint
      }

      dynamic "env" {
        for_each = local.secretos
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = local.secretos[env.key]
              version = "latest"
            }
          }
        }
      }
    }
  }

  # La imagen la despliega el CI (gcloud run services update): Terraform solo la usa
  # al crear el servicio y no la revierte después. `client*` los rellena gcloud.
  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }

  depends_on = [
    google_project_service.run,
    google_artifact_registry_repository_iam_member.run_lee_imagenes,
    google_secret_manager_secret_iam_member.lector,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "invocador_push" {
  project  = var.project_id
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.push.email}"
}

# --- suscripción push y cola de mensajes fallidos ---

resource "google_pubsub_topic" "dlq" {
  project = var.project_id
  name    = "${var.topic_name}-notificaciones-dlq"
}

# Retiene los mensajes fallidos 7 días para poder inspeccionarlos y reenviarlos.
resource "google_pubsub_subscription" "dlq" {
  project = var.project_id
  name    = "${var.topic_name}-notificaciones-dlq"
  topic   = google_pubsub_topic.dlq.name

  message_retention_duration = "604800s"

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_subscription" "this" {
  project = var.project_id
  name    = "notificaciones-enviar-correo"
  topic   = var.topic_name

  # Solo los mensajes EnviarCorreo; el resto del tópico no es de esta función.
  filter = "attributes.tipo = \"EnviarCorreo\""

  ack_deadline_seconds       = 30
  retain_acked_messages      = false
  message_retention_duration = "86400s"

  expiration_policy {
    ttl = ""
  }

  push_config {
    push_endpoint = google_cloud_run_v2_service.this.uri

    oidc_token {
      service_account_email = google_service_account.push.email
      audience              = google_cloud_run_v2_service.this.uri
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = var.max_delivery_attempts
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.invocador_push,
    google_service_account_iam_member.pubsub_firma_oidc,
  ]
}

# El agente de servicio de Pub/Sub publica en la cola de fallidos y confirma (ack) los
# mensajes de la suscripción al moverlos.
resource "google_pubsub_topic_iam_member" "dlq_publicador" {
  project = var.project_id
  topic   = google_pubsub_topic.dlq.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_agent
}

resource "google_pubsub_subscription_iam_member" "dlq_suscriptor" {
  project      = var.project_id
  subscription = google_pubsub_subscription.this.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}

# --- Despliegue desde el CI ---
# El CI de fn-notificaciones (rama develop) actualiza la imagen con
# `gcloud run services update`. Permisos mínimos: solo este servicio, y poder
# actuar como su cuenta de ejecución (Cloud Run lo exige al cambiar de revisión).
resource "google_cloud_run_v2_service_iam_member" "ci_despliega" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${var.ci_service_account}"
}

resource "google_service_account_iam_member" "ci_actua_como_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.ci_service_account}"
}
