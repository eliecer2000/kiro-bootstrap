# Orbit Bootstrap

> AWS-first framework for [Kiro](https://kiro.dev) that auto-detects your project type, validates and installs tooling, loads the right agents and skills per profile, and leaves your environment ready to build in seconds.

[![GitHub stars](https://img.shields.io/github/stars/eliecer2000/kiro-bootstrap?style=social)](https://github.com/eliecer2000/kiro-bootstrap/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/eliecer2000/kiro-bootstrap?style=social)](https://github.com/eliecer2000/kiro-bootstrap/network)
[![Last commit](https://img.shields.io/github/last-commit/eliecer2000/kiro-bootstrap)](https://github.com/eliecer2000/kiro-bootstrap/commits/main)
[![Version](https://img.shields.io/badge/version-2.5.0-blue)](https://github.com/eliecer2000/kiro-bootstrap/releases)

🇪🇸 [Documentación en Español](README_es.md)

---

![Orbit Bootstrap Demo](assets/REC-20260318140741.gif)

---

## The problem it solves

Every AWS project starts the same way: copy-paste configs, install linters, hunt for the right agent prompts, wire up hooks, remember which steering rules apply. It is repetitive, error-prone, and burns time before you write a single line of business logic.

Orbit eliminates that friction. It reads your project, resolves the right profile, validates your environment, and loads a curated set of agents, skills, steering rules, and hooks — all tailored to your stack. You go from a blank directory to a fully configured AI-assisted workspace in one command.

---

## How it works

Orbit runs a 6-step pipeline when you prepare a project:

```
1. Session Gates          Ask once per session if you want to prepare the environment
2. Detect / Select Profile  Auto-detect project type or launch an interactive wizard
3. Validate Environment   Check system tools (git, node, python3, aws, terraform)
                          and auto-install missing ones via brew / apt / nvm / corepack
4. Load Artifacts         Copy agents, steering packs, skills, hooks, and extensions
                          from the framework into .kiro/ scoped to your profile
5. Install Tooling        Install project devDependencies (eslint, prettier, vitest,
                          ruff, black, pytest, tsc, mypy) using the detected package manager
6. Write Project State    Write .kiro/.orbit-project.json with profile metadata
```

Profile resolution uses 4 dimensions:

| Dimension   | Options |
|-------------|---------|
| Workload    | backend-api, backend-worker, infra, shared-lib, frontend-amplify |
| Runtime     | typescript, javascript, python |
| Provisioner | cdk, terraform |
| Framework   | react, vue, nuxt (frontend-amplify only) |

Auto-detection evaluates required files, globs, package.json dependencies (wildcard support like @aws-sdk/*), and text patterns. If no profile matches, the wizard kicks in.

---

## Installation

```bash
curl -sL https://raw.githubusercontent.com/eliecer2000/kiro-bootstrap/main/install.sh | bash
```

After installing:

```bash
~/.kiro/orbit/install.sh --help
~/.kiro/orbit/install.sh --update
~/.kiro/orbit/install.sh --resync-project .
~/.kiro/orbit/install.sh --status
~/.kiro/orbit/install.sh --doctor
```

---

## Profiles

### Phase 1 - Active

| Profile | Workload | Runtime | Provisioner |
|---|---|---|---|
| aws-backend-api-typescript | API Backend | TypeScript | - |
| aws-backend-api-python | API Backend | Python | - |
| aws-backend-api-javascript | API Backend | JavaScript | - |
| aws-backend-lambda-typescript | Lambda Worker | TypeScript | - |
| aws-backend-lambda-python | Lambda Worker | Python | - |
| aws-backend-lambda-javascript | Lambda Worker | JavaScript | - |
| aws-infra-cdk-typescript | Infrastructure | TypeScript | CDK |
| aws-infra-terraform | Infrastructure | HCL | Terraform |
| aws-shared-lib-typescript | Shared Library | TypeScript | - |
| aws-shared-lib-python | Shared Library | Python | - |
| aws-shared-lib-javascript | Shared Library | JavaScript | - |

### Phase 2 - Ready (disabled)

| Profile | Framework |
|---|---|
| aws-amplify-react | React |
| aws-amplify-vue | Vue |
| aws-amplify-nuxt | Nuxt |

---

## Agents

14 specialized agents assigned per profile. Each agent has a declared role, responsibilities, and handoff rules so they coordinate automatically without manual wiring.

| Agent | Role |
|---|---|
| orbit | Bootstrap, onboarding, re-sync, and coordination |
| aws-architect | AWS architecture, serverless patterns, design decisions |
| aws-lambda-python | Lambda functions with Python |
| aws-lambda-typescript | Lambda functions with TypeScript / JavaScript |
| aws-api-integration | API contracts, events, auth, integrations |
| aws-cdk | Infrastructure with AWS CDK |
| aws-terraform | Infrastructure with Terraform |
| aws-iam-security | IAM, secrets, encryption, least privilege |
| aws-data-dynamodb | DynamoDB modeling and access patterns |
| aws-observability | Logs, metrics, alarms, traces |
| aws-test-quality | Tests, quality gates, technical acceptance |
| aws-amplify-react | Frontend Amplify + React (phase 2) |
| aws-amplify-vue | Frontend Amplify + Vue (phase 2) |
| aws-amplify-nuxt | Frontend Amplify + Nuxt (phase 2) |

Handoffs are declared in agents-registry.json: orbit to aws-architect when architecture is needed, aws-architect to aws-iam-security when decisions touch IAM or networking, aws-lambda agents to aws-test-quality when tests are required.

---

## Skills

22 local skills organized by domain. Skills are Markdown documents loaded into agent context — they carry domain rules, code examples, anti-patterns, and validation checklists.

| Category | Skills |
|---|---|
| Runtime | typescript-runtime, javascript-runtime, python-runtime |
| Serverless | aws-lambda-typescript, aws-lambda-python, aws-serverless |
| API and Data | aws-api, aws-dynamodb |
| Infrastructure | aws-cdk, aws-terraform, aws-ec2, aws-rds, aws-s3, aws-cloudfront |
| Security | aws-security |
| Operations | aws-observability, aws-cost-operations, aws-diagrams |
| Testing | aws-testing |
| Architecture | aws-architecture |
| Framework | orbit-bootstrap, find-skills |

find-skills is mandatory in every profile — lets agents discover and activate additional skills on demand.

---

## Steering packs

Steering packs are context rules injected into every Kiro session. They encode team standards, AWS best practices, and runtime-specific conventions so agents follow them without being told.

Shared packs in every profile: core, git, security, aws-shared, testing, observability.

Additional packs per profile: runtime-typescript, runtime-python, runtime-javascript, lambda, api, cdk, terraform, amplify.

Three inclusion modes: `always` (every session), `fileMatch` (when a matching file is opened), `manual` (user-triggered via # in chat).

---

## Hooks

Automated hooks run on IDE events with no manual setup. Each profile gets the hooks that match its runtime:

| Runtime | Hooks |
|---|---|
| Node.js (TS/JS) | format on save, lint on save, test after task |
| Python | format on save, lint on save, test after task |
| Terraform | fmt on save, validate after task |

---

## Declarative catalog

Everything in Orbit is declarative. The catalog is the source of truth:

- `manifest.json` — pipeline steps, policies (conflict strategy, remote skills, session opt-out), wizard questions, public commands
- `profiles/*.json` — one file per profile: dimensions, detection rules, tooling, agents, steering, skills, hooks, validations
- `agents-registry.json` — full contract per agent: role, responsibilities, handoffs, skills, model, acceptance checklist, remote skills allowlist

The runtime (`lib/orbit_catalog.py`) reads the catalog and acts. No hardcoded logic.

---

## Catalog validation

```bash
python3 lib/orbit_catalog.py --bootstrap-dir . validate-catalog
```

Cross-validates manifest, profiles, and agents-registry: required fields, agent references, remote skills allowlist, and presence of agent files.

---

## Running from Kiro chat

When Orbit operates from the Kiro chat, it runs the real pipeline before any scaffolding:

```bash
ORBIT_BOOTSTRAP_DECISION=yes \
ORBIT_HOME_DECISION=no \
ORBIT_PROJECT_PROFILE_ID=<profile-id> \
ORBIT_REMOTE_SKILL_DECISION=no \
~/.kiro/orbit/install.sh --resync-project "<path>"
```

Orbit resolves the profile-id internally from the wizard. It never asks for the raw ID, AWS credentials, or CLI profile during normal bootstrap. Scaffolding only starts after `.kiro/.orbit-project.json` exists and all artifact directories are loaded.

---

## Repository structure

```
agents/          Agent JSON definitions
profiles/        Project profiles (detection, tooling, validations, agents, skills)
steering/        Steering packs by technical layer
skills/          Local skills with full documentation
hooks/           Automated hooks by runtime (format, lint, test)
extensions/      Kiro extension packs per profile
lib/             Runtime: pipeline, session, catalog, artifact loading, tooling install
validations/     System tool validation and auto-install
docs/            Technical documentation
templates/       Context templates for project onboarding
tests/           Framework test suite
```

---

## Tests

```bash
bash tests/test-all.sh
```

---

## Documentation

- [Architecture](docs/architecture.md) — Components, declarative catalog, runtime
- [Bootstrap Flow](docs/bootstrap-flow.md) — Step-by-step pipeline
- [Profile Matrix](docs/profile-matrix.md) — Detail per profile
- [Agent Catalog](docs/agent-catalog.md) — Roles, responsibilities, handoffs
- [Authoring Guide](docs/authoring.md) — How to add agents, skills, profiles, steering

---

## Releases

```bash
bash release.sh 2.5.0
```

See [CONTRIBUTING.md](CONTRIBUTING.md#release-process) for details.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add profiles, agents, skills, and steering packs.

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

## Security

To report a vulnerability, see [SECURITY.md](SECURITY.md). Do not open public issues for security concerns.

## License

[MIT](LICENSE) — Eliezer Rangel
