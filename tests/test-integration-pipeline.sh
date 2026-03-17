#!/usr/bin/env bash
# =============================================================================
# Test de Integración: Pipeline completo
# Verifica las conexiones entre todos los componentes del pipeline:
#   instalación → bootstrap → detección → validación → carga
#
# Requerimientos validados: 1.1, 2.1, 2.3, 2.4, 3.1
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✓ ${desc}"
    ((PASS++))
  else
    echo "  ✗ ${desc}"
    echo "    Expected: '${expected}'"
    echo "    Actual:   '${actual}'"
    ((FAIL++))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  ✓ ${desc}"
    ((PASS++))
  else
    echo "  ✗ ${desc}"
    echo "    Expected to contain: '${needle}'"
    echo "    In: '${haystack}'"
    ((FAIL++))
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "  ✓ ${desc}"
    ((PASS++))
  else
    echo "  ✗ ${desc} — file not found: ${path}"
    ((FAIL++))
  fi
}

assert_dir_exists() {
  local desc="$1" path="$2"
  if [[ -d "$path" ]]; then
    echo "  ✓ ${desc}"
    ((PASS++))
  else
    echo "  ✗ ${desc} — dir not found: ${path}"
    ((FAIL++))
  fi
}

# =============================================================================
# Setup: temp directories
# =============================================================================
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf ${TMPDIR_TEST}" EXIT

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Test de Integración: Pipeline Completo"
echo "════════════════════════════════════════════════════════════"

# =============================================================================
# 1. Verify install.sh → artifact paths (Req 1.1)
# =============================================================================
echo ""
echo "=== 1. install.sh → artifact paths ==="

INSTALL_CONTENT=$(cat "${BOOTSTRAP_DIR}/install.sh")

assert_contains \
  "install.sh references agents/jarvis-bootstrap.json" \
  'agents/jarvis-bootstrap.json' \
  "$INSTALL_CONTENT"

assert_contains \
  "install.sh references steering/bootstrap-init.md" \
  'steering/bootstrap-init.md' \
  "$INSTALL_CONTENT"

assert_contains \
  "install.sh references hooks/bootstrap-init.kiro.hook" \
  'hooks/bootstrap-init.kiro.hook' \
  "$INSTALL_CONTENT"

# Verify the source files actually exist
assert_file_exists \
  "agents/jarvis-bootstrap.json exists in repo" \
  "${BOOTSTRAP_DIR}/agents/jarvis-bootstrap.json"

assert_file_exists \
  "steering/bootstrap-init.md exists in repo" \
  "${BOOTSTRAP_DIR}/steering/bootstrap-init.md"

assert_file_exists \
  "hooks/bootstrap-init.kiro.hook exists in repo" \
  "${BOOTSTRAP_DIR}/hooks/bootstrap-init.kiro.hook"

# =============================================================================
# 2. steering/bootstrap-init.md → manifest & registry paths (Req 2.1, 2.3)
# =============================================================================
echo ""
echo "=== 2. steering/bootstrap-init.md → manifest & registry ==="

STEERING_CONTENT=$(cat "${BOOTSTRAP_DIR}/steering/bootstrap-init.md")

assert_contains \
  "steering references manifest.json path" \
  '~/.kiro/kiro-bootstrap/manifest.json' \
  "$STEERING_CONTENT"

assert_contains \
  "steering references agents-registry.json path" \
  '~/.kiro/kiro-bootstrap/agents-registry.json' \
  "$STEERING_CONTENT"

# =============================================================================
# 3. jarvis-bootstrap.json → resources (Req 2.1)
# =============================================================================
echo ""
echo "=== 3. jarvis-bootstrap.json → resources ==="

AGENT_CONTENT=$(cat "${BOOTSTRAP_DIR}/agents/jarvis-bootstrap.json")

assert_contains \
  "agent resources include manifest.json" \
  'file://~/.kiro/kiro-bootstrap/manifest.json' \
  "$AGENT_CONTENT"

assert_contains \
  "agent resources include agents-registry.json" \
  'file://~/.kiro/kiro-bootstrap/agents-registry.json' \
  "$AGENT_CONTENT"

assert_contains \
  "agent uses haiku-4.5 model" \
  'haiku-4.5' \
  "$AGENT_CONTENT"

# =============================================================================
# 4. pipeline.sh → detect-profile.sh & load-artifacts.sh (Req 3.1)
# =============================================================================
echo ""
echo "=== 4. pipeline.sh → lib scripts ==="

PIPELINE_CONTENT=$(cat "${BOOTSTRAP_DIR}/lib/pipeline.sh")

