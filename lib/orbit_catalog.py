#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
import sys
from typing import Any


def load_json(path: pathlib.Path) -> Any:
    return json.loads(path.read_text())


def bootstrap_dir_from(value: str | None) -> pathlib.Path:
    if value:
        return pathlib.Path(value).expanduser().resolve()
    return pathlib.Path(__file__).resolve().parent.parent


def manifest_path(bootstrap_dir: pathlib.Path) -> pathlib.Path:
    return bootstrap_dir / "manifest.json"


def registry_path(bootstrap_dir: pathlib.Path) -> pathlib.Path:
    return bootstrap_dir / "agents-registry.json"


def load_manifest(bootstrap_dir: pathlib.Path) -> dict[str, Any]:
    return load_json(manifest_path(bootstrap_dir))


def load_registry(bootstrap_dir: pathlib.Path) -> dict[str, Any]:
    return load_json(registry_path(bootstrap_dir))


def load_profiles(bootstrap_dir: pathlib.Path) -> dict[str, dict[str, Any]]:
    profiles_dir = bootstrap_dir / "profiles"
    profiles: dict[str, dict[str, Any]] = {}
    for path in sorted(profiles_dir.glob("*.json")):
        data = load_json(path)
        profile_id = data.get("id", path.stem)
        data["id"] = profile_id
        profiles[profile_id] = data
    return profiles


def read_text_if_exists(path: pathlib.Path) -> str:
    if not path.exists():
        return ""
    return path.read_text()


def package_has_dependency(project_dir: pathlib.Path, dep_name: str) -> bool:
    pkg_path = project_dir / "package.json"
    if not pkg_path.exists():
      return False
    data = load_json(pkg_path)
    search_spaces = [data.get("dependencies", {}), data.get("devDependencies", {})]
    if dep_name.endswith("*"):
        prefix = dep_name[:-1]
        return any(
            any(key.startswith(prefix) for key in space.keys())
            for space in search_spaces
        )
    return any(dep_name in space for space in search_spaces)


def any_glob_matches(project_dir: pathlib.Path, patterns: list[str]) -> bool:
    return any(any(project_dir.glob(pattern)) for pattern in patterns)


def all_globs_match(project_dir: pathlib.Path, patterns: list[str]) -> bool:
    return all(any(project_dir.glob(pattern)) for pattern in patterns)


def detection_match(profile: dict[str, Any], project_dir: pathlib.Path) -> tuple[bool, int]:
    detection = profile.get("detection", {})
    score = 0

    required_files = detection.get("requiredFiles", [])
    if any(not (project_dir / path).exists() for path in required_files):
        return False, 0
    score += len(required_files)

    any_files = detection.get("anyFiles", [])
    if any_files:
        matched = [(project_dir / path).exists() for path in any_files]
        if not any(matched):
            return False, 0
        score += sum(1 for item in matched if item)

    exclude_files = detection.get("excludeFiles", [])
    if any((project_dir / path).exists() for path in exclude_files):
        return False, 0

    required_globs = detection.get("requiredGlobs", [])
    if required_globs and not all_globs_match(project_dir, required_globs):
        return False, 0
    if required_globs:
        score += len(required_globs)

    any_globs = detection.get("anyGlobs", [])
    if any_globs:
        matches = []
        for pattern in any_globs:
            hits = list(project_dir.glob(pattern))
            matches.append(bool(hits))
        if not any(matches):
            return False, 0
        score += sum(1 for item in matches if item)

    package_dependencies = detection.get("packageJsonDependencies", [])
    if any(not package_has_dependency(project_dir, dependency) for dependency in package_dependencies):
        return False, 0
    score += len(package_dependencies)

    text_patterns = detection.get("textPatterns", [])
    for item in text_patterns:
        text_path = project_dir / item["path"]
        if not text_path.exists():
            continue
        contents = read_text_if_exists(text_path)
        if item["pattern"] in contents:
            score += 1

    if score == 0:
        return False, 0

    score += int(detection.get("priority", 0))
    return True, score


