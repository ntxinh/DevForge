# DevForge Multi-CLI Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package DevForge as a skill pack installable on Claude Code, Codex, Devin CLI, OpenCode, Pi, Oh My Pi, Cursor, and Antigravity from a self-hosted marketplace, with the `jira-issue-to-markdown` skill reworked so it works on every one of them.

**Architecture:** One `skills/` directory is the single source of truth. Each host gets the smallest manifest that points at it — JSON manifests for Claude Code/Antigravity, Codex, and Devin; a declarative `pi` block in `package.json`; and one dependency-free JavaScript plugin for OpenCode, which has no convention-based skill discovery. Oh My Pi needs no manifest of its own: it discovers `skills/` by convention and reads `.claude-plugin/marketplace.json` as its marketplace-catalog fallback. `.version-bump.json` maps every version field so one script keeps them in step, and shell tests assert the manifests and skills stay valid.

**Tech Stack:** JSON manifests, Bash + `jq` (tests and version script), Node.js ESM (OpenCode plugin only), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-21-devforge-multi-cli-plugin-design.md`

## Global Constraints

- Plugin name is exactly `devforge`. Marketplace name is exactly `devforge-marketplace`.
- Author is `ntxinh`, email `nguyentrucxjnh@gmail.com`.
- Repository is `https://github.com/ntxinh/DevForge`.
- License is MIT.
- Initial version is `0.1.0`, identical in every manifest.
- Zero runtime dependencies. The OpenCode plugin imports only `node:path`, `node:fs`, and `node:url`. `jq` is a development-time dependency of the scripts and tests only.
- No session-start hook, no bootstrap injection, no `hooks/` directory. DevForge is a skill pack.
- No skill may name a host-specific tool (`present_files`, `Atlassian:getJiraIssue`, `Atlassian:getAccessibleAtlassianResources`). Tests enforce this.
- Every shell script starts with `#!/usr/bin/env bash` and is committed executable (`chmod +x`).
- Work happens in `/home/exodia/GitRepos/MyGits/DevForge`. All paths below are relative to that directory.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `package.json` | npm identity, Pi skill declaration, OpenCode `main` | 1 |
| `.claude-plugin/plugin.json` | Claude Code + Antigravity manifest | 1 |
| `.claude-plugin/marketplace.json` | self-hosted marketplace listing | 1 |
| `.version-bump.json` | map of every file/field carrying a version | 1 |
| `tests/manifests.test.sh` | manifest validity + version parity | 1 |
| `LICENSE`, `.gitignore` | MIT text, ignore `node_modules` | 1 |
| `.codex-plugin/plugin.json` | Codex manifest, explicit `skills` path | 2 |
| `.devin-plugin/plugin.json` | Devin CLI manifest | 2 |
| `.cursor-plugin/plugin.json` | Cursor manifest, explicit `skills` path | 2 |
| `.opencode/plugins/devforge.js` | OpenCode V1 + V2 skill registration | 3 |
| `index.js` | re-export for OpenCode V2 directory form | 3 |
| `.opencode/INSTALL.md` | OpenCode install instructions | 3 |
| `tests/opencode.test.mjs` | asserts the plugin registers skills | 3 |
| `scripts/bump-version.sh` | bump every mapped version field | 4 |
| `tests/bump-version.test.sh` | asserts the bump touches every field | 4 |
| `.github/workflows/ci.yml` | run all tests on push and PR | 5 |
| `tests/skills.test.sh` | skill frontmatter, banned tool names, links | 6 |
| `skills/jira-issue-to-markdown/SKILL.md` | reworked for portability, trimmed | 6, 7, 8 |
| `skills/jira-issue-to-markdown/references/worked-example.md` | example moved out of SKILL.md | 7 |
| `skills/jira-issue-to-markdown/assets/epic-template.md` | epic template | 8 |
| `README.md` | per-CLI install matrix | 9 |
| `docs/smoke-test.md` | manual per-host verification checklist | 10 |

---

### Task 1: Repository scaffolding, Claude Code manifests, manifest test

**Files:**
- Create: `tests/manifests.test.sh`
- Create: `package.json`
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `.version-bump.json`
- Create: `LICENSE`
- Create: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: `.version-bump.json` with a `files` array of `{path, field}` objects — every later task adds its manifest here, and both `tests/manifests.test.sh` and `scripts/bump-version.sh` read it as their only list of version fields. `package.json` `version` is the reference value every other field must equal.

- [ ] **Step 1: Write the failing test**

Create `tests/manifests.test.sh`:

```bash
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
```

Then make it executable:

```bash
chmod +x tests/manifests.test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/manifests.test.sh`
Expected: FAIL with `FAIL: package.json is missing`, exit code 1.

- [ ] **Step 3: Write minimal implementation**

Create `package.json`:

```json
{
  "name": "devforge",
  "version": "0.1.0",
  "description": "DevForge skills for coding agents: Jira issue to developer-ready markdown spec",
  "type": "module",
  "main": ".opencode/plugins/devforge.js",
  "license": "MIT",
  "author": {
    "name": "ntxinh",
    "email": "nguyentrucxjnh@gmail.com"
  },
  "homepage": "https://github.com/ntxinh/DevForge",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/ntxinh/DevForge.git"
  },
  "keywords": [
    "pi-package",
    "skills",
    "jira",
    "spec",
    "coding-agent"
  ],
  "pi": {
    "skills": [
      "./skills"
    ]
  }
}
```

The `pi.skills` array is the whole of Pi support — Pi discovers skills declaratively, so no extension file is needed.

Create `.claude-plugin/plugin.json` (Claude Code reads this; Antigravity reads the same file):

```json
{
  "name": "devforge",
  "description": "DevForge skills for coding agents: turn a Jira issue into a developer-ready markdown spec",
  "version": "0.1.0",
  "author": {
    "name": "ntxinh",
    "email": "nguyentrucxjnh@gmail.com"
  },
  "homepage": "https://github.com/ntxinh/DevForge",
  "repository": "https://github.com/ntxinh/DevForge",
  "license": "MIT",
  "keywords": [
    "skills",
    "jira",
    "spec",
    "requirements",
    "business-analysis"
  ]
}
```

