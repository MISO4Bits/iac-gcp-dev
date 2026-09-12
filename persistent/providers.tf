provider "google" {
  project = var.project_id
  region  = var.region

  # Mismo motivo que en la raíz: sin esto, algunas APIs (Certificate
  # Manager incluida) rechazan las llamadas hechas con credenciales por
  # defecto de la aplicación (ADC) locales con "requires a quota project".
  billing_project       = var.project_id
  user_project_override = true
}
