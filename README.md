# FuelingAgent

### One Script, Seven Tools, Every Machine

![Bash](https://img.shields.io/badge/Bash-5.0%2B-4EAA25?logo=gnubash&logoColor=white) ![Node.js](https://img.shields.io/badge/Node.js-22%2B-339933?logo=nodedotjs&logoColor=white) ![Claude Code](https://img.shields.io/badge/Claude%20Code-required-d97757?logo=anthropic&logoColor=white) ![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?logo=python&logoColor=white) ![graphify](https://img.shields.io/badge/graphify-patched-blue) ![License](https://img.shields.io/badge/License-Apache%202.0-D22128)

> **The Claude Code toolkit this machine runs on, packaged to reinstall itself:** process skills (superpowers, ponytail, karpathy-skills), a dependency graph CLI patched to actually understand Python, diagramming, and docs style — one script, idempotent, no manual re-derivation on a new machine.

## What's in here

| # | Name | Type | Source | What it does |
|---|------|------|--------|---------------|
| 1 | superpowers | plugin | `obra/superpowers-marketplace` | Process for real work: brainstorm → plan → execute, TDD, systematic debugging, code review, worktrees |
| 2 | ponytail | plugin | `DietrichGebert/ponytail` | Keeps changes small — smallest diff that fully solves it, no speculative code |
| 3 | andrej-karpathy-skills | plugin | `multica-ai/andrej-karpathy-skills` | Four habits: state assumptions, simplicity first, surgical edits, verifiable success criteria |
| 4 | graphify | CLI + skill | `ChihebBENCHEIKH1/graphify` (skill) + patched CLI (this repo) | Answers "who calls this / what breaks" from a dependency graph instead of grep — **patched here** to actually extract Python (classes, Pydantic DTOs, functions, inheritance, imports), not just Kotlin/TypeScript |
| 5 | archify | skill | `tt-a1i/archify` | Turns a system, pipeline, or schema into an interactive HTML diagram or one-page explainer |
| 6 | asd-ste100 | skill | `danyuchn/asd-ste100-skill` | Writes docs in Simplified Technical English: short sentences, one term per thing, active voice |
| 7 | claude-code-security-review | built-in command + GitHub Action template | `anthropics/claude-code-security-review` | `/security-review` ships with Claude Code already — nothing to install for local use. This repo's CI Action (template bundled here) runs the same AI security review automatically on every PR — **see "Security review" below for per-repo setup** |

## Install

Requires the `claude` CLI already installed ([claude.com/claude-code](https://claude.com/claude-code)).

```bash
git clone <this-repo-url> FuelingAgent
cd FuelingAgent
./install.sh
```

Restart Claude Code (or start a new session) afterward — plugin/skill registration
and `settings.json` changes don't apply to an already-running session.

The script is idempotent: re-running it is safe and just reinstalls/updates
each piece.

### What it actually does, step by step

1. **Plugins** (superpowers, ponytail, andrej-karpathy-skills) via
   `claude plugin marketplace add <repo>` + `claude plugin install <name>@<marketplace>`.
   This step also removes any earlier caveman install (plugin, MCP server,
   proxy daemon, hooks in `~/.claude/settings.json`). It saves a backup of
   the settings file as `settings.json.bak-caveman` first.
2. **Skills from public repos** (archify, asd-ste100, graphify's `SKILL.md`)
   via `npx skills add <repo> -g`. Needs Node ≥22 — falls back to the Node 22
   this script installs in step 3 if your system Node is older (Node 18, the
   current Ubuntu default, is too old for this specific `skills` CLI release).
3. **graphify CLI**, patched: installs `graphify-cli==0.1.0` from the pinned
   wheel bundled in `patches/graphify/` (not fetched fresh from PyPI, so a
   future PyPI release can't silently change what gets patched), then applies
   two diffs on top of it. Also installs Node 22 locally
   (`~/.local/node22`, doesn't touch system Node) if needed for step 2.

## Why graphify needed patching

graphify's installed version (`graphify-cli==0.1.0`) only extracts Kotlin and
TypeScript. Its Python support was a stub that pulled FastAPI routes and
nothing else — no classes, no functions, no inheritance, no imports. For a
Python project, that's an empty graph.

`patches/graphify/` adds a proper Python extractor: classes, Pydantic
`BaseModel` subclasses tagged as DTOs (including through multi-level
inheritance — `class Leaf(Middle)` where `Middle(Base)` where
`Base(BaseModel)` all resolve to `dto`), module-level functions, `EXTENDS`
edges from class inheritance, and `DEPENDS_ON` edges from resolved imports.

Three real bugs were found and fixed by an independent review before this was
considered done — worth knowing if you ever extend this patch further:

1. **Cross-repo false edges.** The first version resolved import/inheritance
   names against a single global dict, so two unrelated repos each defining
   their own `Strict` class could produce a fabricated edge between them.
   Fixed: resolution is now repo-scoped — a name only resolves against a
   candidate in the *same* repo as the reference; a cross-repo name collision
   produces no edge at all rather than a guess.
2. **Order-dependent misses.** The original design resolved relationships
   *while* declaring, one file at a time, so a file importing a symbol
   declared in a file visited later in the walk silently got no edge — about
   a third of real imports in practice. Fixed: declaration and resolution are
   now two separate passes; resolution only starts once every file's
   declarations are indexed, so file-processing order no longer matters.
3. **EXTENDS self-loops.** A class was indexed before its own base classes
   were resolved, so `class Path(pathlib.Path)` could resolve its own `Path`
   base to itself. Fixed: self-reference is now explicitly excluded during
   resolution.

Applying `patches/graphify/*.diff` to a *different* version of
`graphify-cli` than 0.1.0 may not apply cleanly — that's why the pinned wheel
is bundled instead of relying on `pip install graphify-cli` pulling whatever
is current on PyPI.

### Common mistake: don't hardcode `GRAPHIFY_ROOT`

graphify auto-discovers its workspace root by walking up from the current
directory looking for ≥2 sibling directories that look like projects
(`pyproject.toml`, `package.json`, `settings.gradle.kts`, `.git`, etc.). This
already works correctly for any workspace, on any machine, with no
configuration.

Don't set `GRAPHIFY_ROOT`/`GRAPHIFY_CACHE`/`GRAPHIFY_KB` as fixed paths in
your shell profile — that was a bug this toolkit's history actually hit:
a previous setup hardcoded `GRAPHIFY_ROOT` to one specific workspace's path,
which then silently broke on every *other* workspace once that one machine's
folder layout changed. Let auto-discovery do its job; only set these as
one-off environment variables for a single command if you genuinely need to
override the root for a specific run.

### Using it

```bash
cd <your workspace root>          # the directory containing your projects
graphify build                    # first run: builds the graph
graphify explain SomeClassName    # full briefing: what it is, who calls it, what it depends on
graphify impact SomeClassName     # blast radius if you change it
graphify find SomeName            # locate anything by name
```

Any Python project needs a `pyproject.toml` (even an empty `[project]`
stanza) to be picked up as a repo — `touch pyproject.toml` with a minimal
`[project]` table if the project doesn't have one yet.

## Why caveman was removed

Earlier versions installed the `caveman` plugin (and, optionally, its CLI)
to cut token cost. In practice it raised cost and caused errors:

1. **Hooks on every event.** The CLI's `enable claude` wired
   `caveman-proxy native-hook` into ten hook events in
   `~/.claude/settings.json` (`SessionStart`, `UserPromptSubmit`,
   `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PreCompact`,
   `SubagentStart`, `SubagentStop`, `Stop`, `SessionEnd`). Every tool call
   ran the proxy.
2. **Extra context on every turn.** The plugin injected a "caveman mode"
   instruction block into each user turn, and a long skill text at session
   start. That text is billed again on every request.
3. **Content leaves the machine.** With routing active, recent agent
   messages go to Caveman's cloud to pick a model. On the free tier that
   content may be used to train Caveman's models.
4. **Breaks Remote Control.** `enable claude` can point
   `ANTHROPIC_BASE_URL` at a local proxy (`127.0.0.1:8787`). Remote Control
   refuses any non-default base URL.
5. **Truncated tool output.** Its `think.shrink` feature replaced
   `Read`/`Bash` output with `<<ccr:...>>` markers mid-task. Edits made from
   that view can be wrong.

Re-running `./install.sh` removes all of it. After that, restart Claude
Code: a running session keeps the hooks it loaded at start. The CLI's
binaries stay in `~/.caveman/` but nothing calls them; delete that folder
by hand if you want the disk space back.

## Security review

`/security-review` ships with Claude Code by default — just run it in any
repo, no install needed. That's what `claude-code-security-review` (the
official Anthropic repo) backs; its slash command is already built in.

What the repo adds beyond the built-in command is a **GitHub Action** for
automated review on every PR. To wire it into a repo:

```bash
mkdir -p .github/workflows
cp <this-repo>/templates/github-actions/security-review.yml .github/workflows/
git add .github/workflows/security-review.yml
git commit -m "ci: add AI security review on PRs"
```

Then add a `CLAUDE_API_KEY` repo secret on GitHub (Settings -> Secrets and
variables -> Actions) — the key needs both Claude API and Claude Code usage
enabled.

**Not hardened against prompt injection** — only run it on trusted PRs.
For a public repo, require maintainer approval for workflow runs from
forks (GitHub's own setting, not this template's).

## Repo layout

```
FuelingAgent/
├── install.sh                      # run this
├── install-graphify-patch.sh       # graphify CLI install + patch (called by install.sh)
├── scripts/
│   └── install-node22.sh           # Node 22 install, checksum-verified against nodejs.org
├── patches/graphify/
│   ├── graphify_cli-0.1.0-py3-none-any.whl   # pinned wheel, so the diffs apply to a known base
│   ├── extract.py.diff             # Python declaration + relationship extraction
│   └── workspace.py.diff           # deterministic file-walk ordering
└── templates/github-actions/
    └── security-review.yml         # per-repo opt-in CI, see "Security review" above
```
