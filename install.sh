#!/usr/bin/env bash
# FuelingCodeAgent installer for Claude Code and OpenAI Codex.
# Idempotent: safe to re-run. See README.md for details.
#
# Usage: ./install.sh [--claude] [--codex]
#   With no flags, installs for every agent CLI found on PATH.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WANT_CLAUDE=0
WANT_CODEX=0
for arg in "$@"; do
    case "$arg" in
        --claude) WANT_CLAUDE=1 ;;
        --codex)  WANT_CODEX=1 ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg (use --claude and/or --codex)"; exit 1 ;;
    esac
done
if [ "$WANT_CLAUDE" -eq 0 ] && [ "$WANT_CODEX" -eq 0 ]; then
    command -v claude >/dev/null 2>&1 && WANT_CLAUDE=1
    command -v codex  >/dev/null 2>&1 && WANT_CODEX=1
fi
if [ "$WANT_CLAUDE" -eq 0 ] && [ "$WANT_CODEX" -eq 0 ]; then
    echo "ERROR: neither 'claude' nor 'codex' found on PATH. Install one first:"
    echo "  Claude Code:  https://claude.com/claude-code"
    echo "  Codex CLI:    npm install -g @openai/codex"
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

PLUGINS=(
    "obra/superpowers-marketplace|superpowers|superpowers-marketplace"
    "DietrichGebert/ponytail|ponytail|ponytail"
    "multica-ai/andrej-karpathy-skills|andrej-karpathy-skills|karpathy-skills"
)
# Claude Code only. security-guidance is built on Claude Code hooks and
# claude-security is an Anthropic plugin; neither has a Codex equivalent.
CLAUDE_ONLY_PLUGINS=(
    "anthropics/claude-plugins-official|security-guidance|claude-plugins-official"
    "anthropics/claude-plugins-official|claude-security|claude-plugins-official"
    # Only phoenix-security-review of Phoenix's six plugins. Its hooks are
    # opt-in and stay unwired unless its own install.sh is run -- do not run it:
    # its full preset duplicates security-guidance's per-edit scan and diff
    # review, which doubles the model cost and the findings in context.
    "Security-Phoenix-demo/security-skills-claude-code|phoenix-security-review|phoenix-security"
)
# Pinned: `npx -y skills` takes the newest package every run, so a release can
# change what the installer does without anything here changing. 1.7.6 needs
# node >=22.20.0, which is why scripts/install-node22.sh pins 22.23.4 -- pinning
# one side and not the other is how that mismatch went unnoticed.
SKILLS_PKG="skills@1.7.6"
SKILLS=(
    "tt-a1i/archify"
    "ChihebBENCHEIKH1/graphify"
    "danyuchn/asd-ste100-skill"
)

section "1/7  Node.js (needed by the skills installer)"
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
        note_failure "Node >= $NODE_MIN unavailable -- skills steps skipped"
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

section "2/7  Plugins (superpowers, ponytail, karpathy, security)"
for entry in "${PLUGINS[@]}"; do
    IFS='|' read -r repo name marketplace <<< "$entry"
    if [ "$WANT_CLAUDE" -eq 1 ]; then
        echo "--> [Claude Code] $name"
        try "claude marketplace $repo" claude plugin marketplace add "$repo"
        try "claude plugin $name"      claude plugin install "$name@$marketplace"
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
        try "claude marketplace $repo" claude plugin marketplace add "$repo"
        try "claude plugin $name"      claude plugin install "$name@$marketplace"
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

section "3/7  Skills (archify, graphify, asd-ste100)"
if [ "$SKIP_SKILLS" -eq 1 ]; then
    echo "--> skipped: no Node >= $NODE_MIN (see the summary at the end)"
fi
for repo in "${SKILLS[@]}"; do
    [ "$SKIP_SKILLS" -eq 1 ] && break
    if [ "$WANT_CLAUDE" -eq 1 ]; then
        echo "--> [Claude Code] $repo"
        try "claude skill $repo" run_npx -y "$SKILLS_PKG" add "$repo" -g -a claude-code -y
    fi
    if [ "$WANT_CODEX" -eq 1 ]; then
        echo "--> [Codex] $repo"
        try "codex skill $repo" run_npx -y "$SKILLS_PKG" add "$repo" -g -a codex -y
    fi
done

section "4/7  graphify CLI (patched for Python extraction)"
# Recorded rather than fatal: an abort here would skip steps 5-7 AND the
# summary, leaving a partial install with nothing saying so. The graphify hooks
# in step 7 check `command -v graphify` and stay silent without it, so a
# failure here degrades rather than breaks.
try "graphify CLI (install-graphify-patch.sh)" bash "$HERE/install-graphify-patch.sh"

section "5/7  Remove caveman (no longer part of this toolkit)"
# Earlier versions shipped caveman. Its hooks ran on every agent event and
# raised token cost, so remove any old install.
if [ "$WANT_CLAUDE" -eq 1 ]; then
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

section "6/7  Auto-calling, and the /security-audit shim"
# security-guidance needs nothing: it is hook-driven and runs by itself. The
# other two are invoked, so the agent has to know when to reach for them --
# that is what this block puts in CLAUDE.md. Guarded by a marker so re-running
# the installer does not append a second copy.
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

section "7/7  session hooks (graphify + CLAUDE.md work log)"
# A skill is advice the model may or may not act on; a hook is code that runs.
#
# graphify was installed as a skill, so a structural question often got
# answered with grep instead. graphify-session.sh and graphify-reminder.sh
# state that the graph exists, on every new session and again whenever a
# structural question is asked. They refresh nothing: graphify checks freshness
# on each query and rebuilds itself.
#
# journal-stamp.sh and journal-stop.sh keep a CLAUDE.md in every code
# repository and keep its work log current: the first records that the session
# edited a file, the second blocks the end of the turn once, asking for the
# log entry while the work is still in context.
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
echo "Optional: per-repo PR security review -- see README.md 'Security review'."
