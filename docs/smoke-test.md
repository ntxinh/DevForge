# Install smoke test

Run after any change to a manifest, the OpenCode plugin, or the install
instructions. Record the date, the host version, and the result.

The check per host is the same: install DevForge, start a fresh session, and
confirm `jira-issue-to-markdown` is listed among the available skills and can
be invoked.

| Host | Command | Date | Version | Result |
|---|---|---|---|---|
| Claude Code | `/plugin marketplace add <local path or ntxinh/DevForge>` then `/plugin install devforge@devforge-marketplace` | 2026-09-21 | 2.1.278 | pass (install) — `claude plugin marketplace add ./` + `claude plugin install devforge@devforge-marketplace -y`; plugin enabled, `claude plugin details` lists `jira-issue-to-markdown`. In-session invoke not run (needs interactive session). |
| Antigravity | `agy plugin install <local path or repo URL>` | 2026-09-21 | 1.2.5 | pass (install) — `agy plugin install .` processed 1 skill; `agy plugin list` shows `devforge` (skills). In-session invoke not run. |
| Codex | local plugin install from this checkout | 2026-09-21 | codex-cli 0.147.0 | pass (install) — `codex plugin marketplace add .` + `codex plugin add devforge@devforge-marketplace`; status installed/enabled, skills cached under `~/.codex/plugins/cache/`. In-session invoke not run. |
| Devin CLI | `devin plugins install ntxinh/DevForge` | 2026-09-21 | 3000.10.31 | pass (local install) — `devin plugins install . --local -y`; `devin plugins info devforge` lists `/devforge:jira-issue-to-markdown`. `.agents/plugins/marketplace.json` was NOT required. GitHub `owner/repo` form untested — repo not pushed. |
| OpenCode | config `"plugins": ["<absolute path to this checkout>"]` | 2026-09-21 | 1.18.31 | pass (V1) — `"plugin": ["<abs path>"]` in `opencode.json`; `opencode debug skill` lists `jira-issue-to-markdown` from this checkout. V2 `"plugins"` key untested — installed binary is V1 and ignores it. |
| Pi | `pi install git:github.com/ntxinh/DevForge` | | | not installed locally |

## Notes

- Record the exact error text for any failure, and what fixed it.
- If `devin plugins install` reports a missing marketplace file, add
  `.agents/plugins/marketplace.json` and note that here.

### 2026-09-21 run

- The remote (`origin`) has no branches — the repo is not pushed — so every
  install used this local checkout. All `owner/repo` and GitHub-URL install
  forms in the README are untested.
- `claude plugin marketplace add .` fails with
  `Invalid marketplace source format. Try: owner/repo, https://..., or ./path`;
  `./` (or an absolute path) works.
- `agy plugin validate .` fails with
  `Error: missing plugin.json: stat plugin.json: no such file or directory` —
  validate expects the directory containing `plugin.json`, so point it at
  `.claude-plugin` (validates clean). `agy plugin install .` works regardless.
- OpenCode on a HOME that already has a same-named skill logs
  `duplicate skill name ... existing=~/.claude/skills/synced/...` and keeps the
  existing copy; with a clean HOME the plugin-registered skill lists normally.
- The in-session checks (ask "what skills do you have", invoke the skill on a
  pasted ticket) were not run — they need an interactive session on each host.
