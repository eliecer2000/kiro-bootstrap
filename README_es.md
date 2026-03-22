# Orbit Bootstrap

> Framework AWS-first para [Kiro](https://kiro.dev) que detecta automáticamente el tipo de proyecto, valida e instala herramientas, carga los agentes y skills correctos por perfil, y deja el entorno listo para construir en segundos.

---

## El problema que resuelve

Todo proyecto AWS empieza igual: copiar configs, instalar linters, buscar los prompts correctos para los agentes, conectar hooks, recordar qué reglas de steering aplican. Es repetitivo, propenso a errores y consume tiempo antes de escribir una sola línea de lógica de negocio.

Orbit elimina esa fricción. Lee tu proyecto, resuelve el perfil correcto, valida el entorno y carga un conjunto curado de agentes, skills, reglas de steering y hooks — todo adaptado a tu stack. Pasas de un directorio vacío a un workspace completamente configurado con asistencia de IA en un solo comando.

---

## Cómo funciona

Orbit ejecuta un pipeline de 6 pasos cuando preparas un proyecto:

```
1. Session Gates          Pregunta una vez por sesión si deseas preparar el entorno
2. Detect / Select Profile  Detecta el tipo de proyecto o lanza un wizard interactivo
3. Validate Environment   Verifica herramientas de sistema (git, node, python3, aws, terraform)
                          e instala las que falten via brew / apt / nvm / corepack
4. Load Artifacts         Copia agentes, steering packs, skills, hooks y extensiones
                          del framework a .kiro/ con scope al perfil del proyecto
5. Install Tooling        Instala devDependencies del proyecto (eslint, prettier, vitest,
                          ruff, black, pytest, tsc, mypy) usando el package manager detectado
6. Write Project State    Escribe .kiro/.orbit-project.json con metadata del perfil
```

La resolución de perfil usa 4 dimensiones:

| Dimensión   | Opciones |
|-------------|----------|
| Workload    | backend-api, backend-worker, infra, shared-lib, frontend-amplify |
| Runtime     | typescript, javascript, python |
| Provisioner | cdk, terraform |
| Framework   | react, vue, nuxt (solo frontend-amplify) |

La detección automática evalúa archivos requeridos, globs, dependencias en package.json (wildcards como @aws-sdk/*) y patrones de texto. Si ningún perfil hace match, se lanza el wizard.

---

## Instalación

```bash
curl -sL https://raw.githubusercontent.com/eliecer2000/kiro-bootstrap/main/install.sh | bash
```

Después de instalar:

```bash
~/.kiro/orbit/install.sh --help
~/.kiro/orbit/install.sh --update
~/.kiro/orbit/install.sh --resync-project .
~/.kiro/orbit/install.sh --status
~/.kiro/orbit/install.sh --doctor
```

---

## Perfiles

### Fase 1 - Activos

| Perfil | Workload | Runtime | Provisioner |
|---|---|---|---|
| aws-backend-api-typescript | API Backend | TypeScript | - |
| aws-backend-api-python | API Backend | Python | - |
| aws-backend-api-javascript | API Backend | JavaScript | - |
| aws-backend-lambda-typescript | Lambda Worker | TypeScript | - |
| aws-backend-lambda-python | Lambda Worker | Python | - |
| aws-backend-lambda-javascript | Lambda Worker | JavaScript | - |
| aws-infra-cdk-typescript | Infraestructura | TypeScript | CDK |
| aws-infra-terraform | Infraestructura | HCL | Terraform |
| aws-shared-lib-typescript | Shared Library | TypeScript | - |
| aws-shared-lib-python | Shared Library | Python | - |
| aws-shared-lib-javascript | Shared Library | JavaScript | - |

### Fase 2 - Preparados (deshabilitados)

| Perfil | Framework |
|---|---|
| aws-amplify-react | React |
| aws-amplify-vue | Vue |
| aws-amplify-nuxt | Nuxt |

---

## Agentes

14 agentes especializados asignados por perfil. Cada agente tiene un rol declarado, responsabilidades y reglas de handoff — se coordinan automáticamente sin configuración manual.

| Agente | Rol |
|---|---|
| orbit | Bootstrap, onboarding, resincronización y coordinación |
| aws-architect | Arquitectura AWS, patrones serverless, decisiones de diseño |
| aws-lambda-python | Funciones Lambda con Python |
| aws-lambda-typescript | Funciones Lambda con TypeScript / JavaScript |
| aws-api-integration | Contratos API, eventos, auth e integraciones |
| aws-cdk | Infraestructura con AWS CDK |
| aws-terraform | Infraestructura con Terraform |
| aws-iam-security | IAM, secretos, cifrado y least privilege |
| aws-data-dynamodb | Modelado DynamoDB y access patterns |
| aws-observability | Logs, métricas, alarmas y trazas |
| aws-test-quality | Pruebas, quality gates y aceptación técnica |
| aws-amplify-react | Frontend Amplify + React (fase 2) |
| aws-amplify-vue | Frontend Amplify + Vue (fase 2) |
| aws-amplify-nuxt | Frontend Amplify + Nuxt (fase 2) |

Los handoffs están declarados en agents-registry.json: orbit a aws-architect cuando se necesita diseño de arquitectura, aws-architect a aws-iam-security cuando las decisiones tocan IAM o networking, agentes aws-lambda a aws-test-quality cuando se requieren tests.

---

## Skills

22 skills locales organizadas por dominio. Las skills son documentos Markdown cargados en el contexto del agente — contienen reglas de dominio, ejemplos de código, anti-patrones y checklists de validación.

| Categoría | Skills |
|---|---|
| Runtime | typescript-runtime, javascript-runtime, python-runtime |
| Serverless | aws-lambda-typescript, aws-lambda-python, aws-serverless |
| API y Data | aws-api, aws-dynamodb |
| Infraestructura | aws-cdk, aws-terraform, aws-ec2, aws-rds, aws-s3, aws-cloudfront |
| Seguridad | aws-security |
| Operaciones | aws-observability, aws-cost-operations, aws-diagrams |
| Testing | aws-testing |
| Arquitectura | aws-architecture |
| Framework | orbit-bootstrap, find-skills |

find-skills es obligatoria en todos los perfiles — permite a los agentes descubrir y activar skills adicionales bajo demanda.

---

## Steering packs

Los steering packs son reglas de contexto inyectadas en cada sesión de Kiro. Codifican estándares de equipo, buenas prácticas de AWS y convenciones específicas del runtime para que los agentes las sigan sin necesidad de indicárselo.

Packs compartidos en todos los perfiles: core, git, security, aws-shared, testing, observability.

Packs adicionales por perfil: runtime-typescript, runtime-python, runtime-javascript, lambda, api, cdk, terraform, amplify.

Tres modos de inclusión: `always` (cada sesión), `fileMatch` (cuando se abre un archivo que coincide con el patrón), `manual` (activado por el usuario con # en el chat).

---

## Hooks

Los hooks automatizados se ejecutan en eventos del IDE sin configuración manual. Cada perfil recibe los hooks que corresponden a su runtime:

| Runtime | Hooks |
|---|---|
| Node.js (TS/JS) | format on save, lint on save, test after task |
| Python | format on save, lint on save, test after task |
| Terraform | fmt on save, validate after task |

---

## Catálogo declarativo

Todo en Orbit es declarativo. El catálogo es la fuente de verdad:

- `manifest.json` — pasos del pipeline, políticas (estrategia de conflictos, skills remotas, opt-out de sesión), preguntas del wizard y comandos públicos
- `profiles/*.json` — un archivo por perfil: dimensiones, reglas de detección, tooling, agentes, steering, skills, hooks, validaciones
- `agents-registry.json` — contrato completo por agente: rol, responsabilidades, handoffs, skills, modelo, checklist de aceptación y allowlist de skills remotas

El runtime (`lib/orbit_catalog.py`) lee el catálogo y actúa. Sin lógica hardcodeada.

---

## Validación del catálogo

```bash
python3 lib/orbit_catalog.py --bootstrap-dir . validate-catalog
```

Valida consistencia cruzada entre manifest, profiles y agents-registry: campos requeridos, referencias a agentes, allowlist de skills remotas y presencia de archivos de agentes.

---

## Ejecución desde Kiro

Cuando Orbit opera desde el chat de Kiro, ejecuta el pipeline real antes de cualquier scaffolding:

```bash
ORBIT_BOOTSTRAP_DECISION=yes \
ORBIT_HOME_DECISION=no \
ORBIT_PROJECT_PROFILE_ID=<profile-id> \
ORBIT_REMOTE_SKILL_DECISION=no \
~/.kiro/orbit/install.sh --resync-project "<ruta>"
```

Orbit resuelve el profile-id internamente a partir del wizard. Nunca pide el ID crudo, credenciales AWS ni perfil de CLI durante el bootstrap normal. El scaffolding solo comienza después de que `.kiro/.orbit-project.json` existe y todos los directorios de artefactos están cargados.

---

## Estructura del repositorio

```
agents/          Definiciones JSON de cada agente
profiles/        Perfiles de proyecto (detección, tooling, validaciones, agentes, skills)
steering/        Packs de reglas por capa técnica
skills/          Skills locales con documentación completa
hooks/           Hooks automatizados por runtime (format, lint, test)
extensions/      Packs de extensiones de Kiro por perfil
lib/             Runtime: pipeline, sesión, catálogo, carga de artefactos, instalación de tooling
validations/     Validación y auto-instalación de herramientas de sistema
docs/            Documentación técnica del framework
templates/       Plantillas de contexto para onboarding de proyectos
tests/           Suite de tests del framework
```

---

## Tests

```bash
bash tests/test-all.sh
```

---

## Documentación

- [Arquitectura](docs/architecture.md) — Componentes, catálogo declarativo y runtime
- [Flujo de Bootstrap](docs/bootstrap-flow.md) — Pipeline paso a paso
- [Matriz de Perfiles](docs/profile-matrix.md) — Detalle de cada perfil
- [Catálogo de Agentes](docs/agent-catalog.md) — Roles, responsabilidades y handoffs
- [Guía de Authoring](docs/authoring.md) — Cómo agregar agentes, skills, perfiles y steering

---

## Releases

```bash
bash release.sh 2.5.0
```

Ver [CONTRIBUTING.md](CONTRIBUTING.md#release-process) para más detalles.

---

## Contribuir

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para agregar perfiles, agentes, skills y steering packs.

Lee nuestro [Código de Conducta](CODE_OF_CONDUCT.md) antes de participar.

## Seguridad

Para reportar una vulnerabilidad, ver [SECURITY.md](SECURITY.md). No abras issues públicos para temas de seguridad.

## Licencia

[MIT](LICENSE) — Eliezer Rangel
