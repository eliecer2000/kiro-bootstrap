#!/usr/bin/env bash
# =============================================================================
# Kiro Bootstrap - Validación de Entorno: Infraestructura Terraform
# Escala 24x7
#
# Valida herramientas, versiones y configuración AWS SSO
# para proyectos con perfil "infraestructura-terraform".
#
# Uso:
#   bash validations/infraestructura-terraform.sh /ruta/al/proyecto
#
# Validaciones:
#   - terraform >= 1.5.0 (requerido)
#   - aws >= 2.0.0 (requerido)
#   - git >= 2.30.0 (requerido)
#   - AWS SSO configurado
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
# Ejecución de validaciones del perfil infraestructura-terraform
# =============================================================================

RESULTS=()

# --- Herramientas requeridas (según manifest.json) ---

result=$(validate_tool "terraform" "terraform --version" "1.5.0" "true" "brew install terraform (macOS) | sudo apt install terraform (Linux)") || true
RESULTS+=("$result")

result=$(validate_tool "aws" "aws --version" "2.0.0" "true" "brew install awscli (macOS) | sudo apt install awscli (Linux)") || true
RESULTS+=("$result")

result=$(validate_tool "git" "git --version" "2.30.0" "true" "brew install git (macOS) | sudo apt install git (Linux)") || true
RESULTS+=("$result")

# --- Verificación de AWS SSO (awsCheck: true) ---

result=$(check_aws_sso) || true
RESULTS+=("$result")

# =============================================================================
# Reporte de validación
# =============================================================================

print_validation_report "${RESULTS[@]}"
report_exit=$?

exit $report_exit
