#!/usr/bin/env bash
# =============================================================================
# install-extensions.sh — Instalación de extensiones de Kiro
#
# Instala extensiones desde archivos JSON del directorio extensions/.
# Cada archivo contiene un array "recommendations" con IDs de extensiones.
#
# Uso:
#   source lib/install-extensions.sh
#   install_extensions "/ruta/al/repo" "frontend-nuxt"
# =============================================================================

# Detectar el ejecutable CLI de Kiro
detect_kiro_cli() {
  # Kiro usa el mismo patrón que VS Code para su CLI
  local kiro_bin=""

  # macOS: buscar en Applications
  if [[ -f "/Applications/Kiro.app/Contents/Resources/app/bin/kiro" ]]; then
    kiro_bin="/Applications/Kiro.app/Contents/Resources/app/bin/kiro"
  elif command -v kiro &>/dev/null; then
    kiro_bin="kiro"
  fi

  echo "$kiro_bin"
}

# Extraer IDs de extensiones de un archivo JSON
# Usa grep puro, sin jq
parse_extension_ids() {
  local json_file="$1"

  if [[ ! -f "$json_file" ]]; then
    return 0
  fi

  # Extraer valores del array "recommendations"
  grep -o '"[a-zA-Z0-9_-]*\.[a-zA-Z0-9._-]*"' "$json_file" | tr -d '"' | grep '\.'
}

# Instalar extensiones desde un archivo JSON
install_extensions_from_file() {
  local kiro_cli="$1"
  local json_file="$2"
  local installed=0
  local skipped=0

  local ext_ids
  ext_ids=$(parse_extension_ids "$json_file")

  if [[ -z "$ext_ids" ]]; then
    return 0
  fi

  while IFS= read -r ext_id; do
    # Verificar si ya está instalada (buscar en directorio de extensiones)
    local ext_dir="$HOME/.kiro/extensions"
    if ls "$ext_dir"/${ext_id}-* &>/dev/null 2>&1; then
      skipped=$((skipped + 1))
      continue
    fi

    # Instalar vía CLI
    if "$kiro_cli" --install-extension "$ext_id" --force &>/dev/null 2>&1; then
      installed=$((installed + 1))
      echo "    + Instalada: ${ext_id}"
    else
      echo "    ⚠ No se pudo instalar: ${ext_id}"
    fi
  done <<< "$ext_ids"

  echo "    Resultado: ${installed} nuevas, ${skipped} ya instaladas"
}

# Función principal: instalar extensiones base + perfil
install_extensions() {
  local repo_dir="$1"
  local profile="$2"
  local extensions_dir="${repo_dir}/extensions"

  # Detectar CLI
  local kiro_cli
  kiro_cli=$(detect_kiro_cli)

  if [[ -z "$kiro_cli" ]]; then
    echo "  ⚠ CLI de Kiro no encontrada. Extensiones no instaladas automáticamente."
    echo "    Para instalar manualmente, abrir Kiro y buscar las extensiones en:"
    echo "    ${extensions_dir}/base.json"
    if [[ -n "$profile" && -f "${extensions_dir}/${profile}.json" ]]; then
      echo "    ${extensions_dir}/${profile}.json"
    fi
    return 0
  fi

  echo "  Instalando extensiones base..."
  if [[ -f "${extensions_dir}/base.json" ]]; then
    install_extensions_from_file "$kiro_cli" "${extensions_dir}/base.json"
  fi

  if [[ -n "$profile" && -f "${extensions_dir}/${profile}.json" ]]; then
    echo "  Instalando extensiones del perfil ${profile}..."
    install_extensions_from_file "$kiro_cli" "${extensions_dir}/${profile}.json"
  fi
}
