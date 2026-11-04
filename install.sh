#!/usr/bin/env bash
# FuelingAgent -- reinstalls the full Claude Code toolkit this project runs on:
# process skills, scope discipline, a patched cross-repo code graph, diagramming,
# and docs style. Idempotent: safe to re-run.
#
# See README.md for what each piece does and why. Run this once per machine.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "1/3  Claude Code plugins (superpowers, ponytail,"
echo "     karpathy-skills)"
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

# caveman was dropped from this toolkit (see README "Why caveman was removed").
# Clean up any earlier install so re-running this script fixes old machines.
if claude plugin list 2>/dev/null | grep -q "caveman@caveman"; then
    echo "--> removing caveman plugin (no longer part of this toolkit)"
    claude plugin uninstall caveman@caveman || true
fi
claude plugin marketplace remove caveman >/dev/null 2>&1 || true
claude mcp remove caveman -s user >/dev/null 2>&1 || true
pkill -f caveman-proxy 2>/dev/null || true
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ] && grep -q "caveman" "$SETTINGS"; then
    echo "--> removing caveman hooks / proxy URL from $SETTINGS"
    cp "$SETTINGS" "$SETTINGS.bak-caveman"
    python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    s = json.load(f)
hooks = s.get("hooks", {})
for event in list(hooks):
    groups = []
    for g in hooks[event]:
        g["hooks"] = [h for h in g.get("hooks", []) if "caveman" not in h.get("command", "")]
        if g["hooks"]:
            groups.append(g)
    if groups:
        hooks[event] = groups
    else:
        del hooks[event]
if not hooks:
    s.pop("hooks", None)
env = s.get("env", {})
if "8787" in env.get("ANTHROPIC_BASE_URL", ""):
    del env["ANTHROPIC_BASE_URL"]
s.get("enabledPlugins", {}).pop("caveman@caveman", None)
s.get("extraKnownMarketplaces", {}).pop("caveman", None)
with open(path, "w") as f:
    json.dump(s, f, indent=2)
    f.write("\n")
PY
fi

echo ""
echo "=============================================="
echo "2/3  Claude Code skills (archify, asd-ste100;"
echo "     graphify's SKILL.md front end, separate"
echo "     from the CLI)"
echo "=============================================="
# Needs Node >=22; the repo's own node22/ setup (step 3) provides this if the
# system Node is older. Try system node first, fall back to the bundled one.
NPX_BIN="npx"
if ! node -e 'process.exit(process.versions.node.split(".")[0] >= 22 ? 0 : 1)' 2>/dev/null; then
    if [ -x "$HOME/.local/node22/bin/npx" ]; then
        NPX_BIN="$HOME/.local/node22/bin/npx"
    else
        echo "    system Node is < 22 and no ~/.local/node22 found yet -- run step 3"
        echo "    (node22 install) first, or 'skills add' below may fail."
    fi
fi
"$NPX_BIN" skills add tt-a1i/archify -g || true
"$NPX_BIN" skills add ChihebBENCHEIKH1/graphify -g || true
"$NPX_BIN" skills add danyuchn/asd-ste100-skill -g || true

echo ""
echo "=============================================="
echo "3/3  graphify CLI (patched for Python extraction)"
echo "     + Node 22 (needed by step 2)"
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
echo "Optional: PR security review (GitHub Action)"
echo "=============================================="
echo "/security-review already works locally -- it ships with Claude Code,"
echo "nothing to install. For automated review on every PR, per repo:"
echo ""
echo "  mkdir -p .github/workflows"
echo "  cp \"$HERE/templates/github-actions/security-review.yml\" .github/workflows/"
echo ""
echo "Then add a CLAUDE_API_KEY repo secret on GitHub. See README.md"
echo "'Security review' for the prompt-injection caveat before enabling."
echo ""
echo "Done. Restart Claude Code (or start a new session) for the plugins/skills"
echo "and settings.json changes to take effect."
