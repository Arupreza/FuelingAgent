#!/usr/bin/env bash
# SessionStart hook: keep the code graph fresh and tell the agent it is there.
#
# graphify ships as a skill, so whether it gets used is the model's choice, and
# a structural question often gets answered with grep instead. This makes the
# graph a fact of every coding session rather than a suggestion: it refreshes
# the graph when source files have moved ahead of it, and states where the
# graph is so the agent does not have to decide whether to look. It runs on
# every new session, so closing one and opening another re-arms it.
#
# It stays out of the way of everything that is not software work: a session in
# a notes folder, a data directory or a home directory prints nothing and costs
# no tokens, because the gates below fail there.
#
# WHY IT ONLY REFRESHES A GRAPH THAT EXISTS. An earlier version took the git
# root as the project and built a graph there when none was found. In a
# monorepo that is wrong twice over: `git rev-parse --show-toplevel` inside
# Rezaworks/DeNovo-Design-AI reports Rezaworks, so the hook missed the graph
# that was already built one level down AND started building a graph of every
# project at once. Creating a graph is also not what "keep it up to date"
# asks for. So: walk up for an existing graphify-out and refresh that one;
# where there is none, say so in one line and let the user run build.
set -uo pipefail

LOG="$HOME/.claude/graphify-session.log"
command -v graphify >/dev/null 2>&1 || exit 0

# ---- gate 1: a git repository ------------------------------------------------
GITROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$GITROOT" ] || exit 0

# ---- gate 2: it actually holds source code -----------------------------------
# "Only code and software development" is this test. A git repo of notes, data
# or configuration has no source files and is left alone. Vendored and virtual
# environment trees are pruned so a dependency directory cannot qualify a repo
# that has no code of its own.
PRUNE=( -path '*/node_modules' -o -path '*/.git' -o -path '*/venv'
        -o -path '*/.venv' -o -path '*/site-packages' -o -path '*/dist'
        -o -path '*/build' -o -path '*/graphify-out' )
SRC=( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.tsx'
      -o -name '*.jsx' -o -name '*.go' -o -name '*.rs' -o -name '*.java'
      -o -name '*.kt' -o -name '*.rb' -o -name '*.php' -o -name '*.cs'
      -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h'
      -o -name '*.hpp' -o -name '*.swift' -o -name '*.scala' )

HAS_CODE="$(find . -maxdepth 4 \( "${PRUNE[@]}" \) -prune -o \
    -type f \( "${SRC[@]}" \) -print -quit 2>/dev/null)"
[ -n "$HAS_CODE" ] || exit 0

# ---- find the project: nearest existing graph, walking up --------------------
ROOT=""
dir="$(pwd)"
while [ "$dir" != "/" ]; do
    if [ -f "$dir/graphify-out/graph.json" ]; then ROOT="$dir"; break; fi
    [ "$dir" = "$GITROOT" ] && break        # do not escape the repository
    dir="$(dirname "$dir")"
done

if [ -z "$ROOT" ]; then
    printf 'This repository has no graphify code graph. Run `graphify build` at its root to create one; after that, prefer it over Grep for questions about callers, impact and dependencies.\n'
    exit 0
fi

JSON="$ROOT/graphify-out/graph.json"
GRAPH="$ROOT/graphify-out/GRAPH_REPORT.md"

# ---- refresh, detached -------------------------------------------------------
# Rebuild when any source file is newer than the graph. Comparing timestamps
# rather than using a fixed interval means an untouched project is never
# rebuilt and a busy one is always current. The build is detached because a
# first build on a large repository is slow and a session must never wait.
NEWER="$(find "$ROOT" -maxdepth 6 \( "${PRUNE[@]}" \) -prune -o \
    -type f \( "${SRC[@]}" \) -newer "$JSON" -print -quit 2>/dev/null)"

STALE=0
if [ -n "$NEWER" ]; then
    STALE=1
    LOCK="$ROOT/graphify-out/.build.lock"      # keeps concurrent sessions to one build
    if mkdir "$LOCK" 2>/dev/null; then
        (
            trap 'rmdir "$LOCK" 2>/dev/null' EXIT
            cd "$ROOT" || exit 0
            echo "[$(date '+%F %T')] build start $ROOT" >> "$LOG"
            graphify build -q >> "$LOG" 2>&1
            echo "[$(date '+%F %T')] build end   $ROOT rc=$?" >> "$LOG"
        ) </dev/null >/dev/null 2>&1 &
        disown 2>/dev/null || true
    fi
fi

# ---- tell the agent ----------------------------------------------------------
TARGET="$GRAPH"; [ -s "$GRAPH" ] || TARGET="$JSON"
AGE=$(( ( $(date +%s) - $(stat -c %Y "$JSON" 2>/dev/null || date +%s) ) / 3600 ))
NOTE=""
[ "$STALE" -eq 1 ] && NOTE=" Source files have changed since it was built and a refresh is running in the background, so re-read it if an answer looks out of date."
printf 'This repository has a graphify code graph at %s (built %sh ago).%s For any question about who calls or uses something, what a change would break, what depends on what, or what a module does, read that report or query the graphify CLI FIRST, before Grep or Glob. It answers caller, impact and dependency questions directly and more cheaply than searching.\n' \
    "$TARGET" "$AGE" "$NOTE"
exit 0
