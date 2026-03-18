#!/usr/bin/env bash

_DP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DP_BOOTSTRAP_DIR="$(cd "${_DP_SCRIPT_DIR}/.." && pwd)"

_dp_catalog() {
  python3 "${_DP_BOOTSTRAP_DIR}/lib/orbit_catalog.py" --bootstrap-dir "${_DP_BOOTSTRAP_DIR}" "$@"
}

list_profiles() {
  _dp_catalog list-profiles --enabled-only
}

describe_profile() {
  local profile_id="$1"
  local field="${2:-}"
  if [[ -n "$field" ]]; then
    _dp_catalog profile-field --profile-id "$profile_id" --field "$field"
  else
    _dp_catalog profile-field --profile-id "$profile_id"
  fi
}

detect_profiles() {
  local project_dir="$1"
  _dp_catalog detect --project-dir "$project_dir"
}

detect_single_profile() {
  local project_dir="$1"
  _dp_catalog detect --project-dir "$project_dir" --single
}

resolve_profile_from_answers() {
  local workload="$1"
  local runtime="${2:-}"
  local provisioner="${3:-}"
  local framework="${4:-}"
  _dp_catalog resolve-profile --workload "$workload" ${runtime:+--runtime "$runtime"} ${provisioner:+--provisioner "$provisioner"} ${framework:+--framework "$framework"}
}
