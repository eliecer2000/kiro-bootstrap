# Matriz de Perfiles

## Fase 1 — Perfiles activos

### Backend API

| Perfil | Runtime | Agentes | Tooling | Validaciones |
|---|---|---|---|---|
| `aws-backend-api-typescript` | TypeScript | orbit, aws-architect, aws-api-integration, aws-iam-security, aws-observability, aws-test-quality | eslint, prettier, vitest, tsc | git, node, npm, aws |
| `aws-backend-api-python` | Python | orbit, aws-architect, aws-api-integration, aws-iam-security, aws-observability, aws-test-quality | ruff, black, pytest, mypy | git, python3, aws |
| `aws-backend-api-javascript` | JavaScript | orbit, aws-architect, aws-api-integration, aws-iam-security, aws-observability, aws-test-quality | eslint, prettier, vitest | git, node, npm, aws |

### Backend Lambda

| Perfil | Runtime | Agentes | Tooling | Validaciones |
|---|---|---|---|---|
| `aws-backend-lambda-typescript` | TypeScript | orbit, aws-architect, aws-lambda-typescript, aws-iam-security, aws-observability, aws-test-quality | eslint, prettier, vitest, tsc | git, node, npm, aws |
| `aws-backend-lambda-python` | Python | orbit, aws-architect, aws-lambda-python, aws-iam-security, aws-observability, aws-test-quality | ruff, black, pytest, mypy | git, python3, aws |
| `aws-backend-lambda-javascript` | JavaScript | orbit, aws-architect, aws-lambda-typescript, aws-iam-security, aws-observability, aws-test-quality | eslint, prettier, vitest | git, node, npm, aws |

### Infraestructura

| Perfil | Provisioner | Agentes | Tooling | Validaciones |
|---|---|---|---|---|
| `aws-infra-cdk-typescript` | CDK | orbit, aws-architect, aws-cdk, aws-iam-security, aws-observability, aws-test-quality | eslint, prettier, vitest, tsc | git, node, npm, aws |
| `aws-infra-terraform` | Terraform | orbit, aws-architect, aws-terraform, aws-iam-security, aws-observability | terraform fmt, terraform validate | git, terraform, aws |

### Shared Library

| Perfil | Runtime | Agentes | Tooling | Validaciones |
|---|---|---|---|---|
| `aws-shared-lib-typescript` | TypeScript | orbit, aws-architect, aws-test-quality | eslint, prettier, vitest, tsc | git, node, npm |
| `aws-shared-lib-python` | Python | orbit, aws-architect, aws-test-quality | ruff, black, pytest, mypy | git, python3 |
| `aws-shared-lib-javascript` | JavaScript | orbit, aws-architect, aws-test-quality | eslint, prettier, vitest | git, node, npm |

## Fase 2 — Preparados (deshabilitados)

| Perfil | Framework | Agentes | Validaciones |
|---|---|---|---|
| `aws-amplify-react` | React | orbit, aws-amplify-react | git, node, npm |
| `aws-amplify-vue` | Vue | orbit, aws-amplify-vue | git, node, npm |
| `aws-amplify-nuxt` | Nuxt | orbit, aws-amplify-nuxt | git, node, npm |

## Dimensiones del wizard

Cada perfil se resuelve combinando estas dimensiones:

| Dimension | Valores posibles | Aplica a |
|---|---|---|
| `workload` | backend-api, backend-worker, infra, shared-lib, frontend-amplify | Todos |
| `runtime` | typescript, javascript, python | backend-api, backend-worker, shared-lib |
| `provisioner` | cdk, terraform | infra |
| `framework` | react, vue, nuxt | frontend-amplify |

## Deteccion automatica

Cada perfil define reglas de deteccion que se evaluan contra el directorio del proyecto:

- `requiredFiles` — archivos que deben existir (ej: `cdk.json`, `package.json`)
- `anyFiles` — al menos uno debe existir (ej: `pyproject.toml`, `requirements.txt`)
- `excludeFiles` — si alguno existe, el perfil se descarta (ej: `tsconfig.json` para perfiles JS)
- `packageJsonDependencies` — dependencias requeridas (soporta wildcards: `@aws-sdk/*`)
- `anyGlobs` / `requiredGlobs` — patrones glob sobre la estructura
- `textPatterns` — texto dentro de archivos especificos
- `priority` — peso numerico para desempate entre perfiles

Si ningun perfil hace match, Orbit lanza el wizard interactivo.

## Skills por perfil

Todos los perfiles incluyen `orbit-bootstrap` y `find-skills` como skills obligatorias. Ademas:

| Tipo de perfil | Skills adicionales |
|---|---|
| Backend API (TS/JS) | typescript-runtime o javascript-runtime, aws-api, aws-serverless, aws-testing, aws-observability |
| Backend API (Python) | python-runtime, aws-api, aws-serverless, aws-testing, aws-observability |
| Lambda (TS/JS) | typescript-runtime o javascript-runtime, aws-lambda-typescript, aws-serverless, aws-testing, aws-observability |
| Lambda (Python) | python-runtime, aws-lambda-python, aws-serverless, aws-testing, aws-observability |
| CDK | typescript-runtime, aws-cdk, aws-testing, aws-observability |
| Terraform | aws-terraform, aws-security, aws-observability |
| Shared Lib | runtime correspondiente, aws-testing |
| Amplify | typescript-runtime |

## Hooks por perfil

| Runtime | Hooks |
|---|---|
| Node.js (TS/JS) | node-format-on-save, node-lint-on-save, node-test-after-task |
| Python | python-format-on-save, python-lint-on-save, python-test-after-task |
| Terraform | terraform-fmt-on-save, terraform-validate-after-task |
