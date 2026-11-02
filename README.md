# FuelingAgent

The Claude Code toolkit this machine runs on, packaged so a new machine gets
the same setup with one script instead of re-deriving it from scratch.

## What's in here

| # | Name | Type | Source | What it does |
|---|------|------|--------|---------------|
| 1 | superpowers | plugin | `obra/superpowers-marketplace` | Process for real work: brainstorm → plan → execute, TDD, systematic debugging, code review, worktrees |
| 2 | ponytail | plugin | `DietrichGebert/ponytail` | Keeps changes small — smallest diff that fully solves it, no speculative code |
| 3 | andrej-karpathy-skills | plugin | `multica-ai/andrej-karpathy-skills` | Four habits: state assumptions, simplicity first, surgical edits, verifiable success criteria |
| 4 | graphify | CLI + skill | `ChihebBENCHEIKH1/graphify` (skill) + patched CLI (this repo) | Answers "who calls this / what breaks" from a dependency graph instead of grep — **patched here** to actually extract Python (classes, Pydantic DTOs, functions, inheritance, imports), not just Kotlin/TypeScript |
| 5 | archify | skill | `tt-a1i/archify` | Turns a system, pipeline, or schema into an interactive HTML diagram or one-page explainer |
| 6 | asd-ste100 | skill | none — written locally, bundled here | Writes docs in Simplified Technical English: short sentences, one term per thing, active voice |
| 7 | caveman | plugin + CLI | `JuliusBrussee/caveman` | Compresses agent output/input to cut token cost — **see the caveat below before enabling** |

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

1. **Plugins** (superpowers, ponytail, andrej-karpathy-skills, caveman) via
   `claude plugin marketplace add <repo>` + `claude plugin install <name>@<marketplace>`.
2. **Skills from public repos** (archify, graphify's `SKILL.md`) via
   `npx skills add <repo> -g`. Needs Node ≥22 — falls back to the Node 22 this
   script installs in step 4 if your system Node is older (Node 18, the
   current Ubuntu default, is too old for this specific `skills` CLI release).
3. **The one locally-authored skill** (asd-ste100 — no public repo exists for
   it) is copied from `bundled-skills/` straight into `~/.claude/skills/`.
4. **graphify CLI**, patched: installs `graphify-cli==0.1.0` from the pinned
   wheel bundled in `patches/graphify/` (not fetched fresh from PyPI, so a
   future PyPI release can't silently change what gets patched), then applies
   two diffs on top of it. Also installs Node 22 locally
   (`~/.local/node22`, doesn't touch system Node) if needed for step 2 or for
   the optional Caveman CLI below.

**Caveman's CLI itself is not installed automatically** — see the caveat below.

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

## Caveman caveat

Caveman's full CLI is a **proxy**: when its routing is active, your recent
agent messages are sent to Caveman's cloud to pick a model, and on the free
tier that content may be used to improve Caveman's own models — you accept
this at sign-up. If you work on anything proprietary, know this before
enabling it.

It's also genuinely interfered with reliable work in the past: its
`think.shrink` tool-output compression feature started silently truncating
`Read`/`Bash` tool output mid-task (visible as a `<<ccr:...>>` marker instead
of real content), which is actively dangerous for precision work like code
edits — you can end up editing based on a compressed, wrong view of a file
without realizing it. If this happens:

```bash
# kill the running proxy daemon
pkill -f caveman-proxy

# disable the compression feature specifically (keeps the rest working)
PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest tools config set think.shrink false

# disable/re-enable the Claude Code integration if needed
PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest disable claude
PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest enable claude
```

Note: a `tools config set` change doesn't apply retroactively to an
*already-running* Claude Code session — it takes a session restart to fully
clear. If output looks corrupted mid-session even after disabling, fall back
to reading files via `sed -n` / `cat` through a shell tool instead of the
`Read` tool until you can restart.

To install it, after running `./install.sh`:

```bash
PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest setup --install
PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest login
PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest tools config set think.shrink false
PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest enable claude
```

`login` opens a browser for device authorization — that step needs you, it
can't be scripted.

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
└── bundled-skills/asd-ste100/
    └── SKILL.md                    # the one skill with no public repo to pull from
```
