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

## Branching strategy

All changes go through pull requests. Never push directly to `main`.

```
main              ← protected, requires PR + CI green
  └── feat/xxx    ← new features
  └── fix/xxx     ← bug fixes
  └── docs/xxx    ← documentation changes
  └── chore/xxx   ← maintenance, CI, tooling
```

Branch naming follows the conventional commit prefix: `feat/`, `fix/`, `docs/`, `chore/`.

### Workflow

1. Create a branch from `main`: `git checkout -b feat/my-feature`
2. Make your changes and commit using conventional commits
3. Push and open a PR against `main`
4. CI runs automatically (JSON lint, shellcheck, markdownlint, ruff, catalog validation, tests)
5. Fix any CI failures before requesting review
6. After merge, the maintainer tags and releases

### Versioning

This project follows [Semantic Versioning](https://semver.org/):

- `MAJOR` — breaking changes to the pipeline, profile schema, or agent contract
- `MINOR` — new profiles, agents, skills, or features
- `PATCH` — bug fixes, doc updates, CI improvements

Update `CHANGELOG.md` in your PR under an `[Unreleased]` section. The maintainer moves it to the version section at release time.

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

Skills live in `skills/<skill-name>/SKILL.md`. Each skill must include YAML frontmatter for Kiro discovery:

```markdown
---
name: my-skill
description: Short English description of what this skill does and when to use it.
---

# My Skill

Content here...
```

The `name` and `description` fields are required by Kiro to discover and activate skills.

---

### 4. Add or update a steering pack

Steering packs are Markdown files in `steering/`. They provide contextual instructions to Kiro agents.

Each steering file must include YAML frontmatter with an `inclusion` mode:

```markdown
---
inclusion: always
---
```

or for file-pattern-based activation:

```markdown
---
inclusion: fileMatch
fileMatchPattern: ["**/*.ts", "**/*.tsx"]
---
```

Use `always` for universal rules (core, security, git). Use `fileMatch` for runtime/tool-specific packs.

Keep packs focused and under ~200 lines. Split by concern, not by length.

---

### 5. Fix a bug in `install.sh` or `lib/`

`install.sh` is the main entrypoint. Helper functions live in `lib/`. Before submitting a fix:

```bash
# Run the full test suite
bash tests/test-all.sh

# Validate JSON files
python3 -m json.tool agents-registry.json > /dev/null
python3 -m json.tool manifest.json > /dev/null

# Validate the catalog
python3 lib/orbit_catalog.py validate-catalog
```

---

## Pull request checklist

- [ ] Tested locally with `bash install.sh`
- [ ] No hardcoded paths outside of `~/.kiro/orbit` or the repo root
- [ ] New profiles added to `agents-registry.json` and `docs/profile-matrix.md`
- [ ] All JSON files pass `python3 -m json.tool` validation
- [ ] Skills include YAML frontmatter with `name` and `description`
- [ ] Steering files have correct `inclusion` mode (`always` or `fileMatch`)
- [ ] Agent model set to `claude-sonnet-4`
- [ ] Agent includes `"resources": ["skill://.kiro/skills/**/SKILL.md"]`
- [ ] `CHANGELOG.md` updated
- [ ] PR title follows conventional commits: `feat:`, `fix:`, `docs:`, `chore:`

---

## Code style

- Shell: POSIX-compatible where possible; use `#!/usr/bin/env bash` for Bash-specific scripts. Must pass `shellcheck -S warning`.
- JSON: 2-space indent, no trailing commas. Must pass `python3 -m json.tool`.
- Markdown: ATX headings (`#`), fenced code blocks with language tags. Must pass `markdownlint`.
- Python: Must pass `ruff check`.

---

## CI pipeline

Every PR triggers these checks automatically:

| Job | What it checks |
|---|---|
| lint-json | All `.json` and `.kiro.hook` files are valid JSON |
| lint-shell | All `.sh` files pass shellcheck |
| lint-markdown | All `.md` files pass markdownlint |
| lint-python | Python files pass ruff |
| validate-catalog | `orbit_catalog.py validate-catalog` passes |
| validate-skills | All SKILL.md have `name` + `description` frontmatter |
| validate-steering | All steering files have `inclusion` mode |
| test | Full test suite (`tests/test-all.sh`) |

All jobs must pass before a PR can be merged.

---

## Questions?

Open a [GitHub Discussion](https://github.com/eliecer2000/kiro-bootstrap/discussions) for design questions, or a [GitHub Issue](https://github.com/eliecer2000/kiro-bootstrap/issues) for bugs.
