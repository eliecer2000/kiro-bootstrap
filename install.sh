#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

KIRO_BOOTSTRAP_REPO="${KIRO_BOOTSTRAP_REPO:-https://github.com/eliecer2000/kiro-bootstrap.git}"
KIRO_BOOTSTRAP_BRANCH="${KIRO_BOOTSTRAP_BRANCH:-main}"
INSTALL_DIR="${ORBIT_INSTALL_DIR:-$HOME/.kiro/orbit}"

UPDATE_MODE=false
SHOW_HELP=false
RESYNC_PROJECT_DIR=""

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_help() {
  cat <<'EOF'
Orbit Bootstrap

Uso:
  curl -sL <repo>/install.sh | bash
  ~/.kiro/orbit/install.sh --update
  ~/.kiro/orbit/install.sh --resync-project [ruta]
  ~/.kiro/orbit/install.sh --help

Opciones:
  --update                 Actualiza el repositorio central de Orbit.
  --resync-project [ruta]  Re-ejecuta el bootstrap del proyecto actual o de la ruta indicada.
  --help                   Muestra esta ayuda.

Variables de entorno:
  KIRO_BOOTSTRAP_REPO      Repositorio Git a clonar.
  KIRO_BOOTSTRAP_BRANCH    Rama a instalar o actualizar.
  ORBIT_INSTALL_DIR        Directorio local de instalacion (default: ~/.kiro/orbit).
  ORBIT_PROJECT_PROFILE_ID Fuerza el perfil de proyecto resuelto durante bootstrap o resincronizacion.
  ORBIT_PROFILE_ID         Alias legado de ORBIT_PROJECT_PROFILE_ID.
  ORBIT_BOOTSTRAP_DECISION Responde bootstrap sin prompt (`yes` o `no`).
  ORBIT_HOME_DECISION      Responde el prompt HOME sin interaccion (`yes` o `no`).
  ORBIT_PROJECT_NAME       Nombre de carpeta a crear cuando se arranca desde HOME.
  ORBIT_WORKLOAD           Respuesta del wizard para workload.
  ORBIT_RUNTIME            Respuesta del wizard para runtime.
  ORBIT_PROVISIONER        Respuesta del wizard para provisioner.
  ORBIT_FRAMEWORK          Respuesta del wizard para framework.
  ORBIT_REMOTE_SKILL_DECISION  Decision por defecto para remote skills (`yes` o `no`).
  ORBIT_VALIDATE_AWS_IDENTITY  Valida credenciales AWS solo cuando vale `yes`.
EOF
}

check_os() {
  local os_name
  os_name="$(uname -s)"
  case "$os_name" in
    Darwin|Linux)
      log_success "Sistema operativo soportado: ${os_name}"
      ;;
    *)
      log_error "Sistema operativo no soportado: ${os_name}. Solo macOS y Linux son compatibles."
      exit 2
      ;;
  esac
}

check_dependencies() {
  local missing=()
  local tool
  for tool in git curl python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    for tool in "${missing[@]}"; do
      log_error "${tool} es requerido pero no se encontro en el PATH."
    done
    exit 3
  fi

  log_success "Dependencias verificadas: git, curl, python3"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --update)
        UPDATE_MODE=true
        shift
        ;;
      --help|-h)
        SHOW_HELP=true
        shift
        ;;
      --resync-project)
        if [[ $# -gt 1 && "${2:-}" != --* ]]; then
          RESYNC_PROJECT_DIR="$2"
          shift 2
        else
          RESYNC_PROJECT_DIR="$PWD"
          shift
        fi
        ;;
      *)
        log_error "Argumento desconocido: $1"
        exit 1
        ;;
    esac
  done
}

backup_existing_installation() {
  if [[ -d "$INSTALL_DIR" ]] && [[ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]]; then
    local backup_dir
    backup_dir="${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Instalacion previa detectada en ${INSTALL_DIR}"
    log_info "Creando respaldo en ${backup_dir}..."
    cp -R "$INSTALL_DIR" "$backup_dir"
    log_success "Respaldo creado en ${backup_dir}"
  fi
}

clone_or_update_repo() {
  local git_exit_code=0

  if [[ "$UPDATE_MODE" == true ]]; then
    if [[ ! -d "$INSTALL_DIR/.git" ]]; then
      log_error "No se encontro una instalacion previa en ${INSTALL_DIR}. Ejecuta primero la instalacion inicial."
      exit 4
    fi

    log_info "Actualizando repositorio central..."
    git -C "$INSTALL_DIR" pull origin "$KIRO_BOOTSTRAP_BRANCH" >/dev/null 2>&1 || git_exit_code=$?
    if [[ $git_exit_code -ne 0 ]]; then
      log_error "No se pudo actualizar el repositorio central."
      exit 4
    fi
    log_success "Repositorio actualizado correctamente"
  else
    log_info "Clonando repositorio central..."
    git clone --branch "$KIRO_BOOTSTRAP_BRANCH" --single-branch "$KIRO_BOOTSTRAP_REPO" "$INSTALL_DIR" >/dev/null 2>&1 || git_exit_code=$?
    if [[ $git_exit_code -ne 0 ]]; then
      log_error "No se pudo clonar el repositorio central desde ${KIRO_BOOTSTRAP_REPO}."
      exit 4
    fi
    log_success "Repositorio clonado correctamente en ${INSTALL_DIR}"
  fi
}

read_manifest_version() {
  python3 - "$INSTALL_DIR/manifest.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
if not path.exists():
    print("unknown")
    raise SystemExit(0)
print(json.loads(path.read_text()).get("version", "unknown"))
PY
}

