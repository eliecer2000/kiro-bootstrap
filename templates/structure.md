# Repository Structure

## Directorios Principales

```
.
├── .kiro/                  # Artefactos Orbit (generado por bootstrap)
│   ├── agents/             # Agentes del perfil activo
│   ├── steering/           # Steering packs del perfil
│   ├── skills/             # Skills locales del perfil
│   ├── hooks/              # Hooks del perfil
│   └── .orbit-project.json # Estado del proyecto
├── src/                    # Codigo fuente principal
│   ├── handlers/           # Entry points (Lambda handlers, API routes)
│   ├── services/           # Logica de negocio
│   ├── models/             # Modelos de datos y tipos
│   └── utils/              # Utilidades compartidas
├── tests/                  # Tests
│   ├── unit/               # Tests unitarios
│   └── integration/        # Tests de integracion
├── infra/                  # Infraestructura como codigo (CDK/Terraform)
└── docs/                   # Documentacion del proyecto
```

<!-- Ajustar segun el stack y runtime del proyecto -->

## Capas Tecnicas

| Capa | Directorio | Responsabilidad |
|---|---|---|
| Entry point | `src/handlers/` | Recibir eventos, validar input, delegar a servicios |
| Negocio | `src/services/` | Logica de dominio, orquestacion |
| Datos | `src/models/` | Modelos, esquemas, acceso a datos |
| Infra | `infra/` | Recursos AWS, stacks, modulos |
| Tests | `tests/` | Cobertura unitaria e integracion |

## Convenciones de Nombres

### Archivos

- **Handlers**: `{recurso}.handler.{ext}` (ej: `orders.handler.ts`)
- **Servicios**: `{recurso}.service.{ext}` (ej: `orders.service.ts`)
- **Modelos**: `{recurso}.model.{ext}` (ej: `order.model.ts`)
- **Tests**: `{nombre}.test.{ext}` o `test_{nombre}.{ext}` (Python)

### Variables de entorno

- Prefijo `APP_` para configuracion de aplicacion
- Prefijo `AWS_` reservado para SDK
- Documentar en `.env.example` sin valores reales

## Puntos de Extension Orbit

| Extension | Archivo | Proposito |
|---|---|---|
| Hooks | `.kiro/hooks/*.kiro.hook` | Automatizacion en save/task |
| Steering | `.kiro/steering/*.md` | Reglas contextuales para agentes |
| Skills | `.kiro/skills/*/SKILL.md` | Conocimiento de dominio |
| Agents | `.kiro/agents/*.json` | Agentes especializados |
