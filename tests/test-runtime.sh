#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${BOOTSTRAP_DIR}/lib/detect-profile.sh"
source "${BOOTSTRAP_DIR}/lib/load-artifacts.sh"
source "${BOOTSTRAP_DIR}/lib/pipeline.sh"
source "${BOOTSTRAP_DIR}/lib/install-remote-skills.sh"
source "${BOOTSTRAP_DIR}/validations/common.sh"

PASS=0
FAIL=0

pass() { echo "  + $1"; PASS=$((PASS + 1)); }
fail() { echo "  x $1"; FAIL=$((FAIL + 1)); }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_TEST}"' EXIT

echo ""
echo "=== Runtime Orbit ==="

mkdir -p "${TMPDIR_TEST}/lambda-py/handlers"
touch "${TMPDIR_TEST}/lambda-py/requirements.txt"
touch "${TMPDIR_TEST}/lambda-py/handlers/hello_lambda.py"

detected="$(detect_single_profile "${TMPDIR_TEST}/lambda-py" 2>/dev/null || true)"
if [[ "${detected}" == "aws-backend-lambda-python" ]]; then
  pass "detecta Lambda Python"
else
  fail "no detecta Lambda Python"
fi

PROJECT_DIR="${TMPDIR_TEST}/project"
mkdir -p "${PROJECT_DIR}"
export ORBIT_DRY_RUN_EXTENSIONS=1
export ORBIT_DRY_RUN_REMOTE_SKILLS=1
export ORBIT_REMOTE_SKILLS_AUTO_APPROVE=1
export ORBIT_CONFLICT_STRATEGY=overwrite

if load_artifacts "${PROJECT_DIR}" "${BOOTSTRAP_DIR}" "aws-infra-terraform" >/dev/null 2>&1; then
  pass "carga artefactos de Terraform"
else
  fail "falla la carga de artefactos"
fi

if [[ -f "${PROJECT_DIR}/.kiro/hooks/terraform-fmt-on-save.kiro.hook" ]] && [[ ! -f "${PROJECT_DIR}/.kiro/hooks/node-lint-on-save.kiro.hook" ]]; then
  pass "hooks segmentados por perfil"
else
  fail "hooks mal segmentados"
fi

AWS_DEFER_RESULT="$(ORBIT_VALIDATE_AWS_IDENTITY=no ORBIT_DEPLOY_INTENT=no check_aws_identity 2>/dev/null || true)"
if echo "${AWS_DEFER_RESULT}" | grep -q "diferida hasta despliegue"; then
  pass "difiere validacion de credenciales AWS durante bootstrap"
else
  fail "no difiere validacion de credenciales AWS durante bootstrap"
fi

INVALID_PROFILE_RESULT="$(validate_profile_environment "${PROJECT_DIR}" "${BOOTSTRAP_DIR}" "default" 2>&1 || true)"
if echo "${INVALID_PROFILE_RESULT}" | grep -q "Perfil de proyecto inexistente: default"; then
  pass "falla con mensaje claro ante perfil invalido"
else
  fail "no falla claramente ante perfil invalido"
fi

FAKE_BIN="${TMPDIR_TEST}/fake-bin"
SKILLS_LOG="${TMPDIR_TEST}/skills.log"
mkdir -p "${FAKE_BIN}"
cat > "${FAKE_BIN}/skills" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${SKILLS_LOG}"
EOF
chmod +x "${FAKE_BIN}/skills"

OLD_PATH="${PATH}"
export PATH="${FAKE_BIN}:/usr/bin:/bin"
unset ORBIT_DRY_RUN_REMOTE_SKILLS
unset ORBIT_APPROVED_REMOTE_SKILLS
export ORBIT_TEST_REMOTE_SKILL_DECISION=yes

if install_remote_skill "github-documentation-writer" >/dev/null 2>&1 \
  && grep -q "add github/awesome-copilot@documentation-writer -g -y" "${SKILLS_LOG}" \
  && [[ "${ORBIT_APPROVED_REMOTE_SKILLS}" == "github-documentation-writer" ]]; then
  pass "instala remote skills con skills CLI cuando npx no esta disponible"
else
  fail "no instala remote skills correctamente con skills CLI"
fi

export PATH="${OLD_PATH}"
unset ORBIT_TEST_REMOTE_SKILL_DECISION

if write_project_state "${PROJECT_DIR}" "${BOOTSTRAP_DIR}" "aws-infra-terraform" >/dev/null 2>&1 && [[ -f "${PROJECT_DIR}/.kiro/.orbit-project.json" ]]; then
  pass "escribe estado del proyecto"
else
  fail "no escribe estado del proyecto"
fi

if python3 -m json.tool "${PROJECT_DIR}/.kiro/.orbit-project.json" >/dev/null 2>&1; then
  pass "estado del proyecto es JSON valido"
else
  fail "estado del proyecto es JSON invalido"
fi

steps="$(parse_pipeline_steps "${BOOTSTRAP_DIR}/manifest.json")"
if echo "${steps}" | grep -q "write-project-state"; then
  pass "pipeline expone paso de estado"
else
  fail "pipeline no expone paso de estado"
fi

echo ""
echo "Resultados: ${PASS} ok, ${FAIL} fallos"
[[ "${FAIL}" -eq 0 ]]
