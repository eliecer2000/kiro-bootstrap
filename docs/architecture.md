# Arquitectura de Orbit

## Principio central

Todo en Orbit es declarativo. Los perfiles son la fuente de verdad: definen que agentes, skills, steering, hooks, extensiones, validaciones y tooling aplican a cada tipo de proyecto. El runtime lee esas declaraciones y actua.

## Componentes

### Catalogo declarativo

| Archivo | Contenido |
|---|---|
| `manifest.json` | Pipeline (pasos y orden), politicas (conflictos, skills remotas, sesion), wizard y comandos publicos |
| `profiles/*.json` | Un archivo por perfil: dimensiones, deteccion, tooling, agentes, steering, skills, hooks, validaciones |
| `agents-registry.json` | Contrato de cada agente (rol, responsabilidades, handoffs, skills, modelo) y allowlist de skills remotas |

### Runtime

| Archivo | Funcion |
|---|---|
| `lib/orbit_catalog.py` | Parser unico del catalogo. Lee manifest, profiles y registry. Soporta deteccion de perfiles, resolucion por wizard, acceso a campos (incluyendo dot-notation como `dimensions.runtime`) y validacion cruzada |
| `lib/pipeline.sh` | Orquesta la ejecucion secuencial de los pasos del pipeline definidos en `manifest.json` |
| `lib/session.sh` | Gestiona las gates de sesion: pregunta de bootstrap, prompt HOME, resolucion de perfil |
| `lib/load-artifacts.sh` | Copia agentes, steering, skills, hooks y extensiones del framework a `.kiro/` del proyecto |
| `lib/install-tooling.sh` | Instala devDependencies del proyecto (linters, formatters, test runners) segun el campo `tooling` del perfil |
| `validations/common.sh` | Valida herramientas de sistema y las auto-instala si faltan (controlado por `ORBIT_AUTO_INSTALL_TOOLS`) |
| `validations/profile.sh` | Validaciones especificas por perfil |

### Artefactos por perfil

Cada perfil declara que artefactos se copian al proyecto:

```
profiles/aws-backend-api-typescript.json
  ├── agents: ["orbit", "aws-architect", "aws-api-integration", ...]
  ├── steeringPacks: ["core", "git", "security", "aws-shared", ...]
  ├── localSkills: ["orbit-bootstrap", "find-skills", "typescript-runtime", ...]
  ├── hooks: ["node-format-on-save.kiro.hook", ...]
  └── extensionPacks: ["base", "typescript-aws"]
```

El pipeline copia estos artefactos desde el framework (`~/.kiro/orbit/`) al workspace (`.kiro/`).

## Pipeline

El pipeline ejecuta 6 pasos en orden:

```
┌─────────────────────────────────────────────────────┐
│ 1. session     │ Session Gates                      │
│ 2. detection   │ Detect Or Select Profile           │
│ 3. validation  │ Validate Environment               │
│ 4. loading     │ Load Orbit Artifacts               │
│ 5. tooling     │ Install Project Tooling            │
│ 6. state       │ Write Project State                │
└─────────────────────────────────────────────────────┘
```

Si un paso falla, el pipeline se detiene. Cada paso verifica `ORBIT_SESSION_ABORTED` para respetar la decision del usuario de no continuar.

## Deteccion de perfiles

`orbit_catalog.py` evalua cada perfil habilitado contra el directorio del proyecto usando:

- `requiredFiles` — archivos que deben existir
- `anyFiles` — al menos uno debe existir
- `excludeFiles` — si alguno existe, el perfil se descarta
- `requiredGlobs` / `anyGlobs` — patrones glob
- `packageJsonDependencies` — dependencias en package.json (soporta wildcards como `@aws-sdk/*`)
- `textPatterns` — texto dentro de archivos especificos
- `priority` — peso para desempate

El perfil con mayor score gana. Si no hay match, se lanza el wizard interactivo.

## Instalacion de herramientas

Orbit distingue dos niveles:

### Sistema (paso 3 — validation)

Herramientas globales validadas y auto-instaladas si faltan: `git`, `node`, `npm`, `python3`, `aws`, `terraform`, `pnpm`, `yarn`. Cada perfil declara cuales requiere en su array `validations`.

### Proyecto (paso 5 — tooling)

DevDependencies instaladas segun el campo `tooling` del perfil. El package manager se detecta por lockfile:

| Lockfile | Package Manager |
|---|---|
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| `bun.lockb` | bun |
| (ninguno) | npm (default) |

Para Python: `uv` > `poetry` > `pip3` (en orden de preferencia).

## Validacion del catalogo

```bash
python3 lib/orbit_catalog.py --bootstrap-dir . validate-catalog
```

Verifica consistencia cruzada entre manifest, profiles y agents-registry: campos requeridos, referencias a agentes existentes, skills remotas en el allowlist y archivos de agentes presentes.