def detect_profiles(bootstrap_dir: pathlib.Path, project_dir: pathlib.Path) -> list[str]:
    profiles = load_profiles(bootstrap_dir)
    matches: list[tuple[int, str]] = []
    for profile_id, profile in profiles.items():
        if not profile.get("enabled", True):
            continue
        matched, score = detection_match(profile, project_dir)
        if matched:
            matches.append((score, profile_id))
    matches.sort(key=lambda item: (-item[0], item[1]))
    return [item[1] for item in matches]


def resolve_profile(bootstrap_dir: pathlib.Path, workload: str, runtime: str | None, provisioner: str | None, framework: str | None) -> str:
    profiles = load_profiles(bootstrap_dir)
    for profile_id, profile in profiles.items():
        wizard = profile.get("wizard", {})
        if wizard.get("workload") != workload:
            continue
        if runtime is not None and wizard.get("runtime") not in (None, runtime):
            continue
        if provisioner is not None and wizard.get("provisioner") not in (None, provisioner):
            continue
        if framework is not None and wizard.get("framework") not in (None, framework):
            continue
        return profile_id
    raise SystemExit(f"No se pudo resolver un perfil para workload={workload}, runtime={runtime}, provisioner={provisioner}, framework={framework}")


def emit_pipeline_steps(bootstrap_dir: pathlib.Path) -> None:
    manifest = load_manifest(bootstrap_dir)
    steps = manifest.get("pipeline", {}).get("steps", [])
    parsed = []
    for step in steps:
        parsed.append(
            (
                int(step.get("order", 0)),
                step.get("id", ""),
                step.get("name", ""),
                str(step.get("enabled", True)).lower(),
                step.get("type", ""),
            )
        )
    for order, step_id, name, enabled, step_type in sorted(parsed, key=lambda item: item[0]):
        print(f"{order}|{step_id}|{name}|{enabled}|{step_type}")


def emit_profile_field(bootstrap_dir: pathlib.Path, profile_id: str, field: str | None) -> None:
    profiles = load_profiles(bootstrap_dir)
    if profile_id not in profiles:
        raise SystemExit(f"Perfil de proyecto no encontrado: {profile_id}")
    profile = profiles[profile_id]
    if not field:
        print(json.dumps(profile, indent=2))
        return
    value = profile.get(field, "")
    if isinstance(value, list):
        print("\n".join(str(item) for item in value))
    elif isinstance(value, dict):
        print(json.dumps(value, indent=2))
    else:
        print(value)


def emit_agent_field(bootstrap_dir: pathlib.Path, agent_id: str, field: str | None) -> None:
    registry = load_registry(bootstrap_dir)
    agent = registry["agents"][agent_id]
    if not field:
        print(json.dumps(agent, indent=2))
        return
    value = agent.get(field, "")
    if isinstance(value, list):
        print("\n".join(str(item) for item in value))
    elif isinstance(value, dict):
        print(json.dumps(value, indent=2))
    else:
        print(value)


def emit_remote_skill_field(bootstrap_dir: pathlib.Path, remote_skill_id: str, field: str | None) -> None:
    registry = load_registry(bootstrap_dir)
    for item in registry.get("remoteSkillsAllowlist", []):
        if item.get("id") == remote_skill_id:
            if not field:
                print(json.dumps(item, indent=2))
            else:
                print(item.get(field, ""))
            return
    raise SystemExit(f"Remote skill no encontrada: {remote_skill_id}")


