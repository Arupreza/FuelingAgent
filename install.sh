#!/usr/bin/env bash
# FuelingCodeAgent installer for Claude Code, OpenAI Codex, Cursor and Antigravity.
# Idempotent: safe to re-run. See README.md for details.
#
# Usage: ./install.sh [--claude] [--codex] [--cursor] [--antigravity]
#   With no flags, installs for every agent found on this machine.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WANT_CLAUDE=0
WANT_CODEX=0
WANT_CURSOR=0
WANT_ANTIGRAVITY=0
for arg in "$@"; do
    case "$arg" in
        --claude) WANT_CLAUDE=1 ;;
        --codex)  WANT_CODEX=1 ;;
        --cursor) WANT_CURSOR=1 ;;
        --antigravity) WANT_ANTIGRAVITY=1 ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg (use --claude, --codex, --cursor, --antigravity)"; exit 1 ;;
    esac
done
ANY=$((WANT_CLAUDE + WANT_CODEX + WANT_CURSOR + WANT_ANTIGRAVITY))
if [ "$ANY" -eq 0 ]; then
    command -v claude >/dev/null 2>&1 && WANT_CLAUDE=1
    command -v codex  >/dev/null 2>&1 && WANT_CODEX=1
    # Cursor and Antigravity are desktop apps, often with no CLI on PATH, so
    # their config directory is the signal -- the same test the skills CLI uses.
    { command -v cursor >/dev/null 2>&1 || command -v cursor-agent >/dev/null 2>&1 \
      || [ -d "$HOME/.cursor" ]; } && WANT_CURSOR=1
    { command -v agy >/dev/null 2>&1 || [ -d "$HOME/.gemini/antigravity" ] \
      || [ -d "$HOME/.gemini/antigravity-cli" ]; } && WANT_ANTIGRAVITY=1
fi
if [ $((WANT_CLAUDE + WANT_CODEX + WANT_CURSOR + WANT_ANTIGRAVITY)) -eq 0 ]; then
    echo "ERROR: no supported agent found. Install one first, or name it with a flag:"
    echo "  Claude Code:  https://claude.com/claude-code"
    echo "  Codex CLI:    npm install -g @openai/codex"
    echo "  Cursor:       https://cursor.com          (then ./install.sh --cursor)"
    echo "  Antigravity:  https://antigravity.google  (then ./install.sh --antigravity)"
    exit 1
fi
for agent in claude codex; do
    var="WANT_${agent^^}"
    if [ "${!var}" -eq 1 ] && ! command -v "$agent" >/dev/null 2>&1; then
        echo "ERROR: --$agent requested but '$agent' is not on PATH."
        exit 1
    fi
done

TARGETS=()
[ "$WANT_CLAUDE" -eq 1 ] && TARGETS+=("Claude Code")
[ "$WANT_CODEX" -eq 1 ] && TARGETS+=("Codex")
[ "$WANT_CURSOR" -eq 1 ] && TARGETS+=("Cursor")
[ "$WANT_ANTIGRAVITY" -eq 1 ] && TARGETS+=("Antigravity")
echo "FuelingCodeAgent: installing for ${TARGETS[*]}"

section() {
    echo ""
    echo "=============================================="
    echo "$1"
    echo "=============================================="
}

# Every install below ends in `|| true`, so one upstream outage cannot abort
# the whole run. Left at that, the script exited 0 and printed "Next steps"
# while a security plugin had silently failed -- and step 6 then wrote a
# CLAUDE.md section telling the agent those plugins were active. Record each
# failure and report it at the end with a non-zero exit instead.
FAILED=()
note_failure() { FAILED+=("$1"); echo "    FAILED: $1" >&2; }
try() {   # try <label> <command...>
    local label="$1"; shift
    "$@" || note_failure "$label"
}

# third_party/ holds a pinned, licensed copy of every third-party plugin and
# skill below (scripts/vendor-third-party.sh, sources in third_party/SOURCES.md).
# Upstream is always tried first; the copy is used only when upstream fails --
# a deleted repository, a rename, an outage, no network to GitHub.
MIRROR="$HERE/third_party"
MIRROR_MP="fuelingcodeagent-mirror"
claude_plugin() {   # claude_plugin <repo> <name> <marketplace>
    local repo="$1" name="$2" mp="$3"
    if claude plugin marketplace add "$repo" && claude plugin install "$name@$mp"; then
        return 0
    fi
    if [ -d "$MIRROR/plugins/$name" ]; then
        echo "    upstream $repo failed -- installing the pinned copy from third_party/"
        claude plugin marketplace add "$MIRROR" >/dev/null 2>&1 || true   # already added is fine
        try "claude plugin $name (third_party copy)" claude plugin install "$name@$MIRROR_MP"
    else
        note_failure "claude plugin $name"
    fi
}

