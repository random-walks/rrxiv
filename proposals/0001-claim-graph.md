# RRP-0001 — Claim graph design (retroactive)

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-04
- **Last updated:** 2026-05-04
- **Affects:** schemas, spec docs, `rrxiv.cls`
- **Supersedes:** none
- **Superseded by:** none

## Summary

This RRP retroactively documents the design rationale for the claim graph — the corpus-spanning directed graph whose nodes are individual claims (not papers) and whose edges (`depends_on`, `supports`, `contradicts`, `extends`) make the corpus queryable in ways an unstructured PDF stack is not. The design was set in the v0.1 whitepaper and the v0.1 schemas; this RRP is the formal record so future RRPs that touch the graph have something concrete to amend or supersede.

## Motivation

The whitepaper makes the case for the claim graph at a narrative level, but the schemas and `rrxiv.cls` carry binding design commitments — claim ID format, the four edge types, server-derived `replication_status` semantics, the canonical-claim distinction — that are not the whitepaper's primary subject. Future RRPs that touch any of these will want a single document to amend. Without RRP-0001, every such RRP would have to re-explain what the design *currently is* before proposing a change.

This RRP also formally adopts the design as the protocol's first concrete commitment beyond the locked principles in `spec/0008-governance.md`. From this point forward, changes to the claim graph go through the RRP process; this RRP is the baseline they amend.

## Design

The full design is described in [`spec/0003-claim-graph.md`](../spec/0003-claim-graph.md). The load-bearing commitments are:

### Claims as the unit of structured knowledge

Each claim has a stable, globally unique `id` (convention `<paper_id>:<local_label>`), a natural-language `statement`, and metadata fields covering `claim_type`, `evidence_type`, `scope`, optional author `confidence`, server-derived `replication_status`, and provenance (`extracted_by`, `canonical`).

A claim is not a section. A claim is not a paragraph. A claim is the falsifiable assertion a paper makes; a paper typically contains several. The minimum-viable v0.1 paper has at least one claim (see `template/examples/minimal/`).

### The four edge types

The graph is typed and intentionally minimal:

- **`depends_on`**: X depends on Y if X's argument relies on Y being true. Cycles are a soft error.
- **`supports`**: X supports Y if X is presented as evidence for Y. Reverse-ish of `depends_on` but distinct in semantics.
- **`contradicts`**: X and Y cannot both hold within their stated scopes. Authored by either paper, by annotators, or both.
- **`extends`**: X generalizes, refines, or strengthens Y. Cycles are forbidden by definition.

New edge types require an RRP. The taxonomy is small on purpose.

### Edge declaration: source vs. annotation

Edges land in two ways:

1. **By authors, in source.** The cls macros `\dependson{S}{T}`, `\supports{S}{T}`, `\extendsclaim{S}{T}`, `\contradicts{S}{T}` emit sidecar markers the parser turns into edges.
2. **By annotators, after submission.** A `contradiction` or `extension` annotation creates the corresponding edge. The annotation is signed; the edge inherits provenance from it.

Both kinds of edges share the same on-the-wire shape in the CIR. They differ in `created_by` and in the rules for what they can express (annotators cannot declare authoritative `depends_on` between an existing paper and a new one without the original author confirming via a `claim_extraction` annotation).

### Canonical vs. non-canonical claims

Author-extracted claims are canonical from submission. Agent- or annotator-extracted claims default to non-canonical and require confirmation by either the paper's author or by quorum of credentialed annotators. The exact quorum rule is **deferred** to a future RRP — see [`spec/0006-annotations.md`](../spec/0006-annotations.md).

### Immutability

Claims are immutable. An "updated" claim is a *new* claim with a new ID and an `extends` edge from the new to the old. The old claim's `replication_status` may evolve based on annotations, but its `statement` and `scope` do not. This is the structural commitment that makes citation work.

## Alternatives considered

### Single-edge-type graph ("claim X relates to claim Y")

Considered and rejected. A typeless edge is much easier to declare but loses the analytical leverage that makes the graph worth having. *"X relates to Y"* doesn't tell an agent whether X depends on Y, contradicts Y, or extends Y; the reader has to inspect both claims to decide. The whole point is to surface that structure ahead of time.

