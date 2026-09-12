# `persistent/`

**Este es un estado de Terraform aparte, independiente del resto de `iac-gcp-dev` — y NUNCA se destruye por sesión.**

Contiene solo lo que necesita sobrevivir a que el resto del ambiente (`../` — cluster, Argo CD, Spanner, secretos) se destruya y se vuelva a crear en cada sesión de trabajo: la IP estática y el certificado gestionado que usa el `Gateway` de `bff-web` para tener una dirección pública **estable** (el API Gateway de `modules/ingress` necesita apuntar a algo que no cambie cada vez).

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

Después de aplicar, `terraform output bff_web_static_ip` da la IP a usar en el registro DNS (`bff-web.dev.solventa4bits.com`, a crear a mano en Squarespace mientras no exista la delegación a Cloud DNS — ver DI-010).

El `Gateway` de `bff-web` (en el repo `deploy`) referencia el nombre de esta IP (`bff-web-dev`) y el nombre del `CertificateMap` (`bff-web-dev-map`) directamente — son nombres fijos, no hace falta pasarlos por ninguna otra parte.