PLUGINS=(
    "obra/superpowers-marketplace|superpowers|superpowers-marketplace"
    "DietrichGebert/ponytail|ponytail|ponytail"
    "multica-ai/andrej-karpathy-skills|andrej-karpathy-skills|karpathy-skills"
)
# Claude Code only: claude-security is an Anthropic plugin and Phoenix's is
# built on Claude Code skills, and neither has a Codex equivalent.
#
# Both are on demand, but "on demand" is NOT free, and this comment used to
# claim it was. Measured 6 Nov 2026: their skill and agent descriptions are
# ~1,858 tokens in EVERY request -- more than a well-kept CLAUDE.md -- because
# a description has to be in context for the model to know the skill exists.
# So step 8 installs them and switches them OFF. Turning one back on is a
# one-line settings change, printed there and in the README.
# security-guidance is deliberately not here -- see step 5.
CLAUDE_ONLY_PLUGINS=(
    "anthropics/claude-plugins-official|claude-security|claude-plugins-official"
    # Only phoenix-security-review of Phoenix's six plugins. Its hooks are
    # opt-in and stay unwired unless its own install.sh is run -- do not run
    # it: its preset puts a scan on every edit and a review on every turn,
    # which is the per-turn model cost this toolkit now refuses to carry.
    "Security-Phoenix-demo/security-skills-claude-code|phoenix-security-review|phoenix-security"
)
# Pinned: `npx -y skills` takes the newest package every run, so a release can
# change what the installer does without anything here changing. 1.7.6 needs
# node >=22.20.0, which is why scripts/install-node22.sh pins 22.23.4 -- pinning
# one side and not the other is how that mismatch went unnoticed.
SKILLS_PKG="skills@1.7.6"
# An entry is a repo, optionally followed by flags for the skills CLI.
SKILLS=(
    "tt-a1i/archify"
    "ChihebBENCHEIKH1/graphify"
    "danyuchn/asd-ste100-skill"
    # pg-aiguide ships 11 skills; these are the three that apply to Postgres
    # and pgvector work. The rest are TimescaleDB and PostGIS, and every
    # description loads at session start whether it is used or not.
    #
    # NOT the `postgres` router skill the project README recommends: installed
    # on its own it arrives without the references/ directory it points at, so
    # all nine of its links are dead. These three are self-contained.
    #
    # NOT the Claude Code plugin either -- it registers a remote MCP server at
    # mcp.tigerdata.com, and the plan this supports treats a third-party API as
    # the wrong default for corpus work.
    "timescale/pg-aiguide --skill pgvector-semantic-search --skill postgres-hybrid-text-search --skill design-postgres-tables"
)

section "1/8  Node.js (needed by the skills installer)"
# The test used to be `major >= 22` with stderr discarded, which failed open
# three ways. It passed Node 22.14, which cannot run the pinned skills@1.7.6
# (engines: >=22.20.0), so the real cause surfaced later as an unexplained
# skills failure. It could not tell "no Node" from "Node present but broken",
# because `command not found` and a segfault both land in the same discarded
# stderr. And a failure of the installer below aborted the whole run through
# `set -e`, skipping the summary that says what is missing.
NODE_MIN="22.20.0"          # keep in step with SKILLS_PKG's engines field
NODE_BIN_DIR=""
NODE_OK=0
if ! command -v node >/dev/null 2>&1; then
    echo "--> no system Node found"
