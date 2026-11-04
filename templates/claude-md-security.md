
# Security during development

Installed at user scope, so these apply in every repository.

- **security-guidance** (Anthropic) — runs by itself, nothing to invoke. A free
  regex check on every edit, a model review of each turn's diff, and a deeper
  agentic review when Claude commits or pushes. Findings come back as
  instructions; fix them in the same session rather than deferring them.
- **claude-security** (Anthropic) — invoke for a whole-repository vulnerability
  scan. Use it when the question is "is this codebase safe", not "is this change
  safe": `/security-review` covers only the current branch's diff.
- **phoenix-security-review** — invoke `security-assessment` for a whole-repo
  AppSec pass against OWASP/ASVS, or `threat-modeling` for STRIDE/DREAD on a new
  design. Do NOT run this plugin's own `install.sh`: its hook preset duplicates
  security-guidance's per-edit scan and diff review.

Write repository-specific rules in plain language in
`.claude/claude-security-guidance.md`, and literal patterns in
`.claude/security-patterns.yaml`. Both are additive and are read automatically.
