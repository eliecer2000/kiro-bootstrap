#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Kiro Bootstrap - Instalador
# Escala 24x7
#
# Uso:
#   curl -sL <bitbucket-url>/install.sh | bash   # Instalación inicial
#   ~/.kiro/install.sh --update                   # Actualización
#
# Variables de entorno opcionales:
#   KIRO_BOOTSTRAP_REPO    - URL del repositorio (default: Bitbucket Escala 24x7)
#   KIRO_BOOTSTRAP_BRANCH  - Rama a usar (default: main)
#
# Códigos de salida:
#   0 - Instalación exitosa
#   1 - Error general
#   2 - Sistema operativo no soportado
#   3 - Dependencia faltante (git/curl)
#   4 - Error de red/descarga
# =============================================================================

# --- Colores y formato ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # Sin color

# --- Variables por defecto ---
KIRO_BOOTSTRAP_REPO="${KIRO_BOOTSTRAP_REPO:-https://github.com/eliecer2000/kiro-bootstrap.git}"
KIRO_BOOTSTRAP_BRANCH="${KIRO_BOOTSTRAP_BRANCH:-main}"
INSTALL_DIR="$HOME/.kiro/kiro-bootstrap"

# --- Flags ---
UPDATE_MODE=false

# =============================================================================
# Funciones de utilidad
# =============================================================================

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Validación de prerrequisitos
# =============================================================================

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

  if ! command -v git &>/dev/null; then
    missing+=("git")
  fi

  if ! command -v curl &>/dev/null; then
    missing+=("curl")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    for tool in "${missing[@]}"; do
      log_error "${tool} es requerido pero no se encontró en el PATH. Instalar con: brew install ${tool} (macOS) o sudo apt install ${tool} (Linux)"
    done
    exit 3
  fi

  log_success "Dependencias verificadas: git, curl"
}

# =============================================================================
# Parseo de argumentos
# =============================================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --update)
        UPDATE_MODE=true
        shift
        ;;
      *)
        log_error "Argumento desconocido: $1"
        exit 1
        ;;
    esac
  done
}

# =============================================================================
# Respaldo de instalación previa
# =============================================================================

backup_existing_installation() {
  # Solo respaldar si el directorio existe y no está vacío
  if [[ -d "$INSTALL_DIR" ]] && [[ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]]; then
    local backup_dir="${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"

    log_info "Instalación previa detectada en ${INSTALL_DIR}"
    log_info "Creando respaldo en ${backup_dir}..."

    if ! cp -r "$INSTALL_DIR" "$backup_dir" 2>/dev/null; then
      log_error "Error creando respaldo: espacio insuficiente o permisos inadecuados en ${backup_dir}"
      exit 1
    fi

    log_success "Respaldo creado en ${backup_dir}"
  fi
}

# =============================================================================
# Clonación / Actualización del repositorio central
# =============================================================================

clone_or_update_repo() {
  local git_output
  local git_exit_code

  if [[ "$UPDATE_MODE" == true ]]; then
    # Modo actualización: git pull
    if [[ ! -d "$INSTALL_DIR/.git" ]]; then
      log_error "No se encontró una instalación previa en ${INSTALL_DIR}. Ejecute primero sin --update."
      exit 4
    fi

    log_info "Actualizando repositorio central..."
    git_output=$(git -C "$INSTALL_DIR" pull origin "$KIRO_BOOTSTRAP_BRANCH" 2>&1) || git_exit_code=$?
    git_exit_code=${git_exit_code:-0}

    if [[ $git_exit_code -ne 0 ]]; then
      log_error "Error descargando repositorio: HTTP ${git_exit_code} - ${KIRO_BOOTSTRAP_REPO}"
      exit 4
    fi

    log_success "Repositorio actualizado correctamente"
  else
    # Instalación inicial: git clone
    log_info "Clonando repositorio central..."
    git_output=$(git clone --branch "$KIRO_BOOTSTRAP_BRANCH" --single-branch "$KIRO_BOOTSTRAP_REPO" "$INSTALL_DIR" 2>&1) || git_exit_code=$?
    git_exit_code=${git_exit_code:-0}

    if [[ $git_exit_code -ne 0 ]]; then
      log_error "Error descargando repositorio: HTTP ${git_exit_code} - ${KIRO_BOOTSTRAP_REPO}"
      exit 4
    fi

    log_success "Repositorio clonado correctamente en ${INSTALL_DIR}"
  fi
}

# =============================================================================
# Instalación de artefactos base en ~/.kiro/
# =============================================================================