else
    # `|| true` keeps the captured stderr: assigning on failure would discard
    # the very message this branch exists to show.
    NODE_HAVE="$(node --version 2>&1 || true)"
    if [ -z "$NODE_HAVE" ] || [ "${NODE_HAVE#v}" = "$NODE_HAVE" ]; then
        # `node` exists but will not report a version: a broken install, a shim
        # that errors, a wrapper needing setup. Say so -- silently installing a
        # second Node leaves the broken one to break something else later.
        echo "--> WARNING: 'node' is on PATH but did not report a version:"
        echo "             ${NODE_HAVE:-(no output)}"
        echo "             Treating it as unusable and installing a private Node."
    elif node -e "const v=process.versions.node.split('.').map(Number);
                  const m='$NODE_MIN'.split('.').map(Number);
                  process.exit((v[0]>m[0]||(v[0]===m[0]&&(v[1]>m[1]||(v[1]===m[1]&&v[2]>=m[2]))))?0:1)" 2>/dev/null; then
        echo "--> system Node $NODE_HAVE is >= $NODE_MIN"
        NODE_OK=1
    else
        echo "--> system Node $NODE_HAVE is older than $NODE_MIN (needed by $SKILLS_PKG)"
    fi
fi
if [ "$NODE_OK" -eq 0 ]; then
    if [ ! -x "$HOME/.local/node22/bin/node" ]; then
        echo "--> installing Node into ~/.local/node22 (system Node is not changed)"
        try "Node install (scripts/install-node22.sh)" bash "$HERE/scripts/install-node22.sh"
    fi
    if [ -x "$HOME/.local/node22/bin/node" ]; then
        NODE_BIN_DIR="$HOME/.local/node22/bin"
        echo "--> using $NODE_BIN_DIR/node"
    else
        # Fail closed: skip the steps that need it rather than run them and
        # emit a confusing npx error for each.
        note_failure "Node >= $NODE_MIN unavailable -- skills installed from third_party/, not upstream"
        SKIP_SKILLS=1
    fi
fi
SKIP_SKILLS="${SKIP_SKILLS:-0}"
run_npx() {
    if [ -n "$NODE_BIN_DIR" ]; then
        PATH="$NODE_BIN_DIR:$PATH" npx "$@"
    else
        npx "$@"
    fi
}

section "2/8  Plugins (superpowers, ponytail, karpathy, security)"
for entry in "${PLUGINS[@]}"; do
    IFS='|' read -r repo name marketplace <<< "$entry"
    if [ "$WANT_CLAUDE" -eq 1 ]; then
        echo "--> [Claude Code] $name"
        claude_plugin "$repo" "$name" "$marketplace"
    fi
    if [ "$WANT_CODEX" -eq 1 ]; then
        echo "--> [Codex] $name"
        try "codex marketplace $repo" codex plugin marketplace add "$repo"
        try "codex plugin $name"      codex plugin add "$name@$marketplace"
    fi
done

if [ "$WANT_CLAUDE" -eq 1 ]; then
    for entry in "${CLAUDE_ONLY_PLUGINS[@]}"; do
        IFS='|' read -r repo name marketplace <<< "$entry"
        echo "--> [Claude Code] $name"
        claude_plugin "$repo" "$name" "$marketplace"
    done
fi

