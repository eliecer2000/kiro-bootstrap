# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[2.0.0]: https://github.com/eliecer2000/kiro-bootstrap/compare/v0.1.0...v2.0.0
[0.1.0]: https://github.com/eliecer2000/kiro-bootstrap/releases/tag/v0.1.0
