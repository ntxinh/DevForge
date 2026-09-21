#!/usr/bin/env bash
# Bump the version in every file listed in .version-bump.json.
#
# Usage: scripts/bump-version.sh <major|minor|patch|X.Y.Z>
#
# package.json's version is the current value; every other mapped field is
# overwritten to match the new one.
set -euo pipefail

cd "$(dirname "$0")/.."

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

[ $# -eq 1 ] || { echo "usage: $0 <major|minor|patch|X.Y.Z>" >&2; exit 2; }

current=$(jq -r '.version // empty' package.json)
[ -n "$current" ] || { echo "package.json has no version" >&2; exit 1; }

case "$1" in
  major|minor|patch)
    IFS=. read -r major minor patch <<< "$current"
    case "$1" in
      major) new="$((major + 1)).0.0" ;;
      minor) new="${major}.$((minor + 1)).0" ;;
      patch) new="${major}.${minor}.$((patch + 1))" ;;
    esac
    ;;
  [0-9]*.[0-9]*.[0-9]*)
    new="$1"
    ;;
  *)
    echo "invalid version argument: $1" >&2
    exit 2
    ;;
esac

echo "$current -> $new"

[ -f .version-bump.json ] && jq empty .version-bump.json 2>/dev/null \
  || { echo ".version-bump.json: missing or invalid JSON" >&2; exit 1; }

while IFS=$'\t' read -r file field; do
  [ -f "$file" ] || { echo "$file: missing, skipped" >&2; continue; }
  jq_path=".$(printf '%s' "$field" | sed -E 's/\.([0-9]+)/[\1]/g')"
  tmp=$(mktemp)
  jq --arg v "$new" "$jq_path = \$v" "$file" > "$tmp" \
    && chmod --reference="$file" "$tmp" && mv "$tmp" "$file"
  echo "$file: $field -> $new"
done < <(jq -r '.files[] | "\(.path)\t\(.field)"' .version-bump.json)

# Informational only — this script also runs outside a git checkout, in tests.
git --no-pager diff --stat 2>/dev/null || true