# `claude plugin marketplace add` takes a repository's default branch and offers
# no flag to pin a ref (checked: --claudeai, --scope, --sparse, and nothing
# else), so every run installs whatever is on those branches now. That cannot
# be fixed from here, but it can be made visible: record the commit each
# marketplace resolved to and report anything that moved since the last run.
# Silent drift is the part that matters -- a changed hook arriving unannounced
# runs with the agent's full permissions.
if [ "$WANT_CLAUDE" -eq 1 ]; then
    LOCK="$HOME/.claude/fuelingcodeagent-sources.lock"
    NEWLOCK="$(mktemp)"
    DRIFTED=0
    echo ""
    echo "--> third-party sources installed (unpinned upstream: these can change)"
    for mp in "$HOME/.claude/plugins/marketplaces"/*/; do
        [ -d "$mp/.git" ] || continue
        name="$(basename "$mp")"
        sha="$(git -C "$mp" rev-parse HEAD 2>/dev/null)" || continue
        echo "$name $sha" >> "$NEWLOCK"
        prev="$(awk -v n="$name" '$1==n{print $2}' "$LOCK" 2>/dev/null)"
        if [ -z "$prev" ]; then
            printf "      %-26s %s  (first record)\n" "$name" "${sha:0:12}"
        elif [ "$prev" != "$sha" ]; then
            printf "      %-26s %s  CHANGED from %s\n" "$name" "${sha:0:12}" "${prev:0:12}"
            DRIFTED=1
        else
            printf "      %-26s %s  unchanged\n" "$name" "${sha:0:12}"
        fi
    done
    sort -o "$NEWLOCK" "$NEWLOCK" && mv "$NEWLOCK" "$LOCK"
    if [ "$DRIFTED" -eq 1 ]; then
        echo ""
        echo "    One or more sources changed upstream since the last run. That code runs"
        echo "    as plugins, skills and hooks with the agent's full permissions. Review the"
        echo "    diff before trusting it:  git -C ~/.claude/plugins/marketplaces/<name> log <old>..<new>"
    fi
    echo "    recorded in $LOCK"
fi

section "3/8  Skills (archify, graphify, asd-ste100, pg-aiguide, devops-handover)"
if [ "$SKIP_SKILLS" -eq 1 ]; then
    echo "--> skipped: no Node >= $NODE_MIN (see the summary at the end)"
fi
for entry in "${SKILLS[@]}"; do
    [ "$SKIP_SKILLS" -eq 1 ] && break
    # Split the entry so a repo can carry flags such as --skill. Word
    # splitting is wanted here and nowhere else, which is why it goes through
    # an array rather than an unquoted expansion.
    read -r -a SKILL_ARGS <<< "$entry"
    if [ "$WANT_CLAUDE" -eq 1 ]; then
        echo "--> [Claude Code] ${SKILL_ARGS[0]}"
        run_npx -y "$SKILLS_PKG" add "${SKILL_ARGS[@]}" -g -a claude-code -y \
            || echo "    upstream ${SKILL_ARGS[0]} failed -- third_party/ copy used below"
    fi
    if [ "$WANT_CODEX" -eq 1 ]; then
        echo "--> [Codex] ${SKILL_ARGS[0]}"
        run_npx -y "$SKILLS_PKG" add "${SKILL_ARGS[@]}" -g -a codex -y \
            || echo "    upstream ${SKILL_ARGS[0]} failed -- third_party/ copy used below"
    fi
done

# Any third-party skill still missing -- upstream failed, or no Node -- comes
# from the pinned copy. A skill present already is left alone, so a working
# upstream install is never replaced by the older copy.
backfill_skills() {   # backfill_skills <skills dir> <agent label> [source dir...]
    local dir="$1" agent="$2" root sk name
    shift 2
    [ "$#" -gt 0 ] || set -- "$MIRROR/skills"
    for root in "$@"; do
    for sk in "$root"/*/; do
        [ -f "$sk/SKILL.md" ] || continue
        name="$(basename "$sk")"
        [ -e "$dir/$name/SKILL.md" ] && continue
        install -d "$dir"
        if cp -R "$sk" "$dir/$name"; then
            echo "--> [$agent] $name (pinned copy from third_party/)"
        else
            note_failure "$agent skill $name"
        fi
    done
    done
}
[ "$WANT_CLAUDE" -eq 1 ] && backfill_skills "$HOME/.claude/skills" "Claude Code"
[ "$WANT_CODEX" -eq 1 ] && backfill_skills "$HOME/.agents/skills" "Codex"

# phoenix-security-review for Codex. Upstream ships no Codex plugin, only a
# Claude Code one, but its six skills are plain SKILL.md files Codex reads.
# Installed together from the pinned copy because they link to each other
# (../security-reviewer/checklists/...); the commands, hooks and subagent are
# Claude Code only and are not installed. claude-security has no Codex path at
# all: it runs on Claude Code's Workflow tool and subagents.
PHX="$MIRROR/plugins/phoenix-security-review/skills"
if [ "$WANT_CODEX" -eq 1 ] && [ -d "$PHX" ]; then
    for sk in "$PHX"/*/; do
        [ -f "$sk/SKILL.md" ] || continue
        name="$(basename "$sk")"
        install -d "$HOME/.agents/skills"
        # Replaced, not merged, so a re-run after a third_party/ refresh updates it.
        rm -rf "${HOME:?}/.agents/skills/$name"
        if cp -R "$sk" "$HOME/.agents/skills/$name"; then
            echo "--> [Codex] $name (phoenix-security-review, pinned copy)"
        else
            note_failure "codex skill $name (phoenix-security-review)"
        fi
    done
fi

# Skills written in THIS repository, not fetched from elsewhere. They are
# plain SKILL.md directories, so they install by copying -- no Node, no
# registry, nothing to pin.
if [ "$WANT_CLAUDE" -eq 1 ] && [ -d "$HERE/skills" ]; then
    for sk in "$HERE/skills"/*/; do
        [ -f "$sk/SKILL.md" ] || continue
        name="$(basename "$sk")"
        install -d "$HOME/.claude/skills/$name"
        install -m 644 "$sk/SKILL.md" "$HOME/.claude/skills/$name/SKILL.md"
        echo "--> [Claude Code] $name (from this repository)"
    done
