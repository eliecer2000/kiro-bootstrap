#!/usr/bin/env bash
# =============================================================================
# Test: load-artifacts.sh
# Verifica las funciones del cargador de artefactos
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source the script under test
source "${BOOTSTRAP_DIR}/lib/load-artifacts.sh"

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
    echo "    Actual: '${haystack}'"
    ((FAIL++))
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  ✓ ${desc}"
    ((PASS++))
  else
    echo "  ✗ ${desc}"
    echo "    Expected NOT to contain: '${needle}'"
    echo "    Actual: '${haystack}'"
    ((FAIL++))
  fi
}

REGISTRY="${BOOTSTRAP_DIR}/agents-registry.json"

echo ""
echo "=== Test: filter_agents_by_profile ==="

# Test 1: Filter agents for frontend-nuxt profile
result=$(filter_agents_by_profile "$REGISTRY" "frontend-nuxt")
assert_contains "vue-dev in frontend-nuxt" "vue-dev" "$result"
assert_contains "server-api in frontend-nuxt" "server-api" "$result"
assert_contains "composables-stores in frontend-nuxt" "composables-stores" "$result"
assert_contains "test-agent in frontend-nuxt" "test-agent" "$result"
assert_contains "orchestrator in frontend-nuxt" "orchestrator" "$result"
assert_contains "jarvis-bootstrap (wildcard) in frontend-nuxt" "jarvis-bootstrap" "$result"
assert_not_contains "terraform-agent NOT in frontend-nuxt" "terraform-agent" "$result"
assert_not_contains "lambda-agent NOT in frontend-nuxt" "lambda-agent" "$result"

# Test 2: Filter agents for infraestructura-terraform profile
result=$(filter_agents_by_profile "$REGISTRY" "infraestructura-terraform")
assert_contains "terraform-agent in infraestructura-terraform" "terraform-agent" "$result"
assert_contains "jarvis-bootstrap (wildcard) in infraestructura-terraform" "jarvis-bootstrap" "$result"
assert_not_contains "vue-dev NOT in infraestructura-terraform" "vue-dev" "$result"

# Test 3: Filter agents for backend-lambda profile
result=$(filter_agents_by_profile "$REGISTRY" "backend-lambda")
assert_contains "lambda-agent in backend-lambda" "lambda-agent" "$result"
assert_contains "test-agent in backend-lambda" "test-agent" "$result"
assert_contains "orchestrator in backend-lambda" "orchestrator" "$result"
assert_contains "jarvis-bootstrap (wildcard) in backend-lambda" "jarvis-bootstrap" "$result"

# Test 4: Filter agents for backend-python profile
result=$(filter_agents_by_profile "$REGISTRY" "backend-python")
assert_contains "python-agent in backend-python" "python-agent" "$result"
assert_contains "test-agent in backend-python" "test-agent" "$result"
assert_contains "jarvis-bootstrap (wildcard) in backend-python" "jarvis-bootstrap" "$result"

# Test 5: Non-existent profile still matches wildcard agents (jarvis-bootstrap has "*")
result=$(filter_agents_by_profile "$REGISTRY" "nonexistent" 2>/dev/null) || true
if [[ -n "$result" ]]; then
  assert_contains "wildcard agent matches any profile" "jarvis-bootstrap" "$result"
else
  echo "  ✗ wildcard agent should match nonexistent profile"
  ((FAIL++))
fi

echo ""
echo "=== Test: get_agent_field ==="

result=$(get_agent_field "$REGISTRY" "vue-dev" "file")
assert_eq "vue-dev file" "agents/vue-dev.json" "$result"

result=$(get_agent_field "$REGISTRY" "vue-dev" "model")
assert_eq "vue-dev model" "sonnet-4" "$result"

result=$(get_agent_field "$REGISTRY" "jarvis-bootstrap" "model")
assert_eq "jarvis-bootstrap model" "haiku-4.5" "$result"

result=$(get_agent_field "$REGISTRY" "orchestrator" "file")
assert_eq "orchestrator file" "agents/orchestrator.json" "$result"

echo ""
echo "=== Test: get_agent_array_field ==="

result=$(get_agent_array_field "$REGISTRY" "vue-dev" "steeringFiles")
assert_contains "vue-dev steeringFiles has project-context" "steering/project-context.md" "$result"
assert_contains "vue-dev steeringFiles has vue-components" "steering/vue-components.md" "$result"
assert_contains "vue-dev steeringFiles has i18n" "steering/i18n.md" "$result"

result=$(get_agent_array_field "$REGISTRY" "vue-dev" "skills")
assert_contains "vue-dev skills has vue-components" "skills/vue-components" "$result"

# orchestrator has empty skills array
if result=$(get_agent_array_field "$REGISTRY" "orchestrator" "skills" 2>/dev/null) && [[ -n "$result" ]]; then
  echo "  ✗ orchestrator should have empty skills, got: ${result}"
  ((FAIL++))
else
  echo "  ✓ orchestrator has empty skills"
  ((PASS++))
