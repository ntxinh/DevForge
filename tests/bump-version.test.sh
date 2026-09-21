#!/usr/bin/env bash
# Asserts scripts/bump-version.sh moves EVERY field listed in
# .version-bump.json, by running it against a throwaway copy of the
# version-carrying files.
set -uo pipefail

cd "$(dirname "$0")/.."
REPO=$PWD

command -v jq >/dev/null 2>&1 || { echo "jq is required to run this test" >&2; exit 2; }

FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Copy the scripts plus every file that carries a version.
mkdir -p "$TMP/scripts"
cp "$REPO/scripts/bump-version.sh" "$TMP/scripts/" 2>/dev/null \
  || { echo "FAIL: scripts/bump-version.sh is missing" >&2; exit 1; }
cp "$REPO/.version-bump.json" "$TMP/"
while IFS= read -r file; do
  mkdir -p "$TMP/$(dirname "$file")"
  cp "$REPO/$file" "$TMP/$file"
done < <(jq -r '.files[].path' "$REPO/.version-bump.json")

# Explicit version: every field must end up at 9.9.9
( cd "$TMP" && ./scripts/bump-version.sh 9.9.9 >/dev/null ) || fail "bump to 9.9.9 exited non-zero"
while IFS=$'\t' read -r file field; do
  jq_path=".$(printf '%s' "$field" | sed -E 's/\.([0-9]+)/[\1]/g')"
  actual=$(jq -r "$jq_path // empty" "$TMP/$file")
  [ "$actual" = "9.9.9" ] || fail "$file: $field is '$actual' after explicit bump, expected '9.9.9'"
done < <(jq -r '.files[] | "\(.path)\t\(.field)"' "$REPO/.version-bump.json")

# Relative bump: 9.9.9 -> patch -> 9.9.10
( cd "$TMP" && ./scripts/bump-version.sh patch >/dev/null ) || fail "patch bump exited non-zero"
[ "$(jq -r '.version' "$TMP/package.json")" = "9.9.10" ] \
  || fail "patch bump did not produce 9.9.10"

# 9.9.10 -> minor -> 9.10.0
( cd "$TMP" && ./scripts/bump-version.sh minor >/dev/null ) || fail "minor bump exited non-zero"
[ "$(jq -r '.version' "$TMP/package.json")" = "9.10.0" ] \
  || fail "minor bump did not produce 9.10.0"

# 9.10.0 -> major -> 10.0.0
( cd "$TMP" && ./scripts/bump-version.sh major >/dev/null ) || fail "major bump exited non-zero"
[ "$(jq -r '.version' "$TMP/package.json")" = "10.0.0" ] \
  || fail "major bump did not produce 10.0.0"

# Bad input is rejected
if ( cd "$TMP" && ./scripts/bump-version.sh sideways >/dev/null 2>&1 ); then
  fail "invalid bump argument was accepted"
fi

[ "$FAILED" -eq 0 ] && echo "ok: bump-version moves every mapped field"
exit "$FAILED"