def validate_catalog(bootstrap_dir: pathlib.Path) -> int:
    manifest = load_manifest(bootstrap_dir)
    profiles = load_profiles(bootstrap_dir)
    registry = load_registry(bootstrap_dir)
    agents = registry.get("agents", {})
    remote_skill_ids = {item["id"] for item in registry.get("remoteSkillsAllowlist", [])}
    errors: list[str] = []

    if manifest.get("brand", {}).get("bootstrapAgent") != registry.get("bootstrapAgent"):
        errors.append("manifest.brand.bootstrapAgent debe coincidir con agents-registry.bootstrapAgent")

    required_agent_fields = [
        "role",
        "responsibilities",
        "ownedTasks",
        "handoffs",
        "supportedProfiles",
        "steeringPacks",
        "localSkills",
        "remoteSkills",
        "modelDefault",
        "acceptanceChecklist",
        "file",
    ]
    for agent_id, agent in agents.items():
        for field in required_agent_fields:
            if field not in agent:
                errors.append(f"Agente {agent_id} no define {field}")
        for remote_skill in agent.get("remoteSkills", []):
            if remote_skill not in remote_skill_ids:
                errors.append(f"Agente {agent_id} referencia remote skill no permitida: {remote_skill}")
        if not (bootstrap_dir / agent["file"]).exists():
            errors.append(f"Archivo faltante para agente {agent_id}: {agent['file']}")

    for profile_id, profile in profiles.items():
        for agent_id in profile.get("agents", []):
            if agent_id not in agents:
                errors.append(f"Perfil {profile_id} referencia agente inexistente: {agent_id}")
        for remote_skill in profile.get("remoteSkills", []):
            if remote_skill not in remote_skill_ids:
                errors.append(f"Perfil {profile_id} referencia remote skill no permitida: {remote_skill}")

    if errors:
        print("\n".join(errors))
        return 1

    print("Catalogo Orbit valido")
    return 0


def main() -> int:
    if len(sys.argv) >= 2 and sys.argv[1] == "--list-profiles":
        bootstrap_dir = bootstrap_dir_from(None)
        for profile_id in load_profiles(bootstrap_dir):
            print(profile_id)
        return 0

    parser = argparse.ArgumentParser()
    parser.add_argument("--bootstrap-dir", default=None)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("pipeline-steps")

    detect = subparsers.add_parser("detect")
    detect.add_argument("--project-dir", required=True)
    detect.add_argument("--single", action="store_true")

    list_profiles_parser = subparsers.add_parser("list-profiles")
    list_profiles_parser.add_argument("--enabled-only", action="store_true")

    resolve = subparsers.add_parser("resolve-profile")
    resolve.add_argument("--workload", required=True)
    resolve.add_argument("--runtime")
    resolve.add_argument("--provisioner")
    resolve.add_argument("--framework")

    profile_field = subparsers.add_parser("profile-field")
    profile_field.add_argument("--profile-id", required=True)
    profile_field.add_argument("--field")

    agent_field = subparsers.add_parser("agent-field")
    agent_field.add_argument("--agent-id", required=True)
    agent_field.add_argument("--field")

    remote_skill = subparsers.add_parser("remote-skill-field")
    remote_skill.add_argument("--remote-skill-id", required=True)
    remote_skill.add_argument("--field")

    subparsers.add_parser("validate-catalog")

    args = parser.parse_args()
    bootstrap_dir = bootstrap_dir_from(args.bootstrap_dir)

    if args.command == "pipeline-steps":
        emit_pipeline_steps(bootstrap_dir)
        return 0
    if args.command == "detect":
        matches = detect_profiles(bootstrap_dir, pathlib.Path(args.project_dir).expanduser().resolve())
        if args.single:
            if matches:
                print(matches[0])
                return 0
            return 1
        if not matches:
            return 1
        print("\n".join(matches))
        return 0
    if args.command == "list-profiles":
        profiles = load_profiles(bootstrap_dir)
        for profile_id, profile in profiles.items():
            if args.enabled_only and not profile.get("enabled", True):
                continue
            print(profile_id)
        return 0
    if args.command == "resolve-profile":
        print(
            resolve_profile(
                bootstrap_dir,
                args.workload,
                args.runtime,
                args.provisioner,
                args.framework,
            )
        )
        return 0
    if args.command == "profile-field":
        emit_profile_field(bootstrap_dir, args.profile_id, args.field)
        return 0
    if args.command == "agent-field":
        emit_agent_field(bootstrap_dir, args.agent_id, args.field)
        return 0
    if args.command == "remote-skill-field":
        emit_remote_skill_field(bootstrap_dir, args.remote_skill_id, args.field)
        return 0
    if args.command == "validate-catalog":
        return validate_catalog(bootstrap_dir)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
