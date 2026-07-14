# RRP-0031 — Whitepaper v7: reality-sync + claim-graph dogfooding

| | |
|---|---|
| **Status** | Accepted |
| **Author** | Blaise Albis-Burdige, Claude |
| **Created** | 2026-07-14 |
| **Affects** | `rrxiv-whitepaper` (rrxiv:2605.00001, v6 → v7) only. **No schema, cls, parser, or server changes** — v7 is the first consumer of `rrxiv.cls` 0.8 / RRP-0030. |
| **Sister RRPs** | [RRP-0003](0003-whitepaper-formatting.md) (precedent: whitepaper revisions go through an RRP) · [RRP-0030](0030-claim-authoring-keys.md) (the authoring keys v7 exercises) · [RRP-0029](0029-paper-id-uuidv7.md) (id model v7 describes) · [RRP-0021](0021-structured-authorship.md)/[RRP-0026](0026-gold-standard-agent-attribution.md) (`\rrxivauthor` records) |

## Process note (v0.x accelerated review)

Sole maintainer; pre-1.0; one-PR review cycle. The deviation from a v1.0 RFC process is intentional and bounded — see [`CONTRIBUTING.md#process-note`](../CONTRIBUTING.md).

## Summary

Revise the canonical whitepaper (rrxiv:2605.00001) from v6 to v7. The revision
is **surgical**: the historical design narrative, the v2/v4 addenda, and the
governance commitments carry forward unchanged. What changes is (1) the
paper's claims about reality, which have fallen behind reality, and (2) the
paper's own claim graph, which under-uses the protocol the paper specifies.
The whitepaper's own convention (established at v1, reaffirmed by RRP-0003)
is that substantive revisions require an RRP; this is that RRP.

## Motivation

The July-2026 corpus audit found the whitepaper to be **the stalest artifact
in the corpus** while remaining its most-read paper:

- The v6 body still asserts *"The canonical instance does not yet exist …
  before any production system goes live"* (§Discussion) and describes
  Phase 1 as future work — while `rrxiv.com` + `api.rrxiv.com` have been live
  since May 2026 and open publishing shipped in July 2026 (9 papers, 656
  claims, ORCID auth, hCaptcha, `pip install rrxiv` on PyPI, Highwire +
  JSON-LD Scholar meta tags, UUIDv7 + `id_slug` identifiers per RRP-0029,
  per-discipline replication quorums per RRP-0019).
- The testable-invariants section (v4 addendum) contains eight operational
  claims with **zero edges** among them and default
  `theoretical`/`argument`/no-confidence epistemology on every one — in a
  paper whose thesis is that claim-level structure beats prose.
- The whitepaper cites **none** of its 8 sibling papers, structurally: the
  hub of the corpus has zero outgoing cross-paper edges.
- The author block is plain `\author[n]{}` + `\thanks{}`; the structured
  `\rrxivauthor` records (RRP-0021/0026) that carry ORCID and agent
  provenance are used zero times corpus-wide. The genesis paper should be
  the first consumer.

A protocol whose founding document misdescribes the protocol's own state
undermines the honesty norms the document itself establishes.

## Scope of the v7 revision

### 1. Reality-sync

Rewrite the stale reality-claims; leave the design rationale intact.

