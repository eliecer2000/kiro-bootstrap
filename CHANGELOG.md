# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.1.0] — 2026-03-22

### Fixed
- All 22 SKILL.md files now include YAML frontmatter (`name` + `description`) required by Kiro for skill discovery and activation
- Model IDs corrected from `sonnet-4`/`sonnet-4.6` to `claude-sonnet-4` across all 14 agents, agents-registry.json, and manifest.json
- Agent descriptions improved for better Kiro auto-routing and context matching

### Changed
- Steering inclusion modes aligned with Kiro documentation:
  - `always`: core, security, aws-shared, git (loaded in every session)
  - `fileMatch`: runtime-typescript, runtime-python, runtime-javascript, api, testing, lambda, cdk, terraform, amplify, observability (loaded contextually by file pattern)
- All 14 agent JSON files now include `"resources": ["skill://.kiro/skills/**/SKILL.md"]` for proper skill loading

### Added
- YAML frontmatter with English descriptions on all skills for optimal Kiro keyword matching
- Skill resource bindings on every agent (previously only orbit had resources)

---

## [2.0.0] — 2026-03-18

### Changed
- Complete rebuild as **Orbit** — AWS-first bootstrap framework for Kiro
- 6-step pipeline: Session Gates → Detect Profile → Validate Env → Load Artifacts → Install Tooling → Write State
- Profile matrix now driven by 4 dimensions: workload, runtime, provisioner, framework
- Unified `install.sh` with `--update`, `--resync-project`, `--help` flags
- Extension packs synced automatically from installed Kiro extensions

### Added
- Auto-install of missing system tooling (git, node, python3, aws, terraform)
- Git validation hook on all profiles
- Shared steering packs: core, git, security, aws-shared, testing, observability
- Skill: `orbit-bootstrap`, `find-skills`
- Separate handling of project profiles vs AWS credentials

---

## [0.1.0] — 2026-01-15

### Added
- Initial release of the Kiro Bootstrap framework
- Profile detection based on project structure
- Base agents: orbit orchestrator with Kiro integration
- Skills system with core and custom skill directories
- Steering packs: core, git, security
- Templates for agents, skills, and steering documents
- Hooks system for session lifecycle events
- `install.sh` one-liner installation
- Profiles: `backend-api-ts`, `backend-api-py`, `infra-terraform`, `infra-cdk`, `frontend-amplify`
- Validation system for required environment tooling
- Docs: architecture, bootstrap flow, profile matrix, agent catalog, authoring guide

[2.1.0]: https://github.com/eliecer2000/kiro-bootstrap/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/eliecer2000/kiro-bootstrap/compare/v0.1.0...v2.0.0
[0.1.0]: https://github.com/eliecer2000/kiro-bootstrap/releases/tag/v0.1.0
