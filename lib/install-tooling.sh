#!/usr/bin/env bash

# install-tooling.sh
# Instala herramientas de desarrollo del proyecto (linters, formatters, test runners)
# según el perfil activo. Distingue entre:
#   - Herramientas de SISTEMA (git, node, python3, aws, terraform): solo valida, no instala.
#   - Herramientas de PROYECTO (eslint, prettier, vitest, ruff, black, pytest, mypy): instala automáticamente.

_IT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_IT_BOOTSTRAP_DIR="$(cd "${_IT_SCRIPT_DIR}/.." && pwd)"

_IT_RED="${_IT_RED:-\033[0;31m}"
_IT_GREEN="${_IT_GREEN:-\033[0;32m}"
_IT_YELLOW="${_IT_YELLOW:-\033[0;33m}"
_IT_BLUE="${_IT_BLUE:-\033[0;34m}"
_IT_BOLD="${_IT_BOLD:-\033[1m}"
_IT_NC="${_IT_NC:-\033[0m}"

_it_catalog() {
  python3 "${_IT_BOOTSTRAP_DIR}/lib/orbit_catalog.py" --bootstrap-dir "${_IT_BOOTSTRAP_DIR}" "$@"
}

# Detecta el package manager de Node.js disponible en el proyecto
detect_node_package_manager() {
  local project_dir="$1"

  if [[ -f "${project_dir}/pnpm-lock.yaml" ]]; then
    if command -v pnpm >/dev/null 2>&1; then
      echo "pnpm"
      return 0
    fi
  fi

  if [[ -f "${project_dir}/yarn.lock" ]]; then
    if command -v yarn >/dev/null 2>&1; then
      echo "yarn"
      return 0
    fi
  fi

  if [[ -f "${project_dir}/bun.lockb" ]] || [[ -f "${project_dir}/bun.lock" ]]; then
    if command -v bun >/dev/null 2>&1; then
      echo "bun"
      return 0
    fi
  fi

  # Default: npm (siempre disponible con Node.js)
  if command -v npm >/dev/null 2>&1; then
    echo "npm"
    return 0
  fi

  echo ""
}

# Detecta el package manager de Python disponible en el proyecto
detect_python_package_manager() {
  local project_dir="$1"

  if [[ -f "${project_dir}/pyproject.toml" ]]; then
    if command -v uv >/dev/null 2>&1; then
      echo "uv"
      return 0
    fi
    if command -v poetry >/dev/null 2>&1; then
      if grep -q '\[tool\.poetry\]' "${project_dir}/pyproject.toml" 2>/dev/null; then
        echo "poetry"
        return 0
      fi
    fi
  fi

  if command -v pip3 >/dev/null 2>&1; then
    echo "pip3"
    return 0
  fi

  if command -v pip >/dev/null 2>&1; then
    echo "pip"
    return 0
  fi

  echo ""
}

# Instala un paquete Node.js como devDependency
install_node_package() {
  local project_dir="$1"
  local pkg_manager="$2"
  local package_name="$3"

  case "$pkg_manager" in
    npm)
      npm install --save-dev "$package_name" --prefix "$project_dir" 2>/dev/null
      ;;
    pnpm)
      pnpm add -D "$package_name" --dir "$project_dir" 2>/dev/null
      ;;
    yarn)
      yarn add -D "$package_name" --cwd "$project_dir" 2>/dev/null
      ;;
    bun)
      bun add -d "$package_name" --cwd "$project_dir" 2>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

# Instala un paquete Python como dependencia de desarrollo
install_python_package() {
  local project_dir="$1"
  local pkg_manager="$2"
  local package_name="$3"

  case "$pkg_manager" in
    uv)
      (cd "$project_dir" && uv add --dev "$package_name" 2>/dev/null)
      ;;
    poetry)
      (cd "$project_dir" && poetry add --group dev "$package_name" 2>/dev/null)
      ;;
    pip3)
      pip3 install "$package_name" 2>/dev/null
      ;;
    pip)
      pip install "$package_name" 2>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

