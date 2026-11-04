
# Security during development

Installed at user scope, so these apply in every repository.

**security-guidance** (Anthropic) runs by itself, nothing to invoke: a free
regex check on every edit, a model review of each turn's diff, and a deeper
review when Claude commits. Fix what it reports in the same session.

For a check the user asks for, there are two commands and no others:

- `/claude-security` — Anthropic's. The whole repository, or this branch, or
  findings turned into verified patches. Use it when the question is "is this
  codebase safe", since the built-in `/security-review` only covers the current
  branch's diff.
- `/security-audit [scope]` — Phoenix's OWASP Top 10 and ASVS L1 pass.

Never reach for `/security-review` to call either one: Claude Code has a
built-in command of that name and Phoenix ships another, so it is ambiguous.

Repository-specific rules go in `.claude/claude-security-guidance.md` in plain
language, and literal patterns in `.claude/security-patterns.yaml`. Both are
additive and read automatically. Do not run phoenix-security-review's own
`install.sh`: its hook preset duplicates security-guidance.
