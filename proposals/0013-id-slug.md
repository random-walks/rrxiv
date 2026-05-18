# RRP-0013 — Human-friendly paper slugs (`id_slug`)

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-18
- **Last updated:** 2026-05-18
- **Affects:** schemas / spec docs / API
- **Supersedes:** none
- **Superseded by:** none

## Summary

Add a server-minted `id_slug` field to `paper.schema.json` carrying a human-friendly identifier of the form `rrxiv:YYMM.NNNNN` (e.g. `rrxiv:2402.00128`), borrowed from arXiv's identifier scheme. The canonical `id` remains UUIDv7. Slugs are used in URLs, citations, and human discourse; the UUID is used in storage and graph references.

## Motivation

`paper.schema.json` today specifies paper `id` as UUIDv7 — chosen for collision-free distributed minting and stable lexical ordering. Excellent for machines, awful for humans:

- URLs become `https://rrxiv.org/papers/01923f8e-5b2a-7c4d-9e1f-3a2b1c0d4e5f` — opaque, unmemorable, ungoogleable.
- Citations would read "see rrxiv:01923f8e-5b2a-7c4d-9e1f-3a2b1c0d4e5f §3" rather than the familiar arXiv-shaped "see rrxiv:2402.00128 §3".
- Breadcrumbs, share cards, and copy-paste workflows all suffer.

The official rrxiv-web client at `apps/web/lib/data.ts` currently uses fixture IDs of the form `rrxiv:2402.00128` throughout its UI surface (URL params, breadcrumbs, claim chips, citation badges). Migrating that client to the canonical UUIDv7 IDs as URL segments would degrade the UX measurably. The alternative — letting clients invent their own slug schemes — produces incompatible citations across implementations and isn't a protocol-level solution.

arXiv has been minting `YYMM.NNNNN` IDs for two decades; readers, search engines, and citation parsers all recognise the shape. Borrowing the surface form (with the `rrxiv:` namespace prefix) is the right answer: it's human-friendly, parseable, and signals lineage without inventing new conventions.

## Design

### Schema change

`paper.schema.json` gains one optional property:

```jsonc
{
  "id_slug": {
    "type": "string",
    "description": "Human-friendly paper identifier of the form rrxiv:YYMM.NNNNN. Server-minted at submission, unique per server instance. Used in URLs, citations, and human-readable references. The canonical machine identifier remains `id`. Once assigned, NEVER changes.",
    "pattern": "^rrxiv:[0-9]{4}\\.[0-9]{5}$",
    "examples": ["rrxiv:2402.00128", "rrxiv:2605.00001"]
  }
}
```

Optional in schema, required in practice for any public-facing server. The "optional in schema" allows agent-authored CIRs to validate without minting a slug; the server fills it in on submission.

### Minting rules

A v0.1 server-conformant minting algorithm:

```
YY      = last two digits of the submission timestamp's year, UTC (e.g. "26" for 2026)
MM      = month, zero-padded, UTC
YYMM    = the two concatenated, no separator (e.g. "2605" for May 2026)
NNNNN   = a 5-digit, zero-padded counter, monotonic per (YY,MM)
prefix  = "rrxiv:"
```

Specifically: the first paper submitted in May 2026 across the entire instance gets `rrxiv:2605.00001`. The 100,000th gets `rrxiv:2605.99999`. The 100,001st triggers an instance-policy decision (the canonical instance uses 6-digit overflow `rrxiv:2605.100000`; reference instances may choose differently). 100k papers/month overflow is a v1.0 concern, not v0.1.

This is intentionally identical to arXiv's identifier shape (4-digit `YYMM` + 5-digit counter, dot-separated). The `rrxiv:` prefix disambiguates namespaces; the body shape borrows two decades of human familiarity with arXiv URLs and citations.

The counter is per-instance, not global. Two different rrxiv instances can independently mint `rrxiv:2605.00001` referring to different papers — slugs are unique only within an instance's namespace. The canonical `id` (UUIDv7) disambiguates across instances. This matches how arXiv operates as a single-instance namespace.

### Resolution

Servers MUST accept either form on detail endpoints:

```
GET /api/v0/papers/01923f8e-5b2a-7c4d-9e1f-3a2b1c0d4e5f   → Paper
GET /api/v0/papers/rrxiv:2605.00001                       → same Paper
GET /api/v0/papers/rrxiv%3A2605.00001                     → same Paper (URL-escaped)
```

Implementation note: the router checks for `id.startsWith("rrxiv:")` or matches the slug regex; falls through to UUID lookup otherwise. The colon in `rrxiv:` must be URL-escaped as `%3A` in path segments by well-behaved clients; servers MUST accept both forms.

### Migration

Existing v0.1 CIRs that lack `id_slug` continue to validate (the field is optional). When a server ingests such a CIR for the first time, it mints a slug at ingest time and stores it. From that point the slug is immutable per the "Once assigned, NEVER changes" rule.

The rrxiv whitepaper at `repos/rrxiv/whitepaper/rrxiv-whitepaper.tex` currently lacks an `id_slug`; on first upload to the canonical instance, the server mints `rrxiv:2605.00001` (or whatever the actual first-of-month counter resolves to) and that becomes its permanent slug.

