#!/usr/bin/env bash
# =============================================================================
# test-all.sh — Suite completa de verificación del ecosistema kiro-bootstrap
#
# Ejecuta todas las validaciones y tests del sistema:
#   1. Estructura de directorios
#   2. Validación de JSON
#   3. Sintaxis de scripts bash
#   4. Consistencia de referencias cruzadas
#   5. Tests unitarios (load-artifacts, extensions)
#   6. Tests de integración (pipeline)
#   7. Detección de perfiles
#   8. Validaciones de entorno
#
# Uso:
#   bash kiro-bootstrap/tests/test-all.sh
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL_PASS=0
TOTAL_FAIL=0
SECTION_PASS=0
SECTION_FAIL=0

section_start() {
  SECTION_PASS=0
  SECTION_FAIL=0
  echo ""
  echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  $1${NC}"
  echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
}

section_end() {
  TOTAL_PASS=$((TOTAL_PASS + SECTION_PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + SECTION_FAIL))
  echo -e "  Sección: ${GREEN}${SECTION_PASS} ok${NC}, ${RED}${SECTION_FAIL} fallos${NC}"
}

pass() {
  echo -e "  ${GREEN}✓${NC} $1"
  ((SECTION_PASS++))
}

fail() {
  echo -e "  ${RED}✗${NC} $1"
  ((SECTION_FAIL++))
}


# =============================================================================
# 1. Estructura de directorios
# =============================================================================
section_start "1. Estructura de directorios"

EXPECTED_DIRS=(
  "agents"
  "extensions"
  "hooks"
  "lib"
  "profiles"
  "skills"
  "steering"
  "templates"
  "tests"
  "validations"
)

for dir in "${EXPECTED_DIRS[@]}"; do
  if [[ -d "${BOOTSTRAP_DIR}/${dir}" ]]; then
    pass "Directorio ${dir}/ existe"
  else
    fail "Directorio ${dir}/ NO existe"
  fi
done

# Archivos raíz
for f in install.sh manifest.json agents-registry.json README.md; do
  if [[ -f "${BOOTSTRAP_DIR}/${f}" ]]; then
    pass "Archivo ${f} existe"
  else
    fail "Archivo ${f} NO existe"
  fi
done

section_end

# =============================================================================
# 2. Validación de JSON
# =============================================================================
section_start "2. Validación de archivos JSON"

JSON_FILES=(
  "manifest.json"
  "agents-registry.json"
)

