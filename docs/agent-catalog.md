# Agent Catalog

## Nucleo

| Agente | Rol | Perfiles |
|---|---|---|
| `orbit` | Bootstrap, onboarding, resincronizacion y coordinacion | Todos |

## AWS Core

| Agente | Rol | Perfiles |
|---|---|---|
| `aws-architect` | Arquitectura AWS, patrones serverless y decisiones de diseno | Backend, Lambda, Infra, Shared Lib |
| `aws-iam-security` | IAM, secretos, cifrado y least privilege | Todos |
| `aws-observability` | Logs, metricas, alarmas y trazas | Todos |
| `aws-test-quality` | Pruebas, quality gates y aceptacion tecnica | Todos |

## AWS Workloads

| Agente | Rol | Perfiles |
|---|---|---|
| `aws-lambda-python` | Funciones Lambda con Python | aws-backend-lambda-python |
| `aws-lambda-typescript` | Funciones Lambda con TypeScript/JavaScript | aws-backend-lambda-typescript, aws-backend-lambda-javascript |
| `aws-api-integration` | Contratos API, eventos, auth e integraciones | aws-backend-api-* |
| `aws-terraform` | Infraestructura con Terraform | aws-infra-terraform |
| `aws-cdk` | Infraestructura con AWS CDK | aws-infra-cdk-typescript |
| `aws-data-dynamodb` | Modelado DynamoDB y access patterns | Backend API, Lambda |

## Fase 2 (preparados, deshabilitados)

| Agente | Rol | Perfiles |
|---|---|---|
| `aws-amplify-react` | Frontend Amplify + React | aws-amplify-react |
| `aws-amplify-vue` | Frontend Amplify + Vue | aws-amplify-vue |
| `aws-amplify-nuxt` | Frontend Amplify + Nuxt | aws-amplify-nuxt |

## Handoffs entre agentes

Los agentes se coordinan mediante handoffs declarados en `agents-registry.json`:

| Desde | Hacia | Condicion |
|---|---|---|
| `orbit` | `aws-architect` | Se requiere diseno de arquitectura |
| `orbit` | `aws-test-quality` | Se necesitan pruebas o quality gates |
| `aws-architect` | `aws-iam-security` | Decisiones afectan IAM, networking o secretos |
| `aws-architect` | `aws-terraform` | Implementacion con Terraform |
| `aws-architect` | `aws-cdk` | Implementacion con CDK |
| `aws-lambda-*` | `aws-api-integration` | Lambda expone o consume contratos HTTP |
| `aws-lambda-*` | `aws-test-quality` | Se requieren tests |
| `aws-api-integration` | `aws-lambda-python` | Implementacion objetivo es Python |
| `aws-api-integration` | `aws-lambda-typescript` | Implementacion objetivo es Node.js |
| `aws-terraform` | `aws-iam-security` | Cambios incluyen IAM, redes o secretos |
| `aws-cdk` | `aws-iam-security` | Infraestructura exige revision de permisos |
| `aws-data-dynamodb` | `aws-architect` | Modelado impacta arquitectura o contratos |
| `aws-observability` | `aws-test-quality` | Observabilidad debe cubrirse con pruebas |

## Configuracion de agentes

Todos los agentes deben cumplir:

- Modelo: `claude-sonnet-4`
- Resources: `["skill://.kiro/skills/**/SKILL.md"]`
- Registrados en `agents-registry.json` con contrato completo
- Archivo JSON en `agents/<nombre>.json`
