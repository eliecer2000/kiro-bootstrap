#!/usr/bin/env bash

_LA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LA_BOOTSTRAP_DIR="$(cd "${_LA_SCRIPT_DIR}/.." && pwd)"

_LA_RED="${_LA_RED:-\033[0;31m}"
_LA_GREEN="${_LA_GREEN:-\033[0;32m}"
_LA_YELLOW="${_LA_YELLOW:-\033[0;33m}"
_LA_BLUE="${_LA_BLUE:-\033[0;34m}"
_LA_BOLD="${_LA_BOLD:-\033[1m}"
_LA_NC="${_LA_NC:-\033[0m}"

_LA_NEW=0
_LA_UNCHANGED=0
_LA_MODIFIED=0
_LA_SKIPPED=0
_ORBIT_LAST_PROFILE=""
_ORBIT_LAST_AGENTS=""
_ORBIT_LAST_STEERING=""
_ORBIT_LAST_LOCAL_SKILLS=""
_ORBIT_LAST_HOOKS=""
_ORBIT_LAST_EXTENSION_PACKS=""

source "${_LA_BOOTSTRAP_DIR}/lib/install-extensions.sh"
source "${_LA_BOOTSTRAP_DIR}/lib/install-remote-skills.sh"

_la_catalog() {
  python3 "${_LA_BOOTSTRAP_DIR}/lib/orbit_catalog.py" --bootstrap-dir "${_LA_BOOTSTRAP_DIR}" "$@"
}

get_agent_field() {
  local agent_id="$1"
  local field="$2"
  _la_catalog agent-field --agent-id "$agent_id" --field "$field"
}

get_profile_field() {
  local profile_id="$1"
  local field="$2"
  _la_catalog profile-field --profile-id "$profile_id" --field "$field"
}

_la_prompt_conflict_action() {
  local source="$1"
  local dest="$2"
  local answer=""

  if [[ -n "${ORBIT_CONFLICT_STRATEGY:-}" ]]; then
    echo "${ORBIT_CONFLICT_STRATEGY}"
    return 0
  fi
  if [[ -n "${ORBIT_TEST_CONFLICT_STRATEGY:-}" ]]; then
    echo "${ORBIT_TEST_CONFLICT_STRATEGY}"
    return 0
  fi

  echo "    Conflicto detectado entre ${source} y ${dest}"
  printf "    Accion [keep/overwrite/diff]: "
  read -r answer
  echo "${answer:-keep}"
}

copy_artifact() {
  local source="$1"
  local dest="$2"
  local action dest_dir

  if [[ ! -e "$source" ]]; then
    echo -e "    ${_LA_YELLOW}! Fuente no encontrada: ${source}${_LA_NC}"
    _LA_SKIPPED=$((_LA_SKIPPED + 1))
    return 0
  fi

  if [[ -d "$source" ]]; then
    if [[ -d "$dest" ]] && diff -rq "$source" "$dest" >/dev/null 2>&1; then
      echo -e "    ${_LA_BLUE}= Sin cambios: $(basename "$dest")/${_LA_NC}"
      _LA_UNCHANGED=$((_LA_UNCHANGED + 1))
      return 0
    fi
    if [[ -d "$dest" ]]; then
      action="$(_la_prompt_conflict_action "$source" "$dest")"
      if [[ "$action" == "diff" ]]; then
        diff -ru "$source" "$dest" || true
        action="$(_la_prompt_conflict_action "$source" "$dest")"
      fi
      if [[ "$action" == "overwrite" ]]; then
        rm -rf "$dest"
        mkdir -p "$dest"
        cp -R "$source/." "$dest/"
        echo -e "    ${_LA_GREEN}+ Sobrescrito: $(basename "$dest")/${_LA_NC}"
        _LA_MODIFIED=$((_LA_MODIFIED + 1))
        return 0
      fi
      echo -e "    ${_LA_YELLOW}! Conservado localmente: $(basename "$dest")/${_LA_NC}"
      _LA_MODIFIED=$((_LA_MODIFIED + 1))
      return 0
    fi
    mkdir -p "$dest"
    cp -R "$source/." "$dest/"
    echo -e "    ${_LA_GREEN}+ Nuevo: $(basename "$dest")/${_LA_NC}"
    _LA_NEW=$((_LA_NEW + 1))
    return 0
  fi

  if [[ -f "$dest" ]] && diff -q "$source" "$dest" >/dev/null 2>&1; then
    echo -e "    ${_LA_BLUE}= Sin cambios: $(basename "$dest")${_LA_NC}"
    _LA_UNCHANGED=$((_LA_UNCHANGED + 1))
    return 0
  fi

  if [[ -f "$dest" ]]; then
    action="$(_la_prompt_conflict_action "$source" "$dest")"
    if [[ "$action" == "diff" ]]; then
      diff -u "$dest" "$source" || true
      action="$(_la_prompt_conflict_action "$source" "$dest")"
    fi
    if [[ "$action" == "overwrite" ]]; then
      cp "$source" "$dest"
      echo -e "    ${_LA_GREEN}+ Sobrescrito: $(basename "$dest")${_LA_NC}"
      _LA_MODIFIED=$((_LA_MODIFIED + 1))
      return 0
    fi
    echo -e "    ${_LA_YELLOW}! Conservado localmente: $(basename "$dest")${_LA_NC}"
    _LA_MODIFIED=$((_LA_MODIFIED + 1))
    return 0
  fi

  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"
  cp "$source" "$dest"
  echo -e "    ${_LA_GREEN}+ Nuevo: $(basename "$dest")${_LA_NC}"
  _LA_NEW=$((_LA_NEW + 1))
  return 0
}