fi
if [ "$WANT_CODEX" -eq 1 ] && [ -d "$HERE/skills" ]; then
    for sk in "$HERE/skills"/*/; do
        [ -f "$sk/SKILL.md" ] || continue
        name="$(basename "$sk")"
        install -d "$HOME/.agents/skills/$name"
        install -m 644 "$sk/SKILL.md" "$HOME/.agents/skills/$name/SKILL.md"
        echo "--> [Codex] $name (from this repository)"
    done
fi

# Cursor and Antigravity: everything as skills. Neither has a plugin system
# an installer can drive -- Cursor's /add-plugin works only inside its chat,
# Antigravity's `agy plugin install` needs its CLI -- but both read plain
# SKILL.md directories, which is what every plugin here is made of. Hooks,
# slash commands and subagents are Claude Code features and do not carry over;
# claude-security has nothing that runs outside Claude Code.
#
# Where each one reads global skills, from its own docs (checked 2026-11):
#   Cursor       ~/.agents/skills and ~/.cursor/skills (also ~/.claude/skills,
#                ~/.codex/skills). The skills CLI installs Cursor to
#                ~/.agents/skills, so that is used and ~/.cursor/skills is not:
#                filling both would list every skill twice.
#   Antigravity  ~/.gemini/config/skills, all products (App, IDE, CLI). The
#                skills CLI installs it to ~/.agents/skills, which Antigravity's
#                docs do not list, so it gets the pinned copies directly.
PLUGIN_SKILL_REPOS=(obra/superpowers DietrichGebert/ponytail multica-ai/andrej-karpathy-skills)
COPY_ROOTS=("$MIRROR/plugins/superpowers/skills" "$MIRROR/plugins/ponytail/skills"
            "$MIRROR/plugins/andrej-karpathy-skills/skills" "$MIRROR/skills")
OWN_ROOTS=("$MIRROR/plugins/phoenix-security-review/skills" "$HERE/skills")
copy_skills() {   # copy_skills <dest> <label> <root...> -- replaces, so a refresh lands
    local dest="$1" label="$2" root sk name
    shift 2
    for root in "$@"; do
        for sk in "$root"/*/; do
            [ -f "$sk/SKILL.md" ] || continue
            name="$(basename "$sk")"
            install -d "$dest"
            rm -rf "${dest:?}/$name"
            if cp -R "$sk" "$dest/$name"; then
                echo "--> [$label] $name"
            else
                note_failure "$label skill $name"
            fi
        done
    done
}
if [ "$WANT_CURSOR" -eq 1 ]; then
    if [ "$SKIP_SKILLS" -eq 0 ]; then
        for entry in "${PLUGIN_SKILL_REPOS[@]}" "${SKILLS[@]}"; do
            read -r -a SKILL_ARGS <<< "$entry"
            echo "--> [Cursor] ${SKILL_ARGS[0]}"
            run_npx -y "$SKILLS_PKG" add "${SKILL_ARGS[@]}" -g -a cursor -y \
                || echo "    upstream ${SKILL_ARGS[0]} failed -- third_party/ copy used below"
        done
    fi
    backfill_skills "$HOME/.agents/skills" "Cursor" "${COPY_ROOTS[@]}"
    copy_skills "$HOME/.agents/skills" "Cursor" "${OWN_ROOTS[@]}"
fi
if [ "$WANT_ANTIGRAVITY" -eq 1 ]; then
    copy_skills "$HOME/.gemini/config/skills" "Antigravity" "${COPY_ROOTS[@]}" "${OWN_ROOTS[@]}"
fi

section "4/8  graphify CLI (patched for Python extraction)"
# Recorded rather than fatal: an abort here would skip steps 5-7 AND the
# summary, leaving a partial install with nothing saying so. The graphify hooks
# in step 7 check `command -v graphify` and stay silent without it, so a
# failure here degrades rather than breaks.
try "graphify CLI (install-graphify-patch.sh)" bash "$HERE/install-graphify-patch.sh"

