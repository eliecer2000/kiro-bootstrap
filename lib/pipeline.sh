#!/usr/bin/env bash

_PL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PL_BOOTSTRAP_DIR="$(cd "${_PL_SCRIPT_DIR}/.." && pwd)"

_PL_RED="${_PL_RED:-\033[0;31m}"
_PL_GREEN="${_PL_GREEN:-\033[0;32m}"
_PL_YELLOW="${_PL_YELLOW:-\033[0;33m}"
_PL_BLUE="${_PL_BLUE:-\033[0;34m}"
_PL_BOLD="${_PL_BOLD:-\033[1m}"
_PL_NC="${_PL_NC:-\033[0m}"

_PIPELINE_RESULTS=()
_DETECTED_PROFILE=""

source "${_PL_BOOTSTRAP_DIR}/lib/session.sh"
source "${_PL_BOOTSTRAP_DIR}/lib/load-artifacts.sh"
source "${_PL_BOOTSTRAP_DIR}/validations/common.sh"

_pl_catalog() {
  python3 "${_PL_BOOTSTRAP_DIR}/lib/orbit_catalog.py" --bootstrap-dir "${_PL_BOOTSTRAP_DIR}" "$@"
}

parse_pipeline_steps() {
  _pl_catalog pipeline-steps
}

execute_step() {
  local step_id="$1"
  local step_type="$2"
  local project_dir="$3"
  local bootstrap_dir="$4"

  case "$step_type" in
    session)
      orbit_session_gate "$project_dir"
      if [[ -n "${ORBIT_SESSION_PROJECT_DIR:-}" ]]; then
        project_dir="${ORBIT_SESSION_PROJECT_DIR}"
      fi
      return 0
      ;;
    detection)
      if [[ "${ORBIT_SESSION_ABORTED:-0}" == "1" ]]; then
        return 0
      fi
      if [[ -n "${ORBIT_SESSION_PROJECT_DIR:-}" ]]; then
        project_dir="${ORBIT_SESSION_PROJECT_DIR}"
      fi
      _DETECTED_PROFILE="$(orbit_resolve_profile "$project_dir")"
      echo "Perfil activo: ${_DETECTED_PROFILE}"
      return 0
      ;;
    validation)
      if [[ "${ORBIT_SESSION_ABORTED:-0}" == "1" ]]; then
        return 0
      fi
      if [[ -n "${ORBIT_SESSION_PROJECT_DIR:-}" ]]; then
        project_dir="${ORBIT_SESSION_PROJECT_DIR}"
      fi
      validate_profile_environment "$project_dir" "$bootstrap_dir" "$_DETECTED_PROFILE"
      return $?
      ;;
    loading)
      if [[ "${ORBIT_SESSION_ABORTED:-0}" == "1" ]]; then
        return 0
      fi
      if [[ -n "${ORBIT_SESSION_PROJECT_DIR:-}" ]]; then
        project_dir="${ORBIT_SESSION_PROJECT_DIR}"
      fi
      export _ORBIT_LAST_AGENTS _ORBIT_LAST_STEERING _ORBIT_LAST_LOCAL_SKILLS _ORBIT_LAST_HOOKS _ORBIT_LAST_EXTENSION_PACKS
      load_artifacts "$project_dir" "$bootstrap_dir" "$_DETECTED_PROFILE"
      export _ORBIT_LAST_AGENTS _ORBIT_LAST_STEERING _ORBIT_LAST_LOCAL_SKILLS _ORBIT_LAST_HOOKS _ORBIT_LAST_EXTENSION_PACKS
      return $?
      ;;
    state)
      if [[ "${ORBIT_SESSION_ABORTED:-0}" == "1" ]]; then
        return 0
      fi
      if [[ -n "${ORBIT_SESSION_PROJECT_DIR:-}" ]]; then
        project_dir="${ORBIT_SESSION_PROJECT_DIR}"
      fi
      write_project_state "$project_dir" "$bootstrap_dir" "$_DETECTED_PROFILE"
      return $?
      ;;
    *)
      echo "Tipo de paso desconocido: ${step_type}" >&2
      return 1
      ;;
  esac
}

