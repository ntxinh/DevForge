#!/usr/bin/env bash
# Validates every plugin manifest in this repository:
#  - each file/field listed in .version-bump.json exists, parses, and carries
#    the same version as package.json
#  - each plugin manifest has the required identity fields
#  - the marketplace listing points at this repository's own plugin
#
# Exits non-zero on the first category that fails, after reporting every
# failure it found (so one run shows all the problems, not just the first).
set -uo pipefail

cd "$(dirname "$0")/.."

command -v jq >/dev/null 2>&1 || { echo "jq is required to run this test" >&2; exit 2; }

FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }
pass() { echo "ok: $*"; }

# jq path expression for a dotted field like "plugins.0.version"
jq_path_for() {
  printf '.%s' "$(printf '%s' "$1" | sed -E 's/\.([0-9]+)/[\1]/g')"
}

[ -f package.json ] || { echo "FAIL: package.json is missing" >&2; exit 1; }
EXPECTED_VERSION=$(jq -r '.version // empty' package.json)
[ -n "$EXPECTED_VERSION" ] || fail "package.json: version is empty"

# 1. Version parity across every mapped field
[ -f .version-bump.json ] || { echo "FAIL: .version-bump.json is missing" >&2; exit 1; }
jq empty .version-bump.json 2>/dev/null \
  || { echo "FAIL: .version-bump.json: invalid JSON" >&2; exit 1; }
while IFS=$'\t' read -r file field; do
  if [ ! -f "$file" ]; then
    fail "$file: listed in .version-bump.json but missing"
    continue
  fi
  if ! jq empty "$file" 2>/dev/null; then
    fail "$file: invalid JSON"
    continue
  fi
  actual=$(jq -r "$(jq_path_for "$field") // empty" "$file")
  if [ "$actual" != "$EXPECTED_VERSION" ]; then
    fail "$file: $field is '$actual', expected '$EXPECTED_VERSION'"
  else
    pass "$file: $field == $EXPECTED_VERSION"
  fi
done < <(jq -r '.files[] | "\(.path)\t\(.field)"' .version-bump.json)

# 2. Required identity fields on every plugin manifest present on disk
for manifest in .claude-plugin/plugin.json .codex-plugin/plugin.json .devin-plugin/plugin.json .cursor-plugin/plugin.json; do
  [ -f "$manifest" ] || continue
  for field in .name .description .version .author.name .author.email .license .homepage .repository; do
    value=$(jq -r "$field // empty" "$manifest")
    [ -n "$value" ] || fail "$manifest: $field is empty"
  done
  name=$(jq -r '.name // empty' "$manifest")
  [ "$name" = "devforge" ] || fail "$manifest: name is '$name', expected 'devforge'"
  pass "$manifest: identity fields present"
done

# 3. Marketplace listing
MP=.claude-plugin/marketplace.json
if [ -f "$MP" ]; then
  [ "$(jq -r '.name // empty' "$MP")" = "devforge-marketplace" ] \
    || fail "$MP: name is not 'devforge-marketplace'"
  [ "$(jq -r '.plugins[0].name // empty' "$MP")" = "devforge" ] \
    || fail "$MP: plugins[0].name is not 'devforge'"
  [ "$(jq -r '.plugins[0].source // empty' "$MP")" = "./" ] \
    || fail "$MP: plugins[0].source is not './'"
  pass "$MP: marketplace listing valid"
else
  fail "$MP: missing"
fi

exit "$FAILED"
