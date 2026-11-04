#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): record that this session changed a file here.
#
# The Stop hook needs to know whether the session actually did any work. A
# dirty working tree does not answer that -- a repository can sit dirty for
# months -- so the one reliable signal is an edit that happened in this
# session. This writes that signal and nothing else: no model call, no network.
#
# The stamp lives inside .git, so it is never committed and never shows up in
# git status.
set -uo pipefail
. "$(dirname "$0")/graphify-lib.sh"

ROOT="$(gf_code_repo)" || exit 0
GITDIR="$(git -C "$ROOT" rev-parse --absolute-git-dir 2>/dev/null)" || exit 0
SID="$(cat | gf_session_id)"
[ -n "$SID" ] || SID="nosession"

mkdir -p "$GITDIR/fuelingcodeagent" 2>/dev/null || exit 0
: > "$GITDIR/fuelingcodeagent/edited-$SID" 2>/dev/null || true
exit 0
