#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  + $1"; PASS=$((PASS + 1)); }
fail() { echo "  x $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Catalogo Orbit ==="

if python3 "${BOOTSTRAP_DIR}/lib/orbit_catalog.py" --bootstrap-dir "${BOOTSTRAP_DIR}" validate-catalog >/dev/null; then
  pass "catalogo valido"
else
  fail "catalogo invalido"
fi

if python3 "${BOOTSTRAP_DIR}/lib/orbit_catalog.py" --list-profiles >/dev/null 2>&1; then
  pass "catalogo acepta alias --list-profiles"
else
  fail "catalogo no acepta alias --list-profiles"
fi

for file in manifest.json agents-registry.json; do
  if python3 -m json.tool "${BOOTSTRAP_DIR}/${file}" >/dev/null 2>&1; then
    pass "${file} es JSON valido"
  else
    fail "${file} es JSON invalido"
  fi
done

profile_count="$(python3 "${BOOTSTRAP_DIR}/lib/orbit_catalog.py" --bootstrap-dir "${BOOTSTRAP_DIR}" list-profiles --enabled-only | wc -l | tr -d ' ')"
if [[ "${profile_count}" -ge 10 ]]; then
  pass "hay un banco amplio de perfiles habilitados"
else
  fail "faltan perfiles habilitados"
fi

for path in agents/*.json profiles/*.json hooks/*.kiro.hook extensions/*.json; do
  if python3 -m json.tool "${BOOTSTRAP_DIR}/${path}" >/dev/null 2>&1; then
    pass "${path} es JSON valido"
  else
    fail "${path} es JSON invalido"
  fi
done

if rg -n "Escala 24x7|Escala24x7|Jarvis" "${BOOTSTRAP_DIR}" --glob '!tests/**' >/dev/null; then
  fail "persisten referencias al branding anterior"
else
  pass "rebrand a Orbit completo"
fi

if rg -n '"bootstrapModel": "sonnet-4.6"|"model": "sonnet-4.6"' "${BOOTSTRAP_DIR}/manifest.json" "${BOOTSTRAP_DIR}/agents-registry.json" "${BOOTSTRAP_DIR}/agents/orbit.json" >/dev/null; then
  pass "Orbit usa sonnet-4.6 para bootstrap"
else
  fail "Orbit no usa sonnet-4.6 para bootstrap"
fi

echo ""
echo "Resultados: ${PASS} ok, ${FAIL} fallos"
[[ "${FAIL}" -eq 0 ]]
