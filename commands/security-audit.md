---
description: Full OWASP Top 10 + ASVS L1 security assessment of the codebase. Slow + thorough.
argument-hint: "[scope] (e.g. 'backend', 'frontend', 'A01,A03', or empty for full repo)"
---

Run the **Comprehensive Security Assessment** from the phoenix-security-review
plugin.

This command exists only to give that assessment a name you can type. Plugin
commands are namespaced, so the plugin's own command is
`/phoenix-security-review:security-audit`, which does not appear when you type
`/security-audit` and is easy to get wrong. A user command is not namespaced,
so this one answers to the short name and hands straight off to the plugin.

## Instructions

1. Invoke the skill `phoenix-security-review:security-assessment` with the
   Skill tool.
2. If that name does not resolve, read the skill from disk instead — resolve
   the path with a glob rather than a fixed version, because the version
   directory changes on every plugin update:
   `~/.claude/plugins/cache/phoenix-security/phoenix-security-review/*/skills/security-assessment/SKILL.md`
   Use the highest version present, and follow it as written.
3. If neither works, say so plainly and stop. Do not improvise a security
   audit in its place: an assessment that only looks like the real one is worse
   than none, because it carries the same authority without the same checks.
4. Parse `$ARGUMENTS` for scope hints (full / backend / frontend / specific
   OWASP categories). Empty means the whole repository.
5. Follow the skill's workflow: detect stack, run the OWASP Top 10 and ASVS L1
   checks, present results.
6. Report progress as you go: checks completed, findings so far.
7. Final output sections: Executive Summary, Detailed Findings grouped by OWASP
   category, ASVS L1 Compliance Matrix, Remediation Roadmap.

## Scope guard

- This is the heavy assessment. Confirm scope and budget first if either is
  ambiguous.
- Read-only. Generate test files only if the user asks for them.
- For a pull request or diff only, use `/phoenix-security-review:security-0day`.
- Do not route this to the built-in `/security-review`: that covers the current
  branch's diff, not the repository, and answers a different question.
