# Orbit Architecture

Orbit se compone de un catalogo declarativo y un runtime pequeno:

- `manifest.json` define pipeline, politicas, wizard y comandos publicos.
- `profiles/*.json` describen perfiles, deteccion, tooling, agentes, hooks, steering, skills y validaciones.
- `agents-registry.json` mantiene el contrato detallado de cada agente y el allowlist de skills remotas.
- `lib/orbit_catalog.py` es el parser unico para manifiesto, perfiles y registry.
- `lib/pipeline.sh`, `lib/session.sh`, `lib/load-artifacts.sh` y `validations/common.sh` ejecutan la sesion de Orbit.

Objetivos de arquitectura:

- Unica fuente de verdad por perfil.
- Sin parseo JSON fragil por `grep`.
- Carga de hooks solo cuando el perfil los declara.
- Rebrand completo a Orbit.
