#!/usr/bin/env bash
# UserPromptSubmit hook: name graphify when a structural question is asked.
#
# SessionStart already states the graph exists, but a long session drifts: by
# the fiftieth message that line is far up the context and grep looks closer to
# hand. This repeats the pointer at the moment it matters, and only then, so an
# ordinary prompt costs nothing.
#
# No model call, no network, no rebuild -- graphify refreshes itself on query.
set -uo pipefail
. "$(dirname "$0")/graphify-lib.sh"

INPUT="$(cat)"
PROMPT="$(printf '%s' "$INPUT" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -c 4000)"
[ -n "$PROMPT" ] || exit 0

printf '%s' "$PROMPT" | grep -qiE \
  "who (calls|uses|consumes|touches|depends)|what (breaks|is affected|uses)|call(er|ers|ed by)|impact of|depends on|dependen(cy|cies)|blast radius|where is .* (used|defined)|explain (the )?(class|module|service)" \
  || exit 0

ROOT="$(gf_workspace)" || exit 0
printf 'This is a graphify question. Query the graphify CLI (callers / impact / deps / explain) or read %s/ARCHITECTURE_GRAPH.md before grepping: it answers caller, impact and dependency questions directly, and rebuilds itself if the graph is stale.\n' "$ROOT"
exit 0
