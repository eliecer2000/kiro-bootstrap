---
inclusion: fileMatch
fileMatchPattern: ["**/*.py", "**/pyproject.toml", "**/requirements*.txt", "**/setup.py"]
---

# Runtime Python

## Configuracion

- Python 3.12+ como target.
- Usar `pyproject.toml` como fuente unica de configuracion.
- Package manager: `uv` (preferido) > `poetry` > `pip`.

## Herramientas

```toml
[tool.ruff]
line-length = 120
target-version = "py312"
select = ["E", "F", "I", "N", "W", "UP"]

[tool.black]
line-length = 120

[tool.mypy]
python_version = "3.12"
strict = true

[tool.pytest.ini_options]
testpaths = ["tests"]
```

## Convenciones

- Type hints en funciones publicas y modelos de datos.
- Docstrings en modulos y funciones publicas (Google style).
- Imports ordenados: stdlib, terceros, locales (ruff los ordena).
- Evitar imports circulares: separar modelos de servicios.

## AWS SDK

- Usar `boto3` con type stubs: `boto3-stubs[dynamodb,lambda,s3]`.
- Inicializar clientes fuera del handler.
- Usar `botocore.exceptions.ClientError` para manejo de errores AWS.

## Estructura

```
src/
├── handlers/       # Entry points Lambda
├── services/       # Logica de negocio
├── models/         # Dataclasses / Pydantic models
└── utils/          # Helpers compartidos
tests/
├── unit/
└── integration/
```

## Empaquetado Lambda

- Dependencias en `requirements.txt` o Lambda layer.
- Excluir `__pycache__/`, `tests/`, `*.pyc` del zip.
- Mantener paquete bajo 50MB (250MB descomprimido con layers).
