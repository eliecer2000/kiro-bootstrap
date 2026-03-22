## Description

Brief description of the changes.

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] New profile (adds a project profile)
- [ ] New agent/skill (adds an agent or skill)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## Checklist

- [ ] Tested locally with `bash install.sh`
- [ ] No hardcoded paths outside `~/.kiro/orbit` or repo root
- [ ] New profiles added to `agents-registry.json` and `docs/profile-matrix.md`
- [ ] `CHANGELOG.md` updated
- [ ] PR title follows conventional commits (`feat:`, `fix:`, `docs:`, `chore:`)
- [ ] All JSON files are valid (`python3 -m json.tool`)
- [ ] Skills include YAML frontmatter (`name` + `description`)
- [ ] Steering files have correct `inclusion` mode

## Related issues

Closes #
