#!/usr/bin/env bash
# =============================================================================
# Kiro Bootstrap - Cargador de Artefactos
# Escala 24x7
#
# Script sourceable que provee funciones para copiar selectivamente artefactos
# Kiro al directorio .kiro/ del proyecto según el perfil detectado.
#
# Uso:
#   source lib/load-artifacts.sh
#   load_artifacts "/path/to/project" "/path/to/bootstrap" "frontend-nuxt"
#
# Funciones principales:
#   load_artifacts            - Función principal de carga
#   copy_artifact             - Copia inteligente con detección de cambios
#   filter_agents_by_profile  - Filtra agentes por perfil
#   get_agent_field           - Extrae campo simple de un agente
#   get_agent_array_field     - Extrae campo array de un agente
#   get_global_steering_files - Extrae steering files globales
# =============================================================================

# --- Colores y formato ---
readonly _LA_RED='\033[0;31m'
readonly _LA_GREEN='\033[0;32m'
readonly _LA_YELLOW='\033[0;33m'
readonly _LA_BLUE='\033[0;34m'
readonly _LA_BOLD='\033[1m'
readonly _LA_NC='\033[0m'

# --- Contadores de artefactos ---
_LA_NEW=0
_LA_UNCHANGED=0
_LA_MODIFIED=0
_LA_SKIPPED=0

# =============================================================================
# Parseo de JSON con grep (sin dependencia de jq)
# =============================================================================