section "5/8  Remove caveman and security-guidance (not part of this toolkit)"
# Both were dropped for the same reason: model calls on every turn.
#
# caveman's hooks ran on every agent event.
#
# security-guidance (Anthropic) launched an agentic reviewer on every git
# commit and every git push -- a full Claude Code subprocess on Opus, up to 18
# turns, re-reading the repository, with the default ceiling at 20 reviews an
# hour and a push re-reviewing the whole commit range. Measured on a real
# session: five launches in sixteen minutes across three commits and one push,
# none of it visible in the transcript. The review itself was good; the price
# of having it on every commit was not. Security here is on demand instead --
# /claude-security and /security-audit, run when you choose, which is also
# when the findings are worth reading.
if [ "$WANT_CLAUDE" -eq 1 ]; then
    if claude plugin list 2>/dev/null | grep -q "security-guidance"; then
        claude plugin uninstall security-guidance@claude-plugins-official || true
    fi
    # Its state directory holds a bootstrapped agent SDK venv -- ~380 MB.
    rm -rf "$HOME/.claude/security" \
           "$HOME/.claude/plugins/cache/claude-plugins-official/security-guidance"

    if claude plugin list 2>/dev/null | grep -q "caveman@caveman"; then
        claude plugin uninstall caveman@caveman || true
    fi
    claude plugin marketplace remove caveman >/dev/null 2>&1 || true
    claude mcp remove caveman -s user >/dev/null 2>&1 || true
    rm -rf "$HOME/.claude/skills/caveman" "$HOME/.claude/skills/megacave" \
           "$HOME/.claude/skills/ultracave" "$HOME/.claude/plugins/cache/caveman" \
           "$HOME/.claude/plugins/marketplaces/caveman"
    # The marketplace clone was left behind by earlier versions: unregistered
    # but still on disk, so it showed up in the source list above as a
    # third-party repository this toolkit tracks. It isn't one any more.
    SETTINGS="$HOME/.claude/settings.json"
    if [ -f "$SETTINGS" ] && grep -q "caveman" "$SETTINGS"; then
        echo "--> removing caveman entries from $SETTINGS (backup: $SETTINGS.bak-caveman)"
        cp "$SETTINGS" "$SETTINGS.bak-caveman"
        python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    s = json.load(f)
hooks = s.get("hooks", {})
for event in list(hooks):
    groups = []
    for g in hooks[event]:
        g["hooks"] = [h for h in g.get("hooks", []) if "caveman" not in h.get("command", "")]
        if g["hooks"]:
            groups.append(g)
    if groups:
        hooks[event] = groups
    else:
        del hooks[event]
if not hooks:
    s.pop("hooks", None)
env = s.get("env", {})
if "8787" in env.get("ANTHROPIC_BASE_URL", ""):
    del env["ANTHROPIC_BASE_URL"]
s.get("enabledPlugins", {}).pop("caveman@caveman", None)
s.get("extraKnownMarketplaces", {}).pop("caveman", None)
with open(path, "w") as f:
    json.dump(s, f, indent=2)
    f.write("\n")
PY
    fi
fi
if [ "$WANT_CODEX" -eq 1 ]; then
    codex plugin remove caveman@caveman >/dev/null 2>&1 || true
    codex plugin marketplace remove caveman >/dev/null 2>&1 || true
    codex mcp remove caveman >/dev/null 2>&1 || true
fi
pkill -f caveman-proxy 2>/dev/null || true
echo "--> done"

section "6/8  Auto-calling, and the /security-audit shim"
# Both security plugins are invoked rather than automatic, so the agent has to
# know which one answers which question -- that is what this block puts in
# CLAUDE.md. Guarded by a marker so re-running the installer does not append a
# second copy.
if [ "$WANT_CLAUDE" -eq 1 ]; then
    CMD_FILE="$HOME/.claude/CLAUDE.md"
    MARKER="# Security during development"
    mkdir -p "$HOME/.claude"
    if [ -f "$CMD_FILE" ] && grep -qF "$MARKER" "$CMD_FILE"; then
        echo "--> CLAUDE.md already has the security section; left as it is"
    else
        cp "$CMD_FILE" "$CMD_FILE.bak-security" 2>/dev/null || true
        cat "$HERE/templates/claude-md-security.md" >> "$CMD_FILE"
        echo "--> appended the security section to $CMD_FILE"
    fi