_la_copy_agents() {
  local project_dir="$1"
  local profile_id="$2"
  local agent_id source_file dest_file

  echo -e "  ${_LA_BOLD}Agentes:${_LA_NC}"
  _ORBIT_LAST_AGENTS=""
  while IFS= read -r agent_id; do
    [[ -z "$agent_id" ]] && continue
    source_file="${_LA_BOOTSTRAP_DIR}/$(get_agent_field "$agent_id" file)"
    dest_file="${project_dir}/.kiro/agents/$(basename "$source_file")"
    copy_artifact "$source_file" "$dest_file"
    _ORBIT_LAST_AGENTS="${_ORBIT_LAST_AGENTS}${agent_id}"$'\n'
  done < <(get_profile_field "$profile_id" agents)
}

_la_copy_steering() {
  local project_dir="$1"
  local profile_id="$2"
  local pack source_file dest_file

  echo ""
  echo -e "  ${_LA_BOLD}Steering:${_LA_NC}"
  _ORBIT_LAST_STEERING=""
  while IFS= read -r pack; do
    [[ -z "$pack" ]] && continue
    source_file="${_LA_BOOTSTRAP_DIR}/steering/${pack}.md"
    dest_file="${project_dir}/.kiro/steering/${pack}.md"
    copy_artifact "$source_file" "$dest_file"
    _ORBIT_LAST_STEERING="${_ORBIT_LAST_STEERING}${pack}"$'\n'
  done < <(get_profile_field "$profile_id" steeringPacks)
}

_la_copy_local_skills() {
  local project_dir="$1"
  local profile_id="$2"
  local skill source_dir dest_dir

  echo ""
  echo -e "  ${_LA_BOLD}Skills locales:${_LA_NC}"
  _ORBIT_LAST_LOCAL_SKILLS=""
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    source_dir="${_LA_BOOTSTRAP_DIR}/skills/${skill}"
    dest_dir="${project_dir}/.kiro/skills/${skill}"
    copy_artifact "$source_dir" "$dest_dir"
    _ORBIT_LAST_LOCAL_SKILLS="${_ORBIT_LAST_LOCAL_SKILLS}${skill}"$'\n'
  done < <(get_profile_field "$profile_id" localSkills)
}

_la_copy_hooks() {
  local project_dir="$1"
  local profile_id="$2"
  local hook source_file dest_file

  echo ""
  echo -e "  ${_LA_BOLD}Hooks:${_LA_NC}"
  _ORBIT_LAST_HOOKS=""
  while IFS= read -r hook; do
    [[ -z "$hook" ]] && continue
    source_file="${_LA_BOOTSTRAP_DIR}/hooks/${hook}"
    dest_file="${project_dir}/.kiro/hooks/${hook}"
    copy_artifact "$source_file" "$dest_file"
    _ORBIT_LAST_HOOKS="${_ORBIT_LAST_HOOKS}${hook}"$'\n'
  done < <(get_profile_field "$profile_id" hooks)
}

