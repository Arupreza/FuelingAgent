#!/usr/bin/env bash
# Stop hook: every project keeps a CLAUDE.md, and it stays current without
# anyone remembering to update it.
#
# The file carries two kinds of thing, and the second is the point. A work log
# says what changed and when. Direction says how this project does things --
# the command, the inputs, where output goes, the format that was chosen. Ask
# for the same artefact two weeks later and direction is what makes it come
# out the same; a log entry only proves it once happened.
#
# Why a hook and not a rule in CLAUDE.md: a rule is advice the model may drop
# once the context fills, and the end of a session is exactly when it is
# fullest. A Stop hook is code -- it runs after the model believes it has
# finished, and blocking it hands the turn back with one instruction.
#
# It fires at most ONCE per session per project: the stamp is removed before
# the block is emitted, so if the model writes nothing the next Stop passes
# straight through and the session cannot loop.
set -uo pipefail
. "$(dirname "$0")/graphify-lib.sh"

INPUT="$(cat)"
# Already inside a Stop-hook continuation: let it end.
printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

PROJ="$(gf_project_dir)" || exit 0
SID="$(printf '%s' "$INPUT" | gf_session_id)"
[ -n "$SID" ] || SID="nosession"
STAMP="$(gf_stamp_file "$PROJ" "$SID")" || exit 0
[ -f "$STAMP" ] || exit 0          # nothing was changed in this session

CM="$PROJ/CLAUDE.md"
TODAY="$(date +%F)"

if [ -f "$CM" ]; then
    # Logged under today's date already: leave the stamp, so a later edit in
    # this same session is still covered, and say nothing.
    grep -q "^- $TODAY" "$CM" && exit 0
    REASON="Before you finish: update $CM so the next session can repeat this work without being briefed again. Two parts. (1) Work log: one line under the '## Work log' heading, creating that heading at the end of the file if it is not there yet -- '- $TODAY: <what changed, one sentence>', newest last. (2) Direction, and this is the part that matters: if this session settled how something is done in this project -- a command and its arguments, a script and its inputs, where output belongs, a format or layout that was chosen, a trap that cost time -- write it under a '## How things are done here' heading as an instruction for next time, not as a story. Edit the existing entry instead of adding a near-duplicate, and skip this part if nothing durable came up. Change nothing else in the file, and do not restate it in your reply."
else
    REASON="Before you finish: this project has no CLAUDE.md. Write $CM so the next session needs no briefing -- what the project is, how to run and test it, and the conventions a newcomer would get wrong. Give it a '## How things are done here' heading holding this project's repeatable tasks as instructions: for each one the command or tool, its inputs, where the output goes, and the format or layout that was chosen, so asking for the same artefact in two weeks produces the same thing. End with a '## Work log' heading whose first line is '- $TODAY: <what changed in this session, one sentence>'. Describe the project as it is now, not its history. Keep the file under 80 lines, state only what you have verified in the code, and do not restate it in your reply."
fi

# Fire once: remove the stamp first, so a model that ignores this is not asked
# again and the session always terminates.
rm -f "$STAMP"

# Hand-built JSON: jq may not be installed, and REASON holds no quote or
# newline, so no escaping is needed.
printf '{"decision":"block","reason":"%s"}\n' "$REASON"
exit 0
