# iac-gcp-dev

Infraestructura como código (Terraform) del ambiente **dev** de Solventa: cluster de Kubernetes, punto de entrada público, motor de datos y GitOps. Ver [DI-003](https://miso4bits.atlassian.net/wiki/spaces/4BITS/pages/44630018) para el porqué de la separación de ambientes.

Se aplica **después** de `iac-gcp-admin` — este repo depende de la federación de identidades y del repositorio de Artifact Registry que administra `admin`.

## Prerrequisitos

- Proyecto de GCP `solventa-dev` ya creado, con facturación activa.
- `iac-gcp-admin` ya aplicado (necesita su Artifact Registry y su Workload Identity Federation).
- Bucket de estado `gs://solventa-dev-tfstate` ya creado a mano (ver Confluence 4BITS → "Crear los buckets de estado de Terraform"). Terraform no puede crear el bucket donde guarda su propio estado.
- [Terraform](https://developer.hashicorp.com/terraform) >= 1.7.
- `gcloud auth application-default login` para autenticación local (los pipelines usan Workload Identity Federation, no llaves estáticas).

**Nota de versión del proveedor**: este repo usa el proveedor `hashicorp/google` `~> 8.2` — distinto de `iac-gcp-admin`, que sigue en `~> 5.40`. La divergencia es intencional (2026-09-12): el *add-on* de Secret Manager para Kubernetes Engine (`secret_manager_config` en `google_container_cluster`) no existe antes de la versión 8. Es aceptable porque cada repo tiene su propio estado y no comparte código (DI-003) — pero si algo falla raro al hacer `plan`/`apply` en este repo, revisar primero si es un cambio de comportamiento de la versión 8 en un recurso que antes se probó mentalmente contra la 5 (Spanner, el cluster), no solo un error de configuración.

## Uso

```shell
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

`terraform.tfvars` no se versiona (ver `.gitignore`) — ajustar ahí cualquier valor distinto al de los defaults en `variables.tf`.

**Hábito no negociable del equipo**: `terraform destroy` al terminar cada sesión de trabajo. Todos los recursos de este repo están escritos para poder destruirse sin fricción (`deletion_protection = false`, `disable_on_destroy = true`).

## Pasos manuales después de aplicar

Terraform no puede automatizar todo — algunos valores solo existen después de que algo real corrió. Lista completa, para no perder ninguno:

1. **API key de Identity Platform** (`modules/secrets` crea el contenedor vacío, nunca el valor):
   - Después del primer `apply`, ir a la consola de GCP → Identity Platform → Configuración de la aplicación (o `gcloud identity-platform` / la sección de credenciales del proyecto) y copiar la Web API Key generada para `solventa-dev`.
   - Subirla como primera versión del secreto: `gcloud secrets versions add identity-platform-api-key --project=solventa-dev --data-file=-` (pegar el valor y `Ctrl+D`).
   - Sin este paso, el pod de `bff-web` arranca pero el archivo `/var/secrets/BFF_IDENTITY_API_KEY` no existe — el registro de clientes fallará contra Identity Platform real (revisar `deploy/apps/bff-web` para el resto del cableado).
2. **Cuentas de servicio (GSA) por secreto**: `terraform output secret_reader_service_account_emails` después de aplicar. Cada correo ahí va en la anotación `iam.gke.io/gcp-service-account` de la `ServiceAccount` de Kubernetes (KSA) correspondiente en `deploy` — hoy ya está puesto a mano en `deploy/apps/bff-web/base/serviceaccount.yaml` con el valor esperado (`bff-web-secrets@solventa-dev.iam.gserviceaccount.com`, se arma de forma predecible a partir de la clave del mapa en `modules/secrets`); si se agrega un secreto nuevo, confirmar con el output real antes de pegarlo en `deploy`.
3. **Registro NS del dominio y correo** — no aplica a este repo, ver DI-010 en Confluence ("Log de decisiones de Infraestructura").

## Estructura

```
iac-gcp-dev/
├── modules/                 # una carpeta por pieza reusable, con su propia interfaz (variables/outputs)
│   ├── gke/                 # cluster de GKE Autopilot, southamerica-east1
│   ├── argocd/              # Argo CD (Helm) + root Application de GitOps, DI-007
│   ├── spanner/             # 2 instancias regionales (core + services compartida) + bases de datos, DI-009
│   └── secrets/             # secretos de Secret Manager (solo el contenedor) + acceso por Workload Identity
├── main.tf                  # raíz: solo instancia módulos y conecta sus salidas
├── backend.tf
├── providers.tf             # incluye los providers de Kubernetes/Helm/kubectl, apuntando al cluster de modules/gke
├── variables.tf
├── outputs.tf
└── versions.tf
```

Plan de construcción completo: `modules/gke` → `modules/argocd` (bootstrap de GitOps, sin depender de ningún servicio) → `modules/spanner` (DI-009) → `modules/ingress` (Load Balancer + Cloud Armor + API Gateway + certificado gestionado — pendiente de que exista una dirección real de BFF Web vía el repo `deploy`; ver nota abajo). Sin `modules/messaging` por ahora — los experimentos EXP-01/EXP-02 son 100% síncronos.

**Nota sobre `modules/argocd`**: el root `Application` que crea apunta a `deploy/argocd/` en el repo GitOps `deploy`. Mientras esa carpeta esté vacía o sin sincronizar, Argo CD simplemente queda en estado de sincronización fallida — no bloquea el resto del `apply`.

**Nota sobre `modules/secrets`**: decisión 2026-09-12 — Secret Manager + el *add-on* nativo de GKE (interfaz de almacenamiento de contenedores, CSI) en vez de External Secrets Operator (DI-007, 5.8 queda descartado) o un HashiCorp Vault propio en `admin` (evaluado y rechazado — demasiada carga operativa para lo que resuelve, sin ninguna ventaja dado que GCP ya es la única nube del proyecto). Cero componentes adicionales que mantener: el *add-on* viene con el cluster. El módulo solo crea el contenedor del secreto y el acceso — el valor se sube a mano (ver "Pasos manuales" arriba).

Este repo representa **un solo ambiente** (`dev`, DI-003) — no hay carpeta `environments/`, porque no hace falta: cada ambiente ya es su propio repositorio (`iac-gcp-admin`, `iac-gcp-dev`, `iac-gcp-prod`), cada uno con su propio estado. `modules/` no se comparte entre esos repos (duplicación aceptada a propósito en DI-003, a cambio de independencia total).

Convención al agregar un módulo nuevo: cada uno declara sus propias `variables.tf`/`outputs.tf` y no conoce a los demás; cualquier recurso que conecte dos módulos (o un módulo con un recurso de otro proyecto, como el permiso de Artifact Registry hacia `admin`) vive en el `main.tf` de la raíz, no dentro de ningún módulo.
