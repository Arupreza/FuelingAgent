#!/usr/bin/env bash
# Installs graphify-cli 0.1.0 with Python extraction support (classes, Pydantic
# DTOs, functions, EXTENDS, DEPENDS_ON) added on top of its stock Kotlin/TypeScript
# extractors. See README.md for what this actually does and why.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${GRAPHIFY_VENV_DIR:-$HOME/.venvs/graphify}"
BIN_DIR="${GRAPHIFY_BIN_DIR:-$HOME/.local/bin}"

# RE-RUNS MUST START FROM PRISTINE FILES.
# `uv venv` reuses an existing environment rather than clearing it, and
# `uv pip install` then treats the wheel as already satisfied and installs
# nothing -- so the PATCHED files from the previous run survive, and the patch
# step below meets its own output. GNU patch 2.7.6 skips, exits 1 and leaves a
# .rej file, which `set -e` turns into an aborted install; BSD patch on macOS
# can instead assume -R and silently REVERSE the patch, leaving graphify
# installed but with Python extraction removed. Both were reachable from the
# README's claim that re-running is safe. Clearing the environment removes the
# whole class of problem, and apply_patch below is idempotent regardless.
echo "==> Installing graphify-cli 0.1.0 into $VENV_DIR"
if [ -d "$VENV_DIR" ]; then
    # pyvenv.cfg alone is NOT proof: every virtualenv has one, so that test
    # would delete a real project's environment if GRAPHIFY_VENV_DIR pointed at
    # it (say ~/myproject/.venv). Require the graphify entry point as well --
    # only an environment this script set up has both.
    if [ -f "$VENV_DIR/pyvenv.cfg" ] && [ -e "$VENV_DIR/bin/graphify" ]; then
        echo "    removing the existing environment so the patches apply to pristine files"
        rm -rf "$VENV_DIR"
    else
        # Nothing good follows: uv and python3 -m venv both refuse to create
        # into a non-empty directory, so say why here rather than let their
        # message be the first sign of trouble.
        echo "ERROR: $VENV_DIR exists but is not a graphify environment." >&2
        echo "       Expected both pyvenv.cfg and bin/graphify in it." >&2
        echo "       This script will not delete a directory it did not create." >&2
        echo "       Move it aside, or point GRAPHIFY_VENV_DIR somewhere else." >&2
        exit 1
    fi
fi
if command -v uv >/dev/null 2>&1; then
    uv venv "$VENV_DIR" --quiet
    echo "==> Installing the pinned wheel (bundled, so this doesn't drift with future PyPI releases)"
    uv pip install --python "$VENV_DIR/bin/python" --quiet "$HERE/patches/graphify/graphify_cli-0.1.0-py3-none-any.whl"
else
    echo "    (uv not found, falling back to python3 -m venv + pip -- if this fails with"
    echo "     an ensurepip error, install python3-venv via your package manager first)"
    python3 -m venv "$VENV_DIR"
    echo "==> Installing the pinned wheel (bundled, so this doesn't drift with future PyPI releases)"
    "$VENV_DIR/bin/pip" install --quiet --upgrade pip
    "$VENV_DIR/bin/pip" install --quiet "$HERE/patches/graphify/graphify_cli-0.1.0-py3-none-any.whl"
fi

PKG_DIR="$("$VENV_DIR/bin/python" -c "import graphify, os; print(os.path.dirname(graphify.__file__))")"
echo "==> Package installed at: $PKG_DIR"

# apply_patch -- apply a diff, or report it is already applied, or fail loudly.
#
# `patch -N` is NOT enough on its own: GNU patch 2.7.6 still exits 1 on an
# already-applied patch and still writes a .rej file, so `set -e` kills the
# script. The reliable test is whether the patch applies cleanly IN REVERSE --
# that is true only when it is already applied. Dry runs decide, so nothing is
# written until the outcome is known, and the three cases stay distinct:
# applied now, already applied, or genuinely broken.
apply_patch() {
    local diff="$1" dir="$2" name
    name="$(basename "$diff")"
    if patch -p1 -d "$dir" --dry-run --forward < "$diff" >/dev/null 2>&1; then
        patch -p1 -d "$dir" --forward < "$diff" >/dev/null
        echo "    applied   $name"
    elif patch -p1 -d "$dir" -R --dry-run --forward < "$diff" >/dev/null 2>&1; then
        echo "    already applied, skipped   $name"
    else
        echo "    ERROR: $name does not apply and is not already applied." >&2
        echo "           The installed graphify is not the version these patches target." >&2
        echo "           Remove $VENV_DIR and re-run." >&2
        return 1
    fi
}

echo "==> Applying Python-extraction patches"
apply_patch "$HERE/patches/graphify/extract.py.diff"   "$PKG_DIR/.."
apply_patch "$HERE/patches/graphify/workspace.py.diff" "$PKG_DIR/.."
# A failed run can leave these behind; they are not part of a good install.
find "$PKG_DIR" -maxdepth 1 \( -name '*.rej' -o -name '*.orig' \) -delete 2>/dev/null || true

# Parsing proves the files are valid Python, not that the patches are in them.
# A reversed patch leaves perfectly valid files, which is exactly how the
# earlier bug reported success, so check for the Python extractor itself.
echo "==> Verifying the patched package"
"$VENV_DIR/bin/python" - <<PYCHECK
import ast, sys
ok = True
for f in ("$PKG_DIR/extract.py", "$PKG_DIR/workspace.py"):
    src = open(f).read()
    try:
        ast.parse(src)
    except SyntaxError as e:
        print("  SYNTAX ERROR in %s: %s" % (f, e)); ok = False
for needle in ("BaseModel", "DEPENDS_ON", "EXTENDS"):
    if needle not in open("$PKG_DIR/extract.py").read():
        print("  MISSING %r in extract.py -- the Python patch is not applied" % needle)
        ok = False
print("  verified: syntax valid and the Python extractor is present" if ok else "  VERIFICATION FAILED")
sys.exit(0 if ok else 1)
PYCHECK

echo "==> Linking the graphify binary into $BIN_DIR"
mkdir -p "$BIN_DIR"
ln -sf "$VENV_DIR/bin/graphify" "$BIN_DIR/graphify"

echo "==> Done."
echo ""
echo "Add $BIN_DIR to PATH if it isn't already, then:"
echo "  cd <any project you want to add a marker for> && touch pyproject.toml   # if it's Python and doesn't have one"
echo "  cd <your workspace root, the dir containing multiple project dirs>"
echo "  graphify build"
echo "  graphify explain <SomeClassName>"
echo ""
echo "Do NOT set GRAPHIFY_ROOT/GRAPHIFY_CACHE/GRAPHIFY_KB as fixed paths in your"
echo "shell profile unless you specifically want to override auto-discovery for"
echo "every project forever -- see README.md 'Common mistake' section."
