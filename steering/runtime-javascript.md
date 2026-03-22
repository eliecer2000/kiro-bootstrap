---
inclusion: fileMatch
fileMatchPattern: ["**/*.js", "**/*.mjs", "**/*.cjs", "**/package.json"]
---

# Runtime JavaScript

## Configuracion

- Node.js 18+ como target.
- ESM (`"type": "module"` en package.json) preferido sobre CommonJS.
- Usar `.mjs` para ESM explicito cuando coexisten ambos formatos.

## Scripts obligatorios

```json
{
  "scripts": {
    "lint": "eslint src/",
    "format": "prettier --write 'src/**/*.{js,mjs,json}'",
    "test": "vitest run",
    "build": "esbuild src/handlers/*.js --bundle --platform=node --outdir=dist"
  }
}
```

## Convenciones

- JSDoc para documentar funciones publicas y tipos de parametros.
- Nombres descriptivos: evitar abreviaciones de una letra fuera de loops.
- Manejo explicito de errores: no silenciar con catch vacio.
- Preferir `const` sobre `let`. No usar `var`.

## AWS SDK

- Usar AWS SDK v3 (modular): `@aws-sdk/client-dynamodb`.
- Inicializar clientes fuera del handler.
- Manejar errores del SDK con try/catch y verificar `error.name`.

## Estructura

```
src/
├── handlers/       # Entry points Lambda
├── services/       # Logica de negocio
├── models/         # Schemas y validacion
└── utils/          # Helpers compartidos
tests/
├── unit/
└── integration/
```
