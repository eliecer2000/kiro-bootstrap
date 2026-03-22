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
DOCTOR_MODE=false
STATUS_MODE=false

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
  ~/.kiro/orbit/install.sh --status
  ~/.kiro/orbit/install.sh --doctor
  ~/.kiro/orbit/install.sh --help

Opciones:
  --update                 Actualiza el repositorio central de Orbit.
  --resync-project [ruta]  Re-ejecuta el bootstrap del proyecto actual o de la ruta indicada.
  --status                 Muestra version instalada, perfil activo y artefactos del proyecto.
  --doctor                 Diagnostica problemas en la instalacion y el proyecto actual.
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
      --doctor)
        DOCTOR_MODE=true
        shift
        ;;
      --status)
        STATUS_MODE=true
        shift
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

orbit_status() {
  local version_file="$HOME/.kiro/.orbit-version"
  local project_state=".kiro/.orbit-project.json"

  echo -e "${BOLD}Orbit Status${NC}"
  echo "============================================"

  # Framework installation
  if [[ -d "$INSTALL_DIR" ]]; then
    local fw_version
    fw_version="$(read_manifest_version)"
    local fw_agents
    fw_agents="$(count_registered_agents)"
    echo -e "  Framework:  ${GREEN}instalado${NC}"
    echo -e "  Version:    ${GREEN}${fw_version}${NC}"
    echo -e "  Agentes:    ${GREEN}${fw_agents}${NC}"
    echo -e "  Ruta:       ${INSTALL_DIR}"
  else
    echo -e "  Framework:  ${RED}no instalado${NC}"
    return 0
  fi

  # Version info
  if [[ -f "$version_file" ]]; then
    local installed_at commit_hash
    installed_at="$(python3 -c "import json; print(json.load(open('${version_file}')).get('installedAt','?'))")"
    commit_hash="$(python3 -c "import json; print(json.load(open('${version_file}')).get('commitHash','?')[:12])")"
    echo -e "  Commit:     ${commit_hash}"
    echo -e "  Instalado:  ${installed_at}"
  fi

  echo ""

  # Project state
  if [[ -f "$project_state" ]]; then
    local profile_id last_sync sync_mode
    profile_id="$(python3 -c "import json; print(json.load(open('${project_state}')).get('profileId','?'))")"
    last_sync="$(python3 -c "import json; print(json.load(open('${project_state}')).get('lastSyncAt','?'))")"
    sync_mode="$(python3 -c "import json; print(json.load(open('${project_state}')).get('lastSyncMode','?'))")"
    echo -e "  Proyecto:   ${GREEN}configurado${NC}"
    echo -e "  Perfil:     ${GREEN}${profile_id}${NC}"
    echo -e "  Ultimo sync: ${last_sync} (${sync_mode})"

    local agents_count steering_count skills_count hooks_count
    agents_count="$(python3 -c "import json; print(len(json.load(open('${project_state}')).get('installedPacks',{}).get('agents',[])))")"
    steering_count="$(python3 -c "import json; print(len(json.load(open('${project_state}')).get('installedPacks',{}).get('steering',[])))")"
    skills_count="$(python3 -c "import json; print(len(json.load(open('${project_state}')).get('installedPacks',{}).get('localSkills',[])))")"
    hooks_count="$(python3 -c "import json; print(len(json.load(open('${project_state}')).get('installedPacks',{}).get('hooks',[])))")"
    echo -e "  Artefactos: ${agents_count} agentes, ${steering_count} steering, ${skills_count} skills, ${hooks_count} hooks"
  else
    echo -e "  Proyecto:   ${YELLOW}no configurado (ejecuta --resync-project)${NC}"
  fi
}

