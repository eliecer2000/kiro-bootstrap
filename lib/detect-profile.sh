#!/usr/bin/env bash
# =============================================================================
# Kiro Bootstrap - Detección de Perfil de Proyecto
# Escala 24x7
#
# Script sourceable que provee funciones para detectar el perfil de un proyecto
# basándose en archivos indicadores del directorio raíz.
#
# Uso:
#   source lib/detect-profile.sh
#   detect_profiles "/path/to/project"
#   detect_single_profile "/path/to/project"
#
# Perfiles soportados (por prioridad):
#   1. frontend-nuxt             - nuxt.config.ts + dep nuxt
#   2. infraestructura-terraform - *.tf + backend.tf
#   3. backend-lambda            - @aws-sdk/* sin nuxt.config.ts
#   4. backend-python            - pyproject.toml o requirements.txt
# =============================================================================

# --- Orden de prioridad de perfiles ---
readonly PROFILE_PRIORITY=(
  "frontend-nuxt"
  "infraestructura-terraform"
  "backend-lambda"
  "backend-python"
)

# =============================================================================
# Funciones auxiliares
# =============================================================================

# Verifica si package.json contiene una dependencia (en dependencies o devDependencies).
# Soporta wildcards simples con * al final (ej: @aws-sdk/*).
# Usa grep para parseo, sin dependencia de jq.
#
# Args:
#   $1 - Ruta al directorio del proyecto
#   $2 - Nombre de la dependencia (puede terminar en /*)
# Returns:
#   0 si la dependencia existe, 1 si no
_has_package_dependency() {
  local project_dir="$1"
  local dep_name="$2"
  local pkg_file="${project_dir}/package.json"

  if [[ ! -f "$pkg_file" ]]; then
    return 1
  fi

  # Si el nombre termina en /*, buscar como prefijo
  if [[ "$dep_name" == *'/*' ]]; then
    local prefix="${dep_name%/\*}"
    grep -q "\"${prefix}/" "$pkg_file" 2>/dev/null
    return $?
  fi

  # Buscar dependencia exacta como clave JSON
  grep -q "\"${dep_name}\"" "$pkg_file" 2>/dev/null
  return $?
}

# =============================================================================
# Funciones de detección por perfil
# =============================================================================

# Detecta perfil frontend-nuxt.
# Requiere: nuxt.config.ts existe Y package.json contiene dependencia "nuxt"
#
# Args:
#   $1 - Ruta al directorio del proyecto
# Returns:
#   0 si el perfil aplica, 1 si no
check_frontend_nuxt() {
  local project_dir="$1"

  # Verificar que nuxt.config.ts existe
  if [[ ! -f "${project_dir}/nuxt.config.ts" ]]; then
    return 1
  fi

  # Verificar que package.json contiene dependencia nuxt
  _has_package_dependency "$project_dir" "nuxt"
  return $?
}

# Detecta perfil infraestructura-terraform.
# Requiere: backend.tf existe Y hay archivos *.tf en el directorio
#
# Args:
#   $1 - Ruta al directorio del proyecto
# Returns:
#   0 si el perfil aplica, 1 si no
check_infraestructura_terraform() {
  local project_dir="$1"

  # Verificar que backend.tf existe
  if [[ ! -f "${project_dir}/backend.tf" ]]; then
    return 1
  fi

  # Verificar que hay archivos *.tf (al menos uno además de backend.tf)
  local tf_count
  tf_count=$(find "$project_dir" -maxdepth 1 -name '*.tf' -type f 2>/dev/null | wc -l)

  if [[ "$tf_count" -gt 0 ]]; then
    return 0
  fi

  return 1
}

# Detecta perfil backend-lambda.
# Requiere: package.json contiene dependencia @aws-sdk/* Y nuxt.config.ts NO existe
#
# Args:
#   $1 - Ruta al directorio del proyecto
# Returns:
#   0 si el perfil aplica, 1 si no
check_backend_lambda() {
  local project_dir="$1"

  # Excluir si nuxt.config.ts existe
  if [[ -f "${project_dir}/nuxt.config.ts" ]]; then
    return 1
  fi

  # Verificar que package.json contiene dependencia @aws-sdk/*
  _has_package_dependency "$project_dir" "@aws-sdk/*"
  return $?
}

# Detecta perfil backend-python.
# Requiere: pyproject.toml O requirements.txt existe
#
# Args:
#   $1 - Ruta al directorio del proyecto
# Returns:
#   0 si el perfil aplica, 1 si no
check_backend_python() {
  local project_dir="$1"

  if [[ -f "${project_dir}/pyproject.toml" ]]; then
    return 0
  fi

  if [[ -f "${project_dir}/requirements.txt" ]]; then
    return 0
  fi

  return 1
}

# =============================================================================
# Funciones principales
# =============================================================================

# Detecta todos los perfiles aplicables a un directorio de proyecto.
# Evalúa todos los perfiles en orden de prioridad y retorna todos los que aplican.
# Soporta monorepos donde múltiples perfiles pueden coexistir.
#
# Args:
#   $1 - Ruta al directorio del proyecto
# Output:
#   Imprime un perfil por línea a stdout
# Returns:
#   0 si al menos un perfil fue detectado, 1 si ninguno
detect_profiles() {
  local project_dir="$1"
  local found=false

  if [[ ! -d "$project_dir" ]]; then
    return 1
  fi

  for profile in "${PROFILE_PRIORITY[@]}"; do
    local check_fn="check_${profile//-/_}"

    if "$check_fn" "$project_dir" 2>/dev/null; then
      echo "$profile"
      found=true
    fi
  done

  if [[ "$found" == true ]]; then
    return 0
  fi

  return 1
}

# Detecta el perfil de mayor prioridad para un directorio de proyecto.
# Retorna solo el primer perfil que coincida según el orden de prioridad.
#
# Args:
#   $1 - Ruta al directorio del proyecto
# Output:
#   Imprime el nombre del perfil a stdout
# Returns:
#   0 si un perfil fue detectado, 1 si ninguno
detect_single_profile() {
  local project_dir="$1"

  if [[ ! -d "$project_dir" ]]; then
    return 1
  fi

  for profile in "${PROFILE_PRIORITY[@]}"; do
    local check_fn="check_${profile//-/_}"

    if "$check_fn" "$project_dir" 2>/dev/null; then
      echo "$profile"
      return 0
    fi
  done

  return 1
}