# Verifica si un paquete Node.js ya está instalado en el proyecto
is_node_package_installed() {
  local project_dir="$1"
  local package_name="$2"

  if [[ -f "${project_dir}/node_modules/.package-lock.json" ]] || [[ -d "${project_dir}/node_modules/${package_name}" ]]; then
    return 0
  fi

  # Verificar en package.json
  if [[ -f "${project_dir}/package.json" ]]; then
    if python3 -c "
import json, sys
pkg = json.load(open('${project_dir}/package.json'))
deps = {**pkg.get('dependencies', {}), **pkg.get('devDependencies', {})}
sys.exit(0 if '${package_name}' in deps else 1)
" 2>/dev/null; then
      return 0
    fi
  fi

  return 1
}

# Verifica si un paquete Python ya está instalado
is_python_package_installed() {
  local package_name="$1"
  python3 -c "import importlib; importlib.import_module('${package_name}')" 2>/dev/null
}

# Mapeo de herramientas de tooling a paquetes instalables
get_node_package_name() {
  local tool="$1"
  case "$tool" in
    eslint)       echo "eslint" ;;
    prettier)     echo "prettier" ;;
    vitest)       echo "vitest" ;;
    tsc)          echo "typescript" ;;
    jest)         echo "jest" ;;
    biome)        echo "@biomejs/biome" ;;
    *)            echo "$tool" ;;
  esac
}

get_python_package_name() {
  local tool="$1"
  case "$tool" in
    ruff)         echo "ruff" ;;
    black)        echo "black" ;;
    pytest)       echo "pytest" ;;
    mypy)         echo "mypy" ;;
    flake8)       echo "flake8" ;;
    isort)        echo "isort" ;;
    *)            echo "$tool" ;;
  esac
}

