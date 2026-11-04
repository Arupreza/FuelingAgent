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
- **security** — review of code as it is written, plus two commands for a
  whole-repo audit;
- **a dependency graph** — a cross-repo graph that answers who-calls-what and
  what-a-change-breaks, and refreshes itself.

Works for Claude Code and OpenAI Codex. Re-run the installer any time to update
or repair an install; it never duplicates one.

## Contents

- [Toolkit](#toolkit)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [What the installer does](#what-the-installer-does)
- [Security plugins](#security-plugins)
  - [Asking for a check](#asking-for-a-check)
- [graphify hooks](#graphify-hooks)
- [Supply chain](#supply-chain)
- [graphify: Python support](#graphify-python-support)
- [Security review](#security-review)
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
| security-guidance | plugin | [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) | Reviews code as it is written: regex on every edit, model review of each turn's diff, agentic review on commit. Runs by itself | ✓ | — |
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
| 3 | Skills | `npx skills add <repo> -g -a claude-code` → `~/.claude/skills` | `npx skills add <repo> -g -a codex` → `~/.agents/skills` |
| 4 | graphify CLI | Installs the pinned `graphify-cli==0.1.0` wheel into `~/.venvs/graphify`, applies the Python patches, links `~/.local/bin/graphify` | shared |
| 5 | Cleanup | Removes caveman, which earlier versions of this toolkit installed. Backs up `~/.claude/settings.json` to `settings.json.bak-caveman` before it edits the file | same |

| 6 | Auto-calling | Appends a "Security during development" section to `~/.claude/CLAUDE.md` so the on-demand security skills get reached for without being asked, and installs the `/security-audit` command shim. Skipped if the section is already there; backs up to `CLAUDE.md.bak-security` | n/a |

| 7 | graphify hooks | Installs two hooks to `~/.claude/hooks/` and merges them into `settings.json` so the code graph refreshes and announces itself every session. Needs `jq`; backs up to `settings.json.bak-graphify` | n/a |

Make sure `~/.local/bin` is on your `PATH` so the `graphify` command is found.

## Security plugins

| Plugin | Runs | Cost |
|--------|------|------|
| security-guidance | by itself, on every edit, turn and commit | regex layer free; diff and commit reviews each spend a model call |
| claude-security | when invoked | one deep multi-agent scan |
| phoenix-security-review | when invoked | one pass |

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
`security-guidance` needs no command: it runs on its own.

**Which one.** `/claude-security` asks *are there real vulnerabilities*: it
verifies each finding and can write the patch. `security-audit` asks *does this
meet the standard*: checklist coverage, not exploitability. In doubt, the first.

Do **not** use `/security-review`. Claude Code ships a built-in command of that
name and Phoenix ships another, so it is ambiguous.

### Two traps

- **Never run `phoenix-security-review`'s own `install.sh`.** Its hook preset
  duplicates security-guidance exactly — a per-edit scanner against the
  `PostToolUse` check, a session-end review against the `Stop` review — so
  findings appear twice and the diff review bills twice. Its hooks are opt-in
  and stay unwired after a plain marketplace install.
- **The model-backed layers default to Opus**, one call per file-changing turn.
  `ENABLE_STOP_REVIEW=0` keeps only the free regex check;
  `SECURITY_GUIDANCE_DISABLE=1` switches the plugin off without uninstalling.

Only one of Phoenix's six plugins is installed. The rest are in `/plugin menu`:
`phoenix-sast-rules` needs semgrep on `PATH`, `phoenix-prd-pipeline` overlaps
superpowers' planning skills, and the other two are threat-intelligence and
browser-automation tools rather than coding aids.

## graphify hooks

graphify ships as a skill, so reaching for it was a decision the agent made
each time — and a "who calls this" question often got answered with `grep`.
Two hooks state that the graph exists, so using it is not a choice.

| Hook | Event | Does |
|------|-------|------|
| `graphify-session.sh` | `SessionStart` | names the graph and the CLI, every new session |
| `graphify-reminder.sh` | `UserPromptSubmit` | repeats the pointer when a caller, impact or dependency question is actually asked, since in a long session the SessionStart line drifts far up the context |

`graphify-lib.sh` holds the gate both share. Plain shell: no model call, no
network, nothing when silent.

They print only when all three hold: inside a git repository, that repository
holds source files (`node_modules`, `venv`, `site-packages`, `dist`, `build`,
`__pycache__` pruned), and `graphify root` recognises a workspace. A notes
folder, a data directory or a docs-only repository costs nothing.

They run in **every** repository you open, including one you have just cloned
and not read. The hooks execute no code from the repository, but they do point
the agent at its `ARCHITECTURE_GRAPH.md`, and a hostile repository could put a
prompt injection in that file. The same is true of any file the agent reads, so
this adds no new exposure — but in an untrusted checkout, read before you act.

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

### Turning them off

`/hooks`, or `jq 'del(.hooks.SessionStart, .hooks.UserPromptSubmit)'` on
`~/.claude/settings.json`. Step 7 backs up to `settings.json.bak-graphify` and
merges by command string, so a re-run never adds a second copy.

## Supply chain

Worth knowing before you run the installer. It pulls from seven third-party
GitHub repositories and an npm package, none pinned to a version:
`claude plugin marketplace add <owner/repo>` and `npx -y skills add <owner/repo>`
take whatever is on the default branch at that moment. That code then runs as
plugins, skills and hooks with the agent's full permissions, in every session.

So a re-run is not only an update: it is a fresh pull of whatever those
repositories contain now. Review a source you do not already trust, and treat
`./install.sh` as an action with the same weight as installing a shell plugin.

Two things in here are pinned and do not have this property: the graphify wheel
is bundled in `patches/graphify/`, and the Node tarball is checked against a
hash written into `scripts/install-node22.sh`.

If a step fails, the installer now says so and exits non-zero. A failed
security plugin is not installed whatever the CLAUDE.md section claims —
confirm with `claude plugin list`.

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
├── install.sh                    # entry point (Claude Code and Codex)
├── install-graphify-patch.sh     # graphify CLI install and patch, called by install.sh
├── scripts/
│   └── install-node22.sh         # Node 22 install, against a checksum pinned in the script
├── hooks/
│   ├── graphify-lib.sh           # shared gate: code repo, graphify workspace
│   ├── graphify-session.sh       # SessionStart: names the graph
│   └── graphify-reminder.sh      # UserPromptSubmit: names it again when asked
├── commands/
│   └── security-audit.md         # /security-audit, a shim for the namespaced plugin command
├── patches/graphify/
│   ├── graphify_cli-0.1.0-py3-none-any.whl   # pinned base for the patches
│   ├── extract.py.diff           # Python declaration and relationship extraction
│   └── workspace.py.diff         # deterministic file-walk order
└── templates/
    ├── claude-md-security.md     # appended to ~/.claude/CLAUDE.md by step 6
    └── github-actions/
        └── security-review.yml   # optional per-repository PR security review
```

## License

[Apache License 2.0](LICENSE). Each installed tool keeps its own license; see
its source repository.
