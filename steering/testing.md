---
inclusion: fileMatch
fileMatchPattern: ["**/*.test.*", "**/*.spec.*", "**/tests/**", "**/vitest.config.*", "**/jest.config.*", "**/pytest.ini"]
---

# Testing

## Estrategia

- Cada cambio relevante debe tener pruebas asociadas.
- Piramide de tests: muchos unitarios, algunos de integracion, pocos e2e.
- Priorizar escenarios de error y edge cases sobre happy path.

## Tests unitarios

- Probar logica de negocio aislada de infraestructura.
- Mockear dependencias externas (AWS SDK, HTTP, DB).
- Nombres descriptivos: `should return 404 when order not found`.
- Un assert por test cuando sea posible.

## Tests de integracion

- Probar interaccion real con servicios (DynamoDB local, LocalStack).
- Usar fixtures y cleanup automatico.
- Separar de unitarios con directorios o naming (`*.integration.test.*`).

## Quality gates

| Gate | Umbral minimo |
|---|---|
| Cobertura de lineas | 80% |
| Tests pasando | 100% |
| Lint sin errores | 0 errores |
| Type check | 0 errores |

## Herramientas por runtime

| Runtime | Unit | Integration | Coverage |
|---|---|---|---|
| TypeScript | vitest | vitest + localstack | c8 / istanbul |
| Python | pytest | pytest + moto / localstack | coverage.py |
| Terraform | terraform validate | terratest | N/A |

## Anti-patrones

- No escribir tests que dependen del orden de ejecucion.
- No testear implementacion interna, testear comportamiento.
- No ignorar tests fallidos con skip permanente.
