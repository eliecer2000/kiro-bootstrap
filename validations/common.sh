#!/usr/bin/env bash

_VC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_VC_BOOTSTRAP_DIR="$(cd "${_VC_SCRIPT_DIR}/.." && pwd)"

_VC_RED="${_VC_RED:-\033[0;31m}"
_VC_GREEN="${_VC_GREEN:-\033[0;32m}"
_VC_YELLOW="${_VC_YELLOW:-\033[0;33m}"
_VC_BOLD="${_VC_BOLD:-\033[1m}"
_VC_NC="${_VC_NC:-\033[0m}"

_vc_catalog() {
  python3 "${_VC_BOOTSTRAP_DIR}/lib/orbit_catalog.py" --bootstrap-dir "${_VC_BOOTSTRAP_DIR}" "$@"
}

check_tool_present() {
  command -v "$1" >/dev/null 2>&1
}

get_tool_version() {
  local version_command="$1"
  local raw_output
  raw_output="$(eval "$version_command" 2>&1 || true)"
  echo "$raw_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

compare_versions() {
  local installed="$1"
  local minimum="$2"
  local inst_major inst_minor inst_patch min_major min_minor min_patch

  IFS='.' read -r inst_major inst_minor inst_patch <<< "$installed"
  IFS='.' read -r min_major min_minor min_patch <<< "$minimum"

  inst_major="${inst_major:-0}"
  inst_minor="${inst_minor:-0}"
  inst_patch="${inst_patch:-0}"
  min_major="${min_major:-0}"
  min_minor="${min_minor:-0}"
  min_patch="${min_patch:-0}"

  if (( inst_major > min_major )); then return 0; fi
  if (( inst_major < min_major )); then return 1; fi
  if (( inst_minor > min_minor )); then return 0; fi
  if (( inst_minor < min_minor )); then return 1; fi
  if (( inst_patch >= min_patch )); then return 0; fi
  return 1
}

format_missing_tool_message() {
  echo "Herramienta '$1' no encontrada. Instalar con: $2"
}

validate_tool() {
  local tool_name="$1"
  local version_command="$2"
  local min_version="$3"
  local required="$4"
  local install_hint="$5"
  local installed_version

  if ! check_tool_present "$tool_name"; then
    if [[ "$required" == "true" ]]; then
      echo "FAIL ${tool_name} no-instalado $(format_missing_tool_message "$tool_name" "$install_hint")"
      return 1
    fi
    echo "WARN ${tool_name} no-instalado $(format_missing_tool_message "$tool_name" "$install_hint")"
    return 2
  fi

  installed_version="$(get_tool_version "$version_command")"
  if [[ -z "$installed_version" ]]; then
    echo "WARN ${tool_name} desconocida No se pudo determinar la version de ${tool_name}"
    return 2
  fi

  if compare_versions "$installed_version" "$min_version"; then
    echo "PASS ${tool_name} ${installed_version} ${tool_name} ${installed_version} >= ${min_version}"
    return 0
  fi

  if [[ "$required" == "true" ]]; then
    echo "FAIL ${tool_name} ${installed_version} ${tool_name} ${installed_version} < ${min_version} (minimo requerido: ${min_version})"
    return 1
  fi
  echo "WARN ${tool_name} ${installed_version} ${tool_name} ${installed_version} < ${min_version} (recomendado: ${min_version})"
  return 2
}

check_aws_identity() {
  if ! check_tool_present "aws"; then
    echo "FAIL aws no-instalado AWS CLI no esta instalada"
    return 1
  fi

  if [[ -n "${ORBIT_SKIP_AWS_IDENTITY_CHECK:-}" ]]; then
    echo "WARN aws-sso omitido Validacion AWS omitida por ORBIT_SKIP_AWS_IDENTITY_CHECK"
    return 0
  fi

  if [[ "${ORBIT_VALIDATE_AWS_IDENTITY:-no}" != "yes" && "${ORBIT_DEPLOY_INTENT:-no}" != "yes" ]]; then
    echo "PASS aws-sso diferido Validacion de credenciales AWS diferida hasta despliegue o verificacion explicita"
    return 0
  fi

  if aws sts get-caller-identity >/dev/null 2>&1; then
    local account_id
    account_id="$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo desconocida)"
    echo "PASS aws-sso configurado Sesion AWS activa (cuenta: ${account_id})"
    return 0
  fi

  echo "WARN aws-sso no-configurado Sesion AWS no activa. Ejecuta: aws sso login"
  return 0
}

check_env_files() {
  local project_dir="$1"
  local files="$2"
  local required_vars="$3"
  local has_env=false
  local all_ok=true
  local env_file var found

  for env_file in $files; do
    if [[ -f "${project_dir}/${env_file}" ]]; then
      has_env=true
      echo "PASS env-file ${env_file} Archivo ${env_file} encontrado"
    fi
  done

  if [[ "$has_env" == false ]]; then
    echo "WARN env-file ninguno No se encontro ningun archivo .env (${files})"
    all_ok=false
  fi

  if [[ "$has_env" == true && -n "$required_vars" ]]; then
    for var in $required_vars; do
      found=false
      for env_file in $files; do
        if [[ -f "${project_dir}/${env_file}" ]] && grep -q "^${var}=" "${project_dir}/${env_file}" 2>/dev/null; then
          found=true
          break
        fi
      done
      if [[ "$found" == true ]]; then
        echo "PASS env-var ${var} Variable ${var} definida"
      else
        echo "WARN env-var ${var} Variable ${var} no encontrada en archivos .env"
        all_ok=false
      fi
    done
  fi

  if [[ "$all_ok" == true ]]; then
    return 0
  fi
  return 1
}

print_validation_report() {
  local pass_count=0
  local warn_count=0
  local fail_count=0
  local result status detail

  echo ""
  echo -e "${_VC_BOLD}════════════════════════════════════════════${_VC_NC}"
  echo -e "${_VC_BOLD}  Reporte de Validacion de Entorno${_VC_NC}"
  echo -e "${_VC_BOLD}════════════════════════════════════════════${_VC_NC}"
  echo ""

  for result in "$@"; do
    status="$(echo "$result" | awk '{print $1}')"
    detail="$(echo "$result" | cut -d' ' -f4-)"
    case "$status" in
      PASS)
        echo -e "  ${_VC_GREEN}+${_VC_NC} ${detail}"
        pass_count=$((pass_count + 1))
        ;;
      WARN)
        echo -e "  ${_VC_YELLOW}!${_VC_NC} ${detail}"
        warn_count=$((warn_count + 1))
        ;;
      FAIL)
        echo -e "  ${_VC_RED}x${_VC_NC} ${detail}"
        fail_count=$((fail_count + 1))
        ;;
    esac
  done

  echo ""
  echo -e "${_VC_BOLD}────────────────────────────────────────────${_VC_NC}"
  echo -e "  Aprobados: ${_VC_GREEN}${pass_count}${_VC_NC}  Advertencias: ${_VC_YELLOW}${warn_count}${_VC_NC}  Fallidos: ${_VC_RED}${fail_count}${_VC_NC}"
  echo -e "${_VC_BOLD}════════════════════════════════════════════${_VC_NC}"

  if [[ $fail_count -gt 0 ]]; then
    echo ""
    echo -e "  ${_VC_RED}El entorno tiene problemas bloqueantes.${_VC_NC}"
    return 1
  fi
  if [[ $warn_count -gt 0 ]]; then
    echo ""
    echo -e "  ${_VC_YELLOW}El entorno tiene advertencias. Revisa antes de continuar.${_VC_NC}"
    return 0
  fi
  echo ""
  echo -e "  ${_VC_GREEN}Entorno listo.${_VC_NC}"
  return 0
}

