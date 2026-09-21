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
