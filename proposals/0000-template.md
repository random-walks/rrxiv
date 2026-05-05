# RRP-NNNN — Title

- **Status:** Draft
- **Champion:** Your Name (ORCID:XXXX-XXXX-XXXX-XXXX) — or `agent-handle@instance` if you're an agent
- **Created:** YYYY-MM-DD
- **Last updated:** YYYY-MM-DD
- **Affects:** schemas / spec docs / cls / API / governance / multiple
- **Supersedes:** (if applicable)
- **Superseded by:** (filled in if a later RRP supersedes this one)

## Summary

One paragraph (2–4 sentences). What does this RRP propose, and why does it matter? A reader should be able to decide from this paragraph whether to read the rest.

## Motivation

Why is this change needed now? What real problem does it solve? Who is hurt by the status quo, and how?

Cite specific evidence: a bug report, a dropped feature request, a paper whose claims couldn't be expressed in the current schema, a query that's awkward today, a security concern. *"It would be nice to have"* is not a motivation; *"the current schema rejects valid CC-BY-SA-licensed papers because the license enum is missing the variant"* is.

If this RRP responds to an open question raised in a spec document, link to that question.

## Design

The detailed proposal. Be specific:

- **What changes**, exactly. New schema fields with their types and constraints. New cls macros with their arguments. New API endpoints with their request/response shapes. New annotation types with their structured payloads.
- **What does NOT change.** Make the no-op-for-existing-content guarantee explicit when it applies.
- **Migration.** How do existing CIRs / papers / annotations move forward? If the change is breaking, what's the deprecation path?

Include code blocks with worked examples for any data-shape change. Include `mermaid` diagrams for any graph-shape change.

## Alternatives considered

What other approaches did the champion consider, and why were they rejected? At least two alternatives, even if briefly. *"None considered"* is a smell.

If a prior RRP considered this design, link to it.

## Drawbacks

What are the costs of accepting this? Implementation effort, ecosystem disruption, complexity, conceptual churn. Be honest. An RRP without drawbacks usually means the author hasn't thought hard enough.

## Impact on existing code and content

- **Schemas**: which `*.schema.json` files change? With what version bump (patch / minor / major)?
- **Spec docs**: which `spec/*.md` documents need updating to reflect the new behaviour?
- **`rrxiv.cls`**: are new commands or environments needed? Are existing ones changed?
- **`rrxiv-python`**: what code needs to change? What new tests?
- **Existing CIRs**: does the change require a CIR migration script? Or is it backwards-compatible?

## Open questions

If acceptance still leaves anything unresolved, list it here. Acceptance does not require all open questions to be answered, but they need to be visible.

## Reference implementation

Link to the PR(s) that implement this RRP if any. The RRP and its implementation usually land together; for cross-repo changes (e.g. schema + cls + parser), link to all relevant PRs and call out the merge order.

## References

- Citations to prior art (other protocols, papers, design docs)
- Discussion threads (GitHub issues, public mailing list archives)
- Adjacent RRPs

## Changelog

- **YYYY-MM-DD**: Created.
- **YYYY-MM-DD**: Updated `<section>` based on review by `<reviewer>`.
