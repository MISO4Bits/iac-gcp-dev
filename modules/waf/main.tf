# WAF (Cloud Armor) delante del API Gateway (DI-011) — capa perimetral que
# faltaba: reglas OWASP CRS 4.22 preconfiguradas (la versión más actual
# confirmada con `gcloud compute security-policies
# list-preconfigured-expression-sets` contra el proyecto real, no supuesta)
# + límite de tasa por IP. Se adjunta al backend de APISIX vía
# GCPBackendPolicy en deploy/apps/api-gateway/ (mismo patrón que
# HealthCheckPolicy — Terraform crea el recurso de GCP, el CRD en `deploy`
# lo conecta al Service correspondiente).
#
# Categorías elegidas: las relevantes al stack real de los servicios
# (Python/FastAPI, JSON) — sqli, xss, lfi, rfi, rce, methodenforcement,
# protocolattack, scannerdetection, sessionfixation, generic. Se dejan
# fuera java-v422-stable/php-v422-stable/nodejs-v33-stable: ningún
# servicio corre esos runtimes, agregarlas solo sumaría falsos positivos
# sin protección real.
resource "google_compute_security_policy" "edge" {
  project     = var.project_id
  name        = "edge-waf-dev"
  description = "Cloud Armor delante del API Gateway (DI-011)."

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Regla por defecto: permite lo que no matchea nada mas."
  }

  dynamic "rule" {
    for_each = {
      1000 = "generic-v422-stable"
      1001 = "sqli-v422-stable"
      1002 = "xss-v422-stable"
      1003 = "lfi-v422-stable"
      1004 = "rfi-v422-stable"
      1005 = "rce-v422-stable"
      1006 = "methodenforcement-v422-stable"
      1007 = "protocolattack-v422-stable"
      1008 = "scannerdetection-v422-stable"
      1009 = "sessionfixation-v422-stable"
    }
    content {
      action   = "deny(403)"
      priority = rule.key
      match {
        expr {
          expression = "evaluatePreconfiguredWaf('${rule.value}')"
        }
      }
      description = "OWASP CRS 4.22: ${rule.value}"
    }
  }

  # Limite de tasa por IP — protege endpoints publicos sin autenticacion
  # (ej. bff-web POST /v1/registro, security: [] a proposito en su
  # contrato) de spam/abuso. Sin esto, cualquiera que conozca la URL
  # puede llamarla sin limite (hallazgo real de esta sesion).
  rule {
    action   = "throttle"
    priority = "2000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
    }
    description = "Limite: 100 req/min por IP."
  }
}
