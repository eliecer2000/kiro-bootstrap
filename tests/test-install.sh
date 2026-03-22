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

if echo "${output}" | grep -q -- "--doctor"; then
  pass "help documenta doctor"
else
  fail "help no documenta doctor"
fi

if echo "${output}" | grep -q -- "--status"; then
  pass "help documenta status"
else
  fail "help no documenta status"
fi

INSTALL_CONTENT="$(cat "${BOOTSTRAP_DIR}/install.sh")"
for token in "--help" "--update" "--resync-project" "--doctor" "--status" "Orbit Bootstrap" '$HOME/.kiro/orbit'; do
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

if output="$(bash -s -- --help < "${BOOTSTRAP_DIR}/install.sh")" && echo "${output}" | grep -q "Orbit Bootstrap"; then
  pass "install.sh funciona via stdin con --help"
else
  fail "install.sh falla via stdin con --help"
fi

if grep -rn --fixed-strings "install.sh --resync-project" "${BOOTSTRAP_DIR}/hooks/orbit-session.kiro.hook" "${BOOTSTRAP_DIR}/steering/orbit-session.md" "${BOOTSTRAP_DIR}/agents/orbit.json" >/dev/null 2>&1; then
  pass "Orbit exige resync antes del scaffolding"
else
  fail "Orbit no exige resync antes del scaffolding"
fi

if grep -rn --fixed-strings "ORBIT_PROJECT_PROFILE_ID" "${BOOTSTRAP_DIR}/install.sh" "${BOOTSTRAP_DIR}/hooks/orbit-session.kiro.hook" "${BOOTSTRAP_DIR}/steering/orbit-session.md" "${BOOTSTRAP_DIR}/README.md" "${BOOTSTRAP_DIR}/docs/bootstrap-flow.md" >/dev/null 2>&1; then
  pass "Orbit usa project profile id en la interfaz publica"
else
  fail "Orbit no usa project profile id en la interfaz publica"
fi

if grep -rn 'credenciales AWS diferida\|credenciales ni validar identidad AWS\|perfil de AWS CLI' "${BOOTSTRAP_DIR}/README.md" "${BOOTSTRAP_DIR}/hooks/orbit-session.kiro.hook" "${BOOTSTRAP_DIR}/steering/orbit-session.md" "${BOOTSTRAP_DIR}/docs/bootstrap-flow.md" >/dev/null 2>&1; then
  pass "Orbit difiere credenciales AWS hasta despliegue"
else
  fail "Orbit no documenta el diferimiento de credenciales AWS"
fi

if INSTALL_DIR="${BOOTSTRAP_DIR}" orbit_doctor >/dev/null 2>&1; then
  pass "orbit_doctor pasa sin errores"
else
  fail "orbit_doctor reporta problemas"
fi

echo ""
echo "Resultados: ${PASS} ok, ${FAIL} fallos"
[[ "${FAIL}" -eq 0 ]]
