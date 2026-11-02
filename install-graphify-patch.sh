#!/usr/bin/env bash
# Installs graphify-cli 0.1.0 with Python extraction support (classes, Pydantic
# DTOs, functions, EXTENDS, DEPENDS_ON) added on top of its stock Kotlin/TypeScript
# extractors. See README.md for what this actually does and why.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${GRAPHIFY_VENV_DIR:-$HOME/.venvs/graphify}"
BIN_DIR="${GRAPHIFY_BIN_DIR:-$HOME/.local/bin}"

echo "==> Installing graphify-cli 0.1.0 into $VENV_DIR"
if command -v uv >/dev/null 2>&1; then
    uv venv "$VENV_DIR" --quiet
    echo "==> Installing the pinned wheel (bundled, so this doesn't drift with future PyPI releases)"
    uv pip install --python "$VENV_DIR/bin/python" --quiet "$HERE/patches/graphify_cli-0.1.0-py3-none-any.whl"
else
    echo "    (uv not found, falling back to python3 -m venv + pip -- if this fails with"
    echo "     an ensurepip error, install python3-venv via your package manager first)"
    python3 -m venv "$VENV_DIR"
    echo "==> Installing the pinned wheel (bundled, so this doesn't drift with future PyPI releases)"
    "$VENV_DIR/bin/pip" install --quiet --upgrade pip
    "$VENV_DIR/bin/pip" install --quiet "$HERE/patches/graphify_cli-0.1.0-py3-none-any.whl"
fi

PKG_DIR="$("$VENV_DIR/bin/python" -c "import graphify, os; print(os.path.dirname(graphify.__file__))")"
echo "==> Package installed at: $PKG_DIR"

echo "==> Applying Python-extraction patches"
patch -p1 -d "$PKG_DIR/.." < "$HERE/patches/extract.py.diff"
patch -p1 -d "$PKG_DIR/.." < "$HERE/patches/workspace.py.diff"

echo "==> Verifying the patched package imports and parses cleanly"
"$VENV_DIR/bin/python" -c "import ast; ast.parse(open('$PKG_DIR/extract.py').read()); ast.parse(open('$PKG_DIR/workspace.py').read()); print('syntax OK')"

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
