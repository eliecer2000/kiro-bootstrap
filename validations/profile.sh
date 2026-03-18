#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/common.sh"

if [[ $# -lt 2 ]]; then
  echo "Uso: $0 <profile-id> <project-dir>"
  exit 1
fi

PROFILE_ID="$1"
PROJECT_DIR="$2"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: El directorio '${PROJECT_DIR}' no existe."
  exit 1
fi

validate_profile_environment "$PROJECT_DIR" "$BOOTSTRAP_DIR" "$PROFILE_ID"
