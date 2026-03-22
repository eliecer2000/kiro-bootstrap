---
inclusion: fileMatch
fileMatchPattern: ["**/*.tf", "**/*.tfvars", "**/terraform/**", "**/.terraform*"]
---

# Terraform

## Estructura

```
infra/
├── main.tf                 # Recursos principales
├── variables.tf            # Variables de entrada
├── outputs.tf              # Outputs del modulo/stack
├── providers.tf            # Provider configuration
├── backend.tf              # State backend (S3 + DynamoDB)
├── terraform.tfvars        # Valores por entorno (no versionar prod)
└── modules/
    ├── lambda/
    ├── api-gateway/
    └── dynamodb/
```

## Principios

- State remoto en S3 con locking en DynamoDB. Nunca state local en produccion.
- Un workspace o directorio por entorno (`dev/`, `prod/`) o usar workspaces.
- Modulos para patrones repetidos. Mantener modulos pequenos y enfocados.

## Convenciones

- `terraform fmt` obligatorio antes de cada commit.
- `terraform validate` en CI.
- Nombres de recursos: `{proyecto}_{entorno}_{servicio}` con underscore.
- Variables con descripcion y tipo explicito. Usar `validation` blocks.
- Outputs para valores que otros modulos o servicios necesitan.

## Tags

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.team
  }
}
```

Aplicar `merge(local.common_tags, ...)` en cada recurso.

## Seguridad

- No incluir secretos en `.tfvars`. Usar `data "aws_secretsmanager_secret"`.
- Revisar plan antes de apply: `terraform plan -out=plan.tfplan`.
- Usar `prevent_destroy` en recursos criticos (tablas, buckets con datos).
