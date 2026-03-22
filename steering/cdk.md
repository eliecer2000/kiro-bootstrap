---
inclusion: fileMatch
fileMatchPattern: ["**/cdk.json", "**/cdk/**", "**/lib/**/*.ts", "**/bin/**/*.ts"]
---

# AWS CDK

## Estructura

```
infra/
├── bin/
│   └── app.ts              # Entry point: instancia App y stacks
├── lib/
│   ├── stacks/             # Stacks por dominio
│   │   ├── api-stack.ts
│   │   └── data-stack.ts
│   └── constructs/         # Constructs reutilizables
│       ├── lambda-function.ts
│       └── dynamo-table.ts
├── cdk.json
└── tsconfig.json
```

## Principios

- Separar `App` (bin/) de `Stacks` (lib/stacks/) de `Constructs` (lib/constructs/).
- Stacks pequenos: un stack por dominio o bounded context.
- Constructs encapsulan patrones repetidos con defaults sensatos.
- No poner logica de negocio en stacks.

## Synth y deploy

- `cdk synth` debe ser reproducible y sin side effects.
- `cdk diff` antes de cada deploy para revisar cambios.
- Usar `cdk.context.json` para cache de lookups. Versionar este archivo.

## Convenciones

- IDs de constructs descriptivos: `OrdersTable`, no `Table1`.
- Props tipadas para cada construct custom.
- Tags aplicados a nivel de App o Stack, no por recurso individual.
- Outputs para valores que otros stacks o servicios necesitan.

## Seguridad

- Usar `Grant` methods del CDK en lugar de politicas IAM manuales.
- No usar `*` en resources salvo en dev temporal.
- Habilitar cifrado por defecto en tablas, buckets y colas.
