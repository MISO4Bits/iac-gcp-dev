# Registro de la app Android en Firebase (avisos push, BITS-229).
#
# Vive aquí y no en la raíz porque la raíz se destruye en cada sesión: si la app de Firebase viviera
# allí, cada apply crearía una con un `app_id` nuevo y habría que regenerar `google-services.json`
# y recompilar la app. Aquí el archivo queda estable, igual que los secretos que sobreviven al
# destroy.
#
# El proyecto ya tiene Firebase y la interfaz de mensajería habilitadas (existe la cuenta
# `firebase-adminsdk-fbsvc`); si el `plan` pidiera crear `google_firebase_project`, se importa en
# vez de crearlo. Nadie necesita un rol de Firebase para esto: los teléfonos no tocan Google Cloud.

resource "google_project_service" "firebase" {
  project = var.project_id
  service = "firebase.googleapis.com"

  # Este estado no se destruye por sesión.
  disable_on_destroy = false
}

resource "google_project_service" "fcm" {
  project = var.project_id
  service = "fcm.googleapis.com"

  disable_on_destroy = false
}

resource "google_firebase_android_app" "movil" {
  provider = google-beta

  project      = var.project_id
  display_name = "Solventa móvil"
  # Es el mismo en `debug` y `release`, así que basta una app.
  package_name = var.android_package_name

  # Un `terraform destroy` por error no debe borrar la app: se perdería su `app_id` y habría que
  # regenerar `google-services.json`.
  deletion_policy = "ABANDON"

  depends_on = [google_project_service.firebase]
}

# Contenido de `google-services.json`. No es un secreto: su clave de API queda restringida a la app.
data "google_firebase_android_app_config" "movil" {
  provider = google-beta

  project = var.project_id
  app_id  = google_firebase_android_app.movil.app_id
}
