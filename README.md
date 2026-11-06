# FuelingCodeAgent

**One installer that sets up the same agent toolkit for Claude Code and OpenAI Codex.**

![Bash](https://img.shields.io/badge/Bash-5.0%2B-4EAA25?logo=gnubash&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-22%2B-339933?logo=nodedotjs&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?logo=python&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-supported-d97757?logo=anthropic&logoColor=white)
![Codex](https://img.shields.io/badge/OpenAI%20Codex-supported-412991?logo=openai&logoColor=white)
![License](https://img.shields.io/badge/License-Apache%202.0-D22128)

One command installs an all-in-one toolkit for coding work:

- **development** — process skills for planning, TDD, debugging and review;
- **security** — two commands for a whole-repo audit, run when you ask; no
  model call fires on its own;
- **a dependency graph** — a cross-repo graph that answers who-calls-what and
  what-a-change-breaks, and refreshes itself;
- **a CLAUDE.md per project** — written on the first session that changes
  code, and its work log appended at the end of every session after that.

Works for Claude Code and OpenAI Codex. Re-run the installer any time to update
or repair an install; it never duplicates one.

## Contents

- [Toolkit](#toolkit)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [What the installer does](#what-the-installer-does)
- [Security plugins](#security-plugins)
  - [Asking for a check](#asking-for-a-check)
- [Context cost](#context-cost)
- [Session hooks](#session-hooks)
- [Supply chain](#supply-chain)
- [graphify: Python support](#graphify-python-support)
- [Security review](#security-review)
- [Third-party copies and credits](#third-party-copies-and-credits)
- [Updating and removal](#updating-and-removal)
- [Repository layout](#repository-layout)
- [License](#license)

## Toolkit

| Tool | Type | Source | Purpose | Claude Code | Codex |
|------|------|--------|---------|:-----------:|:-----:|
| superpowers | plugin | [`obra/superpowers-marketplace`](https://github.com/obra/superpowers-marketplace) | Structured workflow: brainstorm, plan, execute, TDD, systematic debugging, code review | ✓ | ✓ |
| ponytail | plugin | [`DietrichGebert/ponytail`](https://github.com/DietrichGebert/ponytail) | Smallest complete change; no speculative code | ✓ | ✓ |
| andrej-karpathy-skills | plugin | [`multica-ai/andrej-karpathy-skills`](https://github.com/multica-ai/andrej-karpathy-skills) | State assumptions, keep it simple, make surgical edits, define success criteria | ✓ | ✓ |
| graphify | CLI + skill | [`ChihebBENCHEIKH1/graphify`](https://github.com/ChihebBENCHEIKH1/graphify) + patch in this repo | Answers "who calls this" and "what breaks" from a dependency graph; patched to extract Python | ✓ | ✓ |
| archify | skill | [`tt-a1i/archify`](https://github.com/tt-a1i/archify) | Interactive HTML diagrams and one-page explainers | ✓ | ✓ |
| asd-ste100 | skill | [`danyuchn/asd-ste100-skill`](https://github.com/danyuchn/asd-ste100-skill) | Documentation in Simplified Technical English | ✓ | ✓ |
| devops-handover | first-party skill | this repository | Audit a codebase the way the team who must deploy it will, before handing it over. Evidence-based: PASS/FAIL/N/A with a command and its output, then GO / CONDITIONAL GO / BLOCK | ✓ | ✓ |
| pg-aiguide | 3 of its 11 skills | [`timescale/pg-aiguide`](https://github.com/timescale/pg-aiguide) | Postgres and pgvector practice: table design, HNSW and halfvec tuning, BM25 + vector hybrid search with RRF. See [note](#pg-aiguide) | ✓ | ✓ |
| claude-security | plugin | [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) | Multi-agent whole-repository vulnerability scan, invoked on demand | ✓ | — |
| phoenix-security-review | plugin | [`Security-Phoenix-demo/security-skills-claude-code`](https://github.com/Security-Phoenix-demo/security-skills-claude-code) | Whole-repo OWASP/ASVS assessment and STRIDE/DREAD threat modelling. See [note](#security-plugins) | ✓ | — |
| security review | command + GitHub Action | [`anthropics/claude-code-security-review`](https://github.com/anthropics/claude-code-security-review) | AI security review of changes and pull requests | ✓ | see [below](#security-review) |

## Requirements

- Linux (x86_64 or arm64) with Bash 5+, `git`, `curl` and Python 3.11+.
  macOS works if Node.js 22+ is already installed.
- At least one agent CLI on your `PATH`:
  - [Claude Code](https://claude.com/claude-code) (`claude`)
  - [OpenAI Codex CLI](https://github.com/openai/codex) (`codex`), for example `npm install -g @openai/codex`
- Node.js 22+. If your system Node is older, the installer puts Node 22 in
  `~/.local/node22` and does not change the system Node.

## Quick start

```bash
git clone https://github.com/Arupreza/FuelingCodeAgent.git
cd FuelingCodeAgent
./install.sh
```

With no options, the installer sets up every agent it finds on your `PATH`.
To choose one agent:

```bash
./install.sh --claude    # Claude Code only
./install.sh --codex     # Codex only
```

After the install:

- **Claude Code:** restart it, or start a new session.
- **Codex:** start a new thread, open `/hooks`, and trust ponytail's two
  lifecycle hooks.

## What the installer does

| Step | Action | Claude Code | Codex |
|------|--------|-------------|-------|
| 1 | Node.js 22 | Uses system Node if it is 22+; otherwise installs to `~/.local/node22` (checksum-verified) | same |
| 2 | Plugins | `claude plugin marketplace add` + `claude plugin install` | `codex plugin marketplace add` + `codex plugin add` |
| 3 | Skills | `npx skills add <repo> -g -a claude-code` → `~/.claude/skills`, plus this repository's own `skills/*/SKILL.md` copied in directly (no Node needed for those) | `npx skills add <repo> -g -a codex` → `~/.agents/skills` |
| 4 | graphify CLI | Installs the pinned `graphify-cli==0.1.0` wheel into `~/.venvs/graphify`, applies the Python patches, links `~/.local/bin/graphify` | shared |
| 5 | Cleanup | Removes caveman, which earlier versions of this toolkit installed. Backs up `~/.claude/settings.json` to `settings.json.bak-caveman` before it edits the file | same |

| 6 | Auto-calling | Appends a "Security during development" section to `~/.claude/CLAUDE.md` so the on-demand security skills get reached for without being asked, and installs the `/security-audit` command shim. Skipped if the section is already there; backs up to `CLAUDE.md.bak-security` | n/a |

| 7 | Session hooks | Installs four hooks to `~/.claude/hooks/` and merges them into `settings.json`: the code graph announces itself every session, and every code repository keeps a `CLAUDE.md` with a current work log. Needs `jq`; backs up to `settings.json.bak-fca-hooks` | n/a |

| 8 | Context cost | Sets `effortLevel` to `medium` if it is unset or `high`, switches the two security plugins off until asked for, and installs `~/.claude/context-cost.sh`. An explicit choice of yours (`low`, `max`) is left alone; backs up to `settings.json.bak-fca-cost` | n/a |

Make sure `~/.local/bin` is on your `PATH` so the `graphify` command is found.

## Security plugins

**Nothing here runs by itself.** Both plugins are invoked, never automatic.

**Both are installed but switched OFF by default**, because "on demand" is not
free. A skill's description has to be in context for the model to know the
skill exists, so the two together cost **~1,858 tokens in every request** —
more than a well-kept `CLAUDE.md` — for tools most people run a few times a
week. Step 8 turns them off; turning one back on is a one-line settings change.

Re-enable before a release, a handover, or any change to authentication,
input handling or a secret:

```bash
python3 - <<'EOF'
import json, os
p = os.path.realpath(os.path.expanduser("~/.claude/settings.json"))
d = json.load(open(p))
d["enabledPlugins"]["phoenix-security-review@phoenix-security"] = True
d["enabledPlugins"]["claude-security@claude-plugins-official"] = True
json.dump(d, open(p, "w"), indent=2)
EOF
```

Restart the session, run the check, then set them back to `false`.

| Plugin | Runs | Cost |
|--------|------|------|
| claude-security | when invoked | one deep multi-agent scan |
| phoenix-security-review | when invoked | one pass |

That is a deliberate change. This toolkit shipped Anthropic's
`security-guidance` for a while, which reviews code as it is written and needs
no asking. The reviews were good. The price was not: it launched an agentic
reviewer on **every `git commit` and every `git push`** — a full Claude Code
subprocess on Opus, up to 18 turns, re-reading the repository, default ceiling
20 reviews an hour, and a push re-reviewing the whole commit range. Measured on
one real session: five launches in sixteen minutes from three commits and a
push, none of it visible in the transcript. Step 5 of the installer now removes
it, along with its ~380 MB state directory.

If you want it back, it is one command — `claude plugin install
security-guidance@claude-plugins-official` — and these are the knobs worth
knowing: `ENABLE_COMMIT_REVIEW=0` drops the agentic pass, `SG_AGENTIC_MODEL`
and `SECURITY_REVIEW_MODEL` move it off Opus, `MAX_COMMIT_REVIEWS_PER_SESSION`
caps it, `SG_PUSH_SWEEP=0` stops push re-reviewing, and
`SECURITY_GUIDANCE_DISABLE=1` switches the whole plugin off without
uninstalling.

### Asking for a check

```
/security-audit        # OWASP Top 10 + ASVS L1
/claude-security       # whole repo, your branch, or patches
```

`/security-audit` is a shim this repo installs to `~/.claude/commands/`. Plugin
commands are namespaced, so Phoenix's own name is
`/phoenix-security-review:security-audit`, which never appears when you type
`/security-audit`; the shim takes the short name and hands straight off to the
plugin's assessment skill. `/claude-security` is a skill rather than a command,
so it answers to its own name already.

Both take an optional scope (`... security-audit backend`) and both answer to
plain English, so "run a Claude Security scan on the whole repo" works too.

Run one before a release, before handing a repository over, and after any
change to authentication, input handling or anything touching a secret.

**Which one.** `/claude-security` asks *are there real vulnerabilities*: it
verifies each finding and can write the patch. `security-audit` asks *does this
meet the standard*: checklist coverage, not exploitability. In doubt, the first.

Do **not** use `/security-review`. Claude Code ships a built-in command of that
name and Phoenix ships another, so it is ambiguous.

### Two traps

- **Never run `phoenix-security-review`'s own `install.sh`.** Its preset wires
  a scanner into `PostToolUse` and a review into `Stop` — a model call per
  file-changing turn, which is the cost this toolkit dropped
  `security-guidance` to avoid. Its hooks are opt-in and stay unwired after a
  plain marketplace install, which is how it is installed here.
- **A security pass nobody reads is pure cost.** The reason these are
  on-demand is not that automatic review is worthless; it is that findings
  arriving mid-task get acknowledged and forgotten. Run a pass at a point
  where you will act on it.

Only one of Phoenix's six plugins is installed. The rest are in `/plugin menu`:
`phoenix-sast-rules` needs semgrep on `PATH`, `phoenix-prd-pipeline` overlaps
superpowers' planning skills, and the other two are threat-intelligence and
browser-automation tools rather than coding aids.

## pg-aiguide

Three skills of the eleven: `pgvector-semantic-search`,
`postgres-hybrid-text-search` and `design-postgres-tables`. ~600 tokens of
description between them, bodies loaded only when used.

Two routes were rejected, both of which the project's own README suggests:

- **`--skill postgres`**, its router skill. Installed on its own it arrives
  without the `references/` directory it points at, so all nine of its links
  resolve to nothing. Verified by installing it: nine dead links, zero
  reference files. Usable only through the plugin, which bundles them.
- **the Claude Code plugin** (`claude plugin marketplace add timescale/pg-aiguide`).
  It wires no hooks, so it costs nothing per turn, but it registers a remote
  MCP server at `mcp.tigerdata.com` and installs all eleven skills, four of
  them TimescaleDB and one PostGIS. Take this route if you want the
  version-aware Postgres manual search; skip it if an external service in the
  loop is the wrong trade.

The three skills are self-contained: no `references/`, nothing to fetch.

## Context cost

Everything in a session's system prompt is re-sent on **every** request, so the
default setup is a standing charge on all future turns. Step 8 addresses the two
levers that dominate, and ships the script that makes the rest measurable.

```bash
bash ~/.claude/context-cost.sh       # run it from the project you are working in
```

```
Per-request context (approx tokens, 4 bytes/token):
  project CLAUDE.md                        1892 tokens
  user CLAUDE.md                            836 tokens
  MEMORY.md                                 646 tokens
  plugin skill descriptions                1054 tokens
  plugin agent descriptions                   0 tokens

Cost multipliers (these matter more than any of the above):
  model                                  opus
  effortLevel                            medium
  enabled plugins                        3 of 5 enabled
```

### The method, in order

1. **Check the multipliers first.** `effortLevel` applies to every turn,
   including "is it done yet?" — it outweighs every file in the list above.
   `medium` by default, raised per session with `/effort high` for schema
   design, debugging and audits.
2. **Then the biggest file.** A project `CLAUDE.md` over ~2,000 tokens is worth
   splitting. On one real project it had reached 11,462 tokens, two thirds of
   that added in two days of appending notes after each task.
3. **Then what you are not using.** A disabled plugin costs nothing; an enabled
   one costs its skill and agent descriptions on every request whether or not
   you invoke it.

### Splitting a CLAUDE.md without losing anything

`templates/claude-md-lean.md` is the rule to paste at the top of a project's
`CLAUDE.md`. The split is:

| File | Holds | Loaded |
|------|-------|--------|
| `CLAUDE.md` | hard rules, paths, commands, one-line gotchas | every request |
| `docs/ENGINEERING_NOTES.md` | why each rule exists, what it cost to learn | on demand |
| `docs/WORKLOG.md` | dated history | on demand |

**Nothing is deleted, only moved** — the detail is still written down, just not
re-sent when nobody is reading it. Measured on one project: 15,817 → 4,428
tokens per request, a 72% cut.

**What stays inline whatever it costs:** rules that prevent damage. "Never run
`git add -A` here", "never walk the data disk", "nothing connects as the
superuser". A rule you have to look up is a rule you break before you notice it
applies. The *explanation* moves; the rule does not.

If the notes grow large, give them a project skill at
`.claude/skills/<name>/SKILL.md`: it costs only its description per request and
loads its body when invoked — an index in context, the detail fetched on
demand. Point it at the notes and tell the reader to grep the headings and read
one section rather than the file.

## Session hooks

A skill description is advice the agent may or may not act on. A hook is code
that runs. Anything that has to happen every time belongs in a hook, and these
four cover the two things that kept not happening.

| Hook | Event | Does |
|------|-------|------|
| `graphify-session.sh` | `SessionStart` | names the graph and the CLI, every new session |
| `graphify-reminder.sh` | `UserPromptSubmit` | repeats the pointer when a caller, impact or dependency question is actually asked, since in a long session the SessionStart line drifts far up the context |
| `journal-stamp.sh` | `PostToolUse` (`Write`, `Edit`) | records that this session changed a file in this project |
| `journal-stop.sh` | `Stop` | if it did, holds the turn open once to get `CLAUDE.md` written or brought up to date |

`graphify-lib.sh` holds the gate all four share. Plain shell: no model call, no
network, nothing when silent.

The graphify pair prints only when all three hold: inside a git repository,
that repository holds source files (`node_modules`, `venv`, `site-packages`,
`dist`, `build`, `__pycache__` pruned), and `graphify root` recognises a
workspace. The journal pair needs the first two. A notes folder, a data
directory or a docs-only repository costs nothing.

### It refreshes itself

graphify checks freshness on every query and rebuilds when source files move,
so the hooks deliberately do no refreshing of their own. An earlier version ran
a one-hour timer; it duplicated the tool and rebuilt when nobody was asking.

### Where the graph lives

graphify is **workspace**-scoped, not per-project: `graphify root` reports the
workspace it builds, which in a monorepo is the whole tree, not the sub-project
you are in, and not `git rev-parse --show-toplevel`.

| Artefact | Path |
|----------|------|
| Graph and caches | `~/.cache/graphify/<workspace>-<hash>/` |
| Readable summary | `<workspace>/ARCHITECTURE_GRAPH.md` |

A `graphify-out/` directory is **not** current output — it is left over from an
older version, never written again, and anything reading it answers from a
months-old graph. Delete any you find.

### The CLAUDE.md work log

Every project you write code in gets a `CLAUDE.md`. The next session reads it
before anything else, because Claude Code loads `CLAUDE.md` from the working
directory upwards on its own — there is nothing to invoke.

The file carries two kinds of thing, and the second is the point:

| Section | Holds | Answers |
|---------|-------|---------|
| `## How things are done here` | the repeatable tasks of this project as instructions — the command and its arguments, the inputs, where output goes, the format that was chosen, the trap that cost time | "make that thing again" |
| `## Work log` | one dated line per session | "when did this change" |

A log alone is not enough. `- 2026-11-05: built the report page` proves it
happened once; it does not say which tool, which inputs or which layout, so
the same request a fortnight later comes out differently. Direction is what
makes it come out the same, which is why the hook asks for both and treats the
second as optional — a session that settled nothing durable adds no
instruction.

**Project, not git root.** A monorepo holds several projects in one repository,
and one file at the top would describe none of them — the real projects are
the sub-directories, not the repository root. So the hooks walk up
from the working directory to the git root and take the first directory that
already has a `CLAUDE.md`, or else looks like a project root (`pyproject.toml`,
`package.json`, `Cargo.toml`, `go.mod`, `setup.py`, `pom.xml`, `build.gradle`,
`Gemfile`, `composer.json`). The git root is the fallback. Sibling projects in
one repository never trigger for each other: the stamp name carries the project
directory.

Keeping it current is the part a rule cannot do. The end of a session is when
the context is fullest and a written instruction is most likely to be dropped —
so this is a `Stop` hook instead, which runs after the agent believes it has
finished and hands the turn back with one request: log what changed.

It is deliberately narrow:

- **Only when work happened.** A dirty working tree proves nothing; a
  repository can sit dirty for months. The signal is an edit made in *this*
  session, stamped by `journal-stamp.sh` into `.git/fuelingcodeagent/` — inside
  `.git`, so it is never committed and never shows in `git status`.
- **Only for software work.** Same gate as the graphify hooks: a git
  repository that holds source files. A notes or data directory gets nothing.
- **Once per session, and it cannot loop.** The stamp is removed before the
  hook asks, so an agent that ignores the request is not asked twice and the
  session always ends.
- **Nothing to say, nothing said.** An entry already dated today, or a session
  that changed no file, and the hook exits silently.

One limit worth knowing: it keys on the working directory, not on the path of
the file edited. A session anchored in one project that reaches across into a
sibling logs the entry in the first.

Turn it off alone with `jq 'del(.hooks.Stop)'`, and the stamp with
`jq 'del(.hooks.PostToolUse)'`.

They run in **every** repository you open, including one you have just cloned
and not read. The hooks execute no code from the repository, but they do point
the agent at its `ARCHITECTURE_GRAPH.md`, and a hostile repository could put a
prompt injection in that file. The same is true of any file the agent reads, so
this adds no new exposure — but in an untrusted checkout, read before you act.

### Turning them off

`/hooks`, or `jq 'del(.hooks.SessionStart, .hooks.UserPromptSubmit, .hooks.PostToolUse, .hooks.Stop)'`
on `~/.claude/settings.json`. Step 7 backs up to `settings.json.bak-fca-hooks`
and merges per script name, so a re-run never adds a second copy — and a hook
added to the toolkit later is wired without re-adding the others.

## Supply chain

Worth knowing before you run the installer. What is pinned:

| Source | Pinned? |
|--------|---------|
| graphify wheel | yes, bundled in `patches/graphify/` |
| Node tarball | yes, SHA-256 in `scripts/install-node22.sh` |
| `skills` npm package | yes, `skills@1.7.6` |
| GitHub Action template | yes, commit SHAs |
| the plugin and skill repos | **no** — but a pinned copy of each is in [`third_party/`](#third-party-copies-and-credits), used if upstream fails |

`claude plugin marketplace add` takes a repository's default branch and has no
flag to pin a ref, so every run installs whatever is on those branches now, and
that code runs as plugins, skills and hooks with the agent's full permissions.
A re-run is therefore not only an update — it is a fresh pull.

Since it cannot be pinned, it is tracked. The installer records the commit each
marketplace resolved to in `~/.claude/fuelingcodeagent-sources.lock` and reports
anything that moved:

```
--> third-party sources installed (unpinned upstream: these can change)
      karpathy-skills            2c606141936f  unchanged
      ponytail                   16352ac229eb  CHANGED from 9f1e02ab4c7d
```

A change is not a problem by itself — upstreams release. Silent change is the
problem, so read the diff before trusting it:

```bash
git -C ~/.claude/plugins/marketplaces/<name> log <old>..<new>
```

If a step fails, the installer says so and exits non-zero, naming each failure.
Nothing aborts around that summary, so a partial install never looks like a
complete one. A failed security plugin is not installed whatever the CLAUDE.md
section claims — confirm with `claude plugin list`.

The Node check requires the version the pinned `skills` package actually needs
(`>=22.20.0`), not merely Node 22, and reports a `node` that exists but cannot
run rather than quietly installing a second one.

## graphify: Python support

The released `graphify-cli==0.1.0` extracts Kotlin and TypeScript only. For
Python, it finds FastAPI routes and nothing else. The patches in
`patches/graphify/` add a full Python extractor:

- classes, and Pydantic `BaseModel` subclasses tagged as DTOs, including
  through multi-level inheritance;
- module-level functions;
- `EXTENDS` edges from class inheritance;
- `DEPENDS_ON` edges from resolved imports.

Resolution is two-pass, so the result does not depend on file order, and names
resolve only within one repository, so unrelated repositories get no false
edges. The patches apply to 0.1.0 only, which is why the wheel is bundled here
rather than pulled from PyPI.

`install-graphify-patch.sh` recreates `~/.venvs/graphify` on each run, so the
patches always meet pristine files, and it refuses to delete a directory it did
not create. It also verifies that the Python extractor is actually present
afterwards rather than only that the files parse — a reversed patch leaves
perfectly valid Python.

### Usage

```bash
cd <workspace root>             # the directory that contains your projects
graphify build                  # build or refresh the graph
graphify explain SomeClassName  # what it is, who calls it, what it depends on
graphify impact SomeClassName   # what is affected if it changes
graphify find SomeName          # locate a symbol by name
```

graphify finds the workspace root itself, walking up until it sees two or more
sibling project directories. A Python project needs a `pyproject.toml`; a
minimal `[project]` table is enough.

> **Do not** set `GRAPHIFY_ROOT`, `GRAPHIFY_CACHE` or `GRAPHIFY_KB` in your
> shell profile. A fixed path breaks auto-discovery for every other workspace.
> Set them only for a single command when you must override the root.

## Security review

**Claude Code.** `/security-review` is built in; there is nothing to install.
To review every pull request automatically, add the bundled GitHub Action to
a repository:

```bash
mkdir -p .github/workflows
cp <path-to-FuelingCodeAgent>/templates/github-actions/security-review.yml .github/workflows/
```

Then add a `CLAUDE_API_KEY` repository secret (Settings → Secrets and
variables → Actions). The key needs Claude API and Claude Code access.

**Codex.** Use the built-in `/review` command for local reviews. The GitHub
Action above runs on Claude and needs a `CLAUDE_API_KEY`, whichever agent you
use locally.

> The action is not hardened against prompt injection. Run it only on trusted
> pull requests. For public repositories, require maintainer approval for
> workflow runs from forks.

## Third-party copies and credits

Everything this toolkit installs from someone else is also kept in
[`third_party/`](third_party/), at a pinned commit, with its authors' licence
beside it. The installer always tries the upstream repository first; the copy
is used only when upstream fails — the repository is deleted or renamed,
GitHub is unreachable, or (for skills) Node is missing. A skill that installed
from upstream is never replaced by the older copy.

**These tools are their authors' work, not this repository's.** Each copy keeps
its upstream `LICENSE` (and `NOTICE`, for the Apache-2.0 ones), and this
repository's Apache-2.0 licence does not cover them. Star, report issues to,
and contribute to the original projects:

| Tool | Author | Licence |
|------|--------|---------|
| [superpowers](https://github.com/obra/superpowers) | Jesse Vincent ([@obra](https://github.com/obra)) | MIT |
| [ponytail](https://github.com/DietrichGebert/ponytail) | DietrichGebert | MIT |
| [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) | multica-ai, after Andrej Karpathy's guidance | MIT (declared upstream; licence text added here, see its `LICENSE`) |
| [claude-security](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/claude-security) | Anthropic | Apache-2.0 |
| [phoenix-security-review](https://github.com/Security-Phoenix-demo/security-skills-claude-code) | Security Skills Contributors (Phoenix Security) | MIT |
| [archify](https://github.com/tt-a1i/archify) | tt-a1i | Apache-2.0 |
| [graphify](https://github.com/ChihebBENCHEIKH1/graphify) | Chiheb Ben Cheikh | MIT |
| [asd-ste100](https://github.com/danyuchn/asd-ste100-skill) | Dustin Yuchen Teng | MIT |
| [pg-aiguide](https://github.com/timescale/pg-aiguide) (3 skills) | Timescale | Apache-2.0 |
| [claude-code-security-review](https://github.com/anthropics/claude-code-security-review) | Anthropic | MIT |

The exact commit of every copy is in
[`third_party/SOURCES.md`](third_party/SOURCES.md). To refresh them all to
upstream, then review what changed before committing it:

```bash
bash scripts/vendor-third-party.sh
git diff --stat third_party/
```

If you are an author of one of these and want your copy removed or changed,
open an issue and it will be.

## Updating and removal

**Update:** run `git pull`, then `./install.sh` again.

**Remove a plugin:**

```bash
claude plugin uninstall <name>@<marketplace>   # Claude Code
codex plugin remove <name>@<marketplace>       # Codex
```

**Remove a skill:** `npx skills remove <skill> -g -a claude-code` or
`-a codex`.

**Remove graphify:** delete `~/.venvs/graphify` and `~/.local/bin/graphify`.

## Repository layout

```
FuelingCodeAgent/
├── CLAUDE.md                     # this repository's own orientation and work log
├── install.sh                    # entry point (Claude Code and Codex)
├── install-graphify-patch.sh     # graphify CLI install and patch, called by install.sh
├── scripts/
│   ├── install-node22.sh         # Node 22 install, against a checksum pinned in the script
│   ├── context-cost.sh           # what a session re-sends every request; installed by step 8
│   └── vendor-third-party.sh     # rebuilds third_party/ from upstream, records each commit
├── hooks/
│   ├── graphify-lib.sh           # shared gates: code repo, project dir, graphify workspace
│   ├── graphify-session.sh       # SessionStart: names the graph
│   ├── graphify-reminder.sh      # UserPromptSubmit: names it again when asked
│   ├── journal-stamp.sh          # PostToolUse: marks that this session edited a file
│   └── journal-stop.sh           # Stop: gets the project CLAUDE.md written and its log appended
├── skills/
│   └── devops-handover/SKILL.md  # pre-handover audit, written here rather than fetched
├── commands/
│   └── security-audit.md         # /security-audit, a shim for the namespaced plugin command
├── patches/graphify/
│   ├── graphify_cli-0.1.0-py3-none-any.whl   # pinned base for the patches
│   ├── extract.py.diff           # Python declaration and relationship extraction
│   └── workspace.py.diff         # deterministic file-walk order
├── third_party/                  # pinned, licensed copies of every third-party tool -- fallback only
│   ├── SOURCES.md                # upstream, commit and licence of each copy
│   ├── .claude-plugin/marketplace.json   # local marketplace `fuelingcodeagent-mirror`
│   ├── plugins/                  # superpowers, ponytail, karpathy, claude-security, phoenix-security-review
│   ├── skills/                   # archify, graphify, asd-ste100, three pg-aiguide skills
│   └── actions/                  # claude-code-security-review
└── templates/
    ├── claude-md-lean.md         # the rule that keeps a project CLAUDE.md from growing back
    ├── claude-md-security.md     # appended to ~/.claude/CLAUDE.md by step 6
    └── github-actions/
        └── security-review.yml   # optional per-repository PR security review
```

## License

[Apache License 2.0](LICENSE), for this repository's own files. Everything under
`third_party/` keeps its authors' licence — see
[Third-party copies and credits](#third-party-copies-and-credits).
