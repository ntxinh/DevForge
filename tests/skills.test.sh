#!/usr/bin/env bash
# Validates every skill in skills/:
#  - SKILL.md exists and opens with YAML frontmatter
#  - frontmatter name matches the directory name; description is non-empty
#  - no host-specific tool name is hardcoded (the skills must run on every
#    supported CLI, not just Claude Code)
#  - every assets/ or references/ path mentioned in backticks exists
set -uo pipefail

cd "$(dirname "$0")/.."

FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }
pass() { echo "ok: $*"; }

# Tool names that exist on one host only. A skill naming these breaks on the
# other five CLIs DevForge supports.
BANNED_TOOLS=(
  'present_files'
  'Atlassian:getJiraIssue'
  'Atlassian:getAccessibleAtlassianResources'
)

shopt -s nullglob
skill_dirs=(skills/*/)
[ "${#skill_dirs[@]}" -gt 0 ] || fail "skills/: no skills found"

for skill_dir in "${skill_dirs[@]}"; do
  name=$(basename "$skill_dir")
  skill_md="${skill_dir}SKILL.md"

  if [ ! -f "$skill_md" ]; then
    fail "$name: SKILL.md is missing"
    continue
  fi

  if [ "$(head -1 "$skill_md")" != "---" ]; then
    fail "$name: SKILL.md does not open with YAML frontmatter"
    continue
  fi

  frontmatter=$(sed -n '2,/^---$/p' "$skill_md" | sed '$d')
  fm_name=$(printf '%s\n' "$frontmatter" | sed -n 's/^name:[[:space:]]*//p' | head -1)
  fm_desc=$(printf '%s\n' "$frontmatter" | sed -n 's/^description:[[:space:]]*//p' | head -1)

  [ "$fm_name" = "$name" ] \
    || fail "$name: frontmatter name is '$fm_name', expected '$name'"
  [ -n "$fm_desc" ] \
    || fail "$name: frontmatter description is empty"

  for banned in "${BANNED_TOOLS[@]}"; do
    if grep -qF -- "$banned" "$skill_md"; then
      fail "$name: SKILL.md hardcodes host-specific tool '$banned'"
    fi
  done

  while IFS= read -r rel; do
    [ -f "${skill_dir}${rel}" ] \
      || fail "$name: SKILL.md references missing file '$rel'"
  done < <(grep -oE '`(assets|references)/[A-Za-z0-9._-]+`' "$skill_md" | tr -d '`' | sort -u)

  pass "$name: skill valid"
done

exit "$FAILED"