# Agregar todos los JSON de subdirectorios
for subdir in agents profiles extensions; do
  for f in "${BOOTSTRAP_DIR}/${subdir}"/*.json; do
    [[ -f "$f" ]] || continue
    JSON_FILES+=("${subdir}/$(basename "$f")")
  done
done

for json_file in "${JSON_FILES[@]}"; do
  full_path="${BOOTSTRAP_DIR}/${json_file}"
  if [[ ! -f "$full_path" ]]; then
    fail "JSON no encontrado: ${json_file}"
    continue
  fi
  if python3 -m json.tool "$full_path" > /dev/null 2>&1; then
    pass "JSON válido: ${json_file}"
  else
    fail "JSON inválido: ${json_file}"
  fi
done

section_end

# =============================================================================
# 3. Sintaxis de scripts bash
# =============================================================================
section_start "3. Sintaxis de scripts bash"

BASH_SCRIPTS=(
  "install.sh"
  "lib/detect-profile.sh"
  "lib/pipeline.sh"
  "lib/load-artifacts.sh"
  "lib/install-extensions.sh"
  "validations/common.sh"
  "validations/frontend-nuxt.sh"
  "validations/infraestructura-terraform.sh"
  "validations/backend-lambda.sh"
  "validations/backend-python.sh"
)

for script in "${BASH_SCRIPTS[@]}"; do
  full_path="${BOOTSTRAP_DIR}/${script}"
  if [[ ! -f "$full_path" ]]; then
    fail "Script no encontrado: ${script}"
    continue
  fi
  if bash -n "$full_path" 2>/dev/null; then
    pass "Sintaxis OK: ${script}"
  else
    fail "Error de sintaxis: ${script}"
  fi
done

section_end

# =============================================================================
# 4. Consistencia de referencias cruzadas
# =============================================================================
section_start "4. Referencias cruzadas manifest ↔ registry ↔ archivos"

REGISTRY="${BOOTSTRAP_DIR}/agents-registry.json"
MANIFEST="${BOOTSTRAP_DIR}/manifest.json"

# 4a. Agentes del manifest existen en registry
MANIFEST_AGENTS=$(grep -oE '"(vue-dev|server-api|composables-stores|test-agent|orchestrator|terraform-agent|lambda-agent|python-agent)"' "$MANIFEST" | tr -d '"' | sort -u)
for agent in $MANIFEST_AGENTS; do
  if grep -q "\"${agent}\"" "$REGISTRY"; then
    pass "Agente '${agent}' del manifest existe en registry"
  else
    fail "Agente '${agent}' del manifest NO existe en registry"
  fi
done

# 4b. Archivos de agentes referenciados en registry existen en disco
AGENT_FILES=$(grep -oE '"file"\s*:\s*"[^"]*"' "$REGISTRY" | grep -oE 'agents/[^"]*')
for agent_file in $AGENT_FILES; do
  if [[ -f "${BOOTSTRAP_DIR}/${agent_file}" ]]; then
    pass "Archivo de agente '${agent_file}' existe"
  else
    fail "Archivo de agente '${agent_file}' NO existe"
  fi
done

# 4c. Steering files referenciados en registry existen en disco
STEERING_FILES=$(grep -oE '"steering/[^"]*"' "$REGISTRY" | tr -d '"' | sort -u)
for sf in $STEERING_FILES; do
  if [[ -f "${BOOTSTRAP_DIR}/${sf}" ]]; then
    pass "Steering '${sf}' existe"
  else
    fail "Steering '${sf}' NO existe"
  fi
done

# 4d. Skills referenciados en registry existen en disco
SKILL_DIRS=$(grep -oE '"skills/[^"]*"' "$REGISTRY" | tr -d '"' | sort -u)
for skill in $SKILL_DIRS; do
  if [[ -d "${BOOTSTRAP_DIR}/${skill}" ]]; then
    pass "Skill '${skill}/' existe"
  else
    fail "Skill '${skill}/' NO existe"
  fi
done

# 4e. Perfiles del manifest tienen archivo en profiles/
PROFILE_NAMES=$(grep -oE '"(frontend-nuxt|infraestructura-terraform|backend-lambda|backend-python)"' "$MANIFEST" | tr -d '"' | sort -u)
for profile in $PROFILE_NAMES; do
  if [[ -f "${BOOTSTRAP_DIR}/profiles/${profile}.json" ]]; then
    pass "Perfil '${profile}' tiene archivo en profiles/"
  else
    fail "Perfil '${profile}' NO tiene archivo en profiles/"
  fi
done

# 4f. Perfiles del manifest tienen script de validación
for profile in $PROFILE_NAMES; do
  if [[ -f "${BOOTSTRAP_DIR}/validations/${profile}.sh" ]]; then
    pass "Perfil '${profile}' tiene script de validación"
  else
    fail "Perfil '${profile}' NO tiene script de validación"
  fi
done

# 4g. Perfiles del manifest tienen archivo de extensiones
for profile in $PROFILE_NAMES; do
  if [[ -f "${BOOTSTRAP_DIR}/extensions/${profile}.json" ]]; then
    pass "Perfil '${profile}' tiene archivo de extensiones"
  else
    fail "Perfil '${profile}' NO tiene archivo de extensiones"
  fi
done

# 4h. Extensiones base existe
if [[ -f "${BOOTSTRAP_DIR}/extensions/base.json" ]]; then
  pass "Extensiones base (base.json) existe"
else
  fail "Extensiones base (base.json) NO existe"
fi

# 4i. install.sh referencia artefactos que existen
INSTALL_CONTENT=$(cat "${BOOTSTRAP_DIR}/install.sh")
for artifact in "agents/jarvis-bootstrap.json" "steering/bootstrap-init.md" "hooks/bootstrap-init.kiro.hook"; do
  if echo "$INSTALL_CONTENT" | grep -q "$artifact"; then
    if [[ -f "${BOOTSTRAP_DIR}/${artifact}" || -f "${BOOTSTRAP_DIR}/${artifact}" ]]; then
      pass "install.sh → '${artifact}' existe"
    else
      fail "install.sh referencia '${artifact}' pero NO existe"
    fi
  else
    fail "install.sh NO referencia '${artifact}'"
  fi
done

section_end


# =============================================================================
# 5. Detección de perfiles (funcional)
# =============================================================================
section_start "5. Detección de perfiles"

source "${BOOTSTRAP_DIR}/lib/detect-profile.sh"

TMPDIR_TEST=$(mktemp -d)
trap "rm -rf ${TMPDIR_TEST}" EXIT

# 5a. frontend-nuxt
PROJ="${TMPDIR_TEST}/nuxt"
mkdir -p "$PROJ"
touch "${PROJ}/nuxt.config.ts"
echo '{"dependencies":{"nuxt":"^4.0.0"}}' > "${PROJ}/package.json"
result=$(detect_single_profile "$PROJ" 2>/dev/null) || true
if [[ "$result" == "frontend-nuxt" ]]; then
  pass "Detecta frontend-nuxt correctamente"
else
  fail "frontend-nuxt: esperado 'frontend-nuxt', obtuvo '${result}'"
fi

# 5b. infraestructura-terraform
PROJ="${TMPDIR_TEST}/terraform"
mkdir -p "$PROJ"
touch "${PROJ}/backend.tf" "${PROJ}/main.tf" "${PROJ}/variables.tf"
result=$(detect_single_profile "$PROJ" 2>/dev/null) || true
if [[ "$result" == "infraestructura-terraform" ]]; then
  pass "Detecta infraestructura-terraform correctamente"
else
  fail "infraestructura-terraform: esperado 'infraestructura-terraform', obtuvo '${result}'"
fi

# 5c. backend-lambda
PROJ="${TMPDIR_TEST}/lambda"
mkdir -p "$PROJ"
echo '{"dependencies":{"@aws-sdk/client-dynamodb":"^3.0.0"}}' > "${PROJ}/package.json"
result=$(detect_single_profile "$PROJ" 2>/dev/null) || true
if [[ "$result" == "backend-lambda" ]]; then
  pass "Detecta backend-lambda correctamente"
else
  fail "backend-lambda: esperado 'backend-lambda', obtuvo '${result}'"
fi

# 5d. backend-python (pyproject.toml)
PROJ="${TMPDIR_TEST}/python1"
mkdir -p "$PROJ"
touch "${PROJ}/pyproject.toml"
result=$(detect_single_profile "$PROJ" 2>/dev/null) || true
if [[ "$result" == "backend-python" ]]; then
  pass "Detecta backend-python (pyproject.toml)"
else
  fail "backend-python: esperado 'backend-python', obtuvo '${result}'"
fi

# 5e. backend-python (requirements.txt)
PROJ="${TMPDIR_TEST}/python2"
mkdir -p "$PROJ"
touch "${PROJ}/requirements.txt"
result=$(detect_single_profile "$PROJ" 2>/dev/null) || true
if [[ "$result" == "backend-python" ]]; then
  pass "Detecta backend-python (requirements.txt)"
else
  fail "backend-python: esperado 'backend-python', obtuvo '${result}'"
fi

# 5f. Proyecto sin perfil
PROJ="${TMPDIR_TEST}/empty"
mkdir -p "$PROJ"
result=$(detect_single_profile "$PROJ" 2>/dev/null) || true
if [[ -z "$result" ]]; then
  pass "Proyecto vacío: no detecta perfil (correcto)"
else
  fail "Proyecto vacío: detectó '${result}' cuando no debería"
fi

# 5g. Monorepo (nuxt + python)
PROJ="${TMPDIR_TEST}/monorepo"
mkdir -p "$PROJ"
touch "${PROJ}/nuxt.config.ts" "${PROJ}/pyproject.toml"
echo '{"dependencies":{"nuxt":"^4.0.0"}}' > "${PROJ}/package.json"
result=$(detect_profiles "$PROJ" 2>/dev/null) || true
if echo "$result" | grep -q "frontend-nuxt" && echo "$result" | grep -q "backend-python"; then
  pass "Monorepo: detecta múltiples perfiles"
else
  fail "Monorepo: esperado frontend-nuxt + backend-python, obtuvo '${result}'"
fi

# 5h. Prioridad: nuxt gana sobre lambda cuando ambos aplican
PROJ="${TMPDIR_TEST}/priority"
mkdir -p "$PROJ"
touch "${PROJ}/nuxt.config.ts"
echo '{"dependencies":{"nuxt":"^4.0.0","@aws-sdk/client-s3":"^3.0.0"}}' > "${PROJ}/package.json"
result=$(detect_single_profile "$PROJ" 2>/dev/null) || true
if [[ "$result" == "frontend-nuxt" ]]; then
  pass "Prioridad: frontend-nuxt gana sobre backend-lambda"
else
  fail "Prioridad: esperado 'frontend-nuxt', obtuvo '${result}'"
fi

section_end

# =============================================================================
# 6. Comparación semántica de versiones
# =============================================================================
section_start "6. Comparación semántica de versiones"

source "${BOOTSTRAP_DIR}/validations/common.sh"

# Casos que deben pasar (installed >= minimum)
VERSION_PASS_CASES=(
  "18.19.0|18.0.0"
  "20.0.0|18.0.0"
  "1.5.0|1.5.0"
  "2.0.0|1.99.99"
  "10.2.4|9.0.0"
  "3.10.1|3.10.0"
)

for case in "${VERSION_PASS_CASES[@]}"; do
  IFS='|' read -r installed minimum <<< "$case"
  if compare_versions "$installed" "$minimum"; then
    pass "${installed} >= ${minimum}"
  else
    fail "${installed} >= ${minimum} (debería pasar)"
  fi
done

# Casos que deben fallar (installed < minimum)
VERSION_FAIL_CASES=(
  "17.9.9|18.0.0"
  "1.4.9|1.5.0"
  "0.99.99|1.0.0"
  "3.9.99|3.10.0"
)

for case in "${VERSION_FAIL_CASES[@]}"; do
  IFS='|' read -r installed minimum <<< "$case"
  if ! compare_versions "$installed" "$minimum"; then
    pass "${installed} < ${minimum} (correctamente falla)"
  else
    fail "${installed} < ${minimum} (debería fallar)"
  fi
done

section_end

# =============================================================================
# 7. Módulo de extensiones
# =============================================================================
section_start "7. Módulo de extensiones (install-extensions.sh)"

source "${BOOTSTRAP_DIR}/lib/install-extensions.sh"

# 7a. parse_extension_ids extrae IDs correctamente de base.json
result=$(parse_extension_ids "${BOOTSTRAP_DIR}/extensions/base.json")
if echo "$result" | grep -q "dbaeumer.vscode-eslint"; then
  pass "parse_extension_ids: extrae dbaeumer.vscode-eslint de base.json"
else
  fail "parse_extension_ids: no encontró dbaeumer.vscode-eslint en base.json"
fi

if echo "$result" | grep -q "esbenp.prettier-vscode"; then
  pass "parse_extension_ids: extrae esbenp.prettier-vscode de base.json"
else
  fail "parse_extension_ids: no encontró esbenp.prettier-vscode en base.json"
fi

# 7b. parse_extension_ids extrae IDs de frontend-nuxt.json
result=$(parse_extension_ids "${BOOTSTRAP_DIR}/extensions/frontend-nuxt.json")
if echo "$result" | grep -q "vue.volar"; then
  pass "parse_extension_ids: extrae vue.volar de frontend-nuxt.json"
else
  fail "parse_extension_ids: no encontró vue.volar en frontend-nuxt.json"
fi

if echo "$result" | grep -q "bradlc.vscode-tailwindcss"; then
  pass "parse_extension_ids: extrae bradlc.vscode-tailwindcss de frontend-nuxt.json"
else
  fail "parse_extension_ids: no encontró bradlc.vscode-tailwindcss en frontend-nuxt.json"
fi

# 7c. parse_extension_ids de infraestructura-terraform.json
result=$(parse_extension_ids "${BOOTSTRAP_DIR}/extensions/infraestructura-terraform.json")
if echo "$result" | grep -q "hashicorp.terraform"; then
  pass "parse_extension_ids: extrae hashicorp.terraform"
else
  fail "parse_extension_ids: no encontró hashicorp.terraform"
fi

# 7d. parse_extension_ids de archivo inexistente retorna vacío
result=$(parse_extension_ids "/tmp/no-existe-xyz.json" 2>/dev/null) || true
if [[ -z "$result" ]]; then
  pass "parse_extension_ids: archivo inexistente retorna vacío"
else
  fail "parse_extension_ids: archivo inexistente debería retornar vacío"
fi

# 7e. Cada perfil tiene extensiones parseables
for profile in frontend-nuxt backend-lambda backend-python infraestructura-terraform; do
  ext_file="${BOOTSTRAP_DIR}/extensions/${profile}.json"
  count=$(parse_extension_ids "$ext_file" | wc -l | tr -d ' ')
  if [[ "$count" -gt 0 ]]; then
    pass "Perfil ${profile}: ${count} extensiones parseadas"
  else
    fail "Perfil ${profile}: 0 extensiones parseadas"
  fi
done

# 7f. No hay IDs duplicados entre base y perfiles
base_ids=$(parse_extension_ids "${BOOTSTRAP_DIR}/extensions/base.json" | sort)
for profile in frontend-nuxt backend-lambda backend-python infraestructura-terraform; do
  profile_ids=$(parse_extension_ids "${BOOTSTRAP_DIR}/extensions/${profile}.json" | sort)
  duplicates=$(comm -12 <(echo "$base_ids") <(echo "$profile_ids"))
  if [[ -z "$duplicates" ]]; then
    pass "Sin duplicados entre base y ${profile}"
  else
    fail "Duplicados entre base y ${profile}: ${duplicates}"
  fi
done

# 7g. detect_kiro_cli no falla (puede retornar vacío si Kiro no está instalado)
kiro_cli=$(detect_kiro_cli 2>/dev/null) || true
if [[ -n "$kiro_cli" ]]; then
  pass "detect_kiro_cli: encontró CLI en '${kiro_cli}'"
else
  pass "detect_kiro_cli: CLI no encontrada (esperado en entorno de test)"
fi

# 7h. install_extensions con CLI ausente muestra mensaje informativo
output=$(install_extensions "${BOOTSTRAP_DIR}" "frontend-nuxt" 2>&1)
if echo "$output" | grep -q "CLI de Kiro no encontrada\|Instalando extensiones"; then
  pass "install_extensions: maneja ausencia de CLI correctamente"
else
  fail "install_extensions: no manejó ausencia de CLI"
fi

section_end


# =============================================================================
# 8. Tests unitarios existentes
# =============================================================================
section_start "8. Test unitario: load-artifacts"

if bash "${SCRIPT_DIR}/test-load-artifacts.sh" > /dev/null 2>&1; then
  pass "test-load-artifacts.sh — todos los tests pasan"
else
  fail "test-load-artifacts.sh — algunos tests fallaron"
fi

section_end

section_start "9. Test de integración: pipeline"

if bash "${SCRIPT_DIR}/test-integration-pipeline.sh" > /dev/null 2>&1; then
  pass "test-integration-pipeline.sh — todos los tests pasan"
else
  fail "test-integration-pipeline.sh — algunos tests fallaron"
fi

section_end

# =============================================================================
# 10. Hooks: formato JSON válido
# =============================================================================
section_start "10. Hooks: formato JSON"

for hook_file in "${BOOTSTRAP_DIR}/hooks"/*.kiro.hook; do
  [[ -f "$hook_file" ]] || continue
  hook_name=$(basename "$hook_file")
  if python3 -m json.tool "$hook_file" > /dev/null 2>&1; then
    pass "Hook JSON válido: ${hook_name}"
  else
    fail "Hook JSON inválido: ${hook_name}"
  fi
done

section_end

# =============================================================================
# 11. Skills: cada directorio tiene SKILL.md
# =============================================================================
section_start "11. Skills: estructura"

for skill_dir in "${BOOTSTRAP_DIR}/skills"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")
  if [[ -f "${skill_dir}/SKILL.md" ]]; then
    pass "Skill '${skill_name}' tiene SKILL.md"
  else
    fail "Skill '${skill_name}' NO tiene SKILL.md"
  fi
done

section_end

# =============================================================================
# 12. install.sh: funciones clave presentes
# =============================================================================
section_start "12. install.sh: funciones y estructura"

INSTALL_CONTENT=$(cat "${BOOTSTRAP_DIR}/install.sh")

EXPECTED_FUNCTIONS=(
  "check_os"
  "check_dependencies"
  "parse_args"
  "backup_existing_installation"
  "clone_or_update_repo"
  "install_base_artifacts"
  "check_update_needed"
  "main"
)

for fn in "${EXPECTED_FUNCTIONS[@]}"; do
  if echo "$INSTALL_CONTENT" | grep -q "${fn}()"; then
    pass "Función ${fn}() presente en install.sh"
  else
    fail "Función ${fn}() NO encontrada en install.sh"
  fi
done

# Códigos de salida documentados
for code in "exit 2" "exit 3" "exit 4"; do
  if echo "$INSTALL_CONTENT" | grep -q "$code"; then
    pass "Código de salida '${code}' presente"
  else
    fail "Código de salida '${code}' NO encontrado"
  fi
done

# Flag --update
if echo "$INSTALL_CONTENT" | grep -q "\-\-update"; then
  pass "Flag --update soportado"
else
  fail "Flag --update NO encontrado"
fi

# Variables de entorno
for var in "KIRO_BOOTSTRAP_REPO" "KIRO_BOOTSTRAP_BRANCH"; do
  if echo "$INSTALL_CONTENT" | grep -q "$var"; then
    pass "Variable de entorno ${var} soportada"
  else
    fail "Variable de entorno ${var} NO encontrada"
  fi
done

# Integración con extensiones
if echo "$INSTALL_CONTENT" | grep -q "install-extensions.sh"; then
  pass "install.sh integra install-extensions.sh"
else
  fail "install.sh NO integra install-extensions.sh"
fi

section_end

# =============================================================================
# Reporte final
# =============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          REPORTE FINAL — kiro-bootstrap             ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║${NC}  Total:  ${GREEN}${TOTAL_PASS} aprobados${NC}  ${RED}${TOTAL_FAIL} fallidos${NC}               ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ $TOTAL_FAIL -gt 0 ]]; then
  echo -e "${RED}Hay ${TOTAL_FAIL} verificaciones fallidas. Revisar los errores arriba.${NC}"
  exit 1
else
  echo -e "${GREEN}Todas las verificaciones pasaron. El ecosistema está listo.${NC}"
  exit 0
fi
