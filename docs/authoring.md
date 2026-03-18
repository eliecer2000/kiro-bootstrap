# Authoring Guide

## Agentes

Todo agente nuevo debe:

- tener archivo en `agents/`
- estar registrado en `agents-registry.json`
- declarar `role`, `responsibilities`, `ownedTasks`, `handoffs`, `supportedProfiles`, `steeringPacks`, `localSkills`, `remoteSkills`, `modelDefault`, `acceptanceChecklist`
- estar documentado y cubierto por tests

## Steering

Crear packs pequenos y reutilizables en `steering/`, orientados por capa tecnica y no por proyecto aislado.

## Skills

- Skills locales viven en `skills/`
- Skills remotas deben pasar por el allowlist de `agents-registry.json`

## Perfiles

Cada perfil nuevo debe vivir en `profiles/` y declarar deteccion, tooling, agentes, hooks, steering packs y validaciones.