assert_contains \
  "pipeline sources detect-profile.sh" \
  'detect-profile.sh' \
  "$PIPELINE_CONTENT"

assert_contains \
  "pipeline sources load-artifacts.sh" \
  'load-artifacts.sh' \
  "$PIPELINE_CONTENT"

assert_contains \
  "pipeline references validations dir" \
  'validations' \
  "$PIPELINE_CONTENT"

# =============================================================================
# 5. manifest.json ↔ agents-registry.json cross-validation
# =============================================================================
echo ""
echo "=== 5. manifest ↔ registry cross-validation ==="

# All agents listed in manifest profiles must exist in registry
for agent in vue-dev server-api composables-stores test-agent orchestrator terraform-agent lambda-agent python-agent; do
  if grep -q "\"${agent}\"" "${BOOTSTRAP_DIR}/agents-registry.json"; then
    echo "  ✓ manifest agent '${agent}' exists in registry"
    ((PASS++))
  else
    echo "  ✗ manifest agent '${agent}' NOT in registry"
    ((FAIL++))
  fi
done

# All agent files referenced in registry must exist on disk
for file in agents/vue-dev.json agents/server-api.json agents/composables-stores.json agents/test-agent.json agents/orchestrator.json agents/terraform-agent.json agents/lambda-agent.json agents/python-agent.json agents/jarvis-bootstrap.json; do
  assert_file_exists "registry file '${file}' exists" "${BOOTSTRAP_DIR}/${file}"
done

# =============================================================================
# 6. End-to-end: detect_profiles on simulated frontend-nuxt project
# =============================================================================
echo ""
echo "=== 6. E2E: detect_profiles on frontend-nuxt project ==="

# Create simulated frontend-nuxt project
NUXT_PROJECT="${TMPDIR_TEST}/nuxt-project"
mkdir -p "$NUXT_PROJECT"
touch "${NUXT_PROJECT}/nuxt.config.ts"
cat > "${NUXT_PROJECT}/package.json" << 'PKGEOF'
{
  "name": "test-nuxt-project",
  "dependencies": {
    "nuxt": "^4.0.0",
    "vue": "^3.5.0"
  }
}
PKGEOF

# Source detect-profile.sh and test
source "${BOOTSTRAP_DIR}/lib/detect-profile.sh"

detected=$(detect_profiles "$NUXT_PROJECT")
detect_rc=$?

assert_eq "detect_profiles returns 0 for nuxt project" "0" "$detect_rc"
assert_contains "detected profile is frontend-nuxt" "frontend-nuxt" "$detected"

single=$(detect_single_profile "$NUXT_PROJECT")
assert_eq "detect_single_profile returns frontend-nuxt" "frontend-nuxt" "$single"

# =============================================================================
# 7. E2E: filter_agents_by_profile for detected profile
# =============================================================================
echo ""
echo "=== 7. E2E: filter_agents_by_profile for frontend-nuxt ==="

source "${BOOTSTRAP_DIR}/lib/load-artifacts.sh"

agents=$(filter_agents_by_profile "${BOOTSTRAP_DIR}/agents-registry.json" "frontend-nuxt")
filter_rc=$?

assert_eq "filter_agents_by_profile returns 0" "0" "$filter_rc"
assert_contains "filtered agents include vue-dev" "vue-dev" "$agents"
assert_contains "filtered agents include server-api" "server-api" "$agents"
assert_contains "filtered agents include orchestrator" "orchestrator" "$agents"
assert_contains "filtered agents include jarvis-bootstrap (wildcard)" "jarvis-bootstrap" "$agents"

# Verify terraform-agent is NOT included
if echo "$agents" | grep -qx "terraform-agent"; then
  echo "  ✗ terraform-agent should NOT be in frontend-nuxt agents"
  ((FAIL++))
else
  echo "  ✓ terraform-agent correctly excluded from frontend-nuxt"
  ((PASS++))
fi

# =============================================================================
# 8. E2E: load_artifacts copies correct files
# =============================================================================
echo ""
echo "=== 8. E2E: load_artifacts for frontend-nuxt ==="

output=$(load_artifacts "$NUXT_PROJECT" "$BOOTSTRAP_DIR" "frontend-nuxt" 2>&1)
load_rc=$?

assert_eq "load_artifacts returns 0" "0" "$load_rc"
assert_dir_exists ".kiro/agents/ created" "${NUXT_PROJECT}/.kiro/agents"
assert_dir_exists ".kiro/steering/ created" "${NUXT_PROJECT}/.kiro/steering"
assert_dir_exists ".kiro/skills/ created" "${NUXT_PROJECT}/.kiro/skills"

