---
name: jira-issue-to-markdown
description: Translate a Jira issue (Bug, Story, Task, or Spike) into a developer-ready markdown spec for a full-stack SaaS web app. Use this skill whenever the user references a Jira ticket, issue, or issue key (like "ABC-123") and wants it converted, translated, formatted, expanded, or cleaned up into markdown — including when they paste a Jira description, share a Jira URL, or want missing acceptance criteria, edge cases, definition of done, security/performance requirements, or dependencies filled in. Also use when the Jira description includes screenshots/images that contain requirement text, since this skill extracts that text. Trigger this even if the user doesn't say "markdown" explicitly but is clearly asking to turn a Jira ticket into a proper spec, user story, or developer-ready document. The original reporter is usually a non-technical client writing in business language, so part of the value is converting their intent into a structured BA-style spec.
---

# Jira Issue → Markdown Spec

This skill converts a Jira issue — typically written by a non-technical client in plain business language — into a structured markdown spec a developer can act on. It fills in the BA-style sections clients usually omit (acceptance criteria, edge cases, definition of done, security/performance, dependencies) using SaaS-aware defaults, and it extracts any requirement text embedded in attached images.

The key principles:

1. **Never silently invent client intent.** Anything inferred is clearly marked so the BA, PM, Tech Lead, or QA can verify it before the team commits to building.
2. **Ask follow-up questions whenever something is unclear.** If the ticket is ambiguous, contradictory, missing critical context, or you can't confidently choose between reasonable interpretations, stop and ask the user before generating the spec. It's better to surface a short list of clarifying questions up front than to fill the markdown with guesses or `_To be clarified_` placeholders the user has to chase down later.

---

## Workflow

### 1. Get the issue content

If the user pasted the description text, or a screenshot of the Jira UI, use that directly and skip the ladder below.

If they gave only an issue key (e.g. "ABC-123") or a Jira URL, fetch it. Different coding-agent CLIs expose different tools, so work down this ladder and stop at the first rung available to you:

1. **Atlassian MCP.** If an Atlassian MCP server is connected, use its get-issue tool. The exposed name differs per host, so find it in your own tool list rather than assuming a name. If the tool needs a cloudId first, the same server exposes an accessible-resources tool; call that one first. Ask for a markdown response format when the tool supports it, and pull the `attachment` and `comment` fields too.

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

### 2. Identify the issue type → pick the template

Map the Jira `issuetype` field to the right template in `assets/`:

| Jira issue type | Template file |
|---|---|
| Bug, Defect | `assets/bug-template.md` |
| Story, User Story, Improvement, Feature | `assets/story-template.md` |
| Task, Sub-task, Technical Task, Chore | `assets/task-template.md` |
| Spike, Research, Investigation | `assets/spike-template.md` |
| Epic | `assets/epic-template.md` |

If the type is unclear, ask the user — don't guess. The wrong template misses important sections.

Read the template file before filling it in. Don't reproduce it from memory; copy from the file so the structure stays exact.

### 3. Extract content from images (always attempt — do not skip)

Jira clients commonly paste screenshots that contain real requirements (mockups with annotations, error messages, lists of fields). Always attempt to get them into the markdown. Not every coding-agent CLI can read images; when yours cannot, say so in the output rather than skipping the attachment silently.

For each image attached to the issue or pasted by the user:

1. Download the image using whichever rung of the step-1 ladder you used: the MCP attachment URL, `acli jira`, or the stored credentials below. If none can reach it, ask the user to upload it.
2. If the attachment is protected and the MCP provides a `fields.attachment[i].content` URL, download it with Basic Auth using `~/.agents/jira-credentials.json`:

   ```bash
   JIRA_EMAIL=$(jq -r .email ~/.agents/jira-credentials.json)
   JIRA_TOKEN=$(jq -r .api_token ~/.agents/jira-credentials.json)
   mkdir -p "docs/jira/<ISSUE-KEY>"
   curl -s -L -u "$JIRA_EMAIL:$JIRA_TOKEN" \
     "<content_url>" -o "docs/jira/<ISSUE-KEY>/<ISSUE-KEY>-<filename>"
   ```

   Save downloaded images persistently beside the generated Jira docs (not `/tmp`) with the issue key as a filename prefix, so future tools can inspect them visually. If the user specified a different markdown output folder, save images in that same folder instead.
3. If you can read images, read every piece of text in it and describe what's depicted (UI element, flow diagram, error dialog, table, etc.). If you cannot read images in this host, keep the downloaded file and the relative link, and write `[Image N — downloaded, not read: no image support in this host]` where the description would go. Never describe an image you have not seen.
4. Reference downloaded images in the markdown with relative paths when available:

   ```markdown
   ![<filename>](./<ISSUE-KEY>/<ISSUE-KEY>-<filename>)
   ```

5. Place the extracted content under a clearly labeled section in the markdown:

```markdown
## Content extracted from attached images

### `screenshot-2024-01-15.png` — Mockup of the export modal
The image shows a modal titled "Export data" with three radio options:
- CSV (selected by default)
- Excel (.xlsx)
- JSON

There is a date range picker labeled "Date range" with two fields ("From" / "To"), and a checkbox "Include archived items" (unchecked).

The primary button reads "Export" (blue, right-aligned). The secondary button reads "Cancel" (gray, left-aligned).
```

