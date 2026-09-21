# Install smoke test

Run after any change to a manifest, the OpenCode plugin, or the install
instructions. Record the date, the host version, and the result.

The check per host is the same: install DevForge, start a fresh session, and
confirm `jira-issue-to-markdown` is listed among the available skills and can
be invoked.

| Host | Command | Date | Version | Result |
|---|---|---|---|---|
| Claude Code | `/plugin marketplace add <local path or ntxinh/DevForge>` then `/plugin install devforge@devforge-marketplace` | 2026-09-21 | 2.1.278 | pass (install + invoke) — `claude plugin marketplace add ./` + `claude plugin install devforge@devforge-marketplace -y`; plugin enabled, `claude plugin details` lists `jira-issue-to-markdown`. Headless invoke: `claude -p '<pasted-ticket prompt>' --dangerously-skip-permissions` in a scratch dir wrote `docs/jira/2026-09-21-invoices-blank-screen-on-mobile.md` with `_(inferred)_` markers. |
| Antigravity | `agy plugin install <local path or repo URL>` | 2026-09-21 | 1.2.5 | pass (install) — `agy plugin install .` processed 1 skill; `agy plugin list` shows `devforge` (skills). Headless invoke: `agy --dangerously-skip-permissions --print='<pasted-ticket prompt>'` failed — first run timed out at 180s (`error: interrupted`), retry returned `RESOURCE_EXHAUSTED (429): Individual quota reached ... Resets in ~68h`; no file written — not confirmed, needs quota to retry. |
| Codex | local plugin install from this checkout | 2026-09-21 | codex-cli 0.147.0 | pass (install + invoke) — `codex plugin marketplace add .` + `codex plugin add devforge@devforge-marketplace`; status installed/enabled, skills cached under `~/.codex/plugins/cache/`. Headless invoke: `codex exec --dangerously-bypass-approvals-and-sandbox '<pasted-ticket prompt>'` loaded the skill ("Using the Jira-spec workflow") and asked a clarifying question (web app vs native app) instead of writing a file — correct per the skill's ask-first rule; invocation confirmed, no file produced. |
| Devin CLI | `devin plugins install ntxinh/DevForge` | 2026-09-21 | 3000.10.31 | pass (install + invoke) — `devin plugins install . --local -y`; `devin plugins info devforge` lists `/devforge:jira-issue-to-markdown`. `.agents/plugins/marketplace.json` was NOT required. Headless invoke: `devin -p '<pasted-ticket prompt>' --permission-mode dangerous --respect-workspace-trust false` in a scratch dir wrote `docs/jira/2026-09-21-customers-cant-see-invoices-on-mobile.md` with `_(inferred)_` markers. GitHub `owner/repo` form untested — repo not pushed. |
| OpenCode | config `"plugins": ["<absolute path to this checkout>"]` | 2026-09-21 | 1.18.31 | pass (install) — `"plugin": ["<abs path>"]` in `opencode.json`; `opencode debug skill` lists `jira-issue-to-markdown` from this checkout. Headless invoke: `opencode run '<pasted-ticket prompt>'` failed — `Error: Insufficient balance` on the configured provider (glm-5.3); not an install problem, needs a funded provider to retry. V2 `"plugins"` key untested — installed binary is V1 and ignores it. |
| Pi | `pi install git:github.com/ntxinh/DevForge` | | | not installed locally |
| Oh My Pi | `omp plugin marketplace add <local path or ntxinh/DevForge>` then `omp plugin install devforge@devforge-marketplace`; for a checkout, `omp plugin link <path>` | 2026-09-21 | 18.2.6 | pass (install + discover) — `omp plugin marketplace add ./` + `omp plugin install devforge@devforge-marketplace`; `omp plugin list` shows `devforge@devforge-marketplace (0.1.0)`, skill cached under `~/.omp/plugins/cache/plugins/devforge-marketplace___devforge___0.1.0/skills/`. Fresh headless session (`omp -p "list your skills"`) lists `jira-issue-to-markdown`. Invoke not attempted. |
| Cursor | local plugin install from this checkout | | | not installed locally |

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
- Headless invocation was attempted on every installed host with the brief's
  pasted-ticket prompt (run in a scratch dir so generated specs land outside
  this repo). Claude Code and Devin each wrote a spec under `docs/jira/` with
  inferred sections marked — the skill is invocable end-to-end on both. Codex
  invoked the skill and correctly asked a clarifying question instead of
  writing a file. OpenCode could not reach a model (provider balance) and
  Antigravity hit its account quota (429) — both recorded in the table above.
