#!/usr/bin/env bash
# =============================================================================
# Kiro Bootstrap - Pipeline de Configuración
# Escala 24x7
#
# Script sourceable que provee funciones para ejecutar el pipeline de
# configuración definido en el manifiesto. Lee los pasos, los ejecuta en
# orden, maneja fallos con resiliencia y genera un reporte de estado.
#
# Uso:
#   source lib/pipeline.sh
#   execute_pipeline "/path/to/manifest.json" "/path/to/project" "/path/to/bootstrap"
#
# Funciones principales:
#   parse_pipeline_steps  - Lee pasos del manifiesto JSON (sin jq)
#   execute_pipeline      - Ejecutor principal del pipeline
#   execute_step          - Despachador de pasos por tipo
#   print_pipeline_report - Reporte formateado de estado por paso
# =============================================================================

# --- Colores y formato ---
readonly _PL_RED='\033[0;31m'
readonly _PL_GREEN='\033[0;32m'
readonly _PL_YELLOW='\033[0;33m'
readonly _PL_BLUE='\033[0;34m'
readonly _PL_BOLD='\033[1m'
readonly _PL_NC='\033[0m'

# --- Almacenamiento de resultados del pipeline ---
_PIPELINE_RESULTS=()

# --- Estado compartido entre pasos del pipeline ---
_DETECTED_PROFILE=""

# =============================================================================
# Parseo de manifiesto JSON (sin dependencia de jq)
# =============================================================================

