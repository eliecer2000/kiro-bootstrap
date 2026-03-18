#!/usr/bin/env bash

_RS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RS_BOOTSTRAP_DIR="$(cd "${_RS_SCRIPT_DIR}/.." && pwd)"

_rs_catalog() {
  python3 "${_RS_BOOTSTRAP_DIR}/lib/orbit_catalog.py" --bootstrap-dir "${_RS_BOOTSTRAP_DIR}" "$@"
}

remote_skill_field() {
  local remote_skill_id="$1"
  local field="${2:-}"
  if [[ -n "$field" ]]; then
    _rs_catalog remote-skill-field --remote-skill-id "$remote_skill_id" --field "$field"
  else
    _rs_catalog remote-skill-field --remote-skill-id "$remote_skill_id"
  fi
}

detect_skills_cli() {
  if command -v skills >/dev/null 2>&1; then
    echo "skills"
    return 0
  fi
  if command -v npx >/dev/null 2>&1; then
    echo "npx skills"
    return 0
  fi
  echo ""
}

_append_approved_remote_skill() {
  local remote_skill_id="$1"
  if [[ -z "${ORBIT_APPROVED_REMOTE_SKILLS:-}" ]]; then
    ORBIT_APPROVED_REMOTE_SKILLS="$remote_skill_id"
  elif [[ ",${ORBIT_APPROVED_REMOTE_SKILLS}," != *",${remote_skill_id},"* ]]; then
    ORBIT_APPROVED_REMOTE_SKILLS="${ORBIT_APPROVED_REMOTE_SKILLS},${remote_skill_id}"
  fi
  export ORBIT_APPROVED_REMOTE_SKILLS
}

_confirm_remote_skill() {
  local remote_skill_id="$1"
  local package purpose command answer

  package="$(remote_skill_field "$remote_skill_id" package)"
  purpose="$(remote_skill_field "$remote_skill_id" purpose)"
  command="npx skills add ${package} -g -y"

  echo "    Remote skill: ${remote_skill_id}"
  echo "      Package: ${package}"
  echo "      Purpose: ${purpose}"
  echo "      Command: ${command}"

  if [[ -n "${ORBIT_REMOTE_SKILLS_AUTO_APPROVE:-}" ]]; then
    return 0
  fi

  if [[ -n "${ORBIT_REMOTE_SKILL_DECISION:-}" ]]; then
    [[ "${ORBIT_REMOTE_SKILL_DECISION}" == "yes" || "${ORBIT_REMOTE_SKILL_DECISION}" == "y" || "${ORBIT_REMOTE_SKILL_DECISION}" == "approve" ]]
    return $?
  fi

  if [[ -n "${ORBIT_TEST_REMOTE_SKILL_DECISION:-}" ]]; then
    [[ "${ORBIT_TEST_REMOTE_SKILL_DECISION}" == "yes" ]]
    return $?
  fi

  printf "    Instalar esta skill remota? [y/N]: "
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

install_remote_skill() {
  local remote_skill_id="$1"
  local package command display_command skills_cli

  package="$(remote_skill_field "$remote_skill_id" package)"
  display_command="npx skills add ${package} -g -y"
  if ! _confirm_remote_skill "$remote_skill_id"; then
    echo "    - Skill remota omitida: ${remote_skill_id}"
    return 0
  fi

  if [[ -n "${ORBIT_DRY_RUN_REMOTE_SKILLS:-}" ]]; then
    echo "    + Dry-run remote skill: ${display_command}"
    _append_approved_remote_skill "$remote_skill_id"
    return 0
  fi

  skills_cli="$(detect_skills_cli)"
  if [[ -z "$skills_cli" ]]; then
    echo "    ! skills.sh no esta disponible. Ejecuta manualmente: ${display_command}"
    return 0
  fi

  if [[ "$skills_cli" == "skills" ]]; then
    command="skills add ${package} -g -y"
  else
    command="${display_command}"
  fi

  if eval "$command" >/dev/null 2>&1; then
    echo "    + Skill remota instalada: ${remote_skill_id}"
    _append_approved_remote_skill "$remote_skill_id"
    return 0
  fi

  echo "    ! No se pudo instalar la skill remota: ${remote_skill_id}"
  return 0
}
