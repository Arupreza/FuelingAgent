#!/usr/bin/env bash
# Stop hook: every code repository keeps a CLAUDE.md, and its work log stays
# current without anyone remembering to update it.
#
# Why a hook and not a rule in CLAUDE.md: a rule is advice the model may drop
# once the context fills, and the end of a session is exactly when it is
# fullest. A Stop hook is code -- it runs after the model believes it has
# finished, and blocking it hands the turn back with one instruction.
#
# It fires at most ONCE per session per repository: the stamp is removed before
# the block is emitted, so if the model writes nothing the next Stop passes
# straight through and the session cannot loop.
set -uo pipefail
. "$(dirname "$0")/graphify-lib.sh"

INPUT="$(cat)"
# Already inside a Stop-hook continuation: let it end.
printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

ROOT="$(gf_code_repo)" || exit 0
GITDIR="$(git -C "$ROOT" rev-parse --absolute-git-dir 2>/dev/null)" || exit 0
SID="$(printf '%s' "$INPUT" | gf_session_id)"
[ -n "$SID" ] || SID="nosession"
STAMP="$GITDIR/fuelingcodeagent/edited-$SID"
[ -f "$STAMP" ] || exit 0          # nothing was changed in this session

CM="$ROOT/CLAUDE.md"
TODAY="$(date +%F)"

if [ -f "$CM" ]; then
    # Logged under today's date already: leave the stamp, so a later edit in
    # this same session is still covered, and say nothing.
    grep -q "^- $TODAY" "$CM" && exit 0
    REASON="Before you finish: append this session to the work log in $CM. Add one line under the '## Work log' heading, creating that heading at the end of the file if it is not there yet: '- $TODAY: <what changed, one sentence>'. Newest entries go last. If what you did changes how the project is built, run or tested, update that part of the file too. Change nothing else, and do not restate the log in your reply."
else
    REASON="Before you finish: this repository has no CLAUDE.md. Write $CM as a short orientation for whoever opens the next session -- what the project is, how to run and test it, the conventions a newcomer would get wrong -- and end it with a '## Work log' heading whose first line is '- $TODAY: <what changed in this session, one sentence>'. Describe what the repository is now, not its history. Keep the whole file under 80 lines, state only what you have verified in the code, and do not restate it in your reply."
fi

# Fire once: remove the stamp first, so a model that ignores this is not asked
# again and the session always terminates.
rm -f "$STAMP"

# Hand-built JSON: jq may not be installed, and REASON holds no quote or
# newline, so no escaping is needed.
printf '{"decision":"block","reason":"%s"}\n' "$REASON"
exit 0
