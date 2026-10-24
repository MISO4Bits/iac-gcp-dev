# Función que genera el documento de la póliza (componente "Comunicaciones y Documentos",
# función de documentos). Cloud Run sin acceso público: solo la cuenta de la suscripción push
# de Pub/Sub y las cuentas de servicio autorizadas (Core) pueden invocarla.
#
#   Core --PolizaEmitida--> tópico solventa-dominio --push (OIDC)--> Cloud Run --> bucket de PDF
#                                                                        |
#                                              DocumentoPolizaGenerado <-+  (Core arma el correo
#                                                                            y fn-notificaciones lo
#                                                                            envía con el PDF)
#   Core --POST /v1/documentos/polizas/enlace (token de identidad)--> Cloud Run --> enlace firmado
#
# Los enlaces se firman por la API de IAM con la identidad de la propia función: no hay llaves
# en archivos. No lee secretos por su cuenta: reutiliza el de las credenciales OTLP.

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  pubsub_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_project_service" "run" {
  project = var.project_id
  service = "run.googleapis.com"

  disable_on_destroy = true
}

# Firmar enlaces usa la API de credenciales de IAM.
resource "google_project_service" "iamcredentials" {
  project = var.project_id
  service = "iamcredentials.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service_identity" "run" {
  provider = google-beta

  project = var.project_id
  service = "run.googleapis.com"

  depends_on = [google_project_service.run]
}

# Cloud Run lee la imagen del repositorio compartido del proyecto admin con su propio agente de
# servicio. Ya tiene la concesión si fn-notificaciones se aplicó antes; es idempotente.
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
  account_id   = "fn-documentos"
  display_name = "fn-documentos (ejecución)"
  description  = "Identidad con la que corre la función de documentos: escribe y lee el bucket de PDF, firma enlaces y publica DocumentoPolizaGenerado."
}

resource "google_service_account" "push" {
  project      = var.project_id
  account_id   = "fn-documentos-push"
  display_name = "Suscripción push hacia fn-documentos"
  description  = "Firma el token OIDC con el que Pub/Sub invoca la función."
}

resource "google_service_account_iam_member" "pubsub_firma_oidc" {
  service_account_id = google_service_account.push.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.pubsub_agent
}

# Para firmar un enlace la función necesita poder firmar como ella misma.
resource "google_service_account_iam_member" "firma_enlaces" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.runtime.email}"

  depends_on = [google_project_service.iamcredentials]
}

# --- bucket de PDF ---
# Privado, sin acceso público. Se destruye con el ambiente (force_destroy): los datos de las
# pólizas viven en la base SQLite del pod de Core, que también es efímera.

resource "google_storage_bucket" "polizas" {
  project  = var.project_id
  name     = "${var.project_id}-polizas"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  # La web carga el PDF con fetch desde el enlace firmado; abrirlo en una pestaña no lo necesita.
  cors {
    origin          = var.web_origins
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Content-Disposition"]
    max_age_seconds = 300
  }
}

# Crear (solo si no existe) y leer; no borrar ni sobrescribir.
resource "google_storage_bucket_iam_member" "runtime_crea" {
  bucket = google_storage_bucket.polizas.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_storage_bucket_iam_member" "runtime_lee" {
  bucket = google_storage_bucket.polizas.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_pubsub_topic_iam_member" "runtime_publica" {
  project = var.project_id
  topic   = var.topic_name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "otlp" {
  project   = var.project_id
  secret_id = var.otlp_headers_secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

# --- Cloud Run ---

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = "fn-documentos"
  location = var.region

  # Sin acceso público: la autenticación la exige Cloud Run (IAM). El ingreso queda abierto a
  # internet porque Pub/Sub llega desde Google, pero sin run.invoker nadie más puede llamarla.
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false # el equipo destruye y recrea el ambiente por sesión

  template {
    service_account = google_service_account.runtime.email
    timeout         = "60s"

    scaling {
      min_instance_count = 0
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
        name  = "FD_ENVIRONMENT"
        value = "dev"
      }
      env {
        name  = "FD_ALMACEN_BACKEND"
        value = "gcs"
      }
      env {
        name  = "FD_ALMACEN_BUCKET"
        value = google_storage_bucket.polizas.name
      }
      env {
        name  = "FD_FIRMANTE_EMAIL"
        value = google_service_account.runtime.email
      }
      env {
        name  = "FD_PUBLICADOR_BACKEND"
        value = "pubsub"
      }
      env {
        name  = "FD_PUBSUB_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "FD_PUBSUB_TOPIC"
        value = var.topic_name
      }
      env {
        name  = "FD_OTEL_ENABLED"
        value = "true"
      }
      env {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = var.otlp_endpoint
      }
      env {
        name = "OTEL_EXPORTER_OTLP_HEADERS"
        value_source {
          secret_key_ref {
            secret  = var.otlp_headers_secret
            version = "latest"
          }
        }
      }
    }
  }

  # La imagen la despliega el CI (gcloud run services update): Terraform solo la usa al crear.
  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }

  depends_on = [
    google_project_service.run,
    google_artifact_registry_repository_iam_member.run_lee_imagenes,
    google_secret_manager_secret_iam_member.otlp,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "invocador_push" {
  project  = var.project_id
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.push.email}"
}

# Core pide el enlace del documento por HTTP con un token de identidad de su cuenta de servicio.
resource "google_cloud_run_v2_service_iam_member" "invocadores" {
  for_each = toset(var.invoker_service_accounts)

  project  = var.project_id
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${each.value}"
}

# --- suscripción push y cola de mensajes fallidos ---

resource "google_pubsub_topic" "dlq" {
  project = var.project_id
  name    = "${var.topic_name}-documentos-dlq"
}

resource "google_pubsub_subscription" "dlq" {
  project = var.project_id
  name    = "${var.topic_name}-documentos-dlq"
  topic   = google_pubsub_topic.dlq.name

  message_retention_duration = "604800s"

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_subscription" "this" {
  project = var.project_id
  name    = "documentos-poliza-emitida"
  topic   = var.topic_name

  # Solo las pólizas emitidas; el resto del tópico no es de esta función.
  filter = "attributes.tipo = \"PolizaEmitida\""

  ack_deadline_seconds       = 60
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
