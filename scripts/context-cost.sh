#!/usr/bin/env bash
# What this session re-sends on EVERY request. Run it when cost looks high.
#   bash ~/.claude/context-cost.sh      (run it from the project you are in)
t() { [ -f "$1" ] && printf "  %-38s %6d tokens\n" "$2" $(( $(wc -c < "$1") / 4 )); }
SETTINGS="$(readlink -f "$HOME/.claude/settings.json" 2>/dev/null || echo "$HOME/.claude/settings.json")"
export SETTINGS
echo "Per-request context (approx tokens, 4 bytes/token):"
t CLAUDE.md                            "project CLAUDE.md"
t "$HOME/.claude/CLAUDE.md"            "user CLAUDE.md"
for m in "$HOME"/.claude/projects/*/memory/MEMORY.md; do
    [ -f "$m" ] && t "$m" "MEMORY.md ($(basename "$(dirname "$(dirname "$m")")" | tail -c 24))"
done
python3 - <<'PY'
import glob, re, os, json
# Only ENABLED plugins cost anything. A disabled plugin still sits in the
# cache, so counting the directory over-reports and hides the saving.
cfg = json.load(open(os.environ["SETTINGS"]))
on = {k.split("@")[0] for k, v in cfg.get("enabledPlugins", {}).items() if v}
def total(pat):
    n = 0
    for f in glob.glob(os.path.expanduser(pat)):
        plug = f.split("/plugins/cache/")[1].split("/")[1]
        if plug not in on:
            continue
        t = open(f, encoding="utf-8", errors="replace").read(4000)
        m = re.search(r"^description:\s*(.+?)(?=\n\w+:|\n---)", t, re.S | re.M)
        if m: n += len(m.group(1))
    return n // 4
print(f"  {'plugin skill descriptions':38} {total('~/.claude/plugins/cache/*/*/*/skills/*/SKILL.md'):6d} tokens")
print(f"  {'plugin agent descriptions':38} {total('~/.claude/plugins/cache/*/*/*/agents/*.md'):6d} tokens")
print(f"  {'(enabled plugins)':38} {', '.join(sorted(on))}")
PY
echo
echo "Cost multipliers (these matter more than any of the above):"
python3 -c "
import json,os
d=json.load(open(os.environ['SETTINGS']))
for k in ('model','effortLevel'):
    print(f'  {k:38} {d.get(k,\"(default)\")}')
ep=d.get('enabledPlugins',{}); print(f'  {\"enabled plugins\":38} {sum(1 for v in ep.values() if v)} of {len(ep)} enabled')
"
echo
echo "Rule of thumb: anything above ~2000 tokens in the first block is worth splitting."
