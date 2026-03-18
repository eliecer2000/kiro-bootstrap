#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${BOOTSTRAP_DIR}/lib/session.sh"

PASS=0
FAIL=0

pass() { echo "  + $1"; PASS=$((PASS + 1)); }
fail() { echo "  x $1"; FAIL=$((FAIL + 1)); }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_TEST}"' EXIT

echo ""
echo "=== Session Orbit ==="

export ORBIT_SESSION_ABORTED=0
export ORBIT_SESSION_BOOTSTRAP_DECLINED=0
export ORBIT_TEST_BOOTSTRAP_DECISION=no

orbit_session_gate "${TMPDIR_TEST}" >/dev/null 2>&1 || true
if [[ "${ORBIT_SESSION_ABORTED}" == "1" ]]; then
  pass "respeta rechazo de bootstrap"
else
  fail "no respeta rechazo de bootstrap"
fi

unset ORBIT_TEST_BOOTSTRAP_DECISION
export ORBIT_SESSION_ABORTED=0
export ORBIT_SESSION_BOOTSTRAP_DECLINED=0
export ORBIT_SESSION_HOME_DECLINED=0
export ORBIT_SESSION_HOME_HANDLED=0
export ORBIT_TEST_BOOTSTRAP_DECISION=yes
export ORBIT_TEST_HOME_DECISION=yes
export ORBIT_TEST_PROJECT_NAME=orbit-test-home

orbit_session_gate "${HOME}" >/dev/null 2>&1 || true
if [[ "${ORBIT_SESSION_PROJECT_DIR}" == "${HOME}/orbit-test-home" ]] && [[ -d "${HOME}/orbit-test-home" ]]; then
  pass "prepara carpeta cuando se arranca desde HOME"
else
  fail "no prepara carpeta desde HOME"
fi

rm -rf "${HOME}/orbit-test-home"

export ORBIT_TEST_WORKLOAD=infra
export ORBIT_TEST_PROVISIONER=terraform
resolved="$(orbit_resolve_profile "${TMPDIR_TEST}")"
if [[ "${resolved}" == "aws-infra-terraform" ]]; then
  pass "wizard resuelve perfil por workload/provisioner"
else
  fail "wizard no resuelve perfil esperado"
fi

unset ORBIT_TEST_WORKLOAD ORBIT_TEST_PROVISIONER
export ORBIT_PROJECT_PROFILE_ID=aws-infra-cdk-typescript
resolved="$(orbit_resolve_profile "${TMPDIR_TEST}")"
if [[ "${resolved}" == "aws-infra-cdk-typescript" ]]; then
  pass "permite fijar perfil con ORBIT_PROJECT_PROFILE_ID"
else
  fail "no respeta ORBIT_PROJECT_PROFILE_ID"
fi

unset ORBIT_PROJECT_PROFILE_ID
export ORBIT_BOOTSTRAP_DECISION=no
export ORBIT_SESSION_ABORTED=0
export ORBIT_SESSION_BOOTSTRAP_DECLINED=0
orbit_session_gate "${TMPDIR_TEST}" >/dev/null 2>&1 || true
if [[ "${ORBIT_SESSION_ABORTED}" == "1" ]]; then
  pass "acepta decisiones de bootstrap por variables reales"
else
  fail "no acepta decisiones de bootstrap por variables reales"
fi
unset ORBIT_BOOTSTRAP_DECISION

echo ""
echo "Resultados: ${PASS} ok, ${FAIL} fallos"
[[ "${FAIL}" -eq 0 ]]
