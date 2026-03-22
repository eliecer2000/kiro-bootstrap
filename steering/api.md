---
inclusion: fileMatch
fileMatchPattern: ["**/api/**", "**/routes/**", "**/handlers/**", "**/openapi.*", "**/swagger.*"]
---

# API And Events

## Contratos

- Definir contratos de API antes de implementar (OpenAPI, JSON Schema).
- Documentar request/response para cada endpoint.
- Versionar contratos: `/v1/orders`, no cambios breaking sin version nueva.

## Errores

- Formato consistente de errores en toda la API:

```json
{
  "error": {
    "code": "ORDER_NOT_FOUND",
    "message": "Order with ID 123 not found",
    "requestId": "abc-123"
  }
}
```

- Mapear excepciones internas a HTTP status codes apropiados.
- No exponer stack traces ni detalles internos en respuestas de error.

## Autenticacion

- Usar Cognito, IAM authorizer o Lambda authorizer segun el caso.
- Tokens en header `Authorization: Bearer <token>`.
- Validar tokens en cada request, no confiar en cache sin TTL.

## Eventos

- Eventos asincronos con esquema documentado.
- Incluir `eventType`, `timestamp`, `source`, `payload` en cada evento.
- Usar EventBridge o SQS segun el patron (fan-out vs cola).
- Idempotencia: disenar consumidores para procesar el mismo evento multiples veces.

## Rate limiting

- Configurar throttling en API Gateway.
- Documentar limites por endpoint y por cliente.
- Retornar `429 Too Many Requests` con header `Retry-After`.