# Instala las herramientas de tooling del perfil
install_profile_tooling() {
  local project_dir="$1"
  local bootstrap_dir="$2"
  local profile_id="$3"
  local runtime tooling_json
  local installed=0
  local skipped=0
  local failed=0

  echo -e "${_IT_BOLD}${_IT_BLUE}▶ Verificando herramientas de desarrollo...${_IT_NC}"
  echo ""

  # Obtener runtime y tooling del perfil
  runtime="$(_it_catalog profile-field --profile-id "$profile_id" --field "dimensions.runtime" 2>/dev/null || echo "none")"
  tooling_json="$(_it_catalog profile-field --profile-id "$profile_id" --field tooling 2>/dev/null || echo "{}")"

  if [[ -z "$tooling_json" || "$tooling_json" == "{}" ]]; then
    echo -e "  ${_IT_YELLOW}! No se encontro configuracion de tooling para el perfil ${profile_id}${_IT_NC}"
    return 0
  fi

  # Extraer listas de herramientas
  local linters formatters tests typecheck
  linters="$(python3 -c "import json,sys; t=json.loads(sys.argv[1]); print(' '.join(t.get('linters',[])))" "$tooling_json" 2>/dev/null || echo "")"
  formatters="$(python3 -c "import json,sys; t=json.loads(sys.argv[1]); print(' '.join(t.get('formatters',[])))" "$tooling_json" 2>/dev/null || echo "")"
  tests="$(python3 -c "import json,sys; t=json.loads(sys.argv[1]); print(' '.join(t.get('tests',[])))" "$tooling_json" 2>/dev/null || echo "")"
  typecheck="$(python3 -c "import json,sys; t=json.loads(sys.argv[1]); print(' '.join(t.get('typecheck',[])))" "$tooling_json" 2>/dev/null || echo "")"

  # Combinar todas las herramientas
  local all_tools=""
  for tool in $linters $formatters $tests $typecheck; do
    all_tools="${all_tools} ${tool}"
  done
  all_tools="$(echo "$all_tools" | xargs)"

  if [[ -z "$all_tools" ]]; then
    echo -e "  ${_IT_GREEN}+ No hay herramientas de proyecto que instalar.${_IT_NC}"
    return 0
  fi

  # Instalar según runtime
  case "$runtime" in
    typescript|javascript)
      local node_pm
      node_pm="$(detect_node_package_manager "$project_dir")"
      if [[ -z "$node_pm" ]]; then
        echo -e "  ${_IT_YELLOW}! No se encontro package manager de Node.js. Instala npm, pnpm o yarn.${_IT_NC}"
        return 0
      fi

      # Verificar que package.json existe, si no, inicializar
      if [[ ! -f "${project_dir}/package.json" ]]; then
        echo -e "  ${_IT_BLUE}  Inicializando package.json...${_IT_NC}"
        case "$node_pm" in
          npm)  (cd "$project_dir" && npm init -y >/dev/null 2>&1) ;;
          pnpm) (cd "$project_dir" && pnpm init >/dev/null 2>&1) ;;
          yarn) (cd "$project_dir" && yarn init -y >/dev/null 2>&1) ;;
          bun)  (cd "$project_dir" && bun init -y >/dev/null 2>&1) ;;
        esac
      fi

      echo -e "  ${_IT_BOLD}Herramientas Node.js (${node_pm}):${_IT_NC}"
      for tool in $all_tools; do
        # Saltar herramientas que no son paquetes npm
        case "$tool" in
          jsdoc|"terraform fmt"|"terraform validate") continue ;;
        esac

        local pkg_name
        pkg_name="$(get_node_package_name "$tool")"

        if is_node_package_installed "$project_dir" "$pkg_name"; then
          echo -e "    ${_IT_BLUE}= ${pkg_name} ya instalado${_IT_NC}"
          skipped=$((skipped + 1))
          continue
        fi

        echo -e "    ${_IT_GREEN}+ Instalando ${pkg_name}...${_IT_NC}"
        if install_node_package "$project_dir" "$node_pm" "$pkg_name"; then
          installed=$((installed + 1))
        else
          echo -e "    ${_IT_YELLOW}! No se pudo instalar ${pkg_name}${_IT_NC}"
          failed=$((failed + 1))
        fi
      done
      ;;

    python)
      local py_pm
      py_pm="$(detect_python_package_manager "$project_dir")"
      if [[ -z "$py_pm" ]]; then
        echo -e "  ${_IT_YELLOW}! No se encontro package manager de Python. Instala pip, uv o poetry.${_IT_NC}"
        return 0
      fi

      echo -e "  ${_IT_BOLD}Herramientas Python (${py_pm}):${_IT_NC}"
      for tool in $all_tools; do
        local pkg_name
        pkg_name="$(get_python_package_name "$tool")"

        if is_python_package_installed "$pkg_name"; then
          echo -e "    ${_IT_BLUE}= ${pkg_name} ya instalado${_IT_NC}"
          skipped=$((skipped + 1))
          continue
        fi

        echo -e "    ${_IT_GREEN}+ Instalando ${pkg_name}...${_IT_NC}"
        if install_python_package "$project_dir" "$py_pm" "$pkg_name"; then
          installed=$((installed + 1))
        else
          echo -e "    ${_IT_YELLOW}! No se pudo instalar ${pkg_name}${_IT_NC}"
          failed=$((failed + 1))
        fi
      done
      ;;

    none|"")
      # Perfiles sin runtime (terraform, etc.) - no instalar tooling de proyecto
      echo -e "  ${_IT_BLUE}= Perfil sin runtime de aplicacion. Tooling de sistema validado en paso anterior.${_IT_NC}"
      return 0
      ;;
  esac

  echo ""
  echo -e "  ${_IT_BOLD}────────────────────────────────────────────${_IT_NC}"
  echo -e "  Tooling: ${_IT_GREEN}${installed} instalados${_IT_NC}, ${_IT_BLUE}${skipped} existentes${_IT_NC}, ${_IT_YELLOW}${failed} fallidos${_IT_NC}"
  echo -e "  ${_IT_BOLD}────────────────────────────────────────────${_IT_NC}"

  return 0
}
