#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Orbit test suite"
echo "================"

bash "${SCRIPT_DIR}/test-catalog.sh"
bash "${SCRIPT_DIR}/test-runtime.sh"
bash "${SCRIPT_DIR}/test-session.sh"
bash "${SCRIPT_DIR}/test-install.sh"

echo ""
echo "Todas las verificaciones de Orbit pasaron."
