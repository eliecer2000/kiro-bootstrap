#!/usr/bin/env bash

_IE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_IE_BOOTSTRAP_DIR="$(cd "${_IE_SCRIPT_DIR}/.." && pwd)"

_ie_catalog() {
  python3 "${_IE_BOOTSTRAP_DIR}/lib/orbit_catalog.py" --bootstrap-dir "${_IE_BOOTSTRAP_DIR}" "$@"
}

detect_kiro_cli() {
  if [[ -f "/Applications/Kiro.app/Contents/Resources/app/bin/kiro" ]]; then
    echo "/Applications/Kiro.app/Contents/Resources/app/bin/kiro"
    return 0
  fi
  if command -v kiro >/dev/null 2>&1; then
    echo "kiro"
    return 0
  fi
  echo ""
}

parse_extension_ids() {
  local json_file="$1"
  python3 - "$json_file" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
if not path.exists():
    raise SystemExit(0)
data = json.loads(path.read_text())
for item in data.get("recommendations", []):
    print(item)
PY
}

profile_extension_packs() {
  local profile_id="$1"
  _ie_catalog profile-field --profile-id "$profile_id" --field extensionPacks
}

install_extensions_from_file() {
  local kiro_cli="$1"
  local json_file="$2"
  local installed=0
  local skipped=0
  local ext_dir="$HOME/.kiro/extensions"
  local ext_id

  while IFS= read -r ext_id; do
    [[ -z "$ext_id" ]] && continue
    if [[ -d "$ext_dir" ]] && ls "$ext_dir"/${ext_id}-* >/dev/null 2>&1; then
      skipped=$((skipped + 1))
      continue
    fi
    if [[ -n "${ORBIT_DRY_RUN_EXTENSIONS:-}" ]]; then
      echo "    + Dry-run: ${ext_id}"
      installed=$((installed + 1))
      continue
    fi
    if "$kiro_cli" --install-extension "$ext_id" --force >/dev/null 2>&1; then
      echo "    + Instalada: ${ext_id}"
      installed=$((installed + 1))
    else
      echo "    ! No se pudo instalar: ${ext_id}"
    fi
  done < <(parse_extension_ids "$json_file")

  echo "    Resultado: ${installed} nuevas, ${skipped} ya instaladas"
}

install_extensions() {
  local repo_dir="$1"
  local profile_id="${2:-}"
  local extensions_dir="${repo_dir}/extensions"
  local kiro_cli

  kiro_cli="$(detect_kiro_cli)"
  if [[ -z "$kiro_cli" ]]; then
    echo "  ! CLI de Kiro no encontrada. Revisa manualmente las recomendaciones de extensiones."
    return 0
  fi

  if [[ -f "${extensions_dir}/base.json" ]]; then
    echo "  Instalando extensiones base..."
    install_extensions_from_file "$kiro_cli" "${extensions_dir}/base.json"
  fi

  if [[ -n "$profile_id" ]]; then
    local pack
    while IFS= read -r pack; do
      [[ -z "$pack" ]] && continue
      if [[ -f "${extensions_dir}/${pack}.json" ]]; then
        echo "  Instalando pack de extensiones ${pack}..."
        install_extensions_from_file "$kiro_cli" "${extensions_dir}/${pack}.json"
      fi
    done < <(profile_extension_packs "$profile_id")
  fi
}
