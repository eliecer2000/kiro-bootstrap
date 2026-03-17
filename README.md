# kiro-bootstrap — Escala 24x7

Repositorio central de configuración de Kiro IDE para todos los proyectos de Escala 24x7. Provee un sistema de bootstrap automatizado que detecta el tipo de proyecto y carga los agentes, steering files, skills y hooks correspondientes.

## Instalación

Ejecutar en la terminal:

```bash
curl -sL https://bitbucket.org/escala24x7/kiro-bootstrap/raw/main/install.sh | bash
```

Esto descarga el repositorio y configura los artefactos base en `~/.kiro/`.

### Requisitos previos

- macOS o Linux
- `git` instalado y disponible en el PATH
- `curl` instalado y disponible en el PATH

### Actualización

```bash
~/.kiro/install.sh --update
```

Si la versión local ya coincide con la remota, el sistema informa que está actualizado y omite la re-ejecución.

## Estructura del repositorio

```
kiro-bootstrap/
├── install.sh              # Instalador bash
├── manifest.json           # Manifiesto de perfiles y pipeline
├── agents-registry.json    # Registro centralizado de agentes
├── README.md               # Este archivo
├── agents/                 # Definiciones JSON de agentes Kiro
├── steering/               # Steering files (Markdown con frontmatter)
├── skills/                 # Skills (directorios con SKILL.md)
├── hooks/                  # Hooks de Kiro (.kiro.hook)
├── templates/              # Templates reutilizables (Markdown)
├── profiles/               # Configuración por perfil de proyecto
└── validations/            # Scripts de validación de entorno por perfil
```

### Descripción de directorios

| Directorio     | Contenido                                                                                 |
| -------------- | ----------------------------------------------------------------------------------------- |
| `agents/`      | Archivos JSON con la definición de cada agente (nombre, modelo, prompt, tools, resources) |
| `steering/`    | Archivos Markdown con reglas de comportamiento, estándares y contexto para los agentes    |
| `skills/`      | Subdirectorios con un archivo `SKILL.md` que define cada skill                            |
| `hooks/`       | Archivos `.kiro.hook` en formato JSON que definen automatizaciones                        |
| `templates/`   | Plantillas Markdown reutilizables para specs, documentación, etc.                         |
| `profiles/`    | Archivos JSON con la configuración específica de cada perfil de proyecto                  |
| `validations/` | Scripts bash de validación de entorno organizados por perfil                              |

## Perfiles de proyecto soportados

| Perfil                      | Detección automática                                            |
| --------------------------- | --------------------------------------------------------------- |
| `frontend-nuxt`             | `nuxt.config.ts` + dependencia `nuxt` en `package.json`         |
| `infraestructura-terraform` | Archivos `*.tf` + `backend.tf`                                  |
| `backend-lambda`            | Dependencia `@aws-sdk/*` en `package.json` sin `nuxt.config.ts` |
| `backend-python`            | `pyproject.toml` o `requirements.txt`                           |

## Cómo agregar un nuevo agente

1. Crear el archivo JSON del agente en `agents/`. Ejemplo:

```json
{
  "name": "mi-agente",
  "description": "Descripción del agente.",
  "model": "sonnet-4",
  "prompt": "Instrucciones del agente...",
  "tools": ["*"],
  "resources": [],
  "welcomeMessage": "Agente activado."
}
```

2. Registrar el agente en `agents-registry.json` agregando una entrada en `agents`:

```json
{
  "mi-agente": {
    "name": "mi-agente",
    "description": "Descripción del agente.",
    "model": "sonnet-4",
    "file": "agents/mi-agente.json",
    "steeringFiles": ["steering/mi-steering.md"],
    "skills": ["skills/mi-skill"],
    "profiles": ["frontend-nuxt"]
  }
}
```

3. Crear los steering files y skills referenciados en los directorios correspondientes.

4. El pipeline de bootstrap cargará automáticamente el nuevo agente en los proyectos que coincidan con los perfiles definidos en `profiles`.

## Cómo agregar un nuevo perfil de proyecto

1. Agregar la definición del perfil en `manifest.json` dentro de `profiles`, incluyendo:
   - Reglas de detección (`detection`)
   - Agentes asociados (`agents`)
   - Validaciones de entorno (`validations`)

2. Crear el archivo de perfil en `profiles/<nombre-perfil>.json`.

3. Crear el script de validación en `validations/<nombre-perfil>.sh`.

4. Asignar el nuevo perfil a los agentes correspondientes en `agents-registry.json`.

## Ejemplo de uso

### Flujo completo de bootstrap

Al abrir Kiro en un proyecto con `nuxt.config.ts` y `package.json` con dependencia `nuxt`, el agente Jarvis se activa automáticamente y ejecuta:

```
▶ Iniciando Pipeline de Configuración...

  ▷ Paso 1: Detección de Perfil de Proyecto
    ✓ Perfil detectado: frontend-nuxt

  ▷ Paso 2: Validación de Entorno
    ✓ node v20.11.0 ≥ 18.0.0 — aprobado
    ✓ npm 10.2.4 ≥ 9.0.0 — aprobado
    ✓ git 2.43.0 ≥ 2.30.0 — aprobado

  ▷ Paso 3: Carga de Artefactos
    Agentes:
      + Nuevo: vue-dev.json
      + Nuevo: server-api.json
      + Nuevo: orchestrator.json
    Steering files:
      + Nuevo: project-context.md
      + Nuevo: vue-components.md
      + Nuevo: jarvis-core.md (global)
      + Nuevo: git-workflow.md (global)
    Skills:
      + Nuevo: vue-components/

  Resumen de carga: 7 nuevos, 0 sin cambios, 0 modificados

════════════════════════════════════════════════════
  Reporte del Pipeline de Configuración
════════════════════════════════════════════════════
  ✓ [1] Detección de Perfil — éxito
  ✓ [2] Validación de Entorno — éxito
  ✓ [3] Carga de Artefactos — éxito

  Pipeline completado exitosamente.
```

### Ejecución de tests

Para verificar que el sistema funciona correctamente:

```bash
# Tests del cargador de artefactos (50 tests)
bash kiro-bootstrap/tests/test-load-artifacts.sh

# Tests de integración del pipeline completo (66 tests)
bash kiro-bootstrap/tests/test-integration-pipeline.sh
```

### Validación de archivos

```bash
# Validar todos los JSON
for f in kiro-bootstrap/*.json kiro-bootstrap/agents/*.json kiro-bootstrap/profiles/*.json; do
  python3 -m json.tool "$f" > /dev/null && echo "✓ $f" || echo "✗ $f"
done

# Validar sintaxis de scripts bash
for f in kiro-bootstrap/install.sh kiro-bootstrap/lib/*.sh kiro-bootstrap/validations/*.sh; do
  bash -n "$f" && echo "✓ $f" || echo "✗ $f"
done
```

## Variables de entorno

| Variable                | Descripción                 | Valor por defecto                                        |
| ----------------------- | --------------------------- | -------------------------------------------------------- |
| `KIRO_BOOTSTRAP_REPO`   | URL del repositorio central | `https://bitbucket.org/eliezer-rangel/kiro-steering.git` |
| `KIRO_BOOTSTRAP_BRANCH` | Rama a utilizar             | `main`                                                   |

## Licencia

Uso interno — Escala 24x7.
