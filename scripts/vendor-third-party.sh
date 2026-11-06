#!/usr/bin/env bash
# Rebuild third_party/: a pinned, licensed copy of every third-party plugin,
# skill and action this toolkit installs. install.sh falls back to these when
# an upstream repository is unreachable, renamed or deleted.
#
#   bash scripts/vendor-third-party.sh        # refresh every copy to upstream HEAD
#
# Each copy keeps its upstream LICENSE (and NOTICE, for Apache-2.0). The commit
# each one came from is written to third_party/SOURCES.md. Review the diff
# before committing: this is code that runs with the agent's permissions.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$HERE/third_party"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# name | upstream repo | path inside repo | destination | licence
SOURCES=(
  "superpowers|obra/superpowers|.|plugins/superpowers|MIT"
  "superpowers-marketplace|obra/superpowers-marketplace|.|plugins/superpowers-marketplace|MIT"
  "ponytail|DietrichGebert/ponytail|.|plugins/ponytail|MIT"
  "andrej-karpathy-skills|multica-ai/andrej-karpathy-skills|.|plugins/andrej-karpathy-skills|MIT (declared; no LICENSE file upstream)"
  "claude-security|anthropics/claude-plugins-official|plugins/claude-security|plugins/claude-security|Apache-2.0"
  "phoenix-security-review|Security-Phoenix-demo/security-skills-claude-code|plugins/phoenix-security-review|plugins/phoenix-security-review|MIT"
  "archify|tt-a1i/archify|archify|skills/archify|Apache-2.0"
  "graphify|ChihebBENCHEIKH1/graphify|skill|skills/graphify|MIT"
  "asd-ste100|danyuchn/asd-ste100-skill|.|skills/asd-ste100|MIT"
  "pgvector-semantic-search|timescale/pg-aiguide|skills/pgvector-semantic-search|skills/pgvector-semantic-search|Apache-2.0"
  "postgres-hybrid-text-search|timescale/pg-aiguide|skills/postgres-hybrid-text-search|skills/postgres-hybrid-text-search|Apache-2.0"
  "design-postgres-tables|timescale/pg-aiguide|skills/design-postgres-tables|skills/design-postgres-tables|Apache-2.0"
  "claude-code-security-review|anthropics/claude-code-security-review|.|actions/claude-code-security-review|MIT"
)

{
  echo "# Third-party sources"
  echo
  echo "Copied by \`scripts/vendor-third-party.sh\` on $(date -u +%Y-%m-%d). Every"
  echo "copy is the upstream authors' work, under the upstream licence kept beside it."
  echo "FuelingCodeAgent's own Apache-2.0 licence does not cover these directories."
  echo
  echo "| Name | Upstream | Commit | Licence | Here |"
  echo "|------|----------|--------|---------|------|"
} > "$WORK/SOURCES.md"

declare -A CLONED
for entry in "${SOURCES[@]}"; do
  IFS='|' read -r name repo sub dest licence <<< "$entry"
  src="$WORK/$(tr / _ <<< "$repo")"
  if [ -z "${CLONED[$repo]:-}" ]; then
    git clone -q --depth 1 "https://github.com/$repo" "$src"
    CLONED[$repo]=1
  fi
  sha="$(git -C "$src" rev-parse HEAD)"
  rm -rf "${T:?}/$dest"; mkdir -p "$T/$dest"
  rsync -a --exclude=.git "$src/$sub/" "$T/$dest/"
  # A subdirectory copy still needs the repository's licence and notices.
  for f in LICENSE LICENSE.md NOTICE NOTICE.md THIRD_PARTY_NOTICES.md; do
    [ -f "$src/$f" ] && [ ! -f "$T/$dest/$f" ] && cp "$src/$f" "$T/$dest/"
  done
  echo "| $name | [\`$repo\`](https://github.com/$repo/tree/$sha/$sub) | \`${sha:0:12}\` | $licence | \`third_party/$dest\` |" >> "$WORK/SOURCES.md"
done

# Upstream declares MIT in three places but ships no licence text.
K="$T/plugins/andrej-karpathy-skills/LICENSE"
if [ ! -f "$K" ]; then
  { printf 'MIT License\n\nCopyright (c) multica-ai contributors\n\n'
    printf 'Upstream (https://github.com/multica-ai/andrej-karpathy-skills) declares this\n'
    printf 'licence as "MIT" in README.md, .claude-plugin/plugin.json and\n'
    printf 'skills/karpathy-guidelines/SKILL.md but ships no LICENSE file. This is the\n'
    printf 'standard MIT text, added by FuelingCodeAgent so the terms travel with the copy.\n\n'
    sed -n '/^Permission is hereby granted/,$p' "$T/plugins/ponytail/LICENSE"; } > "$K"
fi

mv "$WORK/SOURCES.md" "$T/SOURCES.md"

# Every copy must carry a licence; refuse to leave one without.
missing=0
for d in "$T"/plugins/* "$T"/skills/* "$T"/actions/*; do
  ls "$d" | grep -qiE '^licen[cs]e' || { echo "NO LICENCE: $d" >&2; missing=1; }
done
[ "$missing" -eq 0 ] || exit 1
echo "third_party/ rebuilt: $(du -sh "$T" | cut -f1); commits in third_party/SOURCES.md"
