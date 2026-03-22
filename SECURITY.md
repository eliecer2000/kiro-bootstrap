# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 2.1.x   | :white_check_mark: |
| 2.0.x   | :x:                |
| < 2.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in Orbit Bootstrap, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, send an email to **[email]** with:

1. A description of the vulnerability
2. Steps to reproduce the issue
3. The potential impact
4. Any suggested fix (optional)

You will receive an acknowledgment within 48 hours. We will work with you to understand the issue and coordinate a fix before any public disclosure.

## Scope

This policy covers:

- The `install.sh` script and all helper scripts in `lib/`
- Agent, skill, and steering file loading mechanisms
- Profile detection and validation logic
- Any code that executes shell commands or modifies the filesystem

## Best Practices

When contributing to Orbit Bootstrap:

- Never commit secrets, API keys, or credentials
- Never use `eval` on untrusted input
- Validate all user-provided paths before filesystem operations
- Use `--` to separate options from arguments in shell commands
- Prefer quoting variables to prevent word splitting and globbing
