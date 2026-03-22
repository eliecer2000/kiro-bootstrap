# Project Overview

## Nombre

<!-- Nombre del proyecto o servicio -->

## Objetivo del Proyecto

<!-- Descripcion breve del problema que resuelve y el valor que aporta -->

## Perfil Orbit

- **Profile ID**: `{{ORBIT_PROFILE_ID}}`
- **Workload**: {{workload}}
- **Runtime**: {{runtime}}
- **Provisioner**: {{provisioner}}

## Servicios AWS Involucrados

| Servicio | Proposito | Tier |
|---|---|---|
| Lambda | Compute principal | Core |
| API Gateway | Exposicion HTTP | Core |
| DynamoDB | Persistencia | Core |
| CloudWatch | Logs y metricas | Observabilidad |
| IAM | Permisos y roles | Seguridad |

<!-- Ajustar segun el stack real del proyecto -->

## Arquitectura de Alto Nivel

```
Cliente → API Gateway → Lambda → DynamoDB
                          ↓
                     CloudWatch (logs, metricas, alarmas)
```

<!-- Reemplazar con el diagrama real del proyecto -->

## Riesgos Operativos

| Riesgo | Impacto | Mitigacion |
|---|---|---|
| Cold starts en Lambda | Latencia en primeras invocaciones | Provisioned concurrency o warming |
| Throttling DynamoDB | Errores 429 en picos | Auto-scaling o on-demand capacity |
| Secretos en codigo | Exposicion de credenciales | Secrets Manager + rotacion |

## Decisiones de Arquitectura

<!-- Documentar decisiones clave con formato ADR ligero:
- **Decision**: Que se decidio
- **Contexto**: Por que se tomo esa decision
- **Consecuencias**: Tradeoffs aceptados
-->

## Contacto

- **Owner**: {{team_or_owner}}
- **Repositorio**: {{repo_url}}