- §Roadmap: Phase 0 and Phase 1 are marked **shipped**, with their own
  definitions-of-done checked against the live instance (noting honestly that
  the corpus, at 9 papers, sits just under Phase 1's "ten to hundred" floor).
  Phase 2 (Open Submission) is reframed as **in progress**: open ORCID
  submission with hCaptcha is live (July 2026); the corpus-density
  (~1,000 structured submissions) and domain-council criteria remain unmet.
- §Discussion "Why we are publishing this whitepaper before building the
  system": retitled to past tense; the closing paragraph now records that the
  instance exists and points at it, instead of promising it.
- §Open questions: item 1 (identifier scheme) records that RRP-0029 settled
  the machine-id/citable-slug split, with DOI integration still open; item 2
  (extraction mechanism) records that RRP-0004 moved parsing to an AST with
  the sidecar retained for edge/author markers.
- Abstract: a v7 entry is prepended to the running revision history, in the
  same style as v2–v6.

### 2. Dogfood the claim graph

- Every claim in the paper gets honest RRP-0030 keys (`type=`, `evidence=`,
  and `labels=`/`confidence=` where honest). The four design-thesis claims
  stay `theoretical`/`argument` (now explicit rather than defaulted); the
  eight operational invariants become `empirical` with
  `evidence=observation` (verified against the live instance or the paper's
  own lineage) or `evidence=experiment` (enforced in code and covered by the
  reference-implementation test suite), chosen per claim.
- The invariants become a real DAG: `\dependson`/`\supports` edges among the
  invariant claims and to the core claims (e.g. the server-derived
  replication-status invariant supports the queryability thesis; slug
  stability depends on lineage acyclicity; verifiable snapshots support
  structural unsellability).
- Cross-paper edges to all 8 sibling papers, each individually justified
  against the live corpus (target claim ids verified via
  `GET /api/v0/papers/{slug}/claims`), e.g. the volume-structure thesis
  supports rrxiv:2605.00002:claim:c1 (claim-level addressability), and a new
  state-of-the-network claim depends on exemplar claims in the Elements
  encoding (rrxiv:2605.00009) and the four demonstration papers it names.

### 3. Structured authorship

The `\author[n]{}` + `\thanks{}` block is replaced by `\rrxivauthor` records
matching `rrxiv-meta.json` byte-for-byte on names: Blaise Albis-Burdige
(ORCID 0009-0002-0561-6499) plus the two agent contributors (Claude Opus 4.7,
Claude Opus 4.8) with RRP-0026 provenance keys (vendor, family, series,
version, release pin, release date, inference environment). Contribution
detail previously in `\thanks{}` footnotes moves to §Acknowledgments.

### 4. State of the network (July 2026)

A new Discussion subsection states, as claims where claim-shaped and as prose
where not, what the network actually is right now: a 9-paper, 656-claim
corpus that is small and agent-heavy in authorship; a community/annotation
layer that is **empty in production** (the early demonstration annotations
were lost to a pre-`--preserve-community` reseed and are being restored); and
a revision UI with no live lineage until this very submission creates the
first one. The protocol's honesty norms apply to its own paper first.

## Honesty constraints (binding on the draft)

Every `type=`, `evidence=`, `confidence=`, label, and edge added in v7 must
be justified by the actual state of the project at drafting time. In
particular: no `confidence` values on claims where the author has no basis
for a band; no `replicated` implications anywhere (production has zero
replication annotations); no cross-paper edge without a stated rationale that
survives reading the target claim's statement.

## Not in scope

- No changes to `schema/`, `rrxiv.cls`, the parser, the server, or the web
  client. v7 consumes cls 0.8 as shipped by RRP-0030.
- No rewrite of the design narrative, the v2 RRP survey, the v4 invariants
  prose, or the governance/sustainability commitments.
- No version bump in `rrxiv-meta.json` — the server assigns v7 and the
  `versions[]` lineage entry at submission time (RRP-0017); the metadata
  reconciliation lands after submission, as it did for v6.
- The motherepo mirror (`whitepaper/rrxiv-whitepaper.tex`) syncs only after
  maintainer approval + successful submission. (The audit found the mirror
  is currently stale at a pre-v2 state; the post-submission sync should fix
  that too.)

## Rollout

1. v7 drafted on `feat/v7-draft` in `rrxiv-whitepaper`; built with tectonic;
   parsed + validated with the current `rrxiv-python` parser (PyPI 0.x lags
   RRP-0030, so the local parser is the gate).
2. Maintainer review of the PR — this RRP and the draft PR are
   cross-referenced and gated together.
3. On approval: `./scripts/submit.sh --revision-of` against the canonical
   instance. This submission is itself load-bearing: it creates the **first
   live version lineage** on production since the RRP-0029 re-mint, lighting
   up the versions rail and `GET /papers/{id}/diff` with real data.
4. After submission: sync the motherepo mirror, reconcile
   `rrxiv-meta.json`/`CITATION.cff`, tag the repo.
