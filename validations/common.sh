#!/usr/bin/env bash
# =============================================================================
# Kiro Bootstrap - Funciones Comunes de Validación de Entorno
# Escala 24x7
#
# Script sourceable que provee funciones compartidas para validar herramientas,
# versiones, configuración AWS SSO y archivos .env.
#
# Uso:
#   source validations/common.sh
#
# Funciones principales:
#   check_tool_present       - Verifica presencia de herramienta en PATH
#   get_tool_version         - Extrae versión semántica de un comando
#   compare_versions         - Comparación semántica major.minor.patch
#   format_missing_tool_message - Mensaje formateado de herramienta faltante
#   validate_tool            - Validación completa de herramienta
#   check_aws_sso            - Verifica configuración AWS SSO
#   check_env_files          - Verifica archivos .env y variables requeridas
#   print_validation_report  - Imprime reporte formateado de validación
# =============================================================================

# --- Colores y formato ---
readonly _VC_RED='\033[0;31m'
readonly _VC_GREEN='\033[0;32m'
readonly _VC_YELLOW='\033[0;33m'
readonly _VC_BOLD='\033[1m'
readonly _VC_NC='\033[0m'

# --- Contadores globales de reporte ---
_VALIDATION_RESULTS=()

# =============================================================================
# Funciones de validación
# =============================================================================

# Verifica si una herramienta está disponible en el PATH.
#
# Args:
#   $1 - Nombre de la herramienta (ej: "node", "terraform")
# Returns:
#   0 si la herramienta está presente, 1 si no
check_tool_present() {
  local tool_name="$1"
  command -v "$tool_name" &>/dev/null
  return $?
}

# Ejecuta un comando de versión y extrae el número de versión (major.minor.patch).
# Soporta formatos comunes: "v1.2.3", "1.2.3", "tool 1.2.3", "aws-cli/2.15.0", etc.
#
# Args:
#   $1 - Comando de versión completo (ej: "node --version")
# Output:
#   Imprime la versión extraída a stdout (ej: "18.19.0")
# Returns:
#   0 si se extrajo una versión, 1 si no
get_tool_version() {
  local version_command="$1"
  local raw_output
  local version

  # Ejecutar el comando y capturar salida (stderr también, para herramientas como aws)
  raw_output=$(eval "$version_command" 2>&1) || true

  # Extraer patrón de versión semántica (major.minor.patch)
  version=$(echo "$raw_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

  if [[ -n "$version" ]]; then
    echo "$version"
    return 0
  fi

  return 1
}

# Comparación semántica de versiones (major.minor.patch).
# Determina si la versión instalada cumple con la versión mínima requerida.
# La comparación es numérica, NO lexicográfica.
#
# Args:
#   $1 - Versión instalada (ej: "18.19.0")
#   $2 - Versión mínima requerida (ej: "18.0.0")
# Returns:
#   0 si instalada >= mínima, 1 si instalada < mínima
compare_versions() {
  local installed="$1"
  local minimum="$2"

  # Extraer componentes de la versión instalada
  local inst_major inst_minor inst_patch
  IFS='.' read -r inst_major inst_minor inst_patch <<< "$installed"
  inst_major=${inst_major:-0}
  inst_minor=${inst_minor:-0}
  inst_patch=${inst_patch:-0}

  # Extraer componentes de la versión mínima
  local min_major min_minor min_patch
  IFS='.' read -r min_major min_minor min_patch <<< "$minimum"
  min_major=${min_major:-0}
  min_minor=${min_minor:-0}
  min_patch=${min_patch:-0}

  # Comparar major
  if (( inst_major > min_major )); then
    return 0
  elif (( inst_major < min_major )); then
    return 1
  fi

  # Major iguales, comparar minor
  if (( inst_minor > min_minor )); then
    return 0
  elif (( inst_minor < min_minor )); then
    return 1
  fi

  # Minor iguales, comparar patch
  if (( inst_patch >= min_patch )); then
    return 0
  fi

  return 1
}


# Genera un mensaje formateado para una herramienta faltante con hint de instalación.
#
# Args:
#   $1 - Nombre de la herramienta
#   $2 - Hint de instalación (ej: "brew install node")
# Output:
#   Imprime mensaje formateado a stdout
format_missing_tool_message() {
  local tool_name="$1"
  local install_hint="$2"

  echo "Herramienta '${tool_name}' no encontrada. Instalar con: ${install_hint}"
}

# Validación completa de una herramienta: presencia, versión y estado.
# Genera una línea de estado con formato: "PASS|WARN|FAIL tool_name version_info message"
#
# Args:
#   $1 - Nombre de la herramienta (ej: "node")
#   $2 - Comando de versión (ej: "node --version")
#   $3 - Versión mínima requerida (ej: "18.0.0")
#   $4 - Requerida: "true" o "false"
#   $5 - Hint de instalación
# Output:
#   Imprime línea de estado a stdout
# Returns:
#   0 si PASS, 1 si FAIL, 2 si WARN
validate_tool() {
  local tool_name="$1"
  local version_command="$2"
  local min_version="$3"
  local required="$4"
  local install_hint="$5"

  # Verificar presencia
  if ! check_tool_present "$tool_name"; then
    local msg
    msg=$(format_missing_tool_message "$tool_name" "$install_hint")
    if [[ "$required" == "true" ]]; then
      echo "FAIL ${tool_name} no-instalado ${msg}"
      return 1
    else
      echo "WARN ${tool_name} no-instalado ${msg}"
      return 2
    fi
  fi

  # Obtener versión instalada
  local installed_version
  installed_version=$(get_tool_version "$version_command")

  if [[ -z "$installed_version" ]]; then
    echo "WARN ${tool_name} desconocida No se pudo determinar la versión de ${tool_name}"
    return 2
  fi

  # Comparar versiones
  if compare_versions "$installed_version" "$min_version"; then
    echo "PASS ${tool_name} ${installed_version} ${tool_name} ${installed_version} >= ${min_version}"
    return 0
  else
    if [[ "$required" == "true" ]]; then
      echo "FAIL ${tool_name} ${installed_version} ${tool_name} ${installed_version} < ${min_version} (mínimo requerido: ${min_version})"
      return 1
    else
      echo "WARN ${tool_name} ${installed_version} ${tool_name} ${installed_version} < ${min_version} (recomendado: ${min_version})"
      return 2
    fi
  fi
}

# Verifica la configuración de AWS SSO ejecutando aws sts get-caller-identity.
#
# Returns:
#   0 si la identidad AWS está configurada, 1 si no
check_aws_sso() {
  if ! check_tool_present "aws"; then
    echo "FAIL aws no-instalado AWS CLI no está instalado"
    return 1
  fi

  if aws sts get-caller-identity &>/dev/null; then
    local account_id
    account_id=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "desconocida")
    echo "PASS aws-sso configurado Sesión AWS activa (cuenta: ${account_id})"
    return 0
  else
    echo "WARN aws-sso no-configurado Sesión AWS no activa. Ejecutar: aws sso login"
    return 1
  fi
}

