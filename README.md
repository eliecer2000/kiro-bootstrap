# Orbit Bootstrap

Framework personal de bootstrap para Kiro con enfoque AWS-first. Orbit detecta o resuelve el tipo de proyecto, valida el entorno, carga agentes/steering/skills por perfil, recomienda extensiones y puede resincronizar `.kiro` cuando el proyecto cambia.

## Instalacion

```bash
curl -sL https://raw.githubusercontent.com/eliecer2000/kiro-bootstrap/main/install.sh | bash
```

Comandos principales:

```bash
~/.kiro/orbit/install.sh --help
~/.kiro/orbit/install.sh --update
~/.kiro/orbit/install.sh --resync-project .
```

## Que Hace Orbit

- Pregunta si deseas preparar el entorno antes de ejecutar bootstrap.
- Si arrancas en `HOME`, ofrece crear una carpeta de proyecto una sola vez por sesion.
- Detecta perfiles AWS-first o lanza un wizard guiado por workload, runtime y provisioner.
- Valida tooling del runtime.
- Carga agentes, steering, skills locales y hooks compatibles con el perfil.
- Propone skills remotas via `skills.sh` con confirmacion explicita.
- Escribe `.kiro/.orbit-project.json` para registrar perfil y ultima resincronizacion.

## Ejecucion Desde Kiro

Cuando el usuario pide configurar el entorno, Orbit debe ejecutar primero el pipeline real del framework y solo despues continuar con el scaffolding del stack. El patron esperado es:

```bash
ORBIT_BOOTSTRAP_DECISION=yes ORBIT_HOME_DECISION=no ORBIT_PROFILE_ID=<profile-id> ORBIT_REMOTE_SKILL_DECISION=no ~/.kiro/orbit/install.sh --resync-project "<ruta>"
```

Si el usuario aprueba skills remotas, `ORBIT_REMOTE_SKILL_DECISION` debe ir en `yes`.

No se debe iniciar `cdk init`, `terraform init` ni scaffolding de aplicacion hasta que existan `.kiro/.orbit-project.json`, `.kiro/agents`, `.kiro/steering`, `.kiro/skills` y `.kiro/hooks`.

## Perfiles Soportados

Fase 1:

- `aws-backend-api-python`
- `aws-backend-api-typescript`
- `aws-backend-api-javascript`
- `aws-backend-lambda-python`
- `aws-backend-lambda-typescript`
- `aws-backend-lambda-javascript`
- `aws-infra-terraform`
- `aws-infra-cdk-typescript`
- `aws-shared-lib-python`
- `aws-shared-lib-typescript`
- `aws-shared-lib-javascript`

Fase 2 preparada en catalogo:

- `aws-amplify-react`
- `aws-amplify-vue`
- `aws-amplify-nuxt`

## Catalogo de Agentes AWS

- `orbit`: bootstrap, onboarding, resincronizacion, gating de skills remotas y escritura del estado del proyecto.
- `aws-architect`: arquitectura, segmentacion del sistema y decisiones AWS-first.
- `aws-lambda-python`: Lambda Python, handlers, empaquetado, pruebas y observabilidad.
- `aws-lambda-typescript`: Lambda TypeScript/JavaScript, bundling, AWS SDK v3 y runtime Node.js.
- `aws-api-integration`: contratos HTTP, eventos, auth e integraciones.
- `aws-terraform`: Terraform, modulos, state y despliegue IaC.
- `aws-cdk`: stacks, constructs y flujos CDK.
- `aws-iam-security`: IAM, secretos, cifrado y endurecimiento basico.
- `aws-data-dynamodb`: modelado DynamoDB y access patterns.
- `aws-observability`: logs, metricas, alarmas y trazas.
- `aws-test-quality`: pruebas, contratos y quality gates.

## Estructura

```text
agents/       Definiciones JSON de agentes Orbit
profiles/     Fuente de verdad por perfil
steering/     Packs de reglas por capa
skills/       Skills locales del framework
hooks/        Automatizaciones segmentadas por runtime
extensions/   Packs de extensiones de Kiro
lib/          Runtime shell + parser del catalogo
validations/  Validacion declarativa por perfil
docs/         Guias de uso, catalogo y authoring
templates/    Plantillas de contexto tecnico y onboarding
```

## Skills.sh

Orbit usa un allowlist de skills remotas en `agents-registry.json`. Cuando una skill remota es necesaria:

1. Muestra el paquete, el proposito y el comando exacto.
2. Pide confirmacion.
3. Ejecuta `npx skills add <package> -g -y` solo si el usuario acepta.

## Agregar Nuevos Agentes

1. Crear el JSON del agente en `agents/`.
2. Registrar el contrato completo en `agents-registry.json`.
3. Asociar steering packs, skills locales y remote skills permitidas.
4. Declarar perfiles soportados.
5. Documentar el agente y agregar cobertura minima en tests.

## Documentacion

- [Arquitectura](docs/architecture.md)
- [Flujo de Bootstrap](docs/bootstrap-flow.md)
- [Matriz de Perfiles](docs/profile-matrix.md)
- [Catalogo de Agentes](docs/agent-catalog.md)
- [Authoring](docs/authoring.md)

## Tests

```bash
bash tests/test-all.sh
```
