# API Gateway del ambiente (DI-011): Apache APISIX corriendo dentro del
# cluster, no el producto gestionado de Google (no disponible en
# southamerica-east1/southamerica-west1 — forzaría el proxy de datos a
# Norteamérica, contra la prioridad #1 de Latencia del proyecto).
#
# Este módulo SOLO instala el producto (plano de datos + su
# ingress-controller). El enrutamiento real (qué prefijo va a qué BFF),
# los plugins (OIDC contra Identity Platform, validación de esquema) y
# el `Gateway`/`GatewayProxy` que expone todo esto viven como manifiestos
# declarativos en `deploy/apps/api-gateway/` (GitOps, DI-007) — mismo
# principio que ya se sigue en todo el repo: Terraform instala la
# plataforma, `deploy` configura lo que corre sobre ella.
#
# Sin etcd (modo "standalone" de APISIX, ver
# https://apisix.apache.org/docs/apisix/deployment-modes/#standalone):
# el ingress-controller (2.2.0, incluido en el chart 2.17.0) ya habla
# Kubernetes Gateway API de forma nativa — el mismo `Gateway`/`HTTPRoute`
# que ya se usa para bff-web, no hace falta el modelo antiguo 100% basado
# en CRDs propios de APISIX para el enrutamiento básico. etcd solo serviría
# como almacén de configuración; en modo standalone esa configuración se
# maneja vía la propia Admin API de APISIX, sin un componente con estado
# adicional que mantener.

# El chart trae una clave de Admin API por defecto conocida (pública, en el
# código fuente del chart) — no es aceptable dejarla tal cual, ni siquiera
# para un Admin API que solo es alcanzable dentro del cluster. Se genera una
# real y se guarda en un Secret, nunca en texto plano en un manifiesto
# versionado — el GatewayProxy en deploy/apps/api-gateway/ la referencia por
# secretKeyRef (soportado directamente por el CRD), nunca por valor.
resource "random_password" "apisix_admin_key" {
  length  = 32
  special = false
}

resource "kubernetes_namespace_v1" "api_gateway" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret_v1" "apisix_admin_key" {
  metadata {
    name      = "apisix-admin-key"
    namespace = kubernetes_namespace_v1.api_gateway.metadata[0].name
  }

  data = {
    "admin-key" = random_password.apisix_admin_key.result
  }
}

resource "helm_release" "apisix" {
  name      = "apisix"
  namespace = kubernetes_namespace_v1.api_gateway.metadata[0].name

  depends_on = [kubernetes_secret_v1.apisix_admin_key]

  repository = "https://apache.github.io/apisix-helm-chart"
  chart      = "apisix"
  version    = var.apisix_chart_version

  # El modo API-driven (arriba) deja el pod de APISIX en 0/1 Ready hasta
  # que el ingress-controller le empuje su primera configuración real por
  # el Admin API — y eso solo pasa cuando existen Gateway/HTTPRoute reales
  # en deploy/apps/api-gateway/ (paso de GitOps posterior a este apply).
  # Mismo principio que la nota del root Application de Argo CD en
  # modules/argocd: la pieza de Terraform puede quedar "no lista todavía"
  # sin que eso sea un error — bloquear el apply esperando algo que
  # depende de un sync de Argo CD que no ha corrido sería un timeout
  # garantizado en cada sesión (el ambiente se destruye y recrea siempre).
  wait = false

  # Provider hashicorp/helm >= 3.0: `set` es un atributo (lista de objetos),
  # ya no un bloque repetible como en la v2 (breaking change real,
  # confirmado con `terraform validate` contra la v3.3.0 instalada).
  set = [
    {
      name  = "etcd.enabled"
      value = "false"
    },
    # NO es apisix.deployment.mode=standalone (ese es el modo file-driven,
    # con role=data_plane y el Admin API deshabilitado — no sirve para el
    # ingress-controller). El modo API-driven que sí necesita el
    # ingress-controller usa role=traditional (el default) con
    # config_provider=yaml — confirmado contra la doc oficial de
    # "Deployment modes" después de que el primer intento (mode=standalone)
    # dejara el pod en CrashLoopBackOff intentando conectar a etcd igual.
    {
      name  = "apisix.deployment.role_traditional.config_provider"
      value = "yaml"
    },
    {
      name  = "ingress-controller.enabled"
      value = "true"
    },
    # El valor por defecto del sub-chart asume el namespace "apisix-ingress"
    # para ubicar el Service del Admin API de APISIX (confirmado con
    # `helm template` antes de escribir esto: el Service real se llama
    # "apisix-admin", en el mismo namespace de este release) — sin esta
    # corrección el ingress-controller no encuentra el Admin API.
    {
      name  = "ingress-controller.apisix.adminService.namespace"
      value = var.namespace
    },
    # Clave real del Admin API, generada arriba — reemplaza la clave de
    # ejemplo pública que trae el chart por defecto (admin.credentials.admin).
    {
      name  = "admin.credentials.secretName"
      value = kubernetes_secret_v1.apisix_admin_key.metadata[0].name
    },
    {
      name  = "admin.credentials.secretAdminKey"
      value = "admin-key"
    },
  ]
}
