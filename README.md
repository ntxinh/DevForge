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

Clone the repository, then add it as a local marketplace and install:

```bash
codex plugin marketplace add /path/to/DevForge
codex plugin add devforge@devforge-marketplace
```

DevForge is not listed in the Codex plugin marketplace.

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
