#!/usr/bin/env bash
# =============================================================================
# Kiro Bootstrap - Validación de Entorno: Frontend Nuxt
# Escala 24x7
#
# Valida herramientas, versiones, configuración AWS SSO y archivos .env
# para proyectos con perfil "frontend-nuxt".
#
# Uso:
#   bash validations/frontend-nuxt.sh /ruta/al/proyecto
#
# Validaciones:
#   - node >= 18.0.0 (requerido)
#   - npm >= 9.0.0 (requerido)
#   - git >= 2.30.0 (requerido)
#   - AWS SSO configurado
#   - Archivos .env con variables requeridas
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
# Ejecución de validaciones del perfil frontend-nuxt
# =============================================================================

RESULTS=()

# --- Herramientas requeridas (según manifest.json) ---

result=$(validate_tool "node" "node --version" "18.0.0" "true" "brew install node (macOS) | sudo apt install nodejs (Linux)") || true
RESULTS+=("$result")

result=$(validate_tool "npm" "npm --version" "9.0.0" "true" "Se instala con Node.js") || true
RESULTS+=("$result")

result=$(validate_tool "git" "git --version" "2.30.0" "true" "brew install git (macOS) | sudo apt install git (Linux)") || true
RESULTS+=("$result")

# --- Verificación de AWS SSO (awsCheck: true) ---

result=$(check_aws_sso) || true
RESULTS+=("$result")

# --- Verificación de archivos .env (envCheck) ---

env_results=$(check_env_files "$PROJECT_DIR" ".env .env.local" "NUXT_PUBLIC_API_BASE NUXT_PUBLIC_COGNITO_USER_POOL_ID") || true
while IFS= read -r line; do
  [[ -n "$line" ]] && RESULTS+=("$line")
done <<< "$env_results"

# =============================================================================
# Reporte de validación
# =============================================================================

print_validation_report "${RESULTS[@]}"
report_exit=$?

exit $report_exit