Don't just dump OCR — describe the structure, because layout often *is* the requirement. Note when text in the image conflicts with the issue description and surface that conflict.

If an image can't be downloaded, note `[Image N — could not download: <filename>]` in the markdown and describe any surrounding context clues from the issue description or ADF nodes.

### 4. Ask clarifying questions before filling

Before you start filling the template, scan the ticket (description + images + comments) and identify anything that's unclear, ambiguous, or contradictory from your end. Common things worth asking about:

- **Scope ambiguity** — "should this apply to all user roles, or only admins?"
- **Conflicting signals** — the description says one thing but the screenshot shows another.
- **Missing critical context** — no environment info on a bug, no acceptance criteria on a feature where the behavior could go several reasonable ways, no indication of which sub-app/module is affected.
- **Choice between reasonable interpretations** — if you'd otherwise have to guess and mark as inferred, ask first.
- **Unknown but answerable facts** — browser version, tenant, affected user accounts, exact reproduction steps.

Ask the user as a short numbered list of focused questions. Don't ask about things you can sensibly infer with a SaaS lens (those go through the inference path with `_(inferred)_` markers) — only ask when the answer would meaningfully change the spec.

If the user says "just do your best" or skips some questions, proceed with inference and mark generously. Don't block on every minor unknown.

### 5. Fill the template

Walk the template top to bottom. For each section:

- **If the client stated it** → write it directly. Keep the client's wording where it captures intent well; rephrase where their language is ambiguous, but preserve the business meaning in the Background/Context section.
- **If the client didn't state it** → consult `references/saas-inference-guide.md` for SaaS defaults relevant to that section, draft a sensible starting point, and **mark it as inferred** (see next step).
- **If you can't reasonably infer it** → leave the section with a placeholder like `_To be clarified with reporter._` rather than fabricating content.

### 6. Mark inferred content honestly

Two conventions, used together:

**For sections that are entirely inferred** (the client gave nothing for that section), put a callout at the top of the section:

```markdown
## Acceptance Criteria

> 💡 _Inferred from context — please verify with the reporter before development begins._

- [ ] AC1: ...
- [ ] AC2: ...
```

**For individual items mixed into a section** that has some client-stated content, append `_(inferred)_` to each inferred item:

```markdown
## Edge Cases
- Empty state when the user has no invoices yet
- Free-tier users shouldn't see the export button _(inferred)_
- Concurrent exports by two admins on the same workspace _(inferred)_
```

This visual distinction matters: a Tech Lead/QA reviewing the spec needs to see at a glance which items are real requirements vs. your suggestions. Don't be shy about marking — over-marking is safer than under-marking.

### 7. Save the markdown file

Filename convention: `{YYYY-MM-DD}-{ISSUE-KEY}-{kebab-case-title}.md`

The `YYYY-MM-DD` prefix is today's date (the date the spec is generated), not the Jira issue's created date. Use the user's current local date.

Example: `2026-04-28-ABC-1234-export-invoices-as-pdf.md`

If there's no issue key (raw paste), use `{YYYY-MM-DD}-{kebab-case-title}.md` (e.g., `2026-04-28-export-invoices-as-pdf.md`).

**Default save location:** `<project-root>/docs/jira/` (i.e. the `docs/jira/` directory at the root of the current project/repo). Create the directory if it doesn't exist. Only deviate from this location if the user explicitly specifies a different path.

After saving, report the absolute path of the file to the user.

---

## Filling missing sections — read the inference guide

`references/saas-inference-guide.md` has section-by-section guidance for inferring AC, edge cases, security/performance flags, dependencies, severity, and DoD in a full-stack SaaS context. Read it whenever you're filling those sections from inference rather than client-stated content. It also contains a translation table for common client phrasings ("it's slow," "we need a button for X") that helps you extract real intent.

---

## Worked example

`references/worked-example.md` walks through a complete conversion: a vague client-written bug report with one screenshot, and the filled markdown spec it becomes. Read it when you are unsure how much to infer or how heavily to mark inferred content.

---

## Edge cases for the skill itself

- **Empty description, only images:** the markdown's "Summary" comes from the image content; flag everything else as needing reporter input.
- **Issue is in a non-English language:** preserve original language quotes in the Background section, but write the structured sections (AC, edge cases, DoD) in English (or in whatever language the user requests).
- **Issue type is custom or unrecognized:** ask the user which template fits best; don't auto-pick.
- **Multiple issues at once:** produce one markdown file per issue, and report the absolute path of every file you wrote.
- **Comments contain the real requirements:** common when clients clarify in comments. Pull comment content too and merge into the appropriate section, attributing as needed (e.g., "Per follow-up comment from [reporter]: ...").
- **Atlassian MCP returns the description in ADF (Atlassian Document Format) JSON:** request `responseContentFormat: "markdown"` to avoid hand-parsing ADF. If markdown isn't available for the field, fall back to ADF and convert.
