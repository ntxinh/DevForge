# DevForge — Multi-CLI Skill Plugin

**Date:** 2026-09-21
**Status:** Approved design, ready for implementation planning

## Problem

DevForge holds one skill, `jira-issue-to-markdown`, and nothing that lets a coding
agent install it. The skill itself is written for Claude Code: it names Atlassian MCP
tools directly and calls `present_files`, neither of which exists in Codex, Devin,
OpenCode, Pi, or Antigravity.

The goal is a plugin that installs on all six CLIs from a self-hosted marketplace,
carrying skills that work the same on each.

## Scope

**In scope**

- Plugin manifests for Claude Code, Codex, Devin CLI, OpenCode, Pi, Antigravity.
- A self-hosted marketplace in this repository.
- Rework of `jira-issue-to-markdown` for host portability, plus a trim and an epic template.
- Version synchronization across manifests, a manifest test, and CI that runs it.

**Out of scope**

- Session-start bootstrap and skill auto-triggering. DevForge is a skill pack: each host
  discovers the skills, and the user invokes them.
- Submission to third-party catalogs such as `openai/plugins`.
- Cursor, Kimi, Muse, Hermes, Gemini, Factory Droid.
- New skills beyond the existing one.

## Identity

| Field | Value |
|---|---|
| Plugin name | `devforge` |
| Marketplace name | `devforge-marketplace` |
| Author | ntxinh \<nguyentrucxjnh@gmail.com\> |
| Repository | https://github.com/ntxinh/DevForge |
| License | MIT |
| Initial version | 0.1.0 |

## Architecture

The repository is the plugin and the marketplace at once. One `skills/` directory is the
single source of truth; each host gets the smallest manifest that points at it. The
manifest shapes come from the `superpowers` project (v6.4.1), which ships them against
these same CLIs, with everything bootstrap-related removed.

### Repository layout

```
DevForge/
├── skills/
│   └── jira-issue-to-markdown/
│       ├── SKILL.md
│       ├── assets/{bug,story,task,spike,epic}-template.md
│       └── references/{saas-inference-guide,worked-example}.md
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── .codex-plugin/plugin.json
├── .devin-plugin/plugin.json
├── .opencode/
│   ├── plugins/devforge.js
│   └── INSTALL.md
├── index.js
├── package.json
├── .version-bump.json
├── scripts/bump-version.sh
├── tests/manifests.test.sh
├── .github/workflows/ci.yml
├── README.md
├── LICENSE
└── .gitignore
```

Files deliberately absent, and why:

- `hooks/` and `hooks/session-start` — no bootstrap, so no hook.
- `.pi/extensions/*.ts` — in `superpowers` that extension exists only to inject the
  bootstrap. Pi discovers skills from `package.json`.
- `.cursor-plugin/`, `.kimi-plugin/`, `.muse-plugin/`, `.hermes-plugin/`,
  `gemini-extension.json` — hosts outside the six.
- `.antigravity-plugin/` — Antigravity reads the Claude-shaped manifest.
- `.agents/plugins/marketplace.json` — added only if the Devin smoke test shows
  `devin plugins install` requires it.

### Host matrix

| Host | Manifest shipped | Skill discovery | Install command |
|---|---|---|---|
| Claude Code | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | `skills/` at plugin root, by convention | `/plugin marketplace add ntxinh/DevForge` then `/plugin install devforge@devforge-marketplace` |
| Antigravity | reuses `.claude-plugin/plugin.json` | same convention | `agy plugin install https://github.com/ntxinh/DevForge` |
| Codex | `.codex-plugin/plugin.json` with `"skills": "./skills/"` | explicit path in the manifest | local plugin install from a checkout |
| Devin CLI | `.devin-plugin/plugin.json` | `skills/` by convention | `devin plugins install ntxinh/DevForge` |
| OpenCode | `.opencode/plugins/devforge.js`, `index.js`, `package.json` `main` | the JS plugin registers `skills/` | config `"plugins": ["devforge@git+https://github.com/ntxinh/DevForge.git"]` |
| Pi | `package.json` `"pi": {"skills": ["./skills"]}` | declarative | `pi install git:github.com/ntxinh/DevForge` |

### OpenCode plugin

OpenCode has no convention-based skill discovery, so it needs the one piece of executable
code in the repository. `.opencode/plugins/devforge.js` is ported from
`superpowers/.opencode/plugins/superpowers.js` and keeps only:

- the dependency-free frontmatter parser,
- V1 registration through the named-export `config` hook,
- V2 registration through the default export's `setup()` and `ctx.skill.transform()`.

The bootstrap injection, the `Skill` compatibility tool, and the
`experimental.chat.messages.transform` path are dropped. Expected size is roughly 120
lines against the original 383. `index.js` re-exports the default export so OpenCode V2
accepts the repository directory as a plugin path; `package.json` `main` points at the
same file for npm and git installs.

## Skill rework: `jira-issue-to-markdown`

### Fetch ladder

Step 1 of the workflow currently instructs the agent to call
`Atlassian:getAccessibleAtlassianResources` and `Atlassian:getJiraIssue` by name. It is
replaced by an ordered ladder; the agent takes the first rung available and stops.