### More edge types from the start (e.g. `methodologically-relates-to`, `domain-overlap`, `cites`)

Considered and rejected for v0.1. Edge taxonomies are easy to grow and almost impossible to shrink. Starting with four well-defined types is conservative; future RRPs can introduce new types when a real use case demands.

### Edge weights (numeric strengths on each edge)

Considered and rejected for v0.1. *"This claim depends 80% on that one"* sounds informative but isn't operationally meaningful — the threshold for "really depends" varies by reader. Adding weights complicates the schema, the API, and the visualisations without paying for itself. Revisit if a use case demands.

### Claim-level citations replacing paper-level citations

Rejected. Paper-level citations are universal academic plumbing; we keep them. The claim graph is a layer *on top of* paper citations, not a replacement.

## Drawbacks

- **Authoring friction.** Authors must write `\begin{claim}` blocks, declare edges with `\dependson{}`, and choose meaningful `\label{}`s. This is more work than dumping prose. The mitigation is good template ergonomics (see `template/rrxiv-template.tex`) and tooling that lints for missing labels.
- **Edge declaration is currently verbose.** `\dependson{paper-id:claim:foo}{other-paper:claim:bar}` requires both IDs spelled out. A future RRP could allow `[depends-on=...]` as an environment argument.
- **Minimal taxonomy may be too minimal.** Some real-world relationships don't fit cleanly into the four types. Authors will compress; the compression loses information.
- **Cross-paper edge integrity is not enforced at submission time.** A paper can declare `\dependson{X}{nonexistent-id}`. v0.1 stores the edge and flags it; there's no resolve-at-submission check yet.
- **The colon ambiguity in the v0.1 sidecar.** Edge markers `RRXIV:edge:<type>:<src>:<dst>` are colon-joined, but `:` is also the conventional separator inside IDs. The parser uses a midpoint-split heuristic. RRP-0002 (draft) addresses this directly.

## Impact on existing code and content

This RRP describes the existing v0.1 design. No code or schema changes follow from acceptance; the artifacts already reflect this design:

- [`schema/claim.schema.json`](../schema/claim.schema.json)
- [`schema/cir.schema.json`](../schema/cir.schema.json) (claim graph edges live in `claim` records' `depends_on` / `supports` / `contradicts` / `extends` fields)
- [`template/rrxiv.cls`](../template/rrxiv.cls) (environments and edge macros)
- [`spec/0003-claim-graph.md`](../spec/0003-claim-graph.md) (prose spec)

## Open questions

- **Quorum rules for canonical-promotion.** Deferred to a future annotations RRP.
- **Claim ID format.** v0.1 uses the convention `<paper_id>:<local_label>` informally. A formal grammar (length cap, reserved characters, normalisation) is needed; track as a future RRP.
- **Cross-paper edge integrity.** What happens when a paper claims an edge to a non-existent claim ID? v0.1 stores the edge with a flag; v0.2 should specify resolution.
- **Graph query language.** What language do servers expose for graph queries (Cypher, GraphQL, bespoke DSL)? See [`spec/0007-api.md`](../spec/0007-api.md).

## Reference implementation

The v0.1 reference implementations are:

- **Schema**: `schema/claim.schema.json` and `schema/cir.schema.json` — JSON Schema 2020-12.
- **`rrxiv.cls`**: `template/rrxiv.cls` — emits sidecar markers on environment opens and inline edge declarations.
- **Parser**: `rrxiv-python/src/rrxiv/parser/` — reads .tex source plus sidecar, builds CIR, validates against the schemas.

## References

- The rrxiv whitepaper (`whitepaper/rrxiv-whitepaper.tex`), v0.1.
- [`spec/0001-overview.md`](../spec/0001-overview.md), [`spec/0002-cir.md`](../spec/0002-cir.md), [`spec/0003-claim-graph.md`](../spec/0003-claim-graph.md).
- Prior art: IETF RFC numbering and lifecycle; Bitcoin BIP process; Python PEP process; the W3C TAG findings on multi-stakeholder protocol design.

## Changelog

- **2026-05-04**: Created. Status: Accepted (retroactive — describes existing v0.1 design).
