---
inclusion: fileMatch
fileMatchPattern: ["**/cloudwatch/**", "**/monitoring/**", "**/alarms/**", "**/dashboards/**", "**/logging/**"]
---

# Observability

## Logs

- Formato JSON estructurado en todos los servicios.
- Campos minimos: `timestamp`, `level`, `message`, `requestId`, `service`.
- Niveles: `DEBUG` (dev), `INFO` (operaciones normales), `WARN` (degradacion), `ERROR` (fallos).
- No loguear PII, tokens ni payloads completos en produccion.
- Retention: 30 dias en dev, 90 dias en prod (ajustar segun compliance).

## Metricas

- Metricas de negocio custom via CloudWatch EMF o PutMetricData.
- Metricas operativas clave:

| Metrica | Namespace | Alarma |
|---|---|---|
| Errores Lambda | AWS/Lambda | > 5 en 5 min |
| Throttles | AWS/Lambda | > 0 |
| Latencia p99 | AWS/Lambda | > 10s |
| DynamoDB consumed capacity | AWS/DynamoDB | > 80% provisioned |
| API Gateway 5xx | AWS/ApiGateway | > 1% de requests |

## Alarmas

- Minimo una alarma por servicio critico.
- Accion: SNS topic con notificacion a equipo.
- Usar composite alarms para reducir ruido.
- Documentar runbook para cada alarma.

## Trazas

- Habilitar X-Ray o ADOT en Lambda y API Gateway.
- Propagar trace ID entre servicios.
- Anotar segmentos con metadata de negocio relevante.

## Dashboards

- Un dashboard operativo por servicio con: errores, latencia, invocaciones, throttles.
- Un dashboard de negocio con metricas custom relevantes.
- Revisar dashboards semanalmente en las primeras iteraciones.
