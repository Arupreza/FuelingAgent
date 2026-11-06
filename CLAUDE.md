# FuelingCodeAgent

Setup as code: one script installs this machine's Claude Code, Codex,
Cursor and Antigravity toolkit (the last two as skills only) -- plugins, skills, security review, the graphify dependency graph, and
the hooks that make them fire by themselves. Nothing here runs during normal
coding; it only installs.

## Running it

```bash
./install.sh --claude          # Claude Code only
./install.sh --codex           # Codex only
./install.sh --claude --codex  # both
./install.sh --cursor --antigravity   # skills into ~/.agents/skills, ~/.gemini/config/skills
```

It is idempotent: a re-run leaves what already succeeded alone. Shell only --
no build, no package manager, no test suite. The check before committing is
`bash -n` on every script you touched; hooks are tested by piping a hook
payload to them, as the comments in `hooks/` describe.

## Layout

| Path | What it holds |
|------|---------------|
| `install.sh` | the entry point, in seven numbered steps |
| `install-graphify-patch.sh` | builds graphify in its own venv, with `patches/` applied |
| `scripts/` | the pinned private Node install |
| `hooks/` | the hooks installed into `~/.claude/hooks` |
| `commands/` | user commands installed into `~/.claude/commands` |
| `templates/` | the CLAUDE.md security section, the PR workflow |
| `patches/` | diffs applied to graphify's source |

## Conventions that are easy to get wrong

- **A hook beats a skill for anything that must always happen.** A skill
  description is advice the model may drop; a hook is code that runs. That is
  the reason `hooks/` exists at all.
- **Everything pins its source.** Node by version and SHA-256, the skills CLI
  by version, the GitHub Actions by commit. Plugins cannot be pinned -- no CLI
  flag accepts a ref -- so step 3 records each marketplace's commit in
  `~/.claude/fuelingcodeagent-sources.lock` and reports drift instead.
- **Fail closed, and say so.** A failing step calls `note_failure`, never
  `|| true`; the summary at the end lists what did not install and exits 1.
  Never swallow a sub-script's exit status.
- **Every write is merged, not replaced.** `settings.json` and `CLAUDE.md` get
  jq merges and appends guarded by an idempotency check, and the backup is
  taken inside the branch that writes -- taken earlier, a re-run would copy the
  already-modified file over the only pre-change copy.
- **`~/.claude/settings.json` may be a symlink.** Follow it with `readlink -f`
  before writing, or the merge replaces the link.
- The templates and the live `~/.claude/CLAUDE.md` section must stay
  byte-identical.

## Work log

- 2026-11-05: added the CLAUDE.md work-log hooks -- `journal-stamp.sh` records
  that a session edited a file, `journal-stop.sh` blocks the end of the turn
  once to get the entry written, and every project now gets a CLAUDE.md on its
  first session. Extracted the shared "is this software work" gate into
  `gf_code_repo`, and replaced step 7's inline jq merge with an idempotent
  `add_hook`.
- 2026-11-05: removed Anthropic's `security-guidance` from the toolkit and
  added its removal to step 5. It launched an agentic Opus reviewer on every
  commit and push -- five subprocesses in sixteen minutes on a real session,
  none of it in the transcript. Security here is on demand only now. Measure
  before blaming context: the loaded descriptions of all six plugins came to
  ~3.7k tokens, so they were never the cost.
- 2026-11-05: the journal hooks now ask for direction, not only history -- a
  '## How things are done here' section holding each repeatable task as an
  instruction, because a dated log line does not say which command, inputs or
  format produced the thing.
- 2026-11-05: the journal hooks target the **project** directory, not the git
  root -- `gf_project_dir` walks up to the first directory with a CLAUDE.md or
  a project marker. Found by checking a real monorepo: every project in it
  would otherwise have shared one file at the repository root.
