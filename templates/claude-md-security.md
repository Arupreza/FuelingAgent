
# Security during development

Installed at user scope, so these apply in every repository.

**security-guidance** (Anthropic) runs by itself, nothing to invoke: a free
regex check on every edit, a model review of each turn's diff, and a deeper
review when Claude commits. Fix what it reports in the same session.

For a check the user asks for, there are two commands and no others:

- `/claude-security` — Anthropic's, a skill rather than a command. The whole
  repository, or this branch, or findings turned into verified patches. Use it
  when the question is "is this codebase safe", since the built-in
  `/security-review` only covers the current branch's diff.
- `/security-audit [scope]` — Phoenix's OWASP Top 10 and ASVS L1 pass. This is
  a user-command shim; the plugin's own namespaced name is
  `/phoenix-security-review:security-audit`, which the shim hands off to.

Pick by the question being asked: Claude Security for "are there real
vulnerabilities here", since it verifies each finding and can patch it;
security-audit for "does this meet OWASP or ASVS", since it reports checklist
coverage. When it is not clear, use Claude Security.

Never reach for `/security-review` to call either one: Claude Code has a
built-in command of that name and Phoenix ships another, so it is ambiguous.

Repository-specific rules go in `.claude/claude-security-guidance.md` in plain
language, and literal patterns in `.claude/security-patterns.yaml`. Both are
additive and read automatically. Do not run phoenix-security-review's own
`install.sh`: its hook preset duplicates security-guidance.