fi

result=$(get_agent_array_field "$REGISTRY" "vue-dev" "profiles")
assert_contains "vue-dev profiles has frontend-nuxt" "frontend-nuxt" "$result"

echo ""
echo "=== Test: get_global_steering_files ==="

result=$(get_global_steering_files "$REGISTRY")
assert_contains "global has jarvis-core" "steering/jarvis-core.md" "$result"
assert_contains "global has git-workflow" "steering/git-workflow.md" "$result"
assert_contains "global has security-policies" "steering/security-policies.md" "$result"
assert_contains "global has cicd-azuredevops" "steering/cicd-azuredevops.md" "$result"

echo ""
echo "=== Test: copy_artifact ==="

# Setup temp dirs
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf ${TMPDIR_TEST}" EXIT

# Test: copy new file
echo "hello" > "${TMPDIR_TEST}/source.txt"
output=$(copy_artifact "${TMPDIR_TEST}/source.txt" "${TMPDIR_TEST}/dest.txt" 2>&1)
assert_contains "new file reports Nuevo" "Nuevo" "$output"
assert_eq "new file content matches" "hello" "$(cat "${TMPDIR_TEST}/dest.txt")"

# Test: copy identical file (should skip)
_LA_UNCHANGED=0
output=$(copy_artifact "${TMPDIR_TEST}/source.txt" "${TMPDIR_TEST}/dest.txt" 2>&1)
assert_contains "identical file reports Sin cambios" "Sin cambios" "$output"

# Test: copy modified file (should report conflict)
echo "modified" > "${TMPDIR_TEST}/dest.txt"
_LA_MODIFIED=0
output=$(copy_artifact "${TMPDIR_TEST}/source.txt" "${TMPDIR_TEST}/dest.txt" 2>&1)
assert_contains "modified file reports Modificado" "Modificado" "$output"
# Verify local version is preserved
assert_eq "local version preserved" "modified" "$(cat "${TMPDIR_TEST}/dest.txt")"

# Test: missing source file (should warn, not fail)
_LA_SKIPPED=0
output=$(copy_artifact "${TMPDIR_TEST}/nonexistent.txt" "${TMPDIR_TEST}/dest2.txt" 2>&1)
assert_contains "missing source warns" "Fuente no encontrada" "$output"

echo ""
echo "=== Test: load_artifacts (integration) ==="

# Create a minimal test project dir
PROJECT_DIR=$(mktemp -d)
trap "rm -rf ${TMPDIR_TEST} ${PROJECT_DIR}" EXIT

# Create some fake source artifacts in bootstrap dir to test copy
mkdir -p "${BOOTSTRAP_DIR}/agents" 2>/dev/null || true
mkdir -p "${BOOTSTRAP_DIR}/steering" 2>/dev/null || true
mkdir -p "${BOOTSTRAP_DIR}/skills" 2>/dev/null || true
mkdir -p "${BOOTSTRAP_DIR}/hooks" 2>/dev/null || true

# Run load_artifacts for frontend-nuxt
output=$(load_artifacts "$PROJECT_DIR" "$BOOTSTRAP_DIR" "frontend-nuxt" 2>&1)
assert_contains "load_artifacts mentions perfil" "frontend-nuxt" "$output"
assert_contains "load_artifacts shows Agentes section" "Agentes" "$output"
assert_contains "load_artifacts shows Steering section" "Steering" "$output"
assert_contains "load_artifacts shows Skills section" "Skills" "$output"
assert_contains "load_artifacts shows Hooks section" "Hooks" "$output"
assert_contains "load_artifacts shows Resumen" "Resumen" "$output"

# Verify directories were created
if [[ -d "${PROJECT_DIR}/.kiro/agents" ]]; then
  echo "  ✓ .kiro/agents/ directory created"
  ((PASS++))
else
  echo "  ✗ .kiro/agents/ directory not created"
  ((FAIL++))
fi

if [[ -d "${PROJECT_DIR}/.kiro/steering" ]]; then
  echo "  ✓ .kiro/steering/ directory created"
  ((PASS++))
else
  echo "  ✗ .kiro/steering/ directory not created"
  ((FAIL++))
fi

if [[ -d "${PROJECT_DIR}/.kiro/skills" ]]; then
  echo "  ✓ .kiro/skills/ directory created"
  ((PASS++))
else
  echo "  ✗ .kiro/skills/ directory not created"
  ((FAIL++))
fi

if [[ -d "${PROJECT_DIR}/.kiro/hooks" ]]; then
  echo "  ✓ .kiro/hooks/ directory created"
  ((PASS++))
else
  echo "  ✗ .kiro/hooks/ directory not created"
  ((FAIL++))
fi

# Test: load_artifacts with missing args
output=$(load_artifacts "" "" "" 2>&1)
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "  ✓ load_artifacts fails with missing args"
  ((PASS++))
else
  echo "  ✗ load_artifacts should fail with missing args"
  ((FAIL++))
fi

echo ""
echo "════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
