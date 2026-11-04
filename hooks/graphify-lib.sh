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

# gf_workspace -- print the graphify workspace root, or nothing.
#
# Two gates, so sessions that are not software work cost nothing: the
# directory must sit in a git repository that holds source files, and graphify
# must recognise a workspace for it. `graphify root` is the authority on the
# second -- it reports the workspace it would build, which in a monorepo is the
# whole tree rather than the sub-project, and is not the same as the git root.
gf_workspace() {
    command -v graphify >/dev/null 2>&1 || return 1
    git rev-parse --show-toplevel >/dev/null 2>&1 || return 1
    [ -n "$(find . -maxdepth 4 \
        \( -path '*/node_modules' -o -path '*/.git' -o -path '*/venv' \
           -o -path '*/.venv' -o -path '*/site-packages' -o -path '*/dist' \
           -o -path '*/build' -o -path '*/__pycache__' \) -prune -o \
        -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.tsx' \
           -o -name '*.jsx' -o -name '*.go' -o -name '*.rs' -o -name '*.java' \
           -o -name '*.kt' -o -name '*.rb' -o -name '*.php' -o -name '*.cs' \
           -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' \
           -o -name '*.hpp' -o -name '*.swift' -o -name '*.scala' \) \
        -print -quit 2>/dev/null)" ] || return 1
    local root
    root="$(graphify root 2>/dev/null | head -1)"
    [ -n "$root" ] && [ -d "$root" ] || return 1
    printf '%s' "$root"
}
