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

if grep -rn 'Escala 24x7\|Escala24x7\|Jarvis' "${BOOTSTRAP_DIR}" --include='*.json' --include='*.md' --include='*.sh' --exclude-dir=tests >/dev/null 2>&1; then
  fail "persisten referencias al branding anterior"
else
  pass "rebrand a Orbit completo"
fi

if grep -rn '"bootstrapModel": "claude-sonnet-4"\|"model": "claude-sonnet-4"' "${BOOTSTRAP_DIR}/manifest.json" "${BOOTSTRAP_DIR}/agents-registry.json" "${BOOTSTRAP_DIR}/agents/orbit.json" >/dev/null 2>&1; then
  pass "Orbit usa claude-sonnet-4 para bootstrap"
else
  fail "Orbit no usa claude-sonnet-4 para bootstrap"
fi

# Validate all agent JSON files have correct model and resources
AGENT_FAIL=0
for agent_file in "${BOOTSTRAP_DIR}"/agents/*.json; do
  agent_name="$(basename "${agent_file}")"
  if ! python3 -c "
import json, sys
a = json.load(open('${agent_file}'))
ok = True
if a.get('model') != 'claude-sonnet-4':
    print(f'  x ${agent_name}: model is {a.get(\"model\")}, expected claude-sonnet-4')
    ok = False
if 'skill://.kiro/skills/**/SKILL.md' not in a.get('resources', []):
    print(f'  x ${agent_name}: missing skill:// resource')
    ok = False
sys.exit(0 if ok else 1)
" 2>/dev/null; then
    AGENT_FAIL=$((AGENT_FAIL + 1))
  fi
done
if [[ "${AGENT_FAIL}" -eq 0 ]]; then
  pass "todos los agentes JSON tienen model y resources correctos"
else
  fail "${AGENT_FAIL} agentes JSON con model o resources incorrectos"
fi

# Validate manifest and registry versions match
MANIFEST_VER="$(python3 -c "import json; print(json.load(open('${BOOTSTRAP_DIR}/manifest.json'))['version'])")"
REGISTRY_VER="$(python3 -c "import json; print(json.load(open('${BOOTSTRAP_DIR}/agents-registry.json'))['version'])")"
if [[ "${MANIFEST_VER}" == "${REGISTRY_VER}" ]]; then
  pass "versiones sincronizadas: manifest=${MANIFEST_VER} registry=${REGISTRY_VER}"
else
  fail "versiones desincronizadas: manifest=${MANIFEST_VER} registry=${REGISTRY_VER}"
fi

# Validate all steering packs referenced by profiles exist
STEERING_FAIL=0
for profile_file in "${BOOTSTRAP_DIR}"/profiles/*.json; do
  profile_name="$(basename "${profile_file}" .json)"
  while IFS= read -r pack; do
    if [[ ! -f "${BOOTSTRAP_DIR}/steering/${pack}.md" ]]; then
      echo "  x ${profile_name}: steering pack '${pack}' no existe"
      STEERING_FAIL=$((STEERING_FAIL + 1))
    fi
  done < <(python3 -c "import json; [print(p) for p in json.load(open('${profile_file}')).get('steeringPacks', [])]" 2>/dev/null)
done
if [[ "${STEERING_FAIL}" -eq 0 ]]; then
  pass "todos los steering packs referenciados existen"
else
  fail "${STEERING_FAIL} steering packs referenciados no existen"
fi

# Validate all local skills referenced by profiles exist
SKILL_FAIL=0
for profile_file in "${BOOTSTRAP_DIR}"/profiles/*.json; do
  profile_name="$(basename "${profile_file}" .json)"
  while IFS= read -r skill; do
    if [[ ! -f "${BOOTSTRAP_DIR}/skills/${skill}/SKILL.md" ]]; then
      echo "  x ${profile_name}: skill '${skill}' no existe"
      SKILL_FAIL=$((SKILL_FAIL + 1))
    fi
  done < <(python3 -c "import json; [print(s) for s in json.load(open('${profile_file}')).get('localSkills', [])]" 2>/dev/null)
done
if [[ "${SKILL_FAIL}" -eq 0 ]]; then
  pass "todas las skills locales referenciadas existen"
else
  fail "${SKILL_FAIL} skills locales referenciadas no existen"
fi

# Validate all hooks referenced by profiles exist
HOOK_FAIL=0
for profile_file in "${BOOTSTRAP_DIR}"/profiles/*.json; do
  profile_name="$(basename "${profile_file}" .json)"
  while IFS= read -r hook; do
    if [[ ! -f "${BOOTSTRAP_DIR}/hooks/${hook}" ]]; then
      echo "  x ${profile_name}: hook '${hook}' no existe"
      HOOK_FAIL=$((HOOK_FAIL + 1))
    fi
  done < <(python3 -c "import json; [print(h) for h in json.load(open('${profile_file}')).get('hooks', [])]" 2>/dev/null)
done
if [[ "${HOOK_FAIL}" -eq 0 ]]; then
  pass "todos los hooks referenciados existen"
else
  fail "${HOOK_FAIL} hooks referenciados no existen"
fi

echo ""
echo "Resultados: ${PASS} ok, ${FAIL} fallos"
[[ "${FAIL}" -eq 0 ]]
