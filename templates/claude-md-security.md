# Security during development

Installed at user scope, so these apply in every repository. **Nothing runs by
itself.** No scan on edit, no review on commit, no model call the user did not
ask for. Security here is a check the user runs, which is also when the
findings are worth reading.

There are two commands and no others:

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

Run one before a release, before handing a repository to someone else, and
after any change to authentication, input handling or anything that touches a
secret. Not on every commit — that was tried, as a plugin that launched an
agentic reviewer on each one, and the cost was out of all proportion to a pass
that nobody reads mid-task.

Repository-specific rules go in `.claude/claude-security-guidance.md` in plain
language, and literal patterns in `.claude/security-patterns.yaml`. Both are
additive and read automatically. Do not run phoenix-security-review's own
`install.sh`: its preset puts a scan on every edit and a review on every turn,
which is exactly what this toolkit refuses to carry.
