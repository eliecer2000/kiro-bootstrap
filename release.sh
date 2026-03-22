#!/usr/bin/env bash
set -euo pipefail

# Orbit Release Script
# Automates: version bump → PR → CI → merge → tag → GitHub Release
#
# Usage: bash release.sh <version>
# Example: bash release.sh 2.5.0

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

log_info() { printf "${YELLOW}→${NC} %s\n" "$1"; }
log_ok()   { printf "${GREEN}✓${NC} %s\n" "$1"; }
log_err()  { printf "${RED}✗${NC} %s\n" "$1"; }

# --- Validate input ---

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  log_err "Uso: bash release.sh <version>"
  log_err "Ejemplo: bash release.sh 2.5.0"
  exit 1
fi

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  log_err "Version invalida: ${VERSION}. Usa formato semver: X.Y.Z"
  exit 1
fi

# --- Validate environment ---

if ! command -v gh >/dev/null 2>&1; then
  log_err "gh CLI no encontrado. Instala: brew install gh"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  log_err "python3 no encontrado."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  log_err "Hay cambios sin commitear. Commitea o stashea antes de hacer release."
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  log_err "Debes estar en main para hacer release. Estas en: ${CURRENT_BRANCH}"
  exit 1
fi

log_info "Pulling latest main..."
git pull origin main --quiet

CURRENT_VERSION="$(python3 -c "import json; print(json.load(open('manifest.json'))['version'])")"
if [[ "$CURRENT_VERSION" == "$VERSION" ]]; then
  log_err "La version ${VERSION} ya es la actual."
  exit 1
fi

if git tag -l "v${VERSION}" | grep -q "v${VERSION}"; then
  log_err "El tag v${VERSION} ya existe."
  exit 1
fi

printf "\n"
printf "${BOLD}Orbit Release v%s${NC}\n" "$VERSION"
printf "============================================\n"
printf "  Actual:  %s\n" "$CURRENT_VERSION"
printf "  Nueva:   ${GREEN}%s${NC}\n" "$VERSION"
printf "\n"

# --- Create release branch ---

BRANCH="chore/release-v${VERSION}"
log_info "Creando rama ${BRANCH}..."
git checkout -b "$BRANCH" --quiet

# --- Bump versions in JSON files ---

log_info "Actualizando versiones..."
python3 - "$VERSION" <<'PYEOF'
import json, pathlib, sys
version = sys.argv[1]
for f in ["manifest.json", "agents-registry.json"]:
    p = pathlib.Path(f)
    data = json.loads(p.read_text())
    data["version"] = version
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PYEOF
log_ok "manifest.json → ${VERSION}"
log_ok "agents-registry.json → ${VERSION}"

# --- Update README badge ---

sed -i.bak "s/version-[0-9]*\.[0-9]*\.[0-9]*/version-${VERSION}/" README.md
rm -f README.md.bak
log_ok "README.md badge → ${VERSION}"

# --- Update CHANGELOG ---

TODAY="$(date +%Y-%m-%d)"
python3 - "$VERSION" "$TODAY" "$CURRENT_VERSION" <<'PYEOF'
import sys, pathlib, re

version, today, current = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path("CHANGELOG.md")
content = p.read_text()

# Replace [Unreleased] with version, or insert new section
if "## [Unreleased]" in content:
    content = content.replace("## [Unreleased]", f"## [{version}] — {today}")
    print(f"RENAMED:[Unreleased] → [{version}] — {today}")
else:
    marker = f"## [{current}]"
    idx = content.find(marker)
    if idx >= 0:
        section = f"## [{version}] — {today}\n\n### Changed\n\n- Version bump to {version}\n\n---\n\n"
        content = content[:idx] + section + content[idx:]
        print(f"INSERTED:new section [{version}]")
    else:
        print("WARNING:could not find insertion point")

# Add comparison link if missing
link_marker = f"[{version}]:"
if link_marker not in content:
    old_link = f"[{current}]: https://github.com"
    new_link = (
        f"[{version}]: https://github.com/eliecer2000/kiro-bootstrap/compare/v{current}...v{version}\n"
        f"[{current}]: https://github.com"
    )
    content = content.replace(old_link, new_link)
    print("LINK:added comparison link")

p.write_text(content)
PYEOF
log_ok "CHANGELOG.md actualizado"

# --- Run tests ---

log_info "Ejecutando tests..."
if bash tests/test-all.sh >/dev/null 2>&1; then
  log_ok "Tests pasaron"
else
  log_err "Tests fallaron. Abortando release."
  git checkout main --quiet
  git branch -D "$BRANCH" --quiet 2>/dev/null || true
  exit 1
fi

# --- Commit, push, create PR ---

log_info "Commiteando..."
git add -A
git commit -m "chore: release v${VERSION}" --quiet

log_info "Pusheando rama..."
git push origin "$BRANCH" --quiet

log_info "Creando PR..."
PR_URL="$(gh pr create \
  --title "chore: release v${VERSION}" \
  --body "Version bump to v${VERSION}

Changes:
- manifest.json → ${VERSION}
- agents-registry.json → ${VERSION}
- README.md badge → ${VERSION}
- CHANGELOG.md updated" \
  --base main \
  --head "$BRANCH" 2>&1 | tail -1)"
log_ok "PR creado: ${PR_URL}"

# --- Wait for CI ---

printf "\n"
log_info "Esperando CI..."
if gh pr checks "$BRANCH" --watch --fail-fast 2>/dev/null; then
  log_ok "CI verde"
else
  log_err "CI fallo. Revisa el PR: ${PR_URL}"
  exit 1
fi

# --- Merge PR ---

log_info "Mergeando PR..."
gh pr merge "$BRANCH" --squash --delete-branch
log_ok "PR mergeado"

# --- Tag on main ---

log_info "Actualizando main local..."
git checkout main --quiet
git pull origin main --quiet

log_info "Creando tag v${VERSION}..."
git tag -a "v${VERSION}" -m "v${VERSION}"
git push origin "v${VERSION}"
log_ok "Tag v${VERSION} pusheado — release workflow se disparara automaticamente"

# --- Done ---

printf "\n"
printf "${BOLD}${GREEN}Release v%s completado${NC}\n" "$VERSION"
printf "============================================\n"
printf "  PR:      %s\n" "$PR_URL"
printf "  Tag:     v%s\n" "$VERSION"
printf "  Release: https://github.com/eliecer2000/kiro-bootstrap/releases/tag/v%s\n" "$VERSION"
