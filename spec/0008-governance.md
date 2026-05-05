# 0008 — Governance

**Status:** stub. Full content TBD.

## Scope

How rrvix is governed: who decides what gets into the protocol, what changes require an RRP, the RRP lifecycle, the dispute resolution process, the relationship between rrvix.org (the canonical instance) and the protocol itself, and the legal/license posture.

## Locked principles

These come from [the whitepaper](../whitepaper/rrvix-whitepaper.tex) and are not up for redebate in v0:

1. **The protocol is permissively-licensed open source.** Code is MIT; spec docs and the whitepaper are CC-BY-4.0.
2. **The corpus is CC-BY licensed.** Submitted content must be under a CC-BY-compatible license; CC-BY-4.0 is the default and recommendation.
3. **Snapshot exports are mandatory and free.** Any rrvix instance must expose a complete, downloadable corpus archive.
4. **Forks are first-class.** If the canonical instance fails its users, the corpus and the code can be forked; the protocol does not lock anyone in.
5. **Governance changes go through the RRP process.** This document, the license files, and the process specification itself can be amended only via accepted RRPs.

## To be written

- **The RRP process** — draft, discussion, acceptance, supersession. See [`proposals/README.md`](../proposals/README.md) (M0.6 milestone) for the implementation.
- **Stewardship structure.** Who has commit rights? How are RRP decisions made? In v0 this will be a small group of maintainers; the path to broader stewardship needs to be specified.
- **Dispute resolution.** When two contributors disagree on a substantive design question and neither side cedes, what's the escalation path?
- **Conflict of interest disclosure.** Maintainers, RRP champions, and major contributors disclose affiliations relevant to specific RRPs.
- **rrvix.org-the-service vs. rrvix-the-protocol.** How is the canonical instance funded? Who operates it? What guarantees does it provide and what doesn't it guarantee? How does the operator recuse from protocol decisions?
- **The cooperative / nonprofit structure.** A cooperative or nonprofit organisation around the canonical instance, structured so the operator does not own the corpus or the protocol.
- **Sunset clauses.** What if a maintainer disappears? What if the canonical instance stops operating?

## Status

This document will land as the **last** Phase 0 milestone. By the time it's written, the RRP process must be running so this document can itself be ratified through it. Until then, the locked principles above are the only governance commitments rrvix carries.
