# Worked example — a vague bug report becomes a spec

This is the full conversion the skill's "Worked example" section points at:
what a non-technical client wrote, and what the markdown spec looks like once
the template is filled and inferences are marked.

---

**Input — Jira issue ABC-456:**

> **Title:** Customers can't see their invoices on mobile
>
> **Type:** Bug
>
> **Description:** Hey — multiple customers have emailed support saying when they open the billing page on their phone they just see a blank screen. It works fine on my laptop. This is happening to paying customers so it's pretty urgent. Attached a screenshot from one of them.
>
> **Attachment:** `customer-screenshot.png` — shows an iPhone Safari screen with the company header and footer visible but a large blank white area in the middle where the invoice list should be.

**Output — `2026-04-28-ABC-456-customers-cant-see-invoices-on-mobile.md`:**

```markdown
# ABC-456 — Customers can't see their invoices on mobile

**Type:** Bug
**Reporter:** [client name]
**Source:** [Jira URL]

---

## Summary
The billing page renders blank in the invoice list area on mobile browsers, while desktop renders correctly.

## User Story Context
Paying customers viewing the billing page on mobile devices.

## Steps to Reproduce
> 💡 _Inferred from the screenshot and description — please verify exact steps with the reporter._
1. Log in as a paying customer on a mobile browser (iOS Safari confirmed; other mobile browsers unknown).
2. Navigate to the billing page.
3. Observe the page area where the invoice list should render.

## Expected Result
The invoice list renders on mobile the same way (or a responsive equivalent of) the desktop view.

## Actual Result
The header and footer render correctly, but the invoice list area is blank. (Confirmed via attached customer screenshot — see "Content extracted from attached images" below.)

## Environment
- Browser & version: iOS Safari (version unknown — _to be confirmed with reporter_)
- OS & device: iPhone (model unknown)
- User account / tenant: Multiple paying customers — exact accounts to confirm
- Frequency: [x] Always (per multiple customer reports)  [ ] Intermittent  [ ] One-time

## Severity
[ ] Critical  [x] High (feature broken for paying customers on a primary device class)  [ ] Medium  [ ] Low

## Acceptance Criteria
- [ ] Invoice list renders correctly on iOS Safari (latest 2 versions)
- [ ] Invoice list renders correctly on Android Chrome (latest 2 versions) _(inferred)_
- [ ] No regression on desktop browsers _(inferred)_
- [ ] Layout is usable at 375px viewport width (iPhone SE) _(inferred)_

## Edge Cases to Verify
> 💡 _Inferred — please verify scope with the reporter._
- Customers with zero invoices (empty state on mobile)
- Customers with many invoices (pagination/scroll on mobile)
- Free-tier users (does the page even apply?)
- Slow mobile connection (loading state visible?)

## Security / Performance Flags
- [ ] Does this expose any user data? — No additional exposure expected
- [x] Does this affect performance under load? — Mobile rendering may be tied to payload size; check
- [ ] Does this bypass any permission checks? — No

## Dependencies / Blockers
- Blocked by: None known _(inferred)_
- Related tickets: Search Jira for prior mobile/billing tickets

## Definition of Done
- [ ] Fix implemented and peer-reviewed
- [ ] Unit tests cover the fix
- [ ] QA verified on iOS Safari and Android Chrome on staging
- [ ] No new errors in logs post-deploy
- [ ] Product owner sign-off

## Content extracted from attached images

### `customer-screenshot.png` — iPhone Safari billing page
The image shows an iPhone Safari window. The company logo and primary navigation are visible at the top. The footer (with copyright and links) is visible at the bottom. The center area, which on desktop contains the invoice list table, is entirely blank/white. No error message is visible. The URL bar shows the billing page route.
```

Notice in the example:
- Client-stated content (severity = High because they said "paying customers... pretty urgent") is unmarked.
- Things inferred from a SaaS bug-fix lens (Android Chrome support, empty/many-invoices edge cases, no permission impact) are clearly tagged.
- The image content is described, not just OCR'd.
- Things genuinely unknown (browser version, account IDs) are flagged as needing reporter confirmation rather than fabricated.
