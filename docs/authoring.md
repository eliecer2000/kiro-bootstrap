# Guia de Authoring

Como agregar nuevos componentes al framework Orbit.

## Agregar un agente

1. Crear el archivo JSON en `agents/<nombre>.json`
2. Registrar el contrato completo en `agents-registry.json` con estos campos obligatorios:

```json
{
  "name": "mi-agente",
  "description": "Descripcion corta",
  "file": "agents/mi-agente.json",
  "role": "Rol en una linea",
  "responsibilities": ["..."],
  "ownedTasks": ["..."],
  "handoffs": [{ "to": "otro-agente", "when": "Condicion" }],
  "supportedProfiles": ["perfil-1", "perfil-2"],
  "steeringPacks": ["core", "..."],
  "localSkills": ["skill-1", "find-skills"],
  "remoteSkills": [],
  "modelDefault": "sonnet-4",
  "acceptanceChecklist": ["..."],
  "phase": 1
}
```

3. Asociar el agente a los perfiles correspondientes en `profiles/*.json` (campo `agents`)
4. Validar con `python3 lib/orbit_catalog.py --bootstrap-dir . validate-catalog`
5. Ejecutar `bash tests/test-catalog.sh`

## Agregar una skill local

1. Crear directorio `skills/<nombre>/`
2. Crear `skills/<nombre>/SKILL.md` con contenido completo:
   - Principios y reglas del dominio
   - Ejemplos de codigo (buenas practicas y anti-patrones)
   - Checklist de validacion
3. Agregar la skill a los perfiles que la necesiten (campo `localSkills` en `profiles/*.json`)
4. Agregar la skill a los agentes que la usen (campo `localSkills` en `agents-registry.json`)

Las skills deben ser documentos completos y utiles, no placeholders de una linea.

## Agregar una skill remota

1. Agregar la entrada al `remoteSkillsAllowlist` en `agents-registry.json`:

```json
{
  "id": "mi-skill-remota",
  "package": "org/repo@skill-name",
  "purpose": "Descripcion del proposito",
  "source": "skills.sh",
  "installMode": "confirm"
}
```

2. Referenciar el ID en los agentes y perfiles que la necesiten (campo `remoteSkills`)
3. La skill solo se instala con confirmacion explicita del usuario

## Agregar un perfil

1. Crear `profiles/<id>.json` con todos los campos requeridos:

```json
{
  "id": "mi-perfil",
  "phase": 1,
  "enabled": true,
  "name": "Nombre descriptivo",
  "description": "Descripcion corta",
  "dimensions": {
    "cloud": "aws",
    "workload": "backend-api",
    "runtime": "typescript",
    "provisioner": "none",
    "framework": "none",
    "features": ["api", "typescript"]
  },
  "wizard": { "workload": "backend-api", "runtime": "typescript" },
  "detection": { "priority": 200, "requiredFiles": ["package.json"], "..." : "..." },
  "tooling": { "linters": ["eslint"], "formatters": ["prettier"], "tests": ["vitest"], "typecheck": ["tsc"] },
  "agents": ["orbit", "aws-architect", "..."],
  "steeringPacks": ["core", "git", "security", "aws-shared", "..."],
  "localSkills": ["orbit-bootstrap", "find-skills", "..."],
  "remoteSkills": [],
  "hooks": ["node-format-on-save.kiro.hook"],
  "extensionPacks": ["base", "..."],
  "validations": [
    { "tool": "git", "command": "git --version", "minVersion": "2.30.0", "required": true, "installHint": "..." },
    { "tool": "node", "command": "node --version", "minVersion": "18.0.0", "required": true, "installHint": "..." }
  ],
  "envCheck": { "files": [], "requiredVars": [] },
  "awsCheck": true
}
```

2. Todos los perfiles deben incluir `git` en validaciones y `find-skills` en localSkills
3. Validar con `python3 lib/orbit_catalog.py --bootstrap-dir . validate-catalog`

## Agregar steering

1. Crear `steering/<nombre>.md` con reglas claras y accionables
2. Orientar por capa tecnica (seguridad, testing, runtime) no por proyecto
3. Agregar el nombre del pack a los perfiles y agentes que lo necesiten (campo `steeringPacks`)

## Agregar hooks

1. Crear `hooks/<nombre>.kiro.hook` como JSON valido:

```json
{
  "name": "Mi Hook",
  "version": "1.0.0",
  "when": {
    "type": "fileEdited",
    "patterns": ["*.ts", "*.tsx"]
  },
  "then": {
    "type": "runCommand",
    "command": "npm run lint"
  }
}
```

2. Agregar el nombre del archivo al campo `hooks` de los perfiles correspondientes

## Agregar extension packs

1. Crear `extensions/<nombre>.json` con la lista de extensiones de Kiro
2. Agregar el nombre al campo `extensionPacks` de los perfiles correspondientes
3. Agregar al `sharedPacks.extensionPacks` en `manifest.json` si aplica a todos

## Validacion

Siempre despues de cualquier cambio:

```bash
# Validar consistencia del catalogo
python3 lib/orbit_catalog.py --bootstrap-dir . validate-catalog

# Ejecutar tests completos
bash tests/test-all.sh
```
