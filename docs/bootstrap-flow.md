# Flujo de Bootstrap

## Pipeline completo

```
Usuario pide preparar entorno
        │
        ▼
┌──────────────────────────────────────────────────────────┐
│ 1. SESSION GATES                                         │
│    - Pregunta si desea preparar el entorno               │
│    - Si rechaza → ORBIT_SESSION_ABORTED=1, fin           │
│    - Si contexto es HOME → ofrece crear carpeta          │
│    - Si acepta carpeta → crea y redirige el flujo        │
└──────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────┐
│ 2. DETECT OR SELECT PROFILE                              │
│    - Evalua perfiles habilitados contra el proyecto       │
│    - Si hay match unico → usa ese perfil                 │
│    - Si hay multiples → elige el de mayor score          │
│    - Si no hay match → lanza wizard interactivo          │
│      (workload → runtime → provisioner → framework)      │
└──────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────┐
│ 3. VALIDATE ENVIRONMENT                                  │
│    - Lee validations[] del perfil                        │
│    - Para cada herramienta: verifica presencia y version │
│    - Si falta y es requerida → intenta auto-instalar     │
│      (brew, apt, nvm, corepack, npm, xcode-select)      │
│    - Si falla la instalacion → FAIL, pipeline se detiene │
│    - Valida identidad AWS solo si ORBIT_DEPLOY_INTENT=yes│
└──────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────┐
│ 4. LOAD ORBIT ARTIFACTS                                  │
│    - Copia agentes del perfil a .kiro/agents/            │
│    - Copia steering packs a .kiro/steering/              │
│    - Copia skills locales a .kiro/skills/                │
│    - Copia hooks a .kiro/hooks/                          │
│    - Instala extension packs en .kiro/settings/          │
└──────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────┐
│ 5. INSTALL PROJECT TOOLING                               │
│    - Lee tooling{} y dimensions.runtime del perfil       │
│    - Detecta package manager (npm/pnpm/yarn/bun/uv/pip) │
│    - Inicializa package.json o pyproject.toml si falta   │
│    - Instala linters, formatters, test runners y         │
│      typecheck como devDependencies                      │
│    - Perfiles sin runtime (terraform) → skip             │
└──────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────┐
│ 6. WRITE PROJECT STATE                                   │
│    - Escribe .kiro/.orbit-project.json                   │
│    - Registra perfil activo, timestamp y artefactos      │
│    - Proyecto listo para scaffolding                     │
└──────────────────────────────────────────────────────────┘
```

## Comando de ejecucion

```bash
ORBIT_BOOTSTRAP_DECISION=yes \
ORBIT_HOME_DECISION=no \
ORBIT_PROJECT_PROFILE_ID=<profile-id> \
ORBIT_REMOTE_SKILL_DECISION=no \
~/.kiro/orbit/install.sh --resync-project "<ruta>"
```

### Variables de entorno

| Variable | Valores | Descripcion |
|---|---|---|
| `ORBIT_BOOTSTRAP_DECISION` | `yes` / `no` | Si el usuario acepta preparar el entorno |
| `ORBIT_HOME_DECISION` | `yes` / `no` | Si se crea carpeta de proyecto desde HOME |
| `ORBIT_PROJECT_PROFILE_ID` | ID del perfil | Perfil resuelto por el wizard |
| `ORBIT_REMOTE_SKILL_DECISION` | `yes` / `no` | Si se instalan skills remotas recomendadas |
| `ORBIT_AUTO_INSTALL_TOOLS` | `yes` / `no` | Auto-instalar herramientas de sistema (default: `yes`) |
| `ORBIT_VALIDATE_AWS_IDENTITY` | `yes` / `no` | Forzar validacion de identidad AWS |
| `ORBIT_DEPLOY_INTENT` | `yes` / `no` | Indica intencion de despliegue (activa validacion AWS) |

## Reglas de sesion

1. Si el usuario rechaza el bootstrap, Orbit no vuelve a preguntar en la sesion actual.
2. Si el contexto es HOME, pregunta una sola vez si desea crear carpeta de proyecto.
3. El perfil se resuelve con el wizard, nunca pidiendo el ID crudo al usuario.
4. Ninguna skill remota se instala sin confirmacion explicita.
5. No se piden credenciales AWS durante el bootstrap normal.
6. El scaffolding comienza solo despues de que el bootstrap termine y los artefactos esten presentes.

## Verificacion post-bootstrap

Despues del bootstrap, estos directorios deben existir:

```
.kiro/
├── .orbit-project.json
├── agents/
├── steering/
├── skills/
└── hooks/
```

Si alguno falta, ejecutar resync:

```bash
~/.kiro/orbit/install.sh --resync-project .
```

## Resincronizacion

Usar resync cuando:

- Se actualizo el framework y se necesitan nuevos artefactos
- Se cambio el perfil del proyecto
- Se detectan artefactos faltantes o desactualizados

El comando es el mismo que el bootstrap, ejecutado sobre un proyecto existente.
