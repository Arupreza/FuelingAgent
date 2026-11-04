# FuelingCodeAgent

**One installer that sets up the same agent toolkit for Claude Code and OpenAI Codex.**

![Bash](https://img.shields.io/badge/Bash-5.0%2B-4EAA25?logo=gnubash&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-22%2B-339933?logo=nodedotjs&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?logo=python&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-supported-d97757?logo=anthropic&logoColor=white)
![Codex](https://img.shields.io/badge/OpenAI%20Codex-supported-412991?logo=openai&logoColor=white)
![License](https://img.shields.io/badge/License-Apache%202.0-D22128)

FuelingCodeAgent installs process skills, a dependency-graph CLI, a diagramming
skill and a documentation-style skill in one step. The script is idempotent:
you can run it again at any time to update or repair an install.

## Contents

- [Toolkit](#toolkit)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [What the installer does](#what-the-installer-does)
- [Security plugins](#security-plugins)
  - [How to ask for a check](#how-to-ask-for-a-check)
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

| 6 | Auto-calling | Appends a "Security during development" section to `~/.claude/CLAUDE.md` so the on-demand security skills get reached for without being asked. Skipped if the section is already there; backs up to `CLAUDE.md.bak-security` | n/a |

Make sure `~/.local/bin` is on your `PATH` so the `graphify` command is found.

## Security plugins

Three plugins cover security, at different depths:

| Plugin | When it runs | Cost |
|--------|--------------|------|
| security-guidance | by itself, on every edit, turn and commit | regex layer free; the diff and commit reviews each spend a model call |
| claude-security | when you invoke it | one deep multi-agent scan |
| phoenix-security-review | when you invoke it | one pass |

Only `phoenix-security-review` of Phoenix's six plugins is installed. The other
five are reachable through `/plugin menu` if you want them; the toolkit leaves
them out because `phoenix-sast-rules` needs semgrep or opengrep on `PATH`,
`phoenix-prd-pipeline` overlaps superpowers' planning skills, and
`phoenix-cti-search` and `phoenix-docs-research` are threat-intelligence and
browser-automation tools rather than coding aids.

### How to ask for a check

Two commands. Nothing else to remember.

```
/claude-security      # Anthropic's: whole-repo scan, or your branch, or patches
/security-audit       # Phoenix's: OWASP Top 10 + ASVS L1 pass
```

Both take a scope if you want one (`/security-audit backend`), and both work
from plain English, so "scan the whole repo with Claude Security" does the same
thing as the first.

`security-guidance` is not in the list because it takes no command: it runs on
every edit, at the end of every turn, and on each commit Claude makes.

Do not use `/security-review` for either. Claude Code has a built-in command of
that name and Phoenix ships another, so the name is ambiguous.

### Do not run Phoenix's own install.sh

Phoenix ships hook presets that its `install.sh` writes into a project's
`.claude/settings.json`. Its full preset duplicates security-guidance exactly:

| Layer | security-guidance | Phoenix full preset |
|-------|-------------------|---------------------|
| Per-edit scan | `PostToolUse` on Edit/Write | `post-edit-quickscan.sh` |
| Diff review | `Stop`, end of turn | `session-end-security-0day.sh` |

Two scanners on one edit duplicate the findings in context, and two diff reviews
bill twice. Phoenix's hooks are opt-in and stay unwired after a plain
marketplace install, so the fix is to never run that script.

### Turning the cost down

The model-backed layers of security-guidance default to a Claude Opus model, one
call per file-changing turn:

```bash
ENABLE_STOP_REVIEW=0        # keep only the free per-edit regex check
ENABLE_COMMIT_REVIEW=0      # keep the turn review, drop the commit review
SECURITY_REVIEW_MODEL=...   # or run the turn review on a cheaper model
SECURITY_GUIDANCE_DISABLE=1 # switch the plugin off without uninstalling
```

## graphify: Python support

The released `graphify-cli==0.1.0` extracts Kotlin and TypeScript only. For
Python, it finds FastAPI routes and nothing else. The patches in
`patches/graphify/` add a full Python extractor:

- classes, and Pydantic `BaseModel` subclasses tagged as DTOs, including
  through multi-level inheritance;
- module-level functions;
- `EXTENDS` edges from class inheritance;
- `DEPENDS_ON` edges from resolved imports.

Resolution runs in two passes, after all declarations are indexed, so the
result does not depend on file order. Names resolve only inside the same
repository, so unrelated repositories never get false edges. A class never
resolves its base to itself.

The patches apply to version 0.1.0 only. For this reason the wheel is bundled
in this repository, not downloaded from PyPI.

### Usage

```bash
cd <workspace root>             # the directory that contains your projects
graphify build                  # build or refresh the graph
graphify explain SomeClassName  # what it is, who calls it, what it depends on
graphify impact SomeClassName   # what is affected if it changes
graphify find SomeName          # locate a symbol by name
```

graphify finds the workspace root by itself: it walks up from the current
directory until it finds two or more sibling project directories
(`pyproject.toml`, `package.json`, `settings.gradle.kts`, `.git`, ...). A
Python project needs a `pyproject.toml`; a minimal `[project]` table is
enough.

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
│   └── install-node22.sh         # Node 22 install, checksum-verified against nodejs.org
├── patches/graphify/
│   ├── graphify_cli-0.1.0-py3-none-any.whl   # pinned base for the patches
│   ├── extract.py.diff           # Python declaration and relationship extraction
│   └── workspace.py.diff         # deterministic file-walk order
└── templates/github-actions/
    └── security-review.yml       # optional per-repository PR security review
```

## License

[Apache License 2.0](LICENSE). Each installed tool keeps its own license; see
its source repository.