fi

# Plugin commands are namespaced, so Phoenix's assessment is only reachable as
# /phoenix-security-review:security-audit -- a name that does not show up when
# you type /security-audit and is easy to get wrong. A user command is not
# namespaced, so this shim gives it the short name and hands off to the plugin.
if [ "$WANT_CLAUDE" -eq 1 ]; then
    mkdir -p "$HOME/.claude/commands"
    install -m 644 "$HERE/commands/security-audit.md" "$HOME/.claude/commands/security-audit.md"
    echo "--> installed /security-audit (shim for phoenix-security-review)"
fi

section "7/8  session hooks (graphify + CLAUDE.md work log)"
# A skill is advice the model may or may not act on; a hook is code that runs.
#
# graphify was installed as a skill, so a structural question often got
# answered with grep instead. graphify-session.sh and graphify-reminder.sh
# state that the graph exists, on every new session and again whenever a
# structural question is asked. They refresh nothing: graphify checks freshness
# on each query and rebuilds itself.
#
# journal-stamp.sh and journal-stop.sh keep a CLAUDE.md in every project and
# keep its work log current: the first records that the session edited a file,
# the second blocks the end of the turn once, asking for the log entry while
# the work is still in context. Project, not git root -- a monorepo holds
# several, and one file at the top would describe none of them.
#
# All four gate on being a git repository that holds source files, so sessions
# in notes, data or home directories pay nothing.
if [ "$WANT_CLAUDE" -eq 1 ]; then
    HOOK_DIR="$HOME/.claude/hooks"
    mkdir -p "$HOOK_DIR"
    for h in graphify-lib.sh graphify-session.sh graphify-reminder.sh \
             journal-stamp.sh journal-stop.sh; do
        install -m 755 "$HERE/hooks/$h" "$HOOK_DIR/$h"
        echo "--> installed $HOOK_DIR/$h"
    done

    # ~/.claude/settings.json may be a symlink to a shared file; follow it so
    # the merge lands on the real file instead of replacing the link.
    SETTINGS_REAL="$(readlink -f "$HOME/.claude/settings.json" 2>/dev/null || echo "$HOME/.claude/settings.json")"
    if ! command -v jq >/dev/null 2>&1; then
        echo "--> jq is not installed; add these hooks yourself (see README) or install jq and re-run"
    else
        [ -s "$SETTINGS_REAL" ] || echo '{}' > "$SETTINGS_REAL"

        # add_hook <event> <matcher|""> <script>
        #
        # Idempotent per script: a re-run adds nothing if that script is
        # already wired, so no hook ever fires twice per event, and a hook
        # added to this list later is picked up without re-adding the rest.
        add_hook() {
            local ev="$1" m="$2" s="$3" tmp
            if jq -e --arg c "$HOOK_DIR/$s" \
                  '[.hooks // {} | .[]? | .[]? | .hooks[]? | .command] | any(contains($c))' \
                  "$SETTINGS_REAL" >/dev/null 2>&1; then
                echo "--> $ev already runs $s; left as it is"
                return 0
            fi
            # One backup per machine, taken before the first write this script
            # ever makes: the oldest copy is the only one guaranteed to predate
            # every change, so it is never overwritten by a later run.
            [ -f "$SETTINGS_REAL.bak-fca-hooks" ] || cp "$SETTINGS_REAL" "$SETTINGS_REAL.bak-fca-hooks"
            tmp="$(mktemp)"
            jq --arg ev "$ev" --arg m "$m" --arg cmd "bash \"$HOOK_DIR/$s\"" '
              .hooks //= {}
              | .hooks[$ev] //= []
              | .hooks[$ev] += [ (if $m == "" then {} else {matcher: $m} end)
                                 + {hooks: [{type: "command", command: $cmd, timeout: 15}]} ]
            ' "$SETTINGS_REAL" > "$tmp" && mv "$tmp" "$SETTINGS_REAL" \
                || { rm -f "$tmp"; note_failure "settings.json merge for $s"; return 1; }
            echo "--> added $s to $ev"
        }

        add_hook SessionStart     ""            graphify-session.sh
        add_hook UserPromptSubmit ""            graphify-reminder.sh
        add_hook PostToolUse      "Write|Edit"  journal-stamp.sh
        add_hook Stop             ""            journal-stop.sh
        echo "--> settings: $SETTINGS_REAL (backup: $SETTINGS_REAL.bak-fca-hooks)"
    fi