# Verifica la existencia de archivos .env y variables requeridas.
#
# Args:
#   $1 - Directorio del proyecto
#   $2 - Lista de archivos .env separados por espacio (ej: ".env .env.local")
#   $3 - Lista de variables requeridas separadas por espacio
# Output:
#   Imprime líneas de estado a stdout
# Returns:
#   0 si todo OK, 1 si hay problemas
check_env_files() {
  local project_dir="$1"
  local files="$2"
  local required_vars="$3"
  local has_env=false
  local all_ok=true

  # Verificar existencia de al menos un archivo .env
  for env_file in $files; do
    if [[ -f "${project_dir}/${env_file}" ]]; then
      has_env=true
      echo "PASS env-file ${env_file} Archivo ${env_file} encontrado"
    fi
  done

  if [[ "$has_env" == false ]]; then
    echo "WARN env-file ninguno No se encontró ningún archivo .env (${files})"
    all_ok=false
  fi

  # Verificar variables requeridas en los archivos .env existentes
  if [[ "$has_env" == true && -n "$required_vars" ]]; then
    for var in $required_vars; do
      local found=false
      for env_file in $files; do
        if [[ -f "${project_dir}/${env_file}" ]]; then
          if grep -q "^${var}=" "${project_dir}/${env_file}" 2>/dev/null; then
            found=true
            break
          fi
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

# Imprime un reporte formateado de validación con conteo de estados.
#
# Args:
#   Recibe líneas de resultado vía stdin o como argumentos del array.
#   Cada línea tiene formato: "PASS|WARN|FAIL nombre versión mensaje"
# Output:
#   Imprime reporte formateado a stdout
print_validation_report() {
  local pass_count=0
  local warn_count=0
  local fail_count=0
  local results=("$@")

  echo ""
  echo -e "${_VC_BOLD}════════════════════════════════════════════${_VC_NC}"
  echo -e "${_VC_BOLD}  Reporte de Validación de Entorno${_VC_NC}"
  echo -e "${_VC_BOLD}════════════════════════════════════════════${_VC_NC}"
  echo ""

  for result in "${results[@]}"; do
    local status
    status=$(echo "$result" | awk '{print $1}')
    local detail
    detail=$(echo "$result" | cut -d' ' -f4-)

    case "$status" in
      PASS)
        echo -e "  ${_VC_GREEN}✓${_VC_NC} ${detail}"
        ((pass_count++))
        ;;
      WARN)
        echo -e "  ${_VC_YELLOW}⚠${_VC_NC} ${detail}"
        ((warn_count++))
        ;;
      FAIL)
        echo -e "  ${_VC_RED}✗${_VC_NC} ${detail}"
        ((fail_count++))
        ;;
    esac
  done

  echo ""
  echo -e "${_VC_BOLD}────────────────────────────────────────────${_VC_NC}"
  echo -e "  Aprobados: ${_VC_GREEN}${pass_count}${_VC_NC}  Advertencias: ${_VC_YELLOW}${warn_count}${_VC_NC}  Fallidos: ${_VC_RED}${fail_count}${_VC_NC}"
  echo -e "${_VC_BOLD}════════════════════════════════════════════${_VC_NC}"

  if [[ $fail_count -gt 0 ]]; then
    echo ""
    echo -e "  ${_VC_RED}El entorno tiene problemas que deben resolverse.${_VC_NC}"
    return 1
  elif [[ $warn_count -gt 0 ]]; then
    echo ""
    echo -e "  ${_VC_YELLOW}El entorno tiene advertencias. Revisar antes de continuar.${_VC_NC}"
    return 0
  else
    echo ""
    echo -e "  ${_VC_GREEN}Entorno listo. Todas las verificaciones aprobadas.${_VC_NC}"
    return 0
  fi
}