_la_install_remote_skills() {
  local profile_id="$1"
  local remote_skill

  echo ""
  echo -e "  ${_LA_BOLD}Skills remotas:${_LA_NC}"
  while IFS= read -r remote_skill; do
    [[ -z "$remote_skill" ]] && continue
    install_remote_skill "$remote_skill"
  done < <(get_profile_field "$profile_id" remoteSkills)
}

_la_install_extensions() {
  local bootstrap_dir="$1"
  local profile_id="$2"

  echo ""
  echo -e "  ${_LA_BOLD}Extensiones:${_LA_NC}"
  _ORBIT_LAST_EXTENSION_PACKS="$(get_profile_field "$profile_id" extensionPacks)"
  install_extensions "$bootstrap_dir" "$profile_id"
}

load_artifacts() {
  local project_dir="$1"
  local bootstrap_dir="$2"
  local profile_id="$3"

  echo -e "${_LA_BOLD}${_LA_BLUE}▶ Cargando artefactos Orbit para perfil: ${profile_id}${_LA_NC}"
  echo ""

  if [[ -z "$project_dir" || -z "$bootstrap_dir" || -z "$profile_id" ]]; then
    echo -e "${_LA_RED}Error: Se requieren project_dir, bootstrap_dir y profile_id.${_LA_NC}"
    return 1
  fi

  mkdir -p "${project_dir}/.kiro/agents" "${project_dir}/.kiro/steering" "${project_dir}/.kiro/skills" "${project_dir}/.kiro/hooks"
  _LA_NEW=0
  _LA_UNCHANGED=0
  _LA_MODIFIED=0
  _LA_SKIPPED=0
  _ORBIT_LAST_PROFILE="$profile_id"

  _la_copy_agents "$project_dir" "$profile_id"
  _la_copy_steering "$project_dir" "$profile_id"
  _la_copy_local_skills "$project_dir" "$profile_id"
  _la_copy_hooks "$project_dir" "$profile_id"
  _la_install_remote_skills "$profile_id"
  _la_install_extensions "$bootstrap_dir" "$profile_id"

  echo ""
  echo -e "${_LA_BOLD}────────────────────────────────────────────────────${_LA_NC}"
  echo -e "  Resumen: ${_LA_GREEN}${_LA_NEW} nuevos${_LA_NC}, ${_LA_BLUE}${_LA_UNCHANGED} sin cambios${_LA_NC}, ${_LA_YELLOW}${_LA_MODIFIED} resueltos${_LA_NC}, ${_LA_YELLOW}${_LA_SKIPPED} omitidos${_LA_NC}"
  echo -e "${_LA_BOLD}────────────────────────────────────────────────────${_LA_NC}"
}

write_project_state() {
  local project_dir="$1"
  local bootstrap_dir="$2"
  local profile_id="$3"
  local state_file commit_hash now

  state_file="${project_dir}/.kiro/.orbit-project.json"
  commit_hash="$(git -C "$bootstrap_dir" rev-parse HEAD 2>/dev/null || echo unknown)"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  python3 - "$state_file" "$profile_id" "$commit_hash" "$now" "${ORBIT_APPROVED_REMOTE_SKILLS:-}" <<'PY'
import json, pathlib, sys

path = pathlib.Path(sys.argv[1])
payload = {
    "profileId": sys.argv[2],
    "bootstrapCommit": sys.argv[3],
    "lastSyncAt": sys.argv[4],
    "lastSyncMode": __import__("os").environ.get("ORBIT_SYNC_MODE", "bootstrap"),
    "approvedRemoteSkills": [item for item in sys.argv[5].split(",") if item],
    "installedPacks": {
        "agents": [item for item in __import__("os").environ.get("_ORBIT_LAST_AGENTS", "").split("\n") if item],
        "steering": [item for item in __import__("os").environ.get("_ORBIT_LAST_STEERING", "").split("\n") if item],
        "localSkills": [item for item in __import__("os").environ.get("_ORBIT_LAST_LOCAL_SKILLS", "").split("\n") if item],
        "hooks": [item for item in __import__("os").environ.get("_ORBIT_LAST_HOOKS", "").split("\n") if item],
        "extensionPacks": [item for item in __import__("os").environ.get("_ORBIT_LAST_EXTENSION_PACKS", "").split("\n") if item],
    },
}
path.write_text(json.dumps(payload, indent=2) + "\n")
PY
}