validate_profile_environment() {
  local project_dir="$1"
  local bootstrap_dir="$2"
  local profile_id="$3"
  local profile_json validation_lines tool command min_version required install_hint result
  local results=()

  profile_json="$(_vc_catalog profile-field --profile-id "$profile_id" 2>/dev/null || true)"
  if [[ -z "$profile_json" ]]; then
    print_validation_report "FAIL profile no-encontrado Perfil de proyecto inexistente: ${profile_id}"
    return 1
  fi

  while IFS='|' read -r tool command min_version required install_hint; do
    [[ -z "$tool" ]] && continue
    result="$(validate_tool "$tool" "$command" "$min_version" "$required" "$install_hint" || true)"
    results+=("$result")
  done < <(python3 - <<'PY' "$profile_json"
import json, sys
profile = json.loads(sys.argv[1])
for item in profile.get("validations", []):
    print(
        "|".join(
            [
                item["tool"],
                item["command"],
                item["minVersion"],
                str(item.get("required", True)).lower(),
                item.get("installHint", ""),
            ]
        )
    )
PY
)

  local aws_check
  aws_check="$(python3 - "$profile_json" <<'PY'
import json, sys
profile = json.loads(sys.argv[1])
print("true" if profile.get("awsCheck") else "false")
PY
)"
  if [[ "$aws_check" == "true" ]]; then
    result="$(check_aws_identity || true)"
    results+=("$result")
  fi

  local env_files env_vars
  env_files="$(python3 - <<'PY' "$profile_json"
import json, sys
profile = json.loads(sys.argv[1])
print(" ".join(profile.get("envCheck", {}).get("files", [])))
PY
)"
  env_vars="$(python3 - <<'PY' "$profile_json"
import json, sys
profile = json.loads(sys.argv[1])
print(" ".join(profile.get("envCheck", {}).get("requiredVars", [])))
PY
)"
  if [[ -n "$env_files" ]]; then
    while IFS= read -r result; do
      [[ -n "$result" ]] && results+=("$result")
    done < <(check_env_files "$project_dir" "$env_files" "$env_vars" || true)
  fi

  if [[ ${#results[@]} -eq 0 ]]; then
    print_validation_report
  else
    print_validation_report "${results[@]}"
  fi
}
