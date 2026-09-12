# `persistent/`

**Este es un estado de Terraform aparte, independiente del resto de `iac-gcp-dev` — y NUNCA se destruye por sesión.**

Contiene solo lo que necesita sobrevivir a que el resto del ambiente (`../` — cluster, Argo CD, Spanner, secretos) se destruya y se vuelva a crear en cada sesión de trabajo: la IP estática y el certificado gestionado del **punto de entrada único del ambiente** (`dev.solventa4bits.com`, DI-010) — hoy lo sirve el `Gateway` de `bff-web` directamente, pero por diseño (DI-011) va a pasar a ser el `Gateway` del API Gateway (Apache APISIX, `deploy/apps/api-gateway/`), no de ningún BFF en particular. Ningún BFF ni la API de socios tienen o van a tener dirección pública propia — todos quedan detrás de este único punto de entrada.

## Por qué existe

Se probó (2026-09-12, experimento documentado en memoria del proyecto) reservar esta IP en `iac-gcp-admin` en vez de aquí, para que la separación "efímero vs. persistente" fuera más limpia (`admin` ya es el único ambiente que no se destruye). **No funciona**: el `Gateway` de Kubernetes de GKE solo puede referenciar direcciones IP estáticas de **su propio proyecto** — no hay forma soportada de usar una IP de otro proyecto (falla con `Error GWCER106: address "..." does not exist`, probado con el nombre corto y con la ruta completa). Por eso esto vive en `solventa-dev`, en un estado separado dentro del mismo repo, en vez de en `solventa-admin`.

## Regla de oro

```
⚠️  NUNCA correr `terraform destroy` aquí.
⚠️  El hábito de "destroy al terminar la sesión" aplica SOLO a la raíz del repo (`../`), NUNCA a esta carpeta.
```

## Uso

Se aplica **una sola vez** (o cuando cambie algo aquí — no en cada sesión):

```shell
cd persistent
terraform init
terraform apply
```

Después de aplicar, `terraform output edge_static_ip` da la IP a usar en el registro DNS (`dev.solventa4bits.com`, a crear a mano en Squarespace mientras no exista la delegación a Cloud DNS — ver DI-010).

El `Gateway` que sirve este tráfico (hoy en `deploy/apps/bff-web/base/gateway.yaml`, mañana en `deploy/apps/api-gateway/`) referencia el nombre de esta IP (`bff-web-dev` — nombre físico heredado, ver comentario en `main.tf`) y el nombre del `CertificateMap` (`edge-dev-map`) directamente — son nombres fijos, no hace falta pasarlos por ninguna otra parte.

**Nota histórica**: estos recursos se llamaron originalmente `bff-web-*` (pensando en una dirección propia para `bff-web`, antes de DI-011). Se renombraron a `edge-*` el 2026-09-12 vía `terraform state mv` (conservando la misma IP física, `34.120.130.162`) al decidir que el API Gateway corre dentro del cluster — el certificado y el mapa sí se recrearon (cambio de dominio de `bff-web.dev.solventa4bits.com` a `dev.solventa4bits.com`), la IP no.
