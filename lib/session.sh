#!/usr/bin/env bash

_ORBIT_SESSION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ORBIT_BOOTSTRAP_DIR="$(cd "${_ORBIT_SESSION_SCRIPT_DIR}/.." && pwd)"

source "${_ORBIT_BOOTSTRAP_DIR}/lib/detect-profile.sh"

ORBIT_SESSION_ABORTED="${ORBIT_SESSION_ABORTED:-0}"
ORBIT_SESSION_BOOTSTRAP_DECLINED="${ORBIT_SESSION_BOOTSTRAP_DECLINED:-0}"
ORBIT_SESSION_HOME_DECLINED="${ORBIT_SESSION_HOME_DECLINED:-0}"
ORBIT_SESSION_HOME_HANDLED="${ORBIT_SESSION_HOME_HANDLED:-0}"
ORBIT_SESSION_PROJECT_DIR="${ORBIT_SESSION_PROJECT_DIR:-}"

_orbit_prompt_choice() {
  local prompt="$1"
  local answer_var="$2"
  local default_value="${3:-}"
  local answer=""

  case "$answer_var" in
    bootstrap)
      if [[ -n "${ORBIT_BOOTSTRAP_DECISION:-}" ]]; then
        printf -v "$answer_var" '%s' "${ORBIT_BOOTSTRAP_DECISION}"
        return 0
      fi
      ;;
    home)
      if [[ -n "${ORBIT_HOME_DECISION:-}" ]]; then
        printf -v "$answer_var" '%s' "${ORBIT_HOME_DECISION}"
        return 0
      fi
      ;;
    workload)
      if [[ -n "${ORBIT_WORKLOAD:-}" ]]; then
        printf -v "$answer_var" '%s' "${ORBIT_WORKLOAD}"
        return 0
      fi
      ;;
    runtime)
      if [[ -n "${ORBIT_RUNTIME:-}" ]]; then
        printf -v "$answer_var" '%s' "${ORBIT_RUNTIME}"
        return 0
      fi
      ;;
    provisioner)
      if [[ -n "${ORBIT_PROVISIONER:-}" ]]; then
        printf -v "$answer_var" '%s' "${ORBIT_PROVISIONER}"
        return 0
      fi
      ;;
    framework)
      if [[ -n "${ORBIT_FRAMEWORK:-}" ]]; then
        printf -v "$answer_var" '%s' "${ORBIT_FRAMEWORK}"
        return 0
      fi
      ;;
  esac

  if [[ "$answer_var" == "bootstrap" && -n "${ORBIT_TEST_BOOTSTRAP_DECISION:-}" ]]; then
    printf -v "$answer_var" '%s' "${ORBIT_TEST_BOOTSTRAP_DECISION}"
    return 0
  fi
  if [[ "$answer_var" == "home" && -n "${ORBIT_TEST_HOME_DECISION:-}" ]]; then
    printf -v "$answer_var" '%s' "${ORBIT_TEST_HOME_DECISION}"
    return 0
  fi
  if [[ "$answer_var" == "workload" && -n "${ORBIT_TEST_WORKLOAD:-}" ]]; then
    printf -v "$answer_var" '%s' "${ORBIT_TEST_WORKLOAD}"
    return 0
  fi
  if [[ "$answer_var" == "runtime" && -n "${ORBIT_TEST_RUNTIME:-}" ]]; then
    printf -v "$answer_var" '%s' "${ORBIT_TEST_RUNTIME}"
    return 0
  fi
  if [[ "$answer_var" == "provisioner" && -n "${ORBIT_TEST_PROVISIONER:-}" ]]; then
    printf -v "$answer_var" '%s' "${ORBIT_TEST_PROVISIONER}"
    return 0
  fi
  if [[ "$answer_var" == "framework" && -n "${ORBIT_TEST_FRAMEWORK:-}" ]]; then
    printf -v "$answer_var" '%s' "${ORBIT_TEST_FRAMEWORK}"
    return 0
  fi

  printf "%s" "$prompt"
  read -r answer
  if [[ -z "$answer" && -n "$default_value" ]]; then
    answer="$default_value"
  fi
  printf -v "$answer_var" '%s' "$answer"
}

