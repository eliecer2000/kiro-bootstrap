---
inclusion: fileMatch
fileMatchPattern: ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.mjs", "**/tsconfig.*.json"]
---

# Runtime TypeScript

## Configuracion

- `strict: true` en tsconfig.json. No relajar sin justificacion.
- Target: `ES2022` o superior para Lambda Node 18+.
- Module: `ESNext` con `moduleResolution: bundler` o `node16`.

## Scripts obligatorios

```json
{
  "scripts": {
    "lint": "eslint src/ --ext .ts,.tsx",
    "format": "prettier --write 'src/**/*.{ts,tsx,json}'",
    "test": "vitest run",
    "typecheck": "tsc --noEmit",
    "build": "esbuild src/handlers/*.ts --bundle --platform=node --outdir=dist"
  }
}
```

## Convenciones

- Tipos explicitos en parametros de funciones y retornos publicos.
- Interfaces para contratos de API y modelos de datos.
- Enums solo cuando el valor es fijo y conocido; preferir union types.
- Evitar `any`: usar `unknown` y narrowing cuando el tipo no es claro.

## AWS SDK

- Usar AWS SDK v3 (modular): `@aws-sdk/client-dynamodb`, no `aws-sdk`.
- Inicializar clientes fuera del handler para reutilizar entre invocaciones.
- Tipar respuestas del SDK con los tipos del paquete.

## Estructura

```
src/
├── handlers/       # Entry points Lambda
├── services/       # Logica de negocio
├── models/         # Tipos e interfaces
└── utils/          # Helpers compartidos
tests/
├── unit/
└── integration/
```
