---
inclusion: always
---

# Git Workflow

## Commits

- Mensajes en formato conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
- Mantener commits pequenos y atomicos: un cambio logico por commit.
- No mezclar refactors con features en el mismo commit.

## Ramas

- Trabajar en ramas feature: `feat/`, `fix/`, `docs/`, `chore/`.
- Nunca pushear directamente a `main`.
- Mantener ramas cortas: merge frecuente, evitar divergencia larga.

## Operaciones destructivas

- Confirmar antes de `force push`, `rebase` sobre ramas compartidas o `reset --hard`.
- No reescribir historial de ramas ajenas.
- Antes de resincronizar artefactos Orbit, verificar si hay cambios locales no commiteados.

## Pull Requests

- Titulo sigue conventional commits.
- Descripcion incluye contexto, cambios y como probar.
- CI debe pasar antes de merge.

## .gitignore

- Incluir: `node_modules/`, `.env`, `.env.local`, `dist/`, `build/`, `__pycache__/`, `.terraform/`, `cdk.out/`.
- No versionar archivos generados ni dependencias instaladas.