_orbit_prompt_project_name() {
  if [[ -n "${ORBIT_PROJECT_NAME:-}" ]]; then
    printf '%s\n' "${ORBIT_PROJECT_NAME}"
    return 0
  fi
  if [[ -n "${ORBIT_TEST_PROJECT_NAME:-}" ]]; then
    printf '%s\n' "${ORBIT_TEST_PROJECT_NAME}"
    return 0
  fi
  local answer=""
  printf "Nombre de la carpeta del proyecto: "
  read -r answer
  printf '%s\n' "$answer"
}

orbit_current_project_dir() {
  local fallback="$1"
  if [[ -n "${ORBIT_SESSION_PROJECT_DIR:-}" ]]; then
    echo "$ORBIT_SESSION_PROJECT_DIR"
    return 0
  fi
  echo "$fallback"
}

orbit_session_gate() {
  local project_dir="$1"
  local bootstrap_decision home_decision project_name new_project_dir

  if [[ "${ORBIT_SESSION_BOOTSTRAP_DECLINED}" == "1" ]]; then
    ORBIT_SESSION_ABORTED=1
    export ORBIT_SESSION_ABORTED
    return 0
  fi

  _orbit_prompt_choice "Deseas configurar el entorno con Orbit? [yes/no]: " bootstrap "yes"
  # shellcheck disable=SC2154 # bootstrap is assigned by _orbit_prompt_choice via printf -v
  if [[ "$bootstrap" != "yes" && "$bootstrap" != "y" ]]; then
    ORBIT_SESSION_BOOTSTRAP_DECLINED=1
    ORBIT_SESSION_ABORTED=1
    export ORBIT_SESSION_BOOTSTRAP_DECLINED ORBIT_SESSION_ABORTED
    echo "Orbit no volvera a preguntar por bootstrap durante esta sesion."
    return 0
  fi

  if [[ "${ORBIT_SESSION_HOME_HANDLED}" == "1" || "${ORBIT_SESSION_HOME_DECLINED}" == "1" ]]; then
    return 0
  fi

  if [[ "$project_dir" == "$HOME" ]]; then
    _orbit_prompt_choice "Estas en HOME. Quieres crear una carpeta de proyecto ahora? [yes/no]: " home "no"
    # shellcheck disable=SC2154 # home is assigned by _orbit_prompt_choice via printf -v
    if [[ "$home" == "yes" || "$home" == "y" ]]; then
      project_name="$(_orbit_prompt_project_name)"
      new_project_dir="${HOME}/${project_name}"
      mkdir -p "$new_project_dir"
      ORBIT_SESSION_PROJECT_DIR="$new_project_dir"
      ORBIT_SESSION_HOME_HANDLED=1
      export ORBIT_SESSION_PROJECT_DIR ORBIT_SESSION_HOME_HANDLED
      echo "Proyecto preparado en ${new_project_dir}. Orbit continuara desde esa ruta."
      return 0
    fi
    ORBIT_SESSION_HOME_DECLINED=1
    export ORBIT_SESSION_HOME_DECLINED
    echo "Orbit no volvera a preguntar por crear carpeta desde HOME en esta sesion."
  fi

  return 0
}

orbit_resolve_profile() {
  local project_dir="$1"
  local detected profiles_count workload runtime provisioner framework

  if [[ -n "${ORBIT_PROJECT_PROFILE_ID:-}" ]]; then
    printf '%s\n' "${ORBIT_PROJECT_PROFILE_ID}"
    return 0
  fi

  if [[ -n "${ORBIT_PROFILE_ID:-}" ]]; then
    printf '%s\n' "${ORBIT_PROFILE_ID}"
    return 0
  fi

  detected="$(detect_profiles "$project_dir" 2>/dev/null || true)"
  profiles_count="$(printf '%s\n' "$detected" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [[ "$profiles_count" == "1" ]]; then
    printf '%s\n' "$detected" | sed '/^$/d' | head -1
    return 0
  fi

  _orbit_prompt_choice "Selecciona workload [backend-api|backend-worker|infra|shared-lib|frontend-amplify]: " workload
  runtime=""
  provisioner=""
  framework=""

  case "$workload" in
    backend-api|backend-worker|shared-lib)
      _orbit_prompt_choice "Selecciona runtime [python|typescript|javascript]: " runtime
      ;;
    infra)
      _orbit_prompt_choice "Selecciona provisioner [terraform|cdk]: " provisioner
      ;;
    frontend-amplify)
      _orbit_prompt_choice "Selecciona framework [react|vue|nuxt]: " framework
      ;;
  esac

  resolve_profile_from_answers "$workload" "$runtime" "$provisioner" "$framework"
}
