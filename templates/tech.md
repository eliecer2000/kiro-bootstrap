# Runtime Checklist

## Runtime

| Campo | Valor |
|---|---|
| Lenguaje | {{runtime}} |
| Version minima | {{min_version}} |
| Package manager | {{package_manager}} |
| Entry point | `src/handlers/` |

## Linter y Formatter

### TypeScript / JavaScript

```json
{
  "scripts": {
    "lint": "eslint src/ --ext .ts,.tsx",
    "lint:fix": "eslint src/ --ext .ts,.tsx --fix",
    "format": "prettier --write 'src/**/*.{ts,tsx,json}'",
    "format:check": "prettier --check 'src/**/*.{ts,tsx,json}'"
  }
}
```

### Python

```toml
[tool.ruff]
line-length = 120
target-version = "py312"

[tool.black]
line-length = 120
target-version = ["py312"]
```

### Terraform

```bash
terraform fmt -recursive
terraform validate
```

<!-- Mantener solo la seccion del runtime del proyecto -->

## Testing y Quality Gates

| Gate | Herramienta | Comando | Umbral |
|---|---|---|---|
| Unit tests | vitest / pytest | `npm test` / `pytest` | 80% cobertura |
| Type check | tsc / mypy | `tsc --noEmit` / `mypy src/` | 0 errores |
| Lint | eslint / ruff | `npm run lint` / `ruff check` | 0 errores |
| Format | prettier / black | `npm run format:check` / `black --check` | 0 diffs |

## Tooling AWS

| Herramienta | Proposito | Instalacion |
|---|---|---|
| AWS CLI v2 | Interaccion con servicios AWS | `brew install awscli` |
| AWS SAM CLI | Testing local de Lambda | `brew install aws-sam-cli` |
| CDK CLI | Deploy de stacks CDK | `npm install -g aws-cdk` |
| Terraform | IaC declarativo | `brew install terraform` |

<!-- Mantener solo las herramientas relevantes al perfil -->

## Observabilidad

### Logs estructurados

```typescript
// TypeScript — usar JSON estructurado
const log = (level: string, message: string, context: Record<string, unknown>) => {
  console.log(JSON.stringify({ level, message, timestamp: new Date().toISOString(), ...context }));
};
```

```python
# Python — usar structlog o logging con JSON
import structlog
logger = structlog.get_logger()
logger.info("event_processed", order_id=order_id, status="success")
```

### Metricas clave

| Metrica | Tipo | Alarma |
|---|---|---|
| Invocaciones Lambda | Count | N/A |
| Errores Lambda | Count | > 5 en 5 min |
| Duracion Lambda | p99 | > 10s |
| Throttles | Count | > 0 |
| DynamoDB consumed RCU/WCU | Sum | > 80% provisioned |
