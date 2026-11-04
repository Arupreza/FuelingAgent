
# Security during development

Installed at user scope, so these apply in every repository.

- **security-guidance** (Anthropic) — runs by itself, nothing to invoke. A free
  regex check on every edit, a model review of each turn's diff, and a deeper
  agentic review when Claude commits or pushes. Findings come back as
  instructions; fix them in the same session rather than deferring them.
- **claude-security** (Anthropic) — invoke for a whole-repository vulnerability
  scan. Use it when the question is "is this codebase safe", not "is this change
  safe": `/security-review` covers only the current branch's diff.
- **phoenix-security-review** — `/security-audit [scope]` for a whole-repo
  OWASP/ASVS pass, `/security-0day` for a fast branch diff, `/threatmodel
  [scope]` for STRIDE/DREAD. Do NOT run this plugin's own `install.sh`: its hook
  preset duplicates security-guidance's per-edit scan and diff review.

Call the deep ones as `/claude-security` (add `scan the whole repo at high`,
`scan my branch` or `suggest patches` to skip the menu). Do not use
`/security-review` to reach either plugin: Claude Code has a built-in command
of that name and Phoenix ships another, so the name is ambiguous. Use
`/security-audit` or `/claude-security` instead.

Write repository-specific rules in plain language in
`.claude/claude-security-guidance.md`, and literal patterns in
`.claude/security-patterns.yaml`. Both are additive and are read automatically.