1. **Atlassian MCP.** If an Atlassian MCP server is connected, use its get-issue tool.
   Tool names differ per host (`Atlassian:getJiraIssue`, `mcp__atlassian__getJiraIssue`),
   so the skill instructs the agent to locate the tool in its own tool list rather than
   assume a name. Request a markdown response format when the tool supports it.
2. **`acli`.** If `acli` is on `PATH`, run `acli jira workitem view <KEY>`.
3. **REST.** If `~/.agents/jira-credentials.json` exists and carries a `base_url`, call
   the Jira REST v3 issue endpoint with curl and Basic Auth.
4. **Paste.** Otherwise ask the user to paste the description. Never guess ticket content.

The credentials file gains a third field so rung 3 knows which site to call:

```json
{
  "email": "you@example.com",
  "api_token": "…",
  "base_url": "https://your-site.atlassian.net"
}
```

Rung 3 skips itself when the file is absent or `base_url` is missing, and the skill
documents the schema where it first reads the file.

### Image handling

The current text reads "ALWAYS do this — do not skip", which is impossible on a host
without vision. The rule becomes: always *attempt*.

1. Download each attachment using the same auth ladder as the fetch step.
2. If the host can read images, read each one and describe its structure, as today.
3. If the host cannot, save the file, link it by relative path, and write
   `[Image N — downloaded, not read: no vision in this host]`.
4. If the download fails, keep the existing `[Image N — could not download: <filename>]`
   note.

Fabricating image content is forbidden in every case.

### Other host-specific references

`present_files` is replaced by "report the absolute path of every file written". No other
host-specific tool name remains in the skill.

### Trim

The worked example, roughly 100 of the file's 260 lines, moves to
`references/worked-example.md`, with a single pointer line left in `SKILL.md`. Target is
about 150 lines in `SKILL.md`, which is what loads on every trigger.

### Epic template

`assets/epic-template.md` is added: epic-level summary, a child-ticket breakdown table,
and rollup acceptance criteria. The issue-type map row for Epic changes from "use
`story-template.md` and note that it is an epic" to the new file.

## Versioning, testing, CI

### Version synchronization

`.version-bump.json` maps every version field in the repository:

| File | Field |
|---|---|
| `package.json` | `version` |
| `.claude-plugin/plugin.json` | `version` |
| `.claude-plugin/marketplace.json` | `plugins.0.version` |
| `.codex-plugin/plugin.json` | `version` |
| `.devin-plugin/plugin.json` | `version` |

`scripts/bump-version.sh <major|minor|patch|X.Y.Z>` reads that map, rewrites each field
with `jq`, and prints the resulting diff. It is roughly 40 lines and fails with a clear
message when `jq` is missing. It is not a port of the 282-line `superpowers` script,
whose audit and grep machinery DevForge does not need. `jq` is a development-time
dependency of this script only; nothing at install or run time requires it.

### Manifest test

`tests/manifests.test.sh`, bash plus `jq`, asserts:

- every manifest is valid JSON;
- required fields are present and non-empty;
- `name` is `devforge` in each plugin manifest;
- every mapped version field equals `package.json`'s `version`;
- every `skills/*/SKILL.md` has frontmatter whose `name` matches its directory name, with
  `name` and `description` non-empty.

It exits non-zero on the first failure and names the file and field.

### CI

`.github/workflows/ci.yml` runs `tests/manifests.test.sh` on push and pull request under
`ubuntu-latest`, which has `jq` preinstalled and needs no setup step.

### Manual smoke test

`claude`, `codex`, `devin`, `opencode`, and `agy` are installed on the development
machine. Each is installed from a local checkout or the pushed repository, and the check
is that `jira-issue-to-markdown` appears in that host's skill list and can be invoked.

`pi` is not installed. Pi ships on its declarative manifest and is marked untested in the
README until someone verifies it.

## Risks

- **Manifest drift.** The shapes are taken from `superpowers` v6.4.1; a CLI may have
  changed its plugin format since. The smoke test across five hosts is what catches this,
  and it runs before the first release.
- **Devin marketplace file.** Whether `devin plugins install` needs
  `.agents/plugins/marketplace.json` alongside `.devin-plugin/plugin.json` is unresolved.
  The Devin smoke test decides it; adding the file is a small change if required.
- **Pi unverified.** No local `pi` binary. Shipped and flagged, not silently claimed to work.
- **Codex distribution.** Only local installation is supported. Listing in
  `openai/plugins` is their review process and is out of scope.

## Success criteria

1. `jira-issue-to-markdown` is discoverable and invocable in Claude Code, Codex, Devin,
   OpenCode, and Antigravity, installed through each host's own plugin command.
2. The Claude Code marketplace flow works from a clean profile:
   `/plugin marketplace add ntxinh/DevForge`, then
   `/plugin install devforge@devforge-marketplace`.
3. The skill converts a Jira issue on a host with no Atlassian MCP, falling back down the
   ladder without inventing content.
4. `tests/manifests.test.sh` passes locally and in CI.
5. `scripts/bump-version.sh patch` moves all five version fields together.