count_registered_agents() {
  python3 - "$INSTALL_DIR/agents-registry.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
if not path.exists():
    print(0)
    raise SystemExit(0)
data = json.loads(path.read_text())
print(len(data.get("agents", {})))
PY
}

write_bootstrap_version() {
  local commit_hash version installed_at version_file
  commit_hash="$(git -C "$INSTALL_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
  version="$(read_manifest_version)"
  installed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  version_file="$HOME/.kiro/.orbit-version"

  mkdir -p "$HOME/.kiro"
  python3 - "$version_file" "$commit_hash" "$installed_at" "$version" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
payload = {
    "commitHash": sys.argv[2],
    "installedAt": sys.argv[3],
    "version": sys.argv[4],
}
path.write_text(json.dumps(payload, indent=2) + "\n")
PY
  log_success "Version registrada en ${version_file}"
}

install_base_artifacts() {
  log_info "Instalando artefactos base en ~/.kiro/..."

  mkdir -p "$HOME/.kiro/agents" "$HOME/.kiro/steering" "$HOME/.kiro/hooks"

  cp "$INSTALL_DIR/agents/orbit.json" "$HOME/.kiro/agents/"
  cp "$INSTALL_DIR/steering/orbit-session.md" "$HOME/.kiro/steering/"
  cp "$INSTALL_DIR/hooks/orbit-session.kiro.hook" "$HOME/.kiro/hooks/"

  write_bootstrap_version

  if [[ -f "$INSTALL_DIR/lib/install-extensions.sh" ]]; then
    # shellcheck disable=SC1090
    source "$INSTALL_DIR/lib/install-extensions.sh"
    log_info "Instalando extensiones base recomendadas..."
    install_extensions "$INSTALL_DIR" ""
  fi

  echo ""
  echo -e "${BOLD}============================================${NC}"
  echo -e "${BOLD}  Resumen de Instalacion Orbit${NC}"
  echo -e "${BOLD}============================================${NC}"
  echo -e "  Version instalada:   ${GREEN}$(read_manifest_version)${NC}"
  echo -e "  Agentes registrados: ${GREEN}$(count_registered_agents)${NC}"
  echo -e "  Ruta de instalacion: ${GREEN}${INSTALL_DIR}${NC}"
  echo -e "${BOLD}============================================${NC}"
  echo ""
  log_success "Instalacion completada exitosamente"
}

check_update_needed() {
  local version_file="$HOME/.kiro/.orbit-version"
  local local_hash remote_hash

  local_hash="$(python3 - "$version_file" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
if not path.exists():
    print("")
    raise SystemExit(0)
print(json.loads(path.read_text()).get("commitHash", ""))
PY
)"

  if [[ -z "$local_hash" || "$local_hash" == "unknown" ]]; then
    log_warn "No se encontro una version local registrada. Ejecutando actualizacion completa..."
    return 0
  fi

  log_info "Verificando version remota..."
  git -C "$INSTALL_DIR" fetch origin "$KIRO_BOOTSTRAP_BRANCH" >/dev/null 2>&1 || {
    log_error "No se pudo consultar la version remota."
    exit 4
  }

  remote_hash="$(git -C "$INSTALL_DIR" rev-parse "origin/${KIRO_BOOTSTRAP_BRANCH}" 2>/dev/null || echo "")"
  if [[ -z "$remote_hash" ]]; then
    log_warn "No se pudo obtener la version remota. Ejecutando actualizacion completa..."
    return 0
  fi

  if [[ "$local_hash" == "$remote_hash" ]]; then
    log_success "Orbit ya esta actualizado (${local_hash:0:12})"
    exit 0
  fi

  log_info "Nueva version disponible. Actualizando..."
}

resync_project_artifacts() {
  local project_dir="$1"
  if [[ -z "$project_dir" ]]; then
    project_dir="$PWD"
  fi
  if [[ ! -d "$project_dir" ]]; then
    log_error "La ruta de proyecto no existe: ${project_dir}"
    exit 1
  fi
  if [[ ! -d "$INSTALL_DIR" ]]; then
    log_error "Orbit no esta instalado en ${INSTALL_DIR}. Ejecuta primero la instalacion inicial."
    exit 1
  fi

  log_info "Resincronizando artefactos del proyecto en ${project_dir}"
  export ORBIT_SYNC_MODE="resync"
  # shellcheck disable=SC1090
  source "$INSTALL_DIR/lib/session.sh"
  # shellcheck disable=SC1090
  source "$INSTALL_DIR/lib/pipeline.sh"
  execute_pipeline "$INSTALL_DIR/manifest.json" "$project_dir" "$INSTALL_DIR"
}

main() {
  parse_args "$@"

  if [[ "$SHOW_HELP" == true ]]; then
    print_help
    return 0
  fi

  echo -e "${BOLD}Orbit Bootstrap${NC}"
  echo "============================================"

  check_os
  check_dependencies

  if [[ -n "$RESYNC_PROJECT_DIR" ]]; then
    resync_project_artifacts "$RESYNC_PROJECT_DIR"
    return 0
  fi

  if [[ "$UPDATE_MODE" == true ]]; then
    log_info "Modo actualizacion activado"
    check_update_needed
    clone_or_update_repo
    install_base_artifacts
  else
    log_info "Iniciando instalacion..."
    backup_existing_installation
    clone_or_update_repo
    install_base_artifacts
  fi
}

if [[ -z "${BASH_SOURCE[0]-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
