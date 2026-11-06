#!/usr/bin/env bash
# Shared gate for the graphify hooks. Source it; it prints nothing itself.
#
# WHY THERE IS NO REFRESH CODE HERE. An earlier version of these hooks ran
# `graphify build` in the background on a one-hour throttle, to keep a long
# session from answering out of a stale graph. That was redundant: graphify
# checks freshness on every query and rebuilds itself when source files have
# moved, which a probe confirmed outright --
#
#   $ graphify callers _probe_fn
#     graph is stale (1 files changed) -- rebuilding...
#     rebuilt
#
# so a timer would duplicate the tool and rebuild even when nobody asks a
# structural question. What was actually missing was never freshness; it was
# that graphify is a skill, so the model had to decide to reach for it, and
# often reached for grep instead. These hooks do only that one job: state that
# the graph exists. The tool keeps it current.

# gf_code_repo -- print the git root, but only for a repository that holds
# source files. This is the shared "is this software work" gate: sessions in
# notes, data or home directories fail it and every hook that uses it exits
# without doing anything.
gf_code_repo() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
    [ -n "$root" ] || return 1
    [ -n "$(find "$root" -maxdepth 4 \
        \( -path '*/node_modules' -o -path '*/.git' -o -path '*/venv' \
           -o -path '*/.venv' -o -path '*/site-packages' -o -path '*/dist' \
           -o -path '*/build' -o -path '*/__pycache__' \) -prune -o \
        -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.tsx' \
           -o -name '*.jsx' -o -name '*.go' -o -name '*.rs' -o -name '*.java' \
           -o -name '*.kt' -o -name '*.rb' -o -name '*.php' -o -name '*.cs' \
           -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' \
           -o -name '*.hpp' -o -name '*.swift' -o -name '*.scala' -o -name '*.sh' \) \
        -print -quit 2>/dev/null)" ] || return 1
    printf '%s' "$root"
}

# gf_project_dir -- print the directory that owns the CLAUDE.md for this work.
#
# NOT the git root. A monorepo holds several projects in one repository, and
# each wants its own CLAUDE.md: in a repository whose sub-directories are the
# actual projects, one CLAUDE.md at the top would describe none of them.
#
# So walk up from the current directory to the git root and take the first
# directory that already has a CLAUDE.md, or failing that looks like a project
# root. Claude Code reads CLAUDE.md from the working directory upwards, so a
# file placed here is loaded automatically by any session working in or under
# it. If nothing matches, the git root is the fallback.
#
# shortcut: keyed on the working directory, not on the file that was edited,
# so a session anchored in one project that edits another logs to the first.
# Split it per edited path if that becomes common.
gf_project_dir() {
    local root dir
    root="$(gf_code_repo)" || return 1
    dir="$(pwd -P 2>/dev/null)" || return 1
    case "$dir" in "$root"|"$root"/*) ;; *) printf '%s' "$root"; return 0 ;; esac
    while :; do
        if [ -f "$dir/CLAUDE.md" ] || [ -f "$dir/pyproject.toml" ] \
           || [ -f "$dir/package.json" ] || [ -f "$dir/Cargo.toml" ] \
           || [ -f "$dir/go.mod" ] || [ -f "$dir/setup.py" ] \
           || [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ] \
           || [ -f "$dir/Gemfile" ] || [ -f "$dir/composer.json" ]; then
            printf '%s' "$dir"; return 0
        fi
        [ "$dir" = "$root" ] && break
        dir="$(dirname "$dir")"
    done
    printf '%s' "$root"
}

# gf_stamp_file -- the per-session, per-project edit stamp, inside .git so it
# is never committed and never shows in git status. The project directory is
# folded into the name, so two projects of one monorepo do not trigger for
# each other. cksum is POSIX, unlike md5sum.
gf_stamp_file() {
    local proj="$1" sid="$2" gitdir key
    gitdir="$(git rev-parse --absolute-git-dir 2>/dev/null)" || return 1
    key="$(printf '%s' "$proj" | cksum | tr -cd '0-9')"
    printf '%s/fuelingcodeagent/edited-%s-%s' "$gitdir" "$sid" "$key"
}

# gf_session_id -- print the session id from a hook payload given on stdin.
gf_session_id() {
    sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

# gf_workspace -- print the graphify workspace root, or nothing.
#
# Two gates, so sessions that are not software work cost nothing: the
# directory must sit in a git repository that holds source files, and graphify
# must recognise a workspace for it. `graphify root` is the authority on the
# second -- it reports the workspace it would build, which in a monorepo is the
# whole tree rather than the sub-project, and is not the same as the git root.
gf_workspace() {
    command -v graphify >/dev/null 2>&1 || return 1
    gf_code_repo >/dev/null || return 1
    local root
    root="$(graphify root 2>/dev/null | head -1)"
    [ -n "$root" ] && [ -d "$root" ] || return 1
    printf '%s' "$root"
}
