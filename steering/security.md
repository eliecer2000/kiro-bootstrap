---
inclusion: always
---

# Security

## Principios

- Aplicar least privilege en todos los roles y politicas IAM.
- Nunca incluir credenciales, tokens o secretos en codigo fuente o configuracion versionada.
- Usar AWS Secrets Manager o SSM Parameter Store para secretos en runtime.
- Documentar riesgos o gaps de seguridad cuando aparezcan.

## IAM

- Cada Lambda o servicio tiene su propio rol con permisos minimos.
- Evitar `*` en Resource salvo en entornos de desarrollo temporal.
- Usar conditions cuando sea posible (ej: `aws:SourceArn`, `aws:PrincipalOrgID`).
- Revisar permisos antes de cada deploy: `iam:PassRole` es critico.

## Secretos

- Variables de entorno sensibles van en Secrets Manager, no en `.env`.
- Rotar secretos periodicamente. Documentar la politica de rotacion.
- No loguear valores de secretos ni tokens en ningun nivel de log.

## Datos

- Cifrar datos en reposo (DynamoDB, S3, RDS) con KMS.
- Cifrar datos en transito (TLS 1.2+).
- Aplicar bucket policies y ACLs restrictivas en S3.

## Validacion de entrada

- Validar y sanitizar toda entrada del usuario antes de procesarla.
- Usar schemas (JSON Schema, Zod, Pydantic) para contratos de API.
- Rechazar payloads que excedan limites razonables.
