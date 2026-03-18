#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${BOOTSTRAP_DIR}/install.sh"

PASS=0
FAIL=0

pass() { echo "  + $1"; PASS=$((PASS + 1)); }
fail() { echo "  x $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Install Orbit ==="

if output="$(print_help)" && echo "${output}" | grep -q -- "--resync-project"; then
  pass "help documenta resincronizacion"
else
  fail "help no documenta resincronizacion"
fi

INSTALL_CONTENT="$(cat "${BOOTSTRAP_DIR}/install.sh")"
for token in "--help" "--update" "--resync-project" "Orbit Bootstrap" "~/.kiro/orbit"; do
  if echo "${INSTALL_CONTENT}" | grep -q -- "${token}"; then
    pass "install.sh contiene ${token}"
  else
    fail "install.sh no contiene ${token}"
  fi
done

if bash -n "${BOOTSTRAP_DIR}/install.sh" >/dev/null 2>&1; then
  pass "install.sh sin errores de sintaxis"
else
  fail "install.sh con errores de sintaxis"
fi

echo ""
echo "Resultados: ${PASS} ok, ${FAIL} fallos"
[[ "${FAIL}" -eq 0 ]]
