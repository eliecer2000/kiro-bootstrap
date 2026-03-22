---
inclusion: fileMatch
fileMatchPattern: ["**/lambda/**", "**/functions/**", "**/handlers/**"]
---

# Lambda

## Estructura del handler

- Handler pequeno: recibir evento, validar, delegar a servicio, retornar respuesta.
- Logica de negocio fuera del handler, en modulos de servicio testeables.
- Un handler por archivo. Nombre del archivo refleja el recurso o accion.

## Validacion de entrada

- Validar el evento antes de procesarlo (schema, tipos, campos requeridos).
- Retornar errores claros con status code y mensaje descriptivo.
- No confiar en que el evento siempre tiene la estructura esperada.

## Errores

- Capturar excepciones conocidas y retornar respuestas controladas.
- Dejar que excepciones inesperadas propaguen para que CloudWatch las registre.
- Incluir contexto en los errores: request ID, recurso afectado, operacion.

## Performance

- Inicializar clientes AWS SDK fuera del handler (reutilizar entre invocaciones).
- Minimizar dependencias para reducir cold starts.
- Usar bundling (esbuild para Node, zip optimizado para Python).
- Configurar memoria segun el perfil de carga (mas memoria = mas CPU).

## Logs

- Logs estructurados en JSON.
- Incluir: `requestId`, `functionName`, `level`, `message`, `timestamp`.
- No loguear payloads completos en produccion (PII, tamano).

## Empaquetado

- TypeScript: esbuild con tree-shaking, target node18+.
- Python: zip con dependencias en layer o incluidas, excluir `__pycache__` y tests.
- Mantener el paquete bajo 50MB (limite de Lambda).