print_pipeline_report() {
  local results=("$@")
  local success_count=0
  local skipped_count=0
  local failed_count=0
  local entry status order step_id step_name

  echo ""
  echo -e "${_PL_BOLD}════════════════════════════════════════════════════${_PL_NC}"
  echo -e "${_PL_BOLD}  Reporte del Pipeline Orbit${_PL_NC}"
  echo -e "${_PL_BOLD}════════════════════════════════════════════════════${_PL_NC}"
  echo ""

  for entry in "${results[@]}"; do
    IFS='|' read -r status order step_id step_name <<< "$entry"
    case "$status" in
      success)
        echo -e "  ${_PL_GREEN}+${_PL_NC} [${order}] ${step_name} (${step_id})"
        success_count=$((success_count + 1))
        ;;
      skipped)
        echo -e "  ${_PL_YELLOW}!${_PL_NC} [${order}] ${step_name} (${step_id}) omitido"
        skipped_count=$((skipped_count + 1))
        ;;
      failed)
        echo -e "  ${_PL_RED}x${_PL_NC} [${order}] ${step_name} (${step_id})"
        failed_count=$((failed_count + 1))
        ;;
    esac
  done

  echo ""
  echo -e "${_PL_BOLD}────────────────────────────────────────────────────${_PL_NC}"
  echo -e "  Exito: ${_PL_GREEN}${success_count}${_PL_NC}  Omitidos: ${_PL_YELLOW}${skipped_count}${_PL_NC}  Fallidos: ${_PL_RED}${failed_count}${_PL_NC}"
  echo -e "${_PL_BOLD}════════════════════════════════════════════════════${_PL_NC}"

  if [[ $failed_count -gt 0 ]]; then
    return 1
  fi
  return 0
}

execute_pipeline() {
  local manifest_path="$1"
  local project_dir="$2"
  local bootstrap_dir="$3"
  local steps_output order step_id step_name step_enabled step_type step_exit

  echo -e "${_PL_BOLD}${_PL_BLUE}▶ Iniciando Pipeline Orbit...${_PL_NC}"
  echo ""

  steps_output="$(parse_pipeline_steps "$manifest_path")"
  _PIPELINE_RESULTS=()

  while IFS='|' read -r order step_id step_name step_enabled step_type; do
    [[ -z "$step_id" ]] && continue

    echo -e "${_PL_BLUE}  > Paso ${order}: ${step_name}${_PL_NC}"
    if [[ "$step_enabled" != "true" ]]; then
      _PIPELINE_RESULTS+=("skipped|${order}|${step_id}|${step_name}")
      continue
    fi

    if [[ "${ORBIT_SESSION_ABORTED:-0}" == "1" && "$step_type" != "session" ]]; then
      echo -e "    ${_PL_YELLOW}! Paso omitido por decision de sesion.${_PL_NC}"
      _PIPELINE_RESULTS+=("skipped|${order}|${step_id}|${step_name}")
      continue
    fi

    set +e
    execute_step "$step_id" "$step_type" "$project_dir" "$bootstrap_dir"
    step_exit=$?
    set -e

    if [[ $step_exit -eq 0 ]]; then
      echo -e "    ${_PL_GREEN}+ Completado.${_PL_NC}"
      _PIPELINE_RESULTS+=("success|${order}|${step_id}|${step_name}")
    else
      echo -e "    ${_PL_RED}x Fallo.${_PL_NC}"
      _PIPELINE_RESULTS+=("failed|${order}|${step_id}|${step_name}")
      echo -e "    ${_PL_RED}x Pipeline detenido por error en ${step_id}.${_PL_NC}"
      echo ""
      break
    fi
    echo ""
  done <<< "$steps_output"

  print_pipeline_report "${_PIPELINE_RESULTS[@]}"
}
