# Secretos de Secret Manager consumidos por pods vía el add-on de Secret
# Manager de GKE (interfaz de almacenamiento de contenedores, CSI) —
# decisión del usuario 2026-09-12, sobre External Secrets Operator y sobre
# HashiCorp Vault propio.
#
# Este módulo solo crea el CONTENEDOR de cada secreto y el acceso — nunca
# el valor. El valor se sube a mano (`gcloud secrets versions add`) después
# de aprovisionar, cuando exista el dato real (ver README del repo).
#
# Por cada entrada de var.secrets: una cuenta de servicio de Google Cloud
# Platform (GSA) dedicada, con permiso de lectura SOLO sobre ese secreto, y
# el enlace de federación de identidades de carga de trabajo (Workload
# Identity Federation) hacia la cuenta de servicio de Kubernetes (KSA) del
# pod que lo consume — mínimo privilegio: un servicio no puede leer el
# secreto de otro.

resource "google_project_service" "secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  disable_on_destroy = true
}

resource "google_secret_manager_secret" "this" {
  for_each = var.secrets

  project   = var.project_id
  secret_id = each.value.secret_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_service_account" "reader" {
  for_each = var.secrets

  project      = var.project_id
  account_id   = each.key
  display_name = "Lector del secreto ${each.value.secret_id}"
  description  = "Cuenta de servicio de mínimo privilegio: solo lee el secreto ${each.value.secret_id} de Secret Manager."
}

resource "google_secret_manager_secret_iam_member" "reader" {
  for_each = var.secrets

  project   = var.project_id
  secret_id = google_secret_manager_secret.this[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.reader[each.key].email}"
}

resource "google_service_account_iam_member" "workload_identity" {
  for_each = var.secrets

  service_account_id = google_service_account.reader[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.ksa_namespace}/${each.value.ksa_name}]"
}