### Spec doc updates

`spec/0002-data-model.md` (or wherever the ID conventions live) gains a new section "Paper identifiers: canonical vs slug" walking through the dual-identifier model with examples. `spec/0007-api.md` documents the dual-resolution behaviour.

## Alternatives considered

### Use the slug as the canonical `id`

Considered — drop UUIDv7 entirely and use `rrxiv:YYYY.MM.NNNNN` as the primary identifier. Rejected because:
- Slug minting requires server coordination; UUIDv7 can be minted client-side or in distributed services.
- Two instances minting independently produces collisions in a federated future.
- 100k/month overflow is a real concern at scale; UUIDv7 has 128 bits of headroom.
- Graph references (`claim.depends_on`, `annotation.target_id`) want stable opaque identifiers, not human-readable slugs that might be re-issued in some future migration.

### DOI-style identifiers

Considered — mint DOIs and use those. Rejected because DOIs require DataCite/CrossRef membership and a publisher commitment; rrxiv's whole point is to operate outside that gatekeeping infrastructure. A future RRP can add DOI-minting as an optional layer for instances that want it.

### Free-form slug chosen by the author

Considered — let authors choose `rrxiv:author/snake-case-title`. Rejected because of namespace contention, profanity risk, and the gap between "what authors want their slug to be" and "what fits in a 30-character URL." The arXiv-shaped slug avoids all of that.

### Append a slug to the UUID instead of replacing in URLs

Considered — URLs like `https://rrxiv.org/papers/01923f8e-5b2a-7c4d/queryability-protocol` where the trailing segment is human-friendly. Rejected because it inherits the UUID's ugliness in the URL and doubles the surface area to maintain. The arXiv-style identifier is the right granularity.

## Drawbacks

- **Two identifiers per paper.** Documentation and client code carry the cognitive load of "use `id` for refs, `id_slug` for URLs." Mitigated by clear naming and by the fact that arXiv works the same way (paper id vs DOI vs arXiv URL — multiple identifiers coexist productively).
- **Slug-collision risk on multi-process instances.** The monotonic counter requires synchronisation. The SQLite reference server's single-writer lock makes this trivial; Postgres instances need a sequence or advisory lock. Documented in `spec/0007-api.md`.
- **Federation ambiguity.** `rrxiv:2605.00001` on instance A and `rrxiv:2605.00001` on instance B refer to different papers. Cross-instance citations must include an instance hint (e.g., `rrxiv.org:2605.00001`). v0.1 is single-canonical-instance so this is theoretical; v1.0 federation RRP must resolve it.

## Impact on existing code and content

| Surface | Change |
|---|---|
| `schema/paper.schema.json` | Add optional `id_slug` field. Minor version bump (0.1.0 → 0.2.0). |
| `schema/cir.schema.json` | No change — CIR references `paper.schema.json#/properties/...` via the embedded `paper` object, which inherits the new optional field. |
| `schema/api.openapi.yaml` | Document dual-resolution on `GET /papers/{id}`. Add `id_slug` to response examples. |
| `spec/0002-data-model.md` | New "Paper identifiers" section. |
| `spec/0007-api.md` | Document dual-resolution. |
| `rrxiv-python/src/rrxiv/server/submissions/router.py` | Mint slug on submission, persist alongside paper. |
| `rrxiv-python/src/rrxiv/server/papers/router.py` | Accept both `id` and `id_slug` on detail endpoint. |
| `rrxiv-python/src/rrxiv/server/store/protocol.py` | New `get_paper_by_slug(slug) -> Paper | None` method on Store. |
| `rrxiv-python/src/rrxiv/server/store/sqlite.py` | Add `id_slug TEXT UNIQUE` column on `papers` table; new migration. |
| `rrxiv-python/src/rrxiv/server/store/memory.py` | In-memory secondary index by slug. |
| Existing CIRs | No required migration. Servers mint slugs on first ingest. |

## Open questions

- **Slug reservation for collisions in federation.** v0.1 doesn't address; v1.0 federation RRP must.
- **Slugs for non-paper entities.** Should claims get slugs too? (`rrxiv:2605.00001:queryability` is already human-readable enough — the slug+localname form works.) Annotations? Future RRP if needed.
- **6-digit overflow.** At 100k/month an instance must extend the format. Defer concrete handling until an instance approaches the threshold.

## Reference implementation

`rrxiv-python` (forthcoming PR adding slug minting on submission + dual-resolution lookup).

## Process note

Per RRP-0012's process note: v0.x accelerated review. The change is additive (no field removals, no behavioural surprises for existing endpoints, optional field) and supports the first public deployment of the protocol. Merging with `Status: Accepted` without the 14-day Discussion window; standard process resumes for v1.0+.

## References

- [arXiv identifier scheme](https://arxiv.org/help/arxiv_identifier)
- [`schema/paper.schema.json`](../schema/paper.schema.json)
- [RRP-0012 — Paper list-item projection](0012-paper-list-item-projection.md)

## Changelog

- **2026-05-18**: Created. Status: Accepted under v0.x accelerated review.