Create `.claude-plugin/marketplace.json`:

```json
{
  "name": "devforge-marketplace",
  "description": "Self-hosted marketplace for the DevForge skill pack",
  "owner": {
    "name": "ntxinh",
    "email": "nguyentrucxjnh@gmail.com"
  },
  "plugins": [
    {
      "name": "devforge",
      "description": "DevForge skills for coding agents: turn a Jira issue into a developer-ready markdown spec",
      "version": "0.1.0",
      "source": "./",
      "author": {
        "name": "ntxinh",
        "email": "nguyentrucxjnh@gmail.com"
      }
    }
  ]
}
```

Create `.version-bump.json` (Codex and Devin entries arrive in Task 2):

```json
{
  "files": [
    { "path": "package.json", "field": "version" },
    { "path": ".claude-plugin/plugin.json", "field": "version" },
    { "path": ".claude-plugin/marketplace.json", "field": "plugins.0.version" }
  ]
}
```

Create `.gitignore`:

```gitignore
node_modules/
.DS_Store
*.log
```

Create `LICENSE` — the standard MIT text with:

```
MIT License

Copyright (c) 2026 ntxinh
```

followed by the unmodified MIT permission paragraphs.

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/manifests.test.sh`
Expected: PASS — `ok:` lines for the three version fields, the Claude manifest, and the marketplace listing; exit code 0.

- [ ] **Step 5: Commit**

```bash
git add package.json .claude-plugin .version-bump.json tests LICENSE .gitignore
git commit -m "feat: add Claude Code plugin manifest, marketplace, and manifest test"
```

---

### Task 2: Codex, Devin, and Cursor manifests

**Files:**
- Create: `.codex-plugin/plugin.json`
- Create: `.devin-plugin/plugin.json`
- Create: `.cursor-plugin/plugin.json`
- Modify: `.version-bump.json`

**Interfaces:**
- Consumes: `.version-bump.json` `files` array and the version `0.1.0` from Task 1; `tests/manifests.test.sh` already checks `.codex-plugin/plugin.json`, `.devin-plugin/plugin.json`, and `.cursor-plugin/plugin.json` when they exist.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Write the failing test**

No new test file. Extend the existing list instead — add all three manifests to `.version-bump.json`, which is what `tests/manifests.test.sh` iterates:

```json
{
  "files": [
    { "path": "package.json", "field": "version" },
    { "path": ".claude-plugin/plugin.json", "field": "version" },
    { "path": ".claude-plugin/marketplace.json", "field": "plugins.0.version" },
    { "path": ".codex-plugin/plugin.json", "field": "version" },
    { "path": ".devin-plugin/plugin.json", "field": "version" },
    { "path": ".cursor-plugin/plugin.json", "field": "version" }
  ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/manifests.test.sh`
Expected: FAIL with
`FAIL: .codex-plugin/plugin.json: listed in .version-bump.json but missing`
and the same for `.devin-plugin/plugin.json` and `.cursor-plugin/plugin.json`; exit code 1.

- [ ] **Step 3: Write minimal implementation**

Create `.codex-plugin/plugin.json`. The `skills` field is required here — Codex reads the path from the manifest rather than by convention:

```json
{
  "name": "devforge",
  "version": "0.1.0",
  "description": "DevForge skills for coding agents: turn a Jira issue into a developer-ready markdown spec",
  "author": {
    "name": "ntxinh",
    "email": "nguyentrucxjnh@gmail.com",
    "url": "https://github.com/ntxinh"
  },
  "homepage": "https://github.com/ntxinh/DevForge",
  "repository": "https://github.com/ntxinh/DevForge",
  "license": "MIT",
  "keywords": [
    "skills",
    "jira",
    "spec",
    "requirements",
    "business-analysis"
  ],
  "skills": "./skills/",
  "hooks": {},
  "interface": {
    "displayName": "DevForge",
    "shortDescription": "Turn a Jira issue into a developer-ready markdown spec",
    "longDescription": "DevForge converts a Jira issue — Bug, Story, Task, Spike, or Epic — into a structured markdown spec a developer can act on, filling in acceptance criteria, edge cases, security and performance flags, dependencies, and definition of done, and clearly marking everything it inferred.",
    "developerName": "ntxinh",
    "category": "Developer Tools",
    "capabilities": [
      "Interactive",
      "Read",
      "Write"
    ],
    "defaultPrompt": [
      "Turn ABC-123 into a markdown spec.",
      "Here's a Jira ticket description — make it developer-ready."
    ],
    "websiteURL": "https://github.com/ntxinh/DevForge"
  }
}
```

Create `.devin-plugin/plugin.json`. Devin finds `skills/` by convention, so no `skills` field:

```json
{
  "name": "devforge",
  "version": "0.1.0",
  "description": "DevForge skills for coding agents: turn a Jira issue into a developer-ready markdown spec",
  "author": {
    "name": "ntxinh",
    "email": "nguyentrucxjnh@gmail.com"
  },
  "homepage": "https://github.com/ntxinh/DevForge",
  "repository": "https://github.com/ntxinh/DevForge",
  "license": "MIT",
  "keywords": [
    "skills",
    "jira",
    "spec",
    "requirements",
    "business-analysis"
  ]
}
```

Create `.cursor-plugin/plugin.json`. Cursor reads the skills path from the manifest, like Codex. The `hooks` field from the superpowers manifest is dropped — DevForge ships no hooks:

```json
{
  "name": "devforge",
  "displayName": "DevForge",
  "description": "DevForge skills for coding agents: turn a Jira issue into a developer-ready markdown spec",
  "version": "0.1.0",
  "author": {
    "name": "ntxinh",
    "email": "nguyentrucxjnh@gmail.com"
  },
  "homepage": "https://github.com/ntxinh/DevForge",
  "repository": "https://github.com/ntxinh/DevForge",
  "license": "MIT",
  "keywords": [
    "skills",
    "jira",
    "spec",
    "requirements",
    "business-analysis"
  ],
  "skills": "./skills/"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/manifests.test.sh`
Expected: PASS — six version fields reported `ok:`, plus `ok:` identity lines for all four plugin manifests; exit code 0.

- [ ] **Step 5: Commit**

```bash
git add .codex-plugin .devin-plugin .cursor-plugin .version-bump.json
git commit -m "feat: add Codex, Devin, and Cursor plugin manifests"
```

---

### Task 3: OpenCode plugin

**Files:**
- Create: `.opencode/plugins/devforge.js`
- Create: `index.js`
- Create: `.opencode/INSTALL.md`
- Create: `tests/opencode.test.mjs`

**Interfaces:**
- Consumes: `skills/<name>/SKILL.md` layout, and `package.json` `main` from Task 1 (already points at `.opencode/plugins/devforge.js`).
- Produces:
  - `.opencode/plugins/devforge.js` named export `DevForgePlugin(): Promise<{ config(config): Promise<void> }>` — the OpenCode V1 hook object.
  - Its default export `{ id: 'devforge', server: DevForgePlugin, setup(ctx): Promise<void> }` — V2 entry point. `setup` returns without error when `ctx` lacks `ctx.skill.transform`.
  - Each registered skill object has the shape `{ id, name, description?, path, content }`, where `path` is the absolute path of the `SKILL.md` and `content` is its body with frontmatter stripped.
  - `index.js` re-exports that default export unchanged.

- [ ] **Step 1: Write the failing test**

Create `tests/opencode.test.mjs`:

```js
// Asserts the OpenCode plugin registers this repository's skills on both the
// V1 (config hook) and V2 (ctx.skill.transform) code paths, and that it stays
// quiet when handed a context shape it does not understand.
import assert from 'node:assert/strict';
import plugin from '../index.js';
import { DevForgePlugin } from '../.opencode/plugins/devforge.js';

assert.equal(plugin.id, 'devforge', 'default export carries the plugin id');
assert.equal(typeof plugin.setup, 'function', 'default export exposes setup()');

// --- V2: setup() registers skills via ctx.skill.transform -------------------
const added = [];
await plugin.setup({
  skill: { transform: async (fn) => fn({ add: (s) => added.push(s) }) },
});

const jira = added.find((s) => s.id === 'jira-issue-to-markdown');
assert.ok(jira, 'jira-issue-to-markdown is registered');
assert.equal(jira.name, 'jira-issue-to-markdown', 'name comes from frontmatter');
assert.ok(jira.description && jira.description.length > 20, 'description is populated');
assert.ok(jira.path.endsWith('/skills/jira-issue-to-markdown/SKILL.md'), 'path is absolute');
assert.ok(!jira.content.startsWith('---'), 'frontmatter is stripped from content');
assert.ok(jira.content.includes('# Jira Issue'), 'body content survives');

// --- V2: a rejecting host skips one skill without throwing ------------------
await plugin.setup({
  skill: {
    transform: async (fn) => fn({ add: () => { throw new Error('rejected'); } }),
  },
});

// --- V1: named export config hook appends the skills directory --------------
const hooks = await DevForgePlugin({});
const config = {};
await hooks.config(config);
assert.ok(
  config.skills.paths.some((p) => p.endsWith('/skills')),
  'V1 config hook adds the skills directory',
);

// Calling it twice must not duplicate the entry.
await hooks.config(config);
assert.equal(config.skills.paths.length, 1, 'skills path is not duplicated');

// V2-shaped config (flat array) is left alone by the V1 hook.
const v2Config = { skills: [] };
await hooks.config(v2Config);
assert.deepEqual(v2Config.skills, [], 'V2 config shape untouched by the V1 hook');

// --- A V1-shaped ctx passed to setup() must return quietly ------------------
await plugin.setup({});
await plugin.setup(undefined);

console.log('ok: opencode plugin registers skills on V1 and V2');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/opencode.test.mjs`
Expected: FAIL with `ERR_MODULE_NOT_FOUND` — `Cannot find module .../index.js`.

- [ ] **Step 3: Write minimal implementation**

Create `.opencode/plugins/devforge.js`:

```js
/**
 * DevForge plugin for OpenCode.ai — registers this repository's skills.
 *
 * Dual-compatible with OpenCode V1 and V2.
 *
 * V1 (opencode 1.x): loaded via the named export DevForgePlugin, whose
 * config hook pushes the skills directory onto config.skills.paths.
 *
 * V2 (opencode 2.0.4 or later): loaded via the default export { id, setup }.
 * setup() registers each skill natively through ctx.skill.transform().
 *
 * DevForge ships no session bootstrap, so there is no message or context
 * hook here — only skill registration.
 *
 * No external dependencies: works in both V1 and V2 without installing
 * @opencode-ai/plugin.
 */

import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Skills directory shared by V1 (config hook) and V2 (ctx.skill.transform).
const skillsDir = path.resolve(__dirname, '../../skills');

// Simple frontmatter extraction. Handles plain `key: value` lines, quoted
// values (including quotes that close on an indented continuation line),
// YAML block scalar markers (`>`, `|`) with indented continuation lines, and
// CRLF line endings. Not a full YAML parser — nested maps flatten into their
// parent key's value, which is fine for the name/description fields consumed
// here.
const extractAndStripFrontmatter = (content) => {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content };

  const frontmatterStr = match[1];
  const body = match[2];
  const frontmatter = {};
  let lastKey = null;

  for (const rawLine of frontmatterStr.split('\n')) {
    const line = rawLine.replace(/\r$/, '');
    const colonIdx = line.indexOf(':');
    if (colonIdx > 0 && !/^\s/.test(line)) {
      const key = line.slice(0, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim();
      // Block scalar markers (>, |, optionally with +/- chomping) carry no
      // value themselves; the indented lines that follow do.
      frontmatter[key] = /^(>[+-]?|\|[+-]?)$/.test(value) ? '' : value;
      lastKey = key;
    } else if (lastKey !== null && line.trim() !== '') {
      // Continuation of a multi-line value: append rather than drop so long
      // descriptions survive parsing.
      frontmatter[lastKey] = `${frontmatter[lastKey]} ${line.trim()}`.trim();
    }
  }

  // A quoted value may close on a continuation line, so unquote only once the
  // value is fully assembled: strip exactly one matching surrounding pair and
  // leave unbalanced quotes alone.
  for (const key of Object.keys(frontmatter)) {
    frontmatter[key] = frontmatter[key].replace(/^(["'])([\s\S]*)\1$/, '$2');
  }

  return { frontmatter, content: body };
};

// Read every skills/<name>/SKILL.md into the Skill.Info shape V2 expects:
// { id, name, description?, path, content }. The file field is `path` —
// renamed from `location` upstream and released in OpenCode v2.0.4.
const readSkills = () => {
  const skills = [];
  if (!fs.existsSync(skillsDir)) return skills;

  for (const entry of fs.readdirSync(skillsDir, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name.startsWith('.')) continue;
    const skillPath = path.join(skillsDir, entry.name, 'SKILL.md');
    if (!fs.existsSync(skillPath)) continue;

    const { frontmatter, content } = extractAndStripFrontmatter(
      fs.readFileSync(skillPath, 'utf8'),
    );
    skills.push({
      id: entry.name,
      name: frontmatter.name || entry.name,
      ...(frontmatter.description ? { description: frontmatter.description } : {}),
      path: skillPath,
      content,
    });
  }

  return skills;
};

/**
 * V1 plugin function (named export, also re-exported as default.server).
 *
 * Injects the skills path into the live config so OpenCode discovers DevForge
 * skills without manual symlinks or config file edits.
 */
export const DevForgePlugin = async () => ({
  config: async (config) => {
    // V2 represents skills as a flat array — leave it to setup().
    if (Array.isArray(config.skills)) return;

    // V1 represents skills as { paths: [...] }.
    config.skills = config.skills || {};
    config.skills.paths = config.skills.paths || [];
    if (!config.skills.paths.includes(skillsDir)) {
      config.skills.paths.push(skillsDir);
    }
  },
});

/**
 * V2 setup function (default.setup), called by the V2 PluginSupervisor.
 *
 * V1 also invokes default.setup, but with a V1-shaped ctx that lacks the
 * skill domain — detect that and return quietly, since V1 is served entirely
 * by the DevForgePlugin named export.
 */
async function setup(ctx) {
  if (!ctx || !ctx.skill || typeof ctx.skill.transform !== 'function') return;

  try {
    const skills = readSkills();
    await ctx.skill.transform((draft) => {
      // draft.add() decodes against the host's Skill.Info schema and throws
      // synchronously on a mismatch. A throw escaping this callback is what
      // the host escalates into a hard-disable of the whole plugin, so
      // contain failures per skill: one rejected payload skips that skill
      // instead of killing registration entirely.
      for (const skill of skills) {
        try {
          draft.add(skill);
        } catch (err) {
          console.error(`[devforge] skill "${skill.id}" rejected by host, skipping:`, err);
        }
      }
    });
  } catch (err) {
    // Never break plugin activation: one failing plugin takes down the whole
    // V2 generation, including provider plugins.
    console.error('[devforge] skill registration failed:', err);
  }
}

export default {
  id: 'devforge',
  server: DevForgePlugin,
  setup,
};
```

Create `index.js`:

```js
// Root entrypoint for OpenCode V2 directory-form plugin registration.
//
// OpenCode V2 hosts (2.0.4 or later) require config plugin entries to be
// directories with an index entrypoint (`index.js`) and reject bare file
// paths ("configured plugin path must be a directory"). npm and git package
// installs resolve via package.json `main`; this file serves the directory
// form, an absolute path such as `"plugins": ["/path/to/DevForge"]`
// (`~` is not expanded).
export { default } from "./.opencode/plugins/devforge.js";
```

Create `.opencode/INSTALL.md`:

````markdown
# Installing DevForge for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed

## Installation

### OpenCode V1

```json
{
  "plugin": ["devforge@git+https://github.com/ntxinh/DevForge.git"]
}
```

### OpenCode V2 (2.0.4 or later)

```json
{
  "plugins": ["devforge@git+https://github.com/ntxinh/DevForge.git"]
}
```

For a local V2 installation, configure the repository directory containing
`index.js`. OpenCode 2.0.4 and 2.0.7 reject a configured direct JavaScript-file
path.

Restart OpenCode. The plugin registers every skill under `skills/`.

Verify by asking: "What skills do you have?" — `jira-issue-to-markdown`
should be listed.
````

- [ ] **Step 4: Run test to verify it passes**

Run: `node tests/opencode.test.mjs`
Expected: PASS — prints `ok: opencode plugin registers skills on V1 and V2`, exit code 0. The rejecting-host case prints one `[devforge] skill "..." rejected by host, skipping:` line to stderr; that is the expected containment behaviour, not a failure.

- [ ] **Step 5: Commit**

```bash
git add .opencode index.js tests/opencode.test.mjs
git commit -m "feat: add OpenCode plugin registering DevForge skills on V1 and V2"
```

---

### Task 4: Version bump script

**Files:**
- Create: `scripts/bump-version.sh`
- Create: `tests/bump-version.test.sh`

**Interfaces:**
- Consumes: `.version-bump.json` `files` array (Tasks 1 and 2) and `package.json` `version` as the current value.
- Produces: `scripts/bump-version.sh <major|minor|patch|X.Y.Z>` — rewrites every mapped field to the new version and prints one `<file>: <field> -> <version>` line per field.

- [ ] **Step 1: Write the failing test**

Create `tests/bump-version.test.sh`:

```bash
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
```

Then:

```bash
chmod +x tests/bump-version.test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/bump-version.test.sh`
Expected: FAIL with `FAIL: scripts/bump-version.sh is missing`, exit code 1.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/bump-version.sh`:

```bash
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

while IFS=$'\t' read -r file field; do
  [ -f "$file" ] || { echo "$file: missing, skipped" >&2; continue; }
  jq_path=".$(printf '%s' "$field" | sed -E 's/\.([0-9]+)/[\1]/g')"
  tmp=$(mktemp)
  jq --arg v "$new" "$jq_path = \$v" "$file" > "$tmp" && mv "$tmp" "$file"
  echo "$file: $field -> $new"
done < <(jq -r '.files[] | "\(.path)\t\(.field)"' .version-bump.json)

# Informational only — this script also runs outside a git checkout, in tests.
git --no-pager diff --stat 2>/dev/null || true
```

Then:

```bash
chmod +x scripts/bump-version.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/bump-version.test.sh`
Expected: PASS — prints `ok: bump-version moves every mapped field`, exit code 0.

Then confirm the real repository is untouched:

Run: `tests/manifests.test.sh`
Expected: PASS, every field still `0.1.0`.

- [ ] **Step 5: Commit**

```bash
git add scripts/bump-version.sh tests/bump-version.test.sh
git commit -m "feat: add version bump script keeping every manifest in sync"
```

---

### Task 5: CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `tests/manifests.test.sh`, `tests/bump-version.test.sh`, `tests/opencode.test.mjs` from Tasks 1, 3, and 4. `tests/skills.test.sh` arrives in Task 6 and is listed here already, so add it to the workflow now and let Task 6 supply the file.
- Produces: nothing for later tasks.

Note on ordering: this task deliberately references `tests/skills.test.sh`, which Task 6 creates. Run Task 5 before Task 6 only if you are executing the plan in order and accept one red CI run in between; otherwise run Task 6 first. Either order lands the same tree.

- [ ] **Step 1: Write the failing test**

There is no test for a workflow file beyond running it. Assert instead that the workflow references every test script, with a one-off check:

```bash
for t in tests/manifests.test.sh tests/skills.test.sh tests/bump-version.test.sh tests/opencode.test.mjs; do
  grep -qF -- "$t" .github/workflows/ci.yml || echo "MISSING: $t"
done
```

- [ ] **Step 2: Run test to verify it fails**

Run the loop above.
Expected: `grep: .github/workflows/ci.yml: No such file or directory` four times, and four `MISSING:` lines.

- [ ] **Step 3: Write minimal implementation**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Validate manifests
        run: tests/manifests.test.sh

      - name: Validate skills
        run: tests/skills.test.sh

      - name: Validate version bump script
        run: tests/bump-version.test.sh

      - name: Validate OpenCode plugin
        run: node tests/opencode.test.mjs
```

`ubuntu-latest` ships `jq`, so no install step is needed.

- [ ] **Step 4: Run test to verify it passes**

Run the loop from Step 1 again.
Expected: no output — all four test scripts are referenced.

Also confirm the workflow is valid YAML:

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"`
Expected: no output, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run manifest, skill, version, and OpenCode tests on push and PR"
```

---

### Task 6: Skill portability — fetch ladder, image handling, host-neutral wording

**Files:**
- Create: `tests/skills.test.sh`
- Modify: `skills/jira-issue-to-markdown/SKILL.md` (workflow step 1, workflow step 3, "Edge cases for the skill itself")

**Interfaces:**
- Consumes: the existing `SKILL.md` structure and its `assets/` and `references/` files.
- Produces: `tests/skills.test.sh`, which every later skill task reruns. It asserts, for each `skills/*/`: frontmatter `name` equals the directory name, `description` is non-empty, no banned host-specific tool name appears, and every `` `assets/...` `` or `` `references/...` `` path mentioned in backticks in `SKILL.md` exists on disk.

- [ ] **Step 1: Write the failing test**

Create `tests/skills.test.sh`:

```bash
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
```

Then:

```bash
chmod +x tests/skills.test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/skills.test.sh`
Expected: FAIL with three lines —

```
FAIL: jira-issue-to-markdown: SKILL.md hardcodes host-specific tool 'present_files'
FAIL: jira-issue-to-markdown: SKILL.md hardcodes host-specific tool 'Atlassian:getJiraIssue'
FAIL: jira-issue-to-markdown: SKILL.md hardcodes host-specific tool 'Atlassian:getAccessibleAtlassianResources'
```

exit code 1.

- [ ] **Step 3: Write minimal implementation**

**3a.** In `skills/jira-issue-to-markdown/SKILL.md`, replace the whole of section `### 1. Get the issue content` — from that heading down to (but not including) `### 2. Identify the issue type` — with:

````markdown
### 1. Get the issue content

If the user pasted the description text, or a screenshot of the Jira UI, use that directly and skip the ladder below.

If they gave only an issue key (e.g. "ABC-123") or a Jira URL, fetch it. Different coding-agent CLIs expose different tools, so work down this ladder and stop at the first rung available to you:

1. **Atlassian MCP.** If an Atlassian MCP server is connected, use its get-issue tool. The exposed name differs per host — it may appear as `Atlassian:getJiraIssue`, `mcp__atlassian__getJiraIssue`, or similar — so find it in your own tool list rather than assuming a name. If the tool needs a cloudId first, the same server exposes an accessible-resources tool; call that one first. Ask for a markdown response format when the tool supports it, and pull the `attachment` and `comment` fields too.

2. **`acli`.** If `acli` is on `PATH`, run:

   ```bash
   acli jira workitem view <ISSUE-KEY>
   ```

3. **REST with stored credentials.** If `~/.agents/jira-credentials.json` exists and contains a `base_url`, call the Jira REST API directly:

   ```bash
   JIRA_EMAIL=$(jq -r .email ~/.agents/jira-credentials.json)
   JIRA_TOKEN=$(jq -r .api_token ~/.agents/jira-credentials.json)
   JIRA_BASE=$(jq -r .base_url ~/.agents/jira-credentials.json)
   curl -s -u "$JIRA_EMAIL:$JIRA_TOKEN" \
     "$JIRA_BASE/rest/api/3/issue/<ISSUE-KEY>?fields=summary,description,issuetype,attachment,comment,reporter"
   ```

   The credentials file has this shape:

   ```json
   {
     "email": "you@example.com",
     "api_token": "…",
     "base_url": "https://your-site.atlassian.net"
   }
   ```

   Skip this rung if the file is absent or has no `base_url` — without a site URL there is nothing to call.

4. **Ask.** If no rung worked, ask the user to paste the description. Never guess at ticket content.
````

**3b.** In section `### 3. Extract content from images`, replace the heading line and the paragraph under it:

```markdown
### 3. Extract content from images (ALWAYS do this — do not skip)

Jira clients commonly paste screenshots that contain real requirements (mockups with annotations, error messages, lists of fields). Always read them. These must end up in the markdown.

For each image attached to the issue or pasted by the user:
```

with:

```markdown
### 3. Extract content from images (always attempt — do not skip)

Jira clients commonly paste screenshots that contain real requirements (mockups with annotations, error messages, lists of fields). Always attempt to get them into the markdown. Not every coding-agent CLI can read images; when yours cannot, say so in the output rather than skipping the attachment silently.

For each image attached to the issue or pasted by the user:
```

**3c.** In the same section, replace numbered item 1:

```markdown
1. Get the image into your context — either via the Atlassian MCP attachment URL, `acli jira`, or by asking the user to upload it if the MCP can't fetch protected attachments.
```

with:

```markdown
1. Download the image using whichever rung of the step-1 ladder you used: the MCP attachment URL, `acli jira`, or the stored credentials below. If none can reach it, ask the user to upload it.
```

**3d.** In the same section, replace numbered item 3:

```markdown
3. Use vision to read every piece of text and describe what's depicted (UI element, flow diagram, error dialog, table, etc.).
```

with:

```markdown
3. If you can read images, read every piece of text in it and describe what's depicted (UI element, flow diagram, error dialog, table, etc.). If you cannot read images in this host, keep the downloaded file and the relative link, and write `[Image N — downloaded, not read: no image support in this host]` where the description would go. Never describe an image you have not seen.
```

**3e.** In `## Edge cases for the skill itself`, replace:

```markdown
- **Multiple issues at once:** produce one markdown file per issue. Use `present_files` with all of them.
```

with:

```markdown
- **Multiple issues at once:** produce one markdown file per issue, and report the absolute path of every file you wrote.
```

**3f.** Confirm no other host-specific tool name survives:

```bash
grep -nE 'present_files|Atlassian:get' skills/jira-issue-to-markdown/SKILL.md
```

Expected: no output.

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/skills.test.sh`
Expected: PASS — `ok: jira-issue-to-markdown: skill valid`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add tests/skills.test.sh skills/jira-issue-to-markdown/SKILL.md
git commit -m "feat: make jira-issue-to-markdown portable across coding-agent CLIs"
```

---

### Task 7: Trim the worked example out of SKILL.md

**Files:**
- Create: `skills/jira-issue-to-markdown/references/worked-example.md`
- Modify: `skills/jira-issue-to-markdown/SKILL.md` (the `## Worked example` section)

**Interfaces:**
- Consumes: `tests/skills.test.sh` from Task 6, which now also checks that any `` `references/worked-example.md` `` mentioned in `SKILL.md` exists on disk.
- Produces: nothing for later tasks.

- [ ] **Step 1: Write the failing test**

No new test file. Add the pointer to `SKILL.md` first, so the existing link check fails. Replace the entire `## Worked example` section in `SKILL.md` — from that heading down to (but not including) the `## Edge cases for the skill itself` heading, including the `---` separator that precedes it — with:

```markdown
## Worked example

`references/worked-example.md` walks through a complete conversion: a vague client-written bug report with one screenshot, and the filled markdown spec it becomes. Read it when you are unsure how much to infer or how heavily to mark inferred content.

---
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/skills.test.sh`
Expected: FAIL with
`FAIL: jira-issue-to-markdown: SKILL.md references missing file 'references/worked-example.md'`,
exit code 1.

- [ ] **Step 3: Write minimal implementation**

Create `skills/jira-issue-to-markdown/references/worked-example.md` containing the text that was just removed from `SKILL.md`, with a short frame at the top so the file stands on its own:

```markdown
# Worked example — a vague bug report becomes a spec

This is the full conversion the skill's "Worked example" section points at:
what a non-technical client wrote, and what the markdown spec looks like once
the template is filled and inferences are marked.

---
```

Below that frame, paste verbatim the content removed in Step 1 — the `**Input — Jira issue ABC-456:**` block, the `**Output — …**` block with the complete markdown spec, and the closing `Notice in the example:` bullet list. Do not rewrite it; it is tuned content and its value is that it shows real marked-up output.

Verify the move lost nothing:

```bash
grep -c 'ABC-456' skills/jira-issue-to-markdown/references/worked-example.md
```

Expected: a count of at least 3 (title, heading, and the output spec's heading).

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/skills.test.sh`
Expected: PASS — `ok: jira-issue-to-markdown: skill valid`, exit code 0.

Check the trim actually landed:

```bash
wc -l skills/jira-issue-to-markdown/SKILL.md
```

Expected: roughly 150 lines, down from 260.

- [ ] **Step 5: Commit**

```bash
git add skills/jira-issue-to-markdown/SKILL.md skills/jira-issue-to-markdown/references/worked-example.md
git commit -m "refactor: move the jira worked example into references/"
```

---

### Task 8: Epic template

**Files:**
- Create: `skills/jira-issue-to-markdown/assets/epic-template.md`
- Modify: `skills/jira-issue-to-markdown/SKILL.md` (the issue-type mapping table)

**Interfaces:**
- Consumes: `tests/skills.test.sh` from Task 6 (link check), and the section style of the existing `assets/story-template.md`.
- Produces: nothing for later tasks.

- [ ] **Step 1: Write the failing test**

No new test file. Change the Epic row of the issue-type table in `SKILL.md` first, so the link check fails. Replace:

```markdown
| Epic | use `story-template.md` (note in the file that this is an epic-level summary; child tickets needed) |
```

with:

```markdown
| Epic | `assets/epic-template.md` |
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/skills.test.sh`
Expected: FAIL with
`FAIL: jira-issue-to-markdown: SKILL.md references missing file 'assets/epic-template.md'`,
exit code 1.

- [ ] **Step 3: Write minimal implementation**

Create `skills/jira-issue-to-markdown/assets/epic-template.md`, matching the heading style and trailing-two-space line breaks of the existing templates:

```markdown
# [JIRA-KEY] — [Epic title]

**Type:** Epic  
**Reporter:** [name]  
**Source:** [Jira URL]

---

## Epic Goal
One paragraph: what capability this epic delivers, and to whom.

## Business Outcome
Why now? What changes for the business or the user once this epic ships?
(Extracted intent from the client's Jira language.)

## Scope
What this epic covers, at a capability level — not a task list.

## Out of Scope
Explicitly list what this epic does NOT cover. Epics attract scope creep more than any other issue type.

## Child Tickets
One row per story or task this epic needs. Create these as separate Jira issues and run them through the matching template.

| # | Proposed title | Type | Why it's needed | Depends on |
|---|---|---|---|---|
| 1 | | Story | | — |
| 2 | | Task | | 1 |
| 3 | | | | |

## Rollup Acceptance Criteria
Epic-level outcomes, verifiable once all children are done. Not a copy of the children's AC.
- [ ] AC1:
- [ ] AC2:

## Cross-Cutting Requirements
- Auth & permission model affected?
- Data migration required?
- Feature flag / staged rollout needed?
- Analytics or reporting to add?

## Security / Performance Requirements
- [ ] New PII or sensitive data introduced?
- [ ] New external integration or third-party data flow?
- [ ] Expected load / SLA requirement at epic scale?

## Dependencies / Blockers
- Depends on:
- Blocked by:
- Related epics:

## Open Questions
Questions for the reporter that must be answered before the child tickets can be written.
1.
2.

## Definition of Done (Epic)
- [ ] All child tickets closed
- [ ] Rollup acceptance criteria pass end to end
- [ ] Cross-cutting requirements addressed, not deferred
- [ ] QA verified the full capability on staging
- [ ] Docs / changelog updated if user-facing
- [ ] Product owner sign-off on the epic, not just the children
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/skills.test.sh`
Expected: PASS — `ok: jira-issue-to-markdown: skill valid`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add skills/jira-issue-to-markdown/assets/epic-template.md skills/jira-issue-to-markdown/SKILL.md
git commit -m "feat: add an epic template to jira-issue-to-markdown"
```

---

### Task 9: README with the per-CLI install matrix

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: the manifests from Tasks 1–3 and the scripts from Task 4 — every install command below must match what those files actually ship.
- Produces: nothing for later tasks.

- [ ] **Step 1: Write the failing test**

No automated test. The check is that every host in the spec's matrix appears with an install command:

```bash
for host in "Claude Code" "Antigravity" "Codex" "Devin" "OpenCode" "Pi" "Oh My Pi" "Cursor"; do
  grep -qF -- "$host" README.md || echo "MISSING: $host"
done
```

- [ ] **Step 2: Run test to verify it fails**

Run the loop above.
Expected: `grep: README.md: No such file or directory` eight times and eight `MISSING:` lines.

- [ ] **Step 3: Write minimal implementation**

Create `README.md`:

````markdown
# DevForge

Skills for coding-agent CLIs. Install once per CLI; the skills work the same on each.

## Skills

| Skill | What it does |
|---|---|
| `jira-issue-to-markdown` | Turns a Jira issue (Bug, Story, Task, Spike, Epic) into a developer-ready markdown spec, filling in acceptance criteria, edge cases, security and performance flags, dependencies, and definition of done — and marking clearly what it inferred. |

## Install

### Claude Code

```text
/plugin marketplace add ntxinh/DevForge
/plugin install devforge@devforge-marketplace
```

### Antigravity

```bash
agy plugin install https://github.com/ntxinh/DevForge
```

Reinstall with the same command to update.

### Codex

Clone the repository and add it as a local plugin; `.codex-plugin/plugin.json`
points Codex at `./skills/`. DevForge is not listed in the Codex plugin
marketplace.

### Devin CLI

```bash
devin plugins install ntxinh/DevForge
devin plugins update devforge
```

### OpenCode

OpenCode V2 (2.0.4 or later), in your config:

```json
{
  "plugins": ["devforge@git+https://github.com/ntxinh/DevForge.git"]
}
```

V1 uses the `"plugin"` key instead. Details: [.opencode/INSTALL.md](.opencode/INSTALL.md).

### Pi

```bash
pi install git:github.com/ntxinh/DevForge
```

**Untested.** Pi support is the declarative `pi.skills` entry in
`package.json`; nobody has run it yet. Reports welcome.

### Oh My Pi

```bash
omp plugin marketplace add ntxinh/DevForge
omp plugin install devforge@devforge-marketplace
```

omp reads `.claude-plugin/marketplace.json` as its catalog and discovers
`skills/` by convention. For a local checkout: `omp plugin link <path>`.

### Cursor

Clone the repository and add it as a local plugin; `.cursor-plugin/plugin.json`
points Cursor at `./skills/`. DevForge is not listed in the Cursor plugin
marketplace.

**Untested.** No `cursor` binary on the development machine; reports welcome.

## Using the Jira skill

Ask your agent to convert a ticket:

> Turn ABC-123 into a markdown spec.

The skill fetches the issue by whatever means your CLI has — an Atlassian MCP
server, the `acli` CLI, the Jira REST API with stored credentials, or by asking
you to paste it. For the REST path, create `~/.agents/jira-credentials.json`:

```json
{
  "email": "you@example.com",
  "api_token": "…",
  "base_url": "https://your-site.atlassian.net"
}
```

Generate the API token at <https://id.atlassian.com/manage-profile/security/api-tokens>.

Output lands in `docs/jira/` in the current project by default.

## Development

```bash
tests/manifests.test.sh      # manifests parse, required fields, version parity
tests/skills.test.sh         # skill frontmatter, no host-specific tools, links resolve
tests/bump-version.test.sh   # version script moves every mapped field
node tests/opencode.test.mjs # OpenCode plugin registers skills on V1 and V2
```

`jq` is required for the shell tests. Release with:

```bash
scripts/bump-version.sh patch
```

which rewrites every version field listed in `.version-bump.json`.

## License

MIT © ntxinh
````

- [ ] **Step 4: Run test to verify it passes**

Run the loop from Step 1 again.
Expected: no output.

Then run the full suite:

```bash
tests/manifests.test.sh && tests/skills.test.sh && tests/bump-version.test.sh && node tests/opencode.test.mjs
```

Expected: all pass, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: add README with the per-CLI install matrix"
```

---

### Task 10: Smoke test on every installed host

**Files:**
- Create: `docs/smoke-test.md`
- Modify: `.devin-plugin/plugin.json` or `.agents/plugins/marketplace.json` — only if the Devin run below shows the marketplace file is required
- Modify: `README.md` — only if a host's install command turns out to differ from what Task 9 documented

**Interfaces:**
- Consumes: every manifest and the README from Tasks 1–3 and 9.
- Produces: `docs/smoke-test.md`, the recorded result per host, which is the evidence that the plugin actually installs.

This task is manual. `claude`, `codex`, `devin`, `opencode`, `agy`, and `omp` are installed on this machine; `pi` and `cursor` are not.

- [ ] **Step 1: Write the checklist**

Create `docs/smoke-test.md`:

```markdown
# Install smoke test

Run after any change to a manifest, the OpenCode plugin, or the install
instructions. Record the date, the host version, and the result.

The check per host is the same: install DevForge, start a fresh session, and
confirm `jira-issue-to-markdown` is listed among the available skills and can
be invoked.

| Host | Command | Date | Version | Result |
|---|---|---|---|---|
| Claude Code | `/plugin marketplace add <local path or ntxinh/DevForge>` then `/plugin install devforge@devforge-marketplace` | | | |
| Antigravity | `agy plugin install <local path or repo URL>` | | | |
| Codex | local plugin install from this checkout | | | |
| Devin CLI | `devin plugins install ntxinh/DevForge` | | | |
| OpenCode | config `"plugins": ["<absolute path to this checkout>"]` | | | |
| Oh My Pi | `omp plugin marketplace add <local path or ntxinh/DevForge>` then `omp plugin install devforge@devforge-marketplace`; for a checkout, `omp plugin link <path>` | | | |
| Pi | `pi install git:github.com/ntxinh/DevForge` | | | not installed locally |
| Cursor | local plugin install from this checkout | | | not installed locally |

## Notes

- Record the exact error text for any failure, and what fixed it.
- If `devin plugins install` reports a missing marketplace file, add
  `.agents/plugins/marketplace.json` and note that here.
```

- [ ] **Step 2: Run the smoke test**

For each installed host, install from this checkout (not from GitHub, unless the repository has been pushed), open a fresh session, and ask:

> What skills do you have?

Expected: `jira-issue-to-markdown` appears in the answer.

Then invoke it with a pasted description, which exercises rung 4 of the fetch ladder without needing Jira access:

> Here's a Jira ticket: "Type: Bug. Customers can't see their invoices on mobile — blank screen on phones, works on desktop." Turn it into a markdown spec.

Expected: a file written under `docs/jira/`, with inferred sections marked, and its absolute path reported.

- [ ] **Step 3: Record results and fix what broke**

Fill in the table. For any host that failed, fix the manifest and rerun that host. Two known candidates:

- Devin may require `.agents/plugins/marketplace.json` in addition to `.devin-plugin/plugin.json`. If so, create it:

  ```json
  {
    "name": "devforge-marketplace",
    "interface": {
      "displayName": "DevForge"
    },
    "plugins": [
      {
        "name": "devforge",
        "source": {
          "source": "url",
          "url": "./"
        },
        "policy": {
          "installation": "AVAILABLE",
          "authentication": "ON_INSTALL"
        },
        "category": "Developer Tools"
      }
    ]
  }
  ```

- A host may reject a manifest field. Record the exact error before changing anything.

- [ ] **Step 4: Re-run the automated suite**

```bash
tests/manifests.test.sh && tests/skills.test.sh && tests/bump-version.test.sh && node tests/opencode.test.mjs
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add docs/smoke-test.md
git commit -m "docs: record install smoke test results per host"
```

---

## Self-Review

**Spec coverage**

| Spec requirement | Task |
|---|---|
| Claude Code manifest + self-hosted marketplace | 1 |
| Pi declarative skills entry | 1 |
| Codex manifest with explicit `skills` path | 2 |
| Devin manifest | 2 |
| Cursor manifest with explicit `skills` path | 2 |
| Oh My Pi via the Claude-shaped marketplace fallback | 1 (file), 9 (docs), 10 (verified) |
| Antigravity via the Claude-shaped manifest | 1 (file), 10 (verified) |
| OpenCode plugin, V1 + V2, bootstrap stripped | 3 |
| `.version-bump.json` mapping six fields | 1, 2 |
| `scripts/bump-version.sh` | 4 |
| Manifest test | 1 |
| CI running the tests | 5 |
| Fetch ladder replacing hardcoded MCP tool names | 6 |
| Image handling that degrades without vision | 6 |
| `present_files` replaced | 6 |
| Credentials file gains `base_url` | 6 (skill), 9 (README) |
| Worked example moved to `references/` | 7 |
| Epic template | 8 |
| Per-CLI install matrix | 9 |
| Manual smoke test across six hosts, Pi and Cursor flagged untested | 10 |
| Risk: Devin marketplace file undecided | 10 |

No spec requirement is unclaimed.

**Type consistency**

`DevForgePlugin` and the default export `{ id, server, setup }` are named identically in Task 3's implementation and in `tests/opencode.test.mjs`. The registered skill object is `{ id, name, description?, path, content }` in both. `.version-bump.json`'s `files[].path` / `files[].field` shape is read by `tests/manifests.test.sh` (Task 1), `tests/bump-version.test.sh` and `scripts/bump-version.sh` (Task 4) with the same dotted-field-to-jq-path transform in each.