# Lee el manifiesto JSON y extrae los pasos del pipeline.
# Cada paso se emite como una línea con formato: "order|id|name|enabled|type"
# Los pasos se emiten ordenados por el campo `order`.
#
# Args:
#   $1 - Ruta al archivo manifest.json
# Output:
#   Una línea por paso a stdout, ordenadas por order
# Returns:
#   0 si se extrajeron pasos, 1 si hubo error
parse_pipeline_steps() {
  local manifest_path="$1"

  if [[ ! -f "$manifest_path" ]]; then
    echo "Error: Manifiesto no encontrado: ${manifest_path}" >&2
    return 1
  fi

  local content
  content=$(cat "$manifest_path") || return 1

  # Extraer el bloque de steps del pipeline usando grep/sed
  # Estrategia: extraer cada objeto step individualmente
  local in_steps=false
  local brace_depth=0
  local current_step=""
  local steps_raw=()

  while IFS= read -r line; do
    # Detectar inicio del array "steps"
    if [[ "$line" =~ \"steps\" ]]; then
      in_steps=true
      continue
    fi

    if [[ "$in_steps" == true ]]; then
      # Contar llaves para delimitar objetos
      local open_braces="${line//[^\{]/}"
      local close_braces="${line//[^\}]/}"
      brace_depth=$(( brace_depth + ${#open_braces} - ${#close_braces} ))

      if [[ ${#open_braces} -gt 0 || -n "$current_step" ]]; then
        current_step+="$line"
      fi

      # Cuando brace_depth vuelve a 0, terminamos un objeto step
      if [[ $brace_depth -eq 0 && -n "$current_step" ]]; then
        steps_raw+=("$current_step")
        current_step=""
      fi

      # Detectar cierre del array de steps (] a nivel 0)
      if [[ "$line" =~ ^\s*\] && $brace_depth -le 0 ]]; then
        in_steps=false
        break
      fi
    fi
  done <<< "$content"

  if [[ ${#steps_raw[@]} -eq 0 ]]; then
    echo "Error: No se encontraron pasos en el pipeline" >&2
    return 1
  fi

  # Extraer campos de cada step y emitir líneas parseadas
  local parsed_lines=()
  for step_json in "${steps_raw[@]}"; do
    local step_id step_name step_enabled step_order step_type

    step_id=$(echo "$step_json" | grep -oE '"id"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    step_name=$(echo "$step_json" | grep -oE '"name"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    step_order=$(echo "$step_json" | grep -oE '"order"\s*:\s*[0-9]+' | head -1 | grep -oE '[0-9]+$')
    step_type=$(echo "$step_json" | grep -oE '"type"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

    # Extraer enabled (true/false)
    step_enabled=$(echo "$step_json" | grep -oE '"enabled"\s*:\s*(true|false)' | head -1 | grep -oE '(true|false)$')

    # Defaults
    step_order=${step_order:-0}
    step_enabled=${step_enabled:-true}

    if [[ -n "$step_id" ]]; then
      parsed_lines+=("${step_order}|${step_id}|${step_name}|${step_enabled}|${step_type}")
    fi
  done

  # Ordenar por campo order (primer campo) y emitir
  printf '%s\n' "${parsed_lines[@]}" | sort -t'|' -k1 -n

  return 0
}

# =============================================================================
# Ejecución de pasos individuales
# =============================================================================

# Despacha la ejecución de un paso del pipeline según su tipo.
# Cada tipo invoca el handler correspondiente.
#
# Args:
#   $1 - ID del paso (ej: "detect-profile")
#   $2 - Tipo del paso (ej: "detection", "validation", "loading")
#   $3 - Directorio del proyecto
#   $4 - Directorio del bootstrap (repositorio central)
# Returns:
#   0 en éxito, 1 en fallo
execute_step() {
  local step_id="$1"
  local step_type="$2"
  local project_dir="$3"
  local bootstrap_dir="$4"

  case "$step_type" in
    detection)
      # Invocar detección de perfil
      local lib_dir="${bootstrap_dir}/lib"
      if [[ -f "${lib_dir}/detect-profile.sh" ]]; then
        # Source detect-profile.sh si no está ya cargado
        if ! type detect_profiles &>/dev/null; then
          source "${lib_dir}/detect-profile.sh"
        fi
        local profiles
        profiles=$(detect_profiles "$project_dir")
        local detect_rc=$?
        if [[ $detect_rc -eq 0 && -n "$profiles" ]]; then
          # Almacenar el primer perfil detectado para uso en pasos posteriores
          _DETECTED_PROFILE=$(echo "$profiles" | head -1)
          echo "$profiles"
          return 0
        else
          echo "No se detectó ningún perfil de proyecto" >&2
          return 1
        fi
      else
        echo "Script de detección no encontrado: ${lib_dir}/detect-profile.sh" >&2
        return 1
      fi
      ;;

    validation)
      # Invocar validación de entorno
      # Primero intentar detectar el perfil para saber qué script de validación usar
      local validations_dir="${bootstrap_dir}/validations"
      local detected_profile=""

      # Intentar obtener el perfil detectado
      if type detect_single_profile &>/dev/null; then
        detected_profile=$(detect_single_profile "$project_dir" 2>/dev/null) || true
      fi

      if [[ -n "$detected_profile" && -f "${validations_dir}/${detected_profile}.sh" ]]; then
        bash "${validations_dir}/${detected_profile}.sh" "$project_dir"
        return $?
      elif [[ -f "${validations_dir}/common.sh" ]]; then
        # Fallback: ejecutar validaciones comunes
        echo "No se encontró script de validación para perfil '${detected_profile}'. Usando validación común." >&2
        source "${validations_dir}/common.sh"
        # Validar herramientas básicas (git)
        local result
        result=$(validate_tool "git" "git --version" "2.30.0" "true" "brew install git (macOS) | sudo apt install git (Linux)") || true
        print_validation_report "$result"
        return $?
      else
        echo "No se encontraron scripts de validación en: ${validations_dir}" >&2
        return 1
      fi
      ;;

    loading)
      # Carga de artefactos según perfil detectado
      local lib_dir="${bootstrap_dir}/lib"
      if [[ -f "${lib_dir}/load-artifacts.sh" ]]; then
        if ! type load_artifacts &>/dev/null; then
          source "${lib_dir}/load-artifacts.sh"
        fi
        # Obtener perfil: usar variable compartida o detectar de nuevo
        local profile="${_DETECTED_PROFILE}"
        if [[ -z "$profile" ]]; then
          if type detect_single_profile &>/dev/null; then
            profile=$(detect_single_profile "$project_dir" 2>/dev/null) || true
          fi
        fi
        if [[ -z "$profile" ]]; then
          echo "No se pudo determinar el perfil para cargar artefactos" >&2
          return 1
        fi
        load_artifacts "$project_dir" "$bootstrap_dir" "$profile"
        return $?
      else
        echo "Cargador de artefactos no encontrado: ${lib_dir}/load-artifacts.sh" >&2
        return 1
      fi
      ;;

    *)
      # Tipo desconocido - extensibilidad para nuevos tipos (Req 3.4)
      echo "Tipo de paso desconocido: ${step_type}" >&2
      return 1
      ;;
  esac
}

# =============================================================================
# Reporte del pipeline
# =============================================================================

# Imprime un reporte formateado del pipeline mostrando el estado de cada paso.
# Los estados posibles son: éxito, omitido, fallido.
#
# Args:
#   Recibe los resultados como argumentos posicionales.
#   Cada argumento tiene formato: "status|order|id|name"
#   donde status es: éxito, omitido, fallido
# Output:
#   Imprime reporte formateado a stdout
# Returns:
#   0 si todos los pasos fueron éxito u omitido, 1 si alguno falló
print_pipeline_report() {
  local results=("$@")
  local exito_count=0
  local omitido_count=0
  local fallido_count=0

  echo ""
  echo -e "${_PL_BOLD}════════════════════════════════════════════════════${_PL_NC}"
  echo -e "${_PL_BOLD}  Reporte del Pipeline de Configuración${_PL_NC}"
  echo -e "${_PL_BOLD}════════════════════════════════════════════════════${_PL_NC}"
  echo ""

  for entry in "${results[@]}"; do
    local status order step_id step_name
    IFS='|' read -r status order step_id step_name <<< "$entry"

    case "$status" in
      "éxito")
        echo -e "  ${_PL_GREEN}✓${_PL_NC} [${order}] ${step_name} (${step_id}) — ${_PL_GREEN}éxito${_PL_NC}"
        ((exito_count++))
        ;;
      "omitido")
        echo -e "  ${_PL_YELLOW}⊘${_PL_NC} [${order}] ${step_name} (${step_id}) — ${_PL_YELLOW}omitido${_PL_NC}"
        ((omitido_count++))
        ;;
      "fallido")
        echo -e "  ${_PL_RED}✗${_PL_NC} [${order}] ${step_name} (${step_id}) — ${_PL_RED}fallido${_PL_NC}"
        ((fallido_count++))
        ;;
    esac
  done

  echo ""
  echo -e "${_PL_BOLD}────────────────────────────────────────────────────${_PL_NC}"
  echo -e "  Éxito: ${_PL_GREEN}${exito_count}${_PL_NC}  Omitidos: ${_PL_YELLOW}${omitido_count}${_PL_NC}  Fallidos: ${_PL_RED}${fallido_count}${_PL_NC}"
  echo -e "${_PL_BOLD}════════════════════════════════════════════════════${_PL_NC}"

  if [[ $fallido_count -gt 0 ]]; then
    echo ""
    echo -e "  ${_PL_YELLOW}Pipeline completado con errores. Revisar pasos fallidos.${_PL_NC}"
    return 1
  else
    echo ""
    echo -e "  ${_PL_GREEN}Pipeline completado exitosamente.${_PL_NC}"
    return 0
  fi
}

# =============================================================================
# Ejecutor principal del pipeline
# =============================================================================

# Ejecuta el pipeline de configuración completo.
# Lee los pasos del manifiesto, los ejecuta en orden, maneja fallos con
# resiliencia (continúa si un paso falla) y genera un reporte final.
#
# Args:
#   $1 - Ruta al archivo manifest.json
#   $2 - Directorio del proyecto destino
#   $3 - Directorio del bootstrap (repositorio central)
# Output:
#   Imprime progreso y reporte a stdout
# Returns:
#   0 si el pipeline completó (incluso con fallos parciales), 1 si no pudo iniciar
execute_pipeline() {
  local manifest_path="$1"
  local project_dir="$2"
  local bootstrap_dir="$3"

  echo -e "${_PL_BOLD}${_PL_BLUE}▶ Iniciando Pipeline de Configuración...${_PL_NC}"
  echo ""

  # Parsear pasos del manifiesto
  local steps_output
  steps_output=$(parse_pipeline_steps "$manifest_path")
  if [[ $? -ne 0 || -z "$steps_output" ]]; then
    echo -e "${_PL_RED}Error: No se pudieron leer los pasos del pipeline desde el manifiesto.${_PL_NC}" >&2
    return 1
  fi

  # Source detect-profile.sh para que esté disponible durante la ejecución
  local lib_dir="${bootstrap_dir}/lib"
  if [[ -f "${lib_dir}/detect-profile.sh" ]]; then
    source "${lib_dir}/detect-profile.sh"
  fi

  # Ejecutar cada paso en orden
  _PIPELINE_RESULTS=()

  while IFS='|' read -r order step_id step_name step_enabled step_type; do
    # Saltar líneas vacías
    [[ -z "$step_id" ]] && continue

    echo -e "${_PL_BLUE}  ▷ Paso ${order}: ${step_name}${_PL_NC}"

    # Verificar si el paso está habilitado (Req 3.2)
    if [[ "$step_enabled" != "true" ]]; then
      echo -e "    ${_PL_YELLOW}⊘ Paso deshabilitado, omitiendo.${_PL_NC}"
      _PIPELINE_RESULTS+=("omitido|${order}|${step_id}|${step_name}")
      continue
    fi

    # Ejecutar el paso con resiliencia (Req 3.5)
    # Desactivar errexit temporalmente para capturar fallos sin abortar
    local step_exit=0
    set +e
    execute_step "$step_id" "$step_type" "$project_dir" "$bootstrap_dir" 2>/dev/null
    step_exit=$?
    set -e

    if [[ $step_exit -eq 0 ]]; then
      echo -e "    ${_PL_GREEN}✓ Completado.${_PL_NC}"
      _PIPELINE_RESULTS+=("éxito|${order}|${step_id}|${step_name}")
    else
      echo -e "    ${_PL_RED}✗ Falló. Continuando con el siguiente paso.${_PL_NC}"
      _PIPELINE_RESULTS+=("fallido|${order}|${step_id}|${step_name}")
    fi

    echo ""
  done <<< "$steps_output"

  # Generar reporte final (Req 3.6)
  print_pipeline_report "${_PIPELINE_RESULTS[@]}"
  return 0
}
