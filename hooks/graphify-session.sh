#!/usr/bin/env bash
# SessionStart hook: state that the code graph exists.
#
# Fires on every new session, so closing one and opening another the next day
# re-arms it. There is nothing to refresh here: graphify checks freshness on
# every query and rebuilds itself, so the graph is current when it is asked,
# not when this runs. See graphify-lib.sh for the probe that established that.
#
# A skill is advice the model may or may not act on. This is the same
# information as a fact of the session, so a structural question does not
# depend on the model choosing to remember the graph is there.
set -uo pipefail
. "$(dirname "$0")/graphify-lib.sh"

ROOT="$(gf_workspace)" || exit 0
SUMMARY="$ROOT/ARCHITECTURE_GRAPH.md"

if [ -s "$SUMMARY" ]; then
    printf 'This workspace has a graphify code graph: summary at %s, queried with the graphify CLI (callers, impact, deps, explain, find). It rebuilds itself when source files change, so it is always current. For any question about who calls or uses something, what a change would break, what depends on what, or what a module does, query graphify FIRST, before Grep or Glob -- it answers those directly and more cheaply than searching.\n' "$SUMMARY"
else
    printf 'This workspace is a graphify workspace (root %s) but has no graph yet. Run `graphify build` once; after that, query the graphify CLI for caller, impact and dependency questions instead of grepping, and it will keep itself current.\n' "$ROOT"
fi
exit 0
