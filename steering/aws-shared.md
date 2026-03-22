---
inclusion: always
---

# AWS Shared

## Enfoque

- AWS-first: preferir servicios gestionados sobre soluciones self-hosted.
- Serverless por defecto salvo que haya una razon clara para contenedores o EC2.
- Decisiones explicitas sobre runtime, datos, eventos e infraestructura.

## Naming

- Recursos AWS: `{proyecto}-{entorno}-{servicio}` (ej: `myapp-prod-orders-table`).
- Stacks IaC: `{proyecto}-{entorno}-{stack}` (ej: `myapp-prod-api-stack`).
- Consistencia entre codigo, IaC y consola AWS.

## Tags

Todos los recursos deben tener como minimo:

| Tag | Ejemplo |
|---|---|
| `Project` | `myapp` |
| `Environment` | `dev` / `staging` / `prod` |
| `Owner` | `team-backend` |
| `ManagedBy` | `terraform` / `cdk` / `manual` |

## Entornos

- Minimo 2 entornos: `dev` y `prod`.
- Configuracion por entorno via variables de entorno o SSM Parameter Store.
- No compartir recursos entre entornos salvo que sea intencional y documentado.

## Observabilidad desde el inicio

- Logs estructurados en JSON desde la primera Lambda o servicio.
- Metricas custom para operaciones de negocio criticas.
- Alarmas minimas: errores, throttles, latencia p99.
- Trazas con X-Ray o ADOT para flujos distribuidos.

## Costos

- Usar on-demand para desarrollo, reserved/savings plans para produccion.
- Revisar Cost Explorer mensualmente.
- Configurar billing alerts en la cuenta.