# Verify agent files were copied
assert_file_exists "vue-dev.json copied" "${NUXT_PROJECT}/.kiro/agents/vue-dev.json"
assert_file_exists "server-api.json copied" "${NUXT_PROJECT}/.kiro/agents/server-api.json"
assert_file_exists "orchestrator.json copied" "${NUXT_PROJECT}/.kiro/agents/orchestrator.json"

# Verify steering files were copied (agent-specific + global)
assert_file_exists "project-context.md copied" "${NUXT_PROJECT}/.kiro/steering/project-context.md"
assert_file_exists "vue-components.md copied" "${NUXT_PROJECT}/.kiro/steering/vue-components.md"

# Verify global steering files were copied
assert_file_exists "jarvis-core.md (global) copied" "${NUXT_PROJECT}/.kiro/steering/jarvis-core.md"
assert_file_exists "git-workflow.md (global) copied" "${NUXT_PROJECT}/.kiro/steering/git-workflow.md"
assert_file_exists "security-policies.md (global) copied" "${NUXT_PROJECT}/.kiro/steering/security-policies.md"

# Verify skills were copied
assert_dir_exists "skills/vue-components copied" "${NUXT_PROJECT}/.kiro/skills/vue-components"

# =============================================================================
# 9. E2E: parse_pipeline_steps reads manifest correctly
# =============================================================================
echo ""
echo "=== 9. E2E: parse_pipeline_steps from manifest ==="

source "${BOOTSTRAP_DIR}/lib/pipeline.sh"

steps_output=$(parse_pipeline_steps "${BOOTSTRAP_DIR}/manifest.json")
parse_rc=$?

assert_eq "parse_pipeline_steps returns 0" "0" "$parse_rc"
assert_contains "step detect-profile found" "detect-profile" "$steps_output"
assert_contains "step validate-environment found" "validate-environment" "$steps_output"
assert_contains "step load-artifacts found" "load-artifacts" "$steps_output"

# Verify order: detect (1) before validate (2) before load (3)
first_step=$(echo "$steps_output" | head -1)
assert_contains "first step is detect-profile" "detect-profile" "$first_step"

last_step=$(echo "$steps_output" | tail -1)
assert_contains "last step is load-artifacts" "load-artifacts" "$last_step"

# =============================================================================
# 10. E2E: Complete chain — detection feeds into filtering and loading
# =============================================================================
echo ""
echo "=== 10. E2E: Complete chain (detect → filter → load) ==="

# Create a fresh project for the complete chain test
CHAIN_PROJECT="${TMPDIR_TEST}/chain-project"
mkdir -p "$CHAIN_PROJECT"
touch "${CHAIN_PROJECT}/nuxt.config.ts"
cat > "${CHAIN_PROJECT}/package.json" << 'PKGEOF'
{
  "name": "chain-test",
  "dependencies": {
    "nuxt": "^4.0.0"
  }
}
PKGEOF

# Step 1: Detect profile
detected_profile=$(detect_single_profile "$CHAIN_PROJECT")
assert_eq "chain: detected profile is frontend-nuxt" "frontend-nuxt" "$detected_profile"

# Step 2: Filter agents by detected profile
chain_agents=$(filter_agents_by_profile "${BOOTSTRAP_DIR}/agents-registry.json" "$detected_profile")
chain_filter_rc=$?
assert_eq "chain: filter returns 0" "0" "$chain_filter_rc"

# Count agents (should be 6: vue-dev, server-api, composables-stores, test-agent, orchestrator, jarvis-bootstrap)
agent_count=$(echo "$chain_agents" | wc -l | tr -d ' ')
assert_eq "chain: 6 agents for frontend-nuxt" "6" "$agent_count"

# Step 3: Load artifacts using detected profile
chain_output=$(load_artifacts "$CHAIN_PROJECT" "$BOOTSTRAP_DIR" "$detected_profile" 2>&1)
chain_load_rc=$?
assert_eq "chain: load_artifacts returns 0" "0" "$chain_load_rc"

# Verify the chain produced correct results
assert_dir_exists "chain: .kiro/agents/ exists" "${CHAIN_PROJECT}/.kiro/agents"
assert_file_exists "chain: vue-dev.json loaded" "${CHAIN_PROJECT}/.kiro/agents/vue-dev.json"
assert_file_exists "chain: jarvis-core.md (global) loaded" "${CHAIN_PROJECT}/.kiro/steering/jarvis-core.md"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "════════════════════════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
