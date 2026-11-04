#!/usr/bin/env bash
# UserPromptSubmit hook: point the agent at an existing code graph.
#
# graphify ships as a skill, so whether it gets used is the model's choice, and
# in practice a structural question often gets answered with grep instead. A
# CLAUDE.md line is advice; this is a check that runs. It fires only when the
# prompt actually asks a structural question AND a built graph exists, so it
# stays silent on ordinary work. No model call, no network.
set -uo pipefail

INPUT="$(cat)"
PROMPT="$(printf '%s' "$INPUT" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -c 4000)"
[ -z "$PROMPT" ] && exit 0

# Structural questions only: who touches this, what breaks, how does X relate.
printf '%s' "$PROMPT" | grep -qiE \
  "who (calls|uses|consumes|touches|depends)|what (breaks|is affected|uses)|call(er|ers|ed by)|impact of|depends on|dependen(cy|cies)|blast radius|where is .* (used|defined)|explain (the )?(class|module|service)" \
  || exit 0

# Nearest built graph, searching upward from the working directory.
dir="$(pwd)"
while [ "$dir" != "/" ]; do
    if [ -f "$dir/graphify-out/GRAPH_REPORT.md" ]; then
        printf 'A built code graph for this workspace is at %s/graphify-out/GRAPH_REPORT.md. Read it, or query it with the graphify CLI, before grepping: it answers caller, impact and dependency questions directly.\n' "$dir"
        exit 0
    fi
    dir="$(dirname "$dir")"
done
exit 0
