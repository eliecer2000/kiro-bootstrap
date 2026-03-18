# Contributing to Orbit Bootstrap

Thank you for your interest in contributing! This document explains how to add profiles, agents, skills, and other components to the framework.

---

## Getting started

```bash
git clone https://github.com/eliecer2000/kiro-bootstrap.git
cd kiro-bootstrap
```

No build step required — the framework is pure shell + JSON + Markdown.

---

## Types of contributions

### 1. Add a new profile

Profiles live in `profiles/`. Each profile is a directory named after its key (e.g., `backend-api-ts`).

**Structure:**
```
profiles/
└── <profile-key>/
    ├── agents/          # Agent YAML/MD files for this profile
    ├── steering/        # Steering packs (.md)
    ├── skills/          # Local skills (.md)
    ├── hooks/           # Hook scripts
    └── tooling.json     # devDependencies to install
```

**Steps:**
1. Create `profiles/<your-profile>/` with the structure above.
2. Add an entry to `agents-registry.json` under the matching workload/runtime key.
3. Update `manifest.json` wizard options if adding a new workload or runtime.
4. Add a row to the profile matrix table in `docs/profile-matrix.md`.
5. Test locally: `bash install.sh` and select your new profile.

**Naming convention:** `<workload>-<runtime>` or `<workload>-<provisioner>` (e.g., `backend-worker-py`, `infra-terraform`).

---

### 2. Add a new agent

Agents live in `agents/`. Use the base template:

```bash
cp templates/agent-templates/base-agent.md agents/<agent-name>.md
```

Edit the frontmatter fields: `name`, `description`, `tools`, `model`.

Then register the agent in `agents-registry.json` under whichever profiles should load it.

See `docs/agent-catalog.md` for existing agents and naming conventions.

---

### 3. Add a new skill

Skills live in `skills/`. Two categories:

| Path | Purpose |
|---|---|
| `skills/core/` | Available to all profiles |
| `skills/custom/` | Profile-specific, referenced from `profiles/<key>/skills/` |

```bash
cp templates/skill-templates/base-skill.md skills/core/<skill-name>.md
# or for profile-specific:
cp templates/skill-templates/base-skill.md profiles/<profile>/skills/<skill-name>.md
```

Document the skill trigger conditions clearly in the frontmatter (`when_to_use`).

---

### 4. Add or update a steering pack

Steering packs are Markdown files in `steering/`. They provide always-on context to the AI agent (coding standards, AWS guidelines, etc.).

Shared packs (all profiles): `steering/core/`, `steering/git/`, `steering/security/`, etc.
Profile-specific packs: `profiles/<key>/steering/`.

Keep packs focused and under ~200 lines. Split by concern, not by length.

---

### 5. Fix a bug in `install.sh` or `lib/`

`install.sh` is the main entrypoint. Helper functions live in `lib/`. Before submitting a fix:

```bash
# Run the test suite
bash tests/run-tests.sh

# Validate the manifest
bash validations/validate-manifest.sh
```

---

## Pull request checklist

- [ ] Tested locally with `bash install.sh`
- [ ] No hardcoded paths outside of `~/.kiro/orbit` or the repo root
- [ ] New profiles added to `agents-registry.json` and `docs/profile-matrix.md`
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] PR title follows conventional commits: `feat:`, `fix:`, `docs:`, `chore:`

---

## Code style

- Shell: POSIX-compatible where possible; use `#!/usr/bin/env bash` for Bash-specific scripts
- JSON: 2-space indent, no trailing commas
- Markdown: ATX headings (`#`), fenced code blocks with language tags

---

## Questions?

Open a [GitHub Discussion](https://github.com/eliecer2000/kiro-bootstrap/discussions) for design questions, or a [GitHub Issue](https://github.com/eliecer2000/kiro-bootstrap/issues) for bugs.