fi

section "8/8  Context cost (effort, security plugins off until asked for)"
# Everything in a session's system prompt is re-sent on every request, so the
# default setup is a standing cost. Two levers dominate, and both are measured
# rather than guessed -- scripts/context-cost.sh prints the breakdown.
#
#   effortLevel   applies to EVERY turn, including "is it done yet?". high is
#                 right for schema design and debugging, not for status checks.
#   the two security plugins   ~1,858 tokens/request for tools used a few
#                 times a week.
#
# Nothing here removes a capability: the plugins stay installed, the model
# stays whatever the user chose, and both changes are one line to undo.
if [ "$WANT_CLAUDE" -eq 1 ]; then
    SETTINGS_REAL="$(readlink -f "$HOME/.claude/settings.json" 2>/dev/null || echo "$HOME/.claude/settings.json")"
    install -m 755 "$HERE/scripts/context-cost.sh" "$HOME/.claude/context-cost.sh"
    echo "--> installed ~/.claude/context-cost.sh  (run it from a project to see what a request carries)"

    if [ -f "$SETTINGS_REAL" ] && command -v python3 >/dev/null 2>&1; then
        [ -f "$SETTINGS_REAL.bak-fca-cost" ] || cp "$SETTINGS_REAL" "$SETTINGS_REAL.bak-fca-cost"
        python3 - "$SETTINGS_REAL" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
changed = []
# Only set a default where the user has expressed no preference. An explicit
# choice of theirs is not ours to overwrite on every re-run.
if "effortLevel" not in d:
    d["effortLevel"] = "medium"; changed.append("effortLevel=medium (new)")
elif d["effortLevel"] == "high":
    d["effortLevel"] = "medium"; changed.append("effortLevel: high -> medium")
ep = d.setdefault("enabledPlugins", {})
for k in ("phoenix-security-review@phoenix-security",
          "claude-security@claude-plugins-official",
          "phoenix-security-review@fuelingcodeagent-mirror",
          "claude-security@fuelingcodeagent-mirror"):
    if ep.get(k) is True:
        ep[k] = False; changed.append(f"{k.split('@')[0]} -> off until asked for")
if changed:
    json.dump(d, open(p, "w"), indent=2)
    for c in changed:
        print(f"    {c}")
else:
    print("    already set; nothing changed")
EOF
        echo "    backup: $SETTINGS_REAL.bak-fca-cost"
        echo ""
        echo "    Raise effort for a hard task with /effort high, per session."
        echo "    Before a release or handover, re-enable the security plugins:"
        echo "      python3 - <<'EOF'"
        echo "      import json; p=\"$SETTINGS_REAL\"; d=json.load(open(p))"
        echo "      d['enabledPlugins']['phoenix-security-review@phoenix-security']=True"
        echo "      d['enabledPlugins']['claude-security@claude-plugins-official']=True"
        echo "      json.dump(d, open(p,'w'), indent=2)"
        echo "      EOF"
    else
        echo "--> no settings.json or no python3; set effortLevel yourself (see README)"
    fi
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
    section "INCOMPLETE -- ${#FAILED[@]} step(s) failed"
    for f in "${FAILED[@]}"; do echo "  - $f"; done
    echo ""
    echo "Those components are NOT installed. Re-run this script once the cause"
    echo "is fixed; it is idempotent, so what succeeded is left alone."
    echo "If a security plugin is listed above, treat it as absent whatever"
    echo "CLAUDE.md says, and check with: claude plugin list"
    exit 1
fi

section "Next steps"
if [ "$WANT_CLAUDE" -eq 1 ]; then
    echo "Claude Code: restart it, or start a new session."
fi
if [ "$WANT_CODEX" -eq 1 ]; then
    echo "Codex: start a new thread, open /hooks, and trust ponytail's two hooks."
fi
if [ "$WANT_CURSOR" -eq 1 ]; then
    echo "Cursor: restart it. Skills are in ~/.agents/skills (Settings -> Rules shows them)."
fi
if [ "$WANT_ANTIGRAVITY" -eq 1 ]; then
    echo "Antigravity: restart it. Skills are in ~/.gemini/config/skills."
fi
echo "Optional: per-repo PR security review -- see README.md 'Security review'."