orbit_doctor() {
  local checks_pass=0
  local checks_fail=0

  echo -e "${BOLD}Orbit Doctor${NC}"
  echo "============================================"

  # 1. Framework installed
  if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "  ${GREEN}+${NC} Framework instalado en ${INSTALL_DIR}"
    checks_pass=$((checks_pass + 1))
  else
    echo -e "  ${RED}x${NC} Framework no instalado. Ejecuta: curl -sL <repo>/install.sh | bash"
    checks_fail=$((checks_fail + 1))
    echo ""
    echo -e "  Resultado: ${checks_pass} ok, ${checks_fail} problemas"
    return 1
  fi

  # 2. Manifest valid
  if python3 -m json.tool "$INSTALL_DIR/manifest.json" >/dev/null 2>&1; then
    echo -e "  ${GREEN}+${NC} manifest.json valido"
    checks_pass=$((checks_pass + 1))
  else
    echo -e "  ${RED}x${NC} manifest.json invalido o corrupto"
    checks_fail=$((checks_fail + 1))
  fi

  # 3. Registry valid
  if python3 -m json.tool "$INSTALL_DIR/agents-registry.json" >/dev/null 2>&1; then
    echo -e "  ${GREEN}+${NC} agents-registry.json valido"
    checks_pass=$((checks_pass + 1))
  else
    echo -e "  ${RED}x${NC} agents-registry.json invalido o corrupto"
    checks_fail=$((checks_fail + 1))
  fi

  # 4. Catalog validation
  if python3 "$INSTALL_DIR/lib/orbit_catalog.py" --bootstrap-dir "$INSTALL_DIR" validate-catalog >/dev/null 2>&1; then
    echo -e "  ${GREEN}+${NC} Catalogo consistente"
    checks_pass=$((checks_pass + 1))
  else
    echo -e "  ${RED}x${NC} Catalogo inconsistente. Ejecuta: python3 ${INSTALL_DIR}/lib/orbit_catalog.py --bootstrap-dir ${INSTALL_DIR} validate-catalog"
    checks_fail=$((checks_fail + 1))
  fi

  # 5. Base artifacts in ~/.kiro
  local base_ok=true
  for f in "$HOME/.kiro/agents/orbit.json" "$HOME/.kiro/steering/orbit-session.md" "$HOME/.kiro/hooks/orbit-session.kiro.hook"; do
    if [[ ! -f "$f" ]]; then
      echo -e "  ${RED}x${NC} Falta artefacto base: ${f}"
      checks_fail=$((checks_fail + 1))
      base_ok=false
    fi
  done
  if [[ "$base_ok" == true ]]; then
    echo -e "  ${GREEN}+${NC} Artefactos base presentes en ~/.kiro"
    checks_pass=$((checks_pass + 1))
  fi

  # 6. System tools
  local tools_ok=true
  for tool in git python3 curl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo -e "  ${RED}x${NC} Herramienta faltante: ${tool}"
      checks_fail=$((checks_fail + 1))
      tools_ok=false
    fi
  done
  if [[ "$tools_ok" == true ]]; then
    echo -e "  ${GREEN}+${NC} Herramientas de sistema disponibles (git, python3, curl)"
    checks_pass=$((checks_pass + 1))
  fi

  # 7. Project state (if in a project)
  if [[ -f ".kiro/.orbit-project.json" ]]; then
    if python3 -m json.tool ".kiro/.orbit-project.json" >/dev/null 2>&1; then
      echo -e "  ${GREEN}+${NC} Estado del proyecto valido"
      checks_pass=$((checks_pass + 1))
    else
      echo -e "  ${RED}x${NC} .kiro/.orbit-project.json corrupto"
      checks_fail=$((checks_fail + 1))
    fi

    # Check project artifacts
    local dirs_ok=true
    for d in .kiro/agents .kiro/steering .kiro/skills .kiro/hooks; do
      if [[ ! -d "$d" ]]; then
        echo -e "  ${RED}x${NC} Directorio faltante: ${d}"
        checks_fail=$((checks_fail + 1))
        dirs_ok=false
      fi
    done
    if [[ "$dirs_ok" == true ]]; then
      echo -e "  ${GREEN}+${NC} Directorios de proyecto completos"
      checks_pass=$((checks_pass + 1))
    fi
  else
    echo -e "  ${YELLOW}~${NC} No hay proyecto Orbit en el directorio actual"
  fi

  # 8. Version file
  if [[ -f "$HOME/.kiro/.orbit-version" ]]; then
    echo -e "  ${GREEN}+${NC} Archivo de version presente"
    checks_pass=$((checks_pass + 1))
  else
    echo -e "  ${YELLOW}~${NC} Sin archivo de version (instalacion antigua?)"
  fi

  echo ""
  if [[ $checks_fail -eq 0 ]]; then
    echo -e "  ${GREEN}Todo en orden: ${checks_pass} verificaciones pasaron${NC}"
  else
    echo -e "  Resultado: ${GREEN}${checks_pass} ok${NC}, ${RED}${checks_fail} problemas${NC}"
  fi

  [[ $checks_fail -eq 0 ]]
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

  if [[ "$STATUS_MODE" == true ]]; then
    orbit_status
    return 0
  fi

  if [[ "$DOCTOR_MODE" == true ]]; then
    orbit_doctor
    return $?
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
