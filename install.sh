#!/usr/bin/env bash
# FuelingAgent -- reinstalls the full Claude Code toolkit this project runs on:
# process skills, scope discipline, a patched cross-repo code graph, diagramming,
# docs style, and token-compression tooling. Idempotent: safe to re-run.
#
# See README.md for what each piece does and why. Run this once per machine.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "1/4  Claude Code plugins (superpowers, ponytail,"
echo "     karpathy-skills, caveman)"
echo "=============================================="
if ! command -v claude >/dev/null 2>&1; then
    echo "ERROR: 'claude' CLI not found on PATH. Install Claude Code first:"
    echo "  https://claude.com/claude-code"
    exit 1
fi

add_plugin() {
    local repo="$1" name="$2" marketplace="$3"
    echo "--> $name ($repo)"
    claude plugin marketplace add "$repo" || true
    claude plugin install "$name@$marketplace" || true
}
add_plugin "obra/superpowers-marketplace"        "superpowers"            "superpowers-marketplace"
add_plugin "DietrichGebert/ponytail"              "ponytail"               "ponytail"
add_plugin "multica-ai/andrej-karpathy-skills"    "andrej-karpathy-skills" "karpathy-skills"
add_plugin "JuliusBrussee/caveman"                "caveman"                "caveman"

echo ""
echo "=============================================="
echo "2/4  Claude Code skills (archify; graphify's"
echo "     SKILL.md front end, separate from the CLI)"
echo "=============================================="
# Needs Node >=22; the repo's own node22/ setup (step 4) provides this if the
# system Node is older. Try system node first, fall back to the bundled one.
NPX_BIN="npx"
if ! node -e 'process.exit(process.versions.node.split(".")[0] >= 22 ? 0 : 1)' 2>/dev/null; then
    if [ -x "$HOME/.local/node22/bin/npx" ]; then
        NPX_BIN="$HOME/.local/node22/bin/npx"
    else
        echo "    system Node is < 22 and no ~/.local/node22 found yet -- run step 4"
        echo "    (node22 install) first, or 'skills add' below may fail."
    fi
fi
"$NPX_BIN" skills add tt-a1i/archify -g || true
"$NPX_BIN" skills add ChihebBENCHEIKH1/graphify -g || true

echo ""
echo "=============================================="
echo "3/4  Bundled skill (asd-ste100 -- no public repo,"
echo "     authored locally, shipped in this toolkit)"
echo "=============================================="
mkdir -p "$HOME/.claude/skills/asd-ste100"
cp "$HERE/bundled-skills/asd-ste100/SKILL.md" "$HOME/.claude/skills/asd-ste100/SKILL.md"
echo "--> installed to ~/.claude/skills/asd-ste100/SKILL.md"

echo ""
echo "=============================================="
echo "4/4  graphify CLI (patched for Python extraction)"
echo "     + Node 22 (needed by caveman CLI and step 2)"
echo "=============================================="
if ! node -e 'process.exit(process.versions.node.split(".")[0] >= 22 ? 0 : 1)' 2>/dev/null; then
    if [ ! -x "$HOME/.local/node22/bin/node" ]; then
        echo "--> installing Node 22.14.0 locally (does not touch system Node)"
        bash "$HERE/scripts/install-node22.sh"
    fi
fi
bash "$HERE/install-graphify-patch.sh"

echo ""
echo "=============================================="
echo "Optional: Caveman CLI (token-compression proxy)"
echo "=============================================="
echo "Not run automatically -- it creates an account and a local proxy daemon"
echo "that can interfere with Claude Code's own tool output if misconfigured"
echo "(see README.md 'Caveman caveat' before enabling). To install:"
echo ""
echo '  PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest setup --install'
echo '  PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest login'
echo '  PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest tools config set think.shrink false'
echo '  PATH="$HOME/.local/node22/bin:$PATH" npx @caveman-ai/cli@latest enable claude'
echo ""
echo "Done. Restart Claude Code (or start a new session) for the plugins/skills"
echo "and settings.json changes to take effect."
