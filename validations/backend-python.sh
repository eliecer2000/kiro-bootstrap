#!/usr/bin/env bash
# =============================================================================
# Kiro Bootstrap - Validación de Entorno: Backend Python
# Escala 24x7
#
# Valida herramientas y versiones para proyectos con perfil "backend-python".
#
# Uso:
#   bash validations/backend-python.sh /ruta/al/proyecto
#
# Validaciones:
#   - python3 >= 3.10.0 (requerido)
#
# Salida:
#   Código 0 si todas las validaciones pasan, 1 si alguna falla
# =============================================================================

set -euo pipefail

# Resolver directorio del script para importar common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# =============================================================================
# Validación de argumentos
# =============================================================================

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <directorio-del-proyecto>"
  exit 1
fi

PROJECT_DIR="$1"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: El directorio '${PROJECT_DIR}' no existe."
  exit 1
fi

# =============================================================================
# Ejecución de validaciones del perfil backend-python
# =============================================================================

RESULTS=()

# --- Herramientas requeridas (según manifest.json) ---

result=$(validate_tool "python3" "python3 --version" "3.10.0" "true" "brew install python3 (macOS) | sudo apt install python3 (Linux)") || true
RESULTS+=("$result")

# --- No requiere AWS SSO (awsCheck: false) ---

# =============================================================================
# Reporte de validación
# =============================================================================

print_validation_report "${RESULTS[@]}"
report_exit=$?

exit $report_exit
