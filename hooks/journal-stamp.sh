#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): record that this session changed a file here.
#
# The Stop hook needs to know whether the session actually did any work. A
# dirty working tree does not answer that -- a repository can sit dirty for
# months -- so the one reliable signal is an edit that happened in this
# session. This writes that signal and nothing else: no model call, no network.
set -uo pipefail
. "$(dirname "$0")/graphify-lib.sh"

PROJ="$(gf_project_dir)" || exit 0
SID="$(cat | gf_session_id)"
[ -n "$SID" ] || SID="nosession"
STAMP="$(gf_stamp_file "$PROJ" "$SID")" || exit 0

mkdir -p "$(dirname "$STAMP")" 2>/dev/null || exit 0
: > "$STAMP" 2>/dev/null || true
exit 0