# Filtra agentes del registro cuyo array "profiles" contiene el perfil dado
# o el wildcard "*".
#
# Args:
#   $1 - Ruta al archivo agents-registry.json
#   $2 - Nombre del perfil (ej: "frontend-nuxt")
# Output:
#   Un nombre de agente por línea a stdout
# Returns:
#   0 si se encontraron agentes, 1 si no
filter_agents_by_profile() {
  local registry_path="$1"
  local profile="$2"

  if [[ ! -f "$registry_path" ]]; then
    echo "Error: Registro de agentes no encontrado: ${registry_path}" >&2
    return 1
  fi

  local content
  content=$(cat "$registry_path") || return 1

  # Parse agent blocks: find each agent name and its profiles array
  local current_agent=""
  local in_profiles=false
  local found_agents=()

  while IFS= read -r line; do
    # Detect agent key (top-level key inside "agents" object)
    # Pattern: "agent-name": {
    if [[ "$line" =~ ^[[:space:]]*\"([a-zA-Z0-9_-]+)\"[[:space:]]*:[[:space:]]*\{ ]]; then
      local candidate="${BASH_REMATCH[1]}"
      # Skip known non-agent keys
      if [[ "$candidate" != "agents" && "$candidate" != "globalSteeringFiles" && "$candidate" != "version" ]]; then
        current_agent="$candidate"
        in_profiles=false
      fi
    fi

    # Detect profiles array start
    if [[ -n "$current_agent" && "$line" =~ \"profiles\" ]]; then
      in_profiles=true
    fi

    # Inside profiles array, look for matching profile or wildcard
    if [[ "$in_profiles" == true && -n "$current_agent" ]]; then
      if [[ "$line" =~ \"${profile}\" || "$line" =~ \"\*\" ]]; then
        found_agents+=("$current_agent")
        current_agent=""
        in_profiles=false
      fi
      # Detect end of profiles array
      if [[ "$line" =~ \] ]]; then
        in_profiles=false
      fi
    fi
  done <<< "$content"

  if [[ ${#found_agents[@]} -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${found_agents[@]}"
  return 0
}

# Extrae el valor de un campo simple (string) de un agente en el registro.
#
# Args:
#   $1 - Ruta al archivo agents-registry.json
#   $2 - Nombre del agente (ej: "vue-dev")
#   $3 - Nombre del campo (ej: "file", "model", "description")
# Output:
#   Valor del campo a stdout
# Returns:
#   0 si se encontró el campo, 1 si no
get_agent_field() {
  local registry_path="$1"
  local agent_name="$2"
  local field="$3"

  if [[ ! -f "$registry_path" ]]; then
    return 1
  fi

  local content
  content=$(cat "$registry_path") || return 1

  # Find the agent block and extract the field value
  local in_agent=false
  local brace_depth=0

  while IFS= read -r line; do
    # Detect start of the target agent block
    if [[ "$line" =~ \"${agent_name}\"[[:space:]]*:[[:space:]]*\{ ]]; then
      in_agent=true
      brace_depth=1
      continue
    fi

    if [[ "$in_agent" == true ]]; then
      # Track brace depth
      local open="${line//[^\{]/}"
      local close="${line//[^\}]/}"
      brace_depth=$(( brace_depth + ${#open} - ${#close} ))

      # Look for the field (only simple string values, not arrays)
      if [[ "$line" =~ \"${field}\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
      fi

      # Exit if we've left the agent block
      if [[ $brace_depth -le 0 ]]; then
        break
      fi
    fi
  done <<< "$content"

  return 1
}

# Extrae los valores de un campo array de un agente en el registro.
# Retorna un valor por línea.
#
# Args:
#   $1 - Ruta al archivo agents-registry.json
#   $2 - Nombre del agente (ej: "vue-dev")
#   $3 - Nombre del campo array (ej: "steeringFiles", "skills", "profiles")
# Output:
#   Un valor por línea a stdout
# Returns:
#   0 si se encontró el campo, 1 si no
get_agent_array_field() {
  local registry_path="$1"
  local agent_name="$2"
  local field="$3"

  if [[ ! -f "$registry_path" ]]; then
    return 1
  fi

  local content
  content=$(cat "$registry_path") || return 1

  local in_agent=false
  local in_field_array=false
  local brace_depth=0
  local found=false

  while IFS= read -r line; do
    # Detect start of the target agent block
    if [[ "$line" =~ \"${agent_name}\"[[:space:]]*:[[:space:]]*\{ ]]; then
      in_agent=true
      brace_depth=1
      continue
    fi

    if [[ "$in_agent" == true ]]; then
      # Track brace depth
      local open="${line//[^\{]/}"
      local close="${line//[^\}]/}"
      brace_depth=$(( brace_depth + ${#open} - ${#close} ))

      # Detect start of the target array field
      if [[ "$in_field_array" == false && "$line" =~ \"${field}\"[[:space:]]*: ]]; then
        in_field_array=true
        # Check if the array is on the same line (e.g., "skills": [])
        if [[ "$line" =~ \[.*\] ]]; then
          # Extract all values from inline array
          local array_content
          array_content=$(echo "$line" | sed 's/.*\[//' | sed 's/\].*//')
          while [[ "$array_content" =~ \"([^\"]+)\" ]]; do
            echo "${BASH_REMATCH[1]}"
            found=true
            array_content="${array_content#*\"${BASH_REMATCH[1]}\"}"
          done
          in_field_array=false
          continue
        fi
      fi

      # Inside the array, extract values
      if [[ "$in_field_array" == true ]]; then
        if [[ "$line" =~ \"([^\"]+)\" ]]; then
          echo "${BASH_REMATCH[1]}"
          found=true
        fi
        # Detect end of array
        if [[ "$line" =~ \] ]]; then
          in_field_array=false
        fi
      fi

      # Exit if we've left the agent block
      if [[ $brace_depth -le 0 ]]; then
        break
      fi
    fi
  done <<< "$content"

  if [[ "$found" == true ]]; then
    return 0
  fi
  return 1
}

# Extrae las rutas de los steering files globales del registro.
# Retorna un path por línea.
#
# Args:
#   $1 - Ruta al archivo agents-registry.json
# Output:
#   Un path de steering file por línea a stdout
# Returns:
#   0 si se encontraron, 1 si no
get_global_steering_files() {
  local registry_path="$1"

  if [[ ! -f "$registry_path" ]]; then
    return 1
  fi

  local content
  content=$(cat "$registry_path") || return 1

  local in_global=false
  local found=false

  while IFS= read -r line; do
    # Detect start of globalSteeringFiles array
    if [[ "$line" =~ \"globalSteeringFiles\" ]]; then
      in_global=true
      continue
    fi

    if [[ "$in_global" == true ]]; then
      # Extract file paths from "file": "..." entries
      if [[ "$line" =~ \"file\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        echo "${BASH_REMATCH[1]}"
        found=true
      fi
      # Detect end of globalSteeringFiles array (closing bracket at depth 0)
      if [[ "$line" =~ ^[[:space:]]*\] ]]; then
        in_global=false
      fi
    fi
  done <<< "$content"

  if [[ "$found" == true ]]; then
    return 0
  fi
  return 1
}

# =============================================================================
# Copia inteligente de artefactos
# =============================================================================

# Copia un artefacto del repositorio central al proyecto, con detección de
# cambios. Si el destino no existe, copia directamente. Si existe y es
# idéntico, omite la copia. Si existe y difiere, reporta el conflicto.
#
# Args:
#   $1 - Ruta del archivo fuente (en el repositorio central)
#   $2 - Ruta del archivo destino (en .kiro/ del proyecto)
# Output:
#   Imprime estado de la operación a stdout
# Returns:
#   0 en éxito o skip, 1 en error
copy_artifact() {
  local source="$1"
  local dest="$2"

  # Verificar que el fuente existe (Req 5.5: advertencia si no existe)
  if [[ ! -e "$source" ]]; then
    echo -e "    ${_LA_YELLOW}⚠ Fuente no encontrada: ${source}${_LA_NC}" >&2
    ((_LA_SKIPPED++))
    return 0
  fi

  # Si es un directorio, copiar recursivamente
  if [[ -d "$source" ]]; then
    if [[ -d "$dest" ]]; then
      # Compare directory contents
      if diff -rq "$source" "$dest" &>/dev/null; then
        echo -e "    ${_LA_BLUE}≡ Sin cambios: $(basename "$dest")/${_LA_NC}"
        ((_LA_UNCHANGED++))
        return 0
      else
        echo -e "    ${_LA_YELLOW}⚠ Modificado localmente: $(basename "$dest")/ — conservando versión local${_LA_NC}"
        ((_LA_MODIFIED++))
        return 0
      fi
    else
      mkdir -p "$dest"
      cp -R "$source/." "$dest/" 2>/dev/null
      echo -e "    ${_LA_GREEN}+ Nuevo: $(basename "$dest")/${_LA_NC}"
      ((_LA_NEW++))
      return 0
    fi
  fi

  # Archivo regular
  if [[ ! -f "$dest" ]]; then
    # Destino no existe: copiar y reportar "nuevo" (Req 7.5)
    local dest_dir
    dest_dir=$(dirname "$dest")
    mkdir -p "$dest_dir"
    cp "$source" "$dest"
    echo -e "    ${_LA_GREEN}+ Nuevo: $(basename "$dest")${_LA_NC}"
    ((_LA_NEW++))
    return 0
  fi

  # Destino existe: comparar contenido (Req 7.5, 10.2)
  if diff -q "$source" "$dest" &>/dev/null; then
    # Idéntico: omitir copia
    echo -e "    ${_LA_BLUE}≡ Sin cambios: $(basename "$dest")${_LA_NC}"
    ((_LA_UNCHANGED++))
    return 0
  fi

  # Difiere: reportar conflicto (Req 7.6)
  echo -e "    ${_LA_YELLOW}⚠ Modificado localmente: $(basename "$dest") — conservando versión local${_LA_NC}"
  ((_LA_MODIFIED++))
  return 0
}

# =============================================================================
# Función principal de carga de artefactos
# =============================================================================

# Carga selectivamente los artefactos Kiro correspondientes al perfil detectado.
# Lee el registro de agentes, filtra por perfil, y copia agentes, steering files,
# skills, hooks y steering files globales al directorio .kiro/ del proyecto.
#
# Args:
#   $1 - Directorio del proyecto destino
#   $2 - Directorio del bootstrap (repositorio central)
#   $3 - Perfil detectado (ej: "frontend-nuxt")
# Output:
#   Imprime progreso y resumen a stdout
# Returns:
#   0 en éxito, 1 en error
load_artifacts() {
  local project_dir="$1"
  local bootstrap_dir="$2"
  local profile="$3"

  local registry_path="${bootstrap_dir}/agents-registry.json"

  echo -e "${_LA_BOLD}${_LA_BLUE}▶ Cargando artefactos para perfil: ${profile}${_LA_NC}"
  echo ""

  # Validar argumentos
  if [[ -z "$project_dir" || -z "$bootstrap_dir" || -z "$profile" ]]; then
    echo -e "${_LA_RED}Error: Se requieren 3 argumentos: project_dir, bootstrap_dir, profile${_LA_NC}" >&2
    return 1
  fi

  if [[ ! -f "$registry_path" ]]; then
    echo -e "${_LA_RED}Error: Registro de agentes no encontrado: ${registry_path}${_LA_NC}" >&2
    return 1
  fi

  # Crear directorios destino si no existen
  mkdir -p "${project_dir}/.kiro/agents"
  mkdir -p "${project_dir}/.kiro/steering"
  mkdir -p "${project_dir}/.kiro/skills"
  mkdir -p "${project_dir}/.kiro/hooks"

  # Reset contadores
  _LA_NEW=0
  _LA_UNCHANGED=0
  _LA_MODIFIED=0
  _LA_SKIPPED=0

  # --- 1. Filtrar y copiar agentes por perfil (Req 2.4, 5.4) ---
  echo -e "  ${_LA_BOLD}Agentes:${_LA_NC}"
  local agents
  agents=$(filter_agents_by_profile "$registry_path" "$profile")
  if [[ $? -ne 0 || -z "$agents" ]]; then
    echo -e "    ${_LA_YELLOW}No se encontraron agentes para el perfil '${profile}'${_LA_NC}"
  else
    # Track steering files and skills to avoid duplicates (bash 3.x compatible)
    local seen_steering=""
    local seen_skills=""

    while IFS= read -r agent_name; do
      [[ -z "$agent_name" ]] && continue

      # Get agent file path
      local agent_file
      agent_file=$(get_agent_field "$registry_path" "$agent_name" "file") || true
      if [[ -n "$agent_file" ]]; then
        local source_agent="${bootstrap_dir}/${agent_file}"
        local dest_agent="${project_dir}/.kiro/agents/$(basename "$agent_file")"
        copy_artifact "$source_agent" "$dest_agent"
      fi

      # --- 2. Collect steering files del agente (Req 7.1) ---
      local steering_files
      steering_files=$(get_agent_array_field "$registry_path" "$agent_name" "steeringFiles" 2>/dev/null) || true
      if [[ -n "$steering_files" ]]; then
        while IFS= read -r sf; do
          [[ -z "$sf" ]] && continue
          # Skip if already seen
          if echo "$seen_steering" | grep -qxF "$sf" 2>/dev/null; then
            continue
          fi
          seen_steering="${seen_steering}${sf}"$'\n'
        done <<< "$steering_files"
      fi

      # --- 3. Collect skills del agente (Req 7.2) ---
      local skills
      skills=$(get_agent_array_field "$registry_path" "$agent_name" "skills" 2>/dev/null) || true
      if [[ -n "$skills" ]]; then
        while IFS= read -r skill; do
          [[ -z "$skill" ]] && continue
          if echo "$seen_skills" | grep -qxF "$skill" 2>/dev/null; then
            continue
          fi
          seen_skills="${seen_skills}${skill}"$'\n'
        done <<< "$skills"
      fi
    done <<< "$agents"

    # --- Copy collected steering files ---
    echo ""
    echo -e "  ${_LA_BOLD}Steering files:${_LA_NC}"
    if [[ -n "$seen_steering" ]]; then
      while IFS= read -r sf; do
        [[ -z "$sf" ]] && continue
        local source_sf="${bootstrap_dir}/${sf}"
        local dest_sf="${project_dir}/.kiro/steering/$(basename "$sf")"
        copy_artifact "$source_sf" "$dest_sf"
      done <<< "$seen_steering"
    fi

    # --- 4. Copy global steering files (Req 7.4) ---
    local global_files
    global_files=$(get_global_steering_files "$registry_path") || true
    if [[ -n "$global_files" ]]; then
      while IFS= read -r gf; do
        [[ -z "$gf" ]] && continue
        # Skip if already copied from agent steering
        if echo "$seen_steering" | grep -qxF "$gf" 2>/dev/null; then
          continue
        fi
        seen_steering="${seen_steering}${gf}"$'\n'
        local source_gf="${bootstrap_dir}/${gf}"
        local dest_gf="${project_dir}/.kiro/steering/$(basename "$gf")"
        copy_artifact "$source_gf" "$dest_gf"
      done <<< "$global_files"
    fi

    # --- 5. Copy collected skills (Req 7.2) ---
    echo ""
    echo -e "  ${_LA_BOLD}Skills:${_LA_NC}"
    if [[ -n "$seen_skills" ]]; then
      while IFS= read -r skill; do
        [[ -z "$skill" ]] && continue
        local source_skill="${bootstrap_dir}/${skill}"
        local dest_skill="${project_dir}/.kiro/skills/$(basename "$skill")"
        copy_artifact "$source_skill" "$dest_skill"
      done <<< "$seen_skills"
    else
      echo -e "    ${_LA_BLUE}(ninguna)${_LA_NC}"
    fi
  fi

  # --- 6. Copy hooks for the profile (Req 7.3) ---
  echo ""
  echo -e "  ${_LA_BOLD}Hooks:${_LA_NC}"
  local hooks_dir="${bootstrap_dir}/hooks"
  if [[ -d "$hooks_dir" ]]; then
    local hook_count=0
    for hook_file in "${hooks_dir}"/*.kiro.hook; do
      [[ ! -f "$hook_file" ]] && continue
      local hook_basename
      hook_basename=$(basename "$hook_file")
      # Skip the bootstrap-init hook (it's a global/installer hook, not per-profile)
      if [[ "$hook_basename" == "bootstrap-init.kiro.hook" ]]; then
        continue
      fi
      local dest_hook="${project_dir}/.kiro/hooks/${hook_basename}"
      copy_artifact "$hook_file" "$dest_hook"
      ((hook_count++))
    done
    if [[ $hook_count -eq 0 ]]; then
      echo -e "    ${_LA_BLUE}(ninguno para este perfil)${_LA_NC}"
    fi
  else
    echo -e "    ${_LA_BLUE}(directorio de hooks no encontrado)${_LA_NC}"
  fi

  # --- 7. Instalar extensiones del perfil ---
  echo ""
  echo -e "  ${_LA_BOLD}Extensiones:${_LA_NC}"
  local ext_script="${bootstrap_dir}/lib/install-extensions.sh"
  if [[ -f "$ext_script" ]]; then
    source "$ext_script"
    install_extensions "$bootstrap_dir" "$profile"
  else
    echo -e "    ${_LA_BLUE}(script de extensiones no encontrado)${_LA_NC}"
  fi

  # --- Resumen ---
  echo ""
  echo -e "${_LA_BOLD}────────────────────────────────────────────────────${_LA_NC}"
  echo -e "  Resumen de carga: ${_LA_GREEN}${_LA_NEW} nuevos${_LA_NC}, ${_LA_BLUE}${_LA_UNCHANGED} sin cambios${_LA_NC}, ${_LA_YELLOW}${_LA_MODIFIED} modificados${_LA_NC}, ${_LA_YELLOW}${_LA_SKIPPED} omitidos${_LA_NC}"
  echo -e "${_LA_BOLD}────────────────────────────────────────────────────${_LA_NC}"

  return 0
}
