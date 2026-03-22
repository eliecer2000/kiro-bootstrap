# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

- Enhanced catalog validator: cross-references steering packs, local skills, hooks, and extension packs against actual files
- Enhanced catalog validator: verifies agent JSON files have correct `model` and `resources` fields
- Enhanced catalog validator: checks manifest/registry version sync
- New CI job `validate-agents`: validates agent JSON integrity (model + resources)
- 5 new tests in test-catalog.sh: agent JSON integrity, version sync, steering/skills/hooks existence

### Changed

- CI test job now depends on `validate-agents` in addition to existing gates
- Enriched all 3 scaffolding templates (product.md, structure.md, tech.md) with real content, tables, and examples
- Enriched all 12 steering packs with actionable rules, conventions, and anti-patterns:
  - `core.md`: idioma, principios, convenciones de codigo, limites
  - `security.md`: IAM, secretos, datos, validacion de entrada
  - `git.md`: commits, ramas, PRs, .gitignore
  - `aws-shared.md`: naming, tags, entornos, costos, observabilidad
  - `testing.md`: estrategia, quality gates, herramientas por runtime
  - `lambda.md`: handlers, errores, performance, logs, empaquetado
  - `api.md`: contratos, errores, auth, eventos, rate limiting
  - `observability.md`: logs, metricas, alarmas, trazas, dashboards
  - `runtime-typescript.md`: tsconfig, scripts, SDK v3, estructura
  - `runtime-python.md`: pyproject, ruff/black/mypy, boto3, empaquetado
  - `runtime-javascript.md`: ESM, JSDoc, SDK v3, estructura
  - `cdk.md`: stacks, constructs, synth, seguridad
  - `terraform.md`: state remoto, modulos, tags, seguridad

---

## [2.2.0] — 2026-03-22

### Added

- GitHub Actions CI workflow: JSON lint, shellcheck, markdownlint, ruff, catalog/skills/steering validation, test suite
- GitHub Actions release workflow: auto-creates GitHub Release from tag with changelog extraction
- `.markdownlint.json` configuration
- `.shellcheckrc` configuration
- Branching strategy and CI documentation in CONTRIBUTING.md

### Fixed

- Replaced `rg` (ripgrep) with `grep` in test scripts for CI portability
- ShellCheck warnings in install.sh, session.sh, and test-install.sh

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
- CODE_OF_CONDUCT.md (Contributor Covenant 2.1)
- SECURITY.md with vulnerability reporting policy
- GitHub issue templates: bug report, feature request, profile request
- GitHub pull request template with v2.1.0 checklist
- Contributing, Security, and License sections in README

### Docs
- Updated CONTRIBUTING.md with v2.1.0 conventions (skill frontmatter, steering inclusion, agent resources)
- Fixed incorrect script references in CONTRIBUTING (tests/run-tests.sh → tests/test-all.sh)
- Expanded agent-catalog.md with handoff matrix and configuration requirements
- Fixed authoring.md: corrected model ID, added skill frontmatter and steering inclusion examples
- Synced README version badge to 2.1.0

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

[2.2.0]: https://github.com/eliecer2000/kiro-bootstrap/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/eliecer2000/kiro-bootstrap/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/eliecer2000/kiro-bootstrap/compare/v0.1.0...v2.0.0
[0.1.0]: https://github.com/eliecer2000/kiro-bootstrap/releases/tag/v0.1.0
