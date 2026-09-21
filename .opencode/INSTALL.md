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