install_base_artifacts() {
  log_info "Instalando artefactos base en ~/.kiro/..."

  # Crear directorios destino si no existen
  mkdir -p "$HOME/.kiro/agents"
  mkdir -p "$HOME/.kiro/steering"
  mkdir -p "$HOME/.kiro/hooks"

  # Copiar artefactos base
  if [[ -f "$INSTALL_DIR/agents/jarvis-bootstrap.json" ]]; then
    cp "$INSTALL_DIR/agents/jarvis-bootstrap.json" "$HOME/.kiro/agents/"
    log_success "Copiado: agents/jarvis-bootstrap.json → ~/.kiro/agents/"
  else
    log_warn "No se encontró agents/jarvis-bootstrap.json en el repositorio"
  fi

  if [[ -f "$INSTALL_DIR/steering/bootstrap-init.md" ]]; then
    cp "$INSTALL_DIR/steering/bootstrap-init.md" "$HOME/.kiro/steering/"
    log_success "Copiado: steering/bootstrap-init.md → ~/.kiro/steering/"
  else
    log_warn "No se encontró steering/bootstrap-init.md en el repositorio"
  fi

  if [[ -f "$INSTALL_DIR/hooks/bootstrap-init.kiro.hook" ]]; then
    cp "$INSTALL_DIR/hooks/bootstrap-init.kiro.hook" "$HOME/.kiro/hooks/"
    log_success "Copiado: hooks/bootstrap-init.kiro.hook → ~/.kiro/hooks/"
  else
    log_warn "No se encontró hooks/bootstrap-init.kiro.hook en el repositorio"
  fi

  # Obtener commit hash del repositorio clonado
  local commit_hash
  commit_hash=$(git -C "$INSTALL_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")

  # Obtener versión desde manifest.json
  local version="unknown"
  if [[ -f "$INSTALL_DIR/manifest.json" ]]; then
    version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$INSTALL_DIR/manifest.json" | head -1 | grep -o '"[^"]*"$' | tr -d '"')
  fi

  # Obtener fecha actual en formato ISO 8601
  local installed_at
  installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Escribir archivo de versión
  cat > "$HOME/.kiro/.bootstrap-version" <<BSEOF
{
  "commitHash": "${commit_hash}",
  "installedAt": "${installed_at}",
  "version": "${version}"
}
BSEOF

  log_success "Versión registrada en ~/.kiro/.bootstrap-version"

  # Contar agentes disponibles en el registro
  local agent_count=0
  if [[ -f "$INSTALL_DIR/agents-registry.json" ]]; then
    agent_count=$(grep -c '"name"' "$INSTALL_DIR/agents-registry.json" 2>/dev/null || echo "0")
  fi

  # Instalar extensiones base
  if [[ -f "$INSTALL_DIR/lib/install-extensions.sh" ]]; then
    source "$INSTALL_DIR/lib/install-extensions.sh"
    log_info "Instalando extensiones recomendadas..."
    install_extensions "$INSTALL_DIR" ""
  fi

  # Mostrar resumen de instalación
  echo ""
  echo -e "${BOLD}============================================${NC}"
  echo -e "${BOLD}  Resumen de Instalación${NC}"
  echo -e "${BOLD}============================================${NC}"
  echo -e "  Versión instalada:    ${GREEN}${version}${NC}"
  echo -e "  Agentes disponibles:  ${GREEN}${agent_count}${NC}"
  echo -e "  Ruta de instalación:  ${GREEN}${INSTALL_DIR}${NC}"
  echo -e "${BOLD}============================================${NC}"
  echo ""
  log_success "Instalación completada exitosamente"
}

# =============================================================================
# Verificación de actualización necesaria
# =============================================================================

check_update_needed() {
  local version_file="$HOME/.kiro/.bootstrap-version"

  # Leer commit hash local desde .bootstrap-version
  local local_hash=""
  if [[ -f "$version_file" ]]; then
    local_hash=$(grep -o '"commitHash"[[:space:]]*:[[:space:]]*"[^"]*"' "$version_file" | grep -o '"[^"]*"$' | tr -d '"')
  fi

  if [[ -z "$local_hash" || "$local_hash" == "unknown" ]]; then
    log_warn "No se encontró versión local registrada. Ejecutando actualización completa..."
    return 0
  fi

  # Obtener commit hash remoto
  log_info "Verificando versión remota..."
  local fetch_output
  local fetch_exit_code
  fetch_output=$(git -C "$INSTALL_DIR" fetch origin "$KIRO_BOOTSTRAP_BRANCH" 2>&1) || fetch_exit_code=$?
  fetch_exit_code=${fetch_exit_code:-0}

  if [[ $fetch_exit_code -ne 0 ]]; then
    log_error "Error descargando repositorio: HTTP ${fetch_exit_code} - ${KIRO_BOOTSTRAP_REPO}"
    exit 4
  fi

  local remote_hash
  remote_hash=$(git -C "$INSTALL_DIR" rev-parse "origin/$KIRO_BOOTSTRAP_BRANCH" 2>/dev/null || echo "")

  if [[ -z "$remote_hash" ]]; then
    log_warn "No se pudo obtener la versión remota. Ejecutando actualización completa..."
    return 0
  fi

  # Comparar hashes
  if [[ "$local_hash" == "$remote_hash" ]]; then
    local short_hash="${local_hash:0:12}"
    log_success "La configuración ya está actualizada (versión: ${short_hash})"
    exit 0
  fi

  log_info "Nueva versión disponible. Actualizando..."
  return 0
}

# =============================================================================
# Función principal
# =============================================================================

main() {
  parse_args "$@"

  echo -e "${BOLD}Kiro Bootstrap - Escala 24x7${NC}"
  echo "============================================"

  if [[ "$UPDATE_MODE" == true ]]; then
    log_info "Modo actualización activado"
  else
    log_info "Iniciando instalación..."
  fi

  # Paso 1: Validar prerrequisitos
  check_os
  check_dependencies

  if [[ "$UPDATE_MODE" == true ]]; then
    # Modo actualización:
    # 1. Verificar si hay nueva versión (exit 0 si ya está actualizado)
    check_update_needed
    # 2. Actualizar repositorio (git pull)
    clone_or_update_repo
    # 3. Re-instalar artefactos base con nueva versión
    install_base_artifacts
  else
    # Modo instalación:
    # 1. Respaldar instalación previa
    backup_existing_installation
    # 2. Clonar repositorio central
    clone_or_update_repo
    # 3. Instalar artefactos base
    install_base_artifacts
  fi
}

main "$@"
