# RRP-0012 — Paper list-item projection

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-18
- **Last updated:** 2026-05-18
- **Affects:** schemas / API
- **Supersedes:** none
- **Superseded by:** none

## Summary

Define `paper_list_item.schema.json`, a server-computed projection of `Paper` that includes aggregate `stats` (claim counts and a paper-level replication status). Make it the response shape of `GET /api/v0/papers` and the response shape of `GET /api/v0/papers/{id}?include=stats`. The canonical `Paper` remains immutable; this is the discovery-shaped view.

## Motivation

Browse and search UIs need at-a-glance counts: *how many claims does this paper register, how many of them have been replicated, how many contested or contradicted*. Today the only way for a client to assemble this is to fetch the CIR (heavy, includes full claim payloads + full annotations) and aggregate client-side, once per paper rendered. That is the wrong shape for a list view and produces non-trivial bandwidth waste against a corpus with even a few thousand papers.

The official rrxiv-web client at [`apps/web/lib/data.ts`](https://github.com/random-walks/rrxiv-web-official/blob/main/apps/web/lib/data.ts) currently uses fixture data with a `Paper` type carrying `claims`, `replicated`, `contradicted`, `contested`, and `status` fields. Migrating that client to a live server with no canonical projection forces either (a) per-paper CIR fetches or (b) bespoke aggregate endpoints, neither of which scale to third-party clients. Defining the projection in the protocol makes it consumable by *any* client.

The aggregates are *derived*, not authored. Mixing them into the immutable `Paper` schema would muddle immutability (a `Paper` is fixed at submission; aggregate counts change every time someone files a replication). They belong in a sibling projection.

## Design

### New schema: `schema/paper_list_item.schema.json`

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://rrxiv.com/schema/v0/paper_list_item.schema.json",
  "title": "Paper list-item",
  "description": "A Paper plus server-computed aggregate stats. Wire shape for GET /api/v0/papers and GET /api/v0/papers/{id}?include=stats.",
  "version": "0.1.0",
  "type": "object",
  "allOf": [{ "$ref": "paper.schema.json" }],
  "required": ["stats"],
  "properties": {
    "stats": { "$ref": "#/$defs/Stats" }
  },
  "$defs": {
    "Stats": {
      "type": "object",
      "required": ["claims", "replicated", "contradicted", "contested", "status", "computed_at"],
      "properties": {
        "claims": { "type": "integer", "minimum": 0, "description": "Total claims registered on this paper." },
        "replicated": { "type": "integer", "minimum": 0, "description": "Claims with replication_status='replicated'." },
        "contradicted": { "type": "integer", "minimum": 0, "description": "Claims with replication_status='contradicted'." },
        "contested": { "type": "integer", "minimum": 0, "description": "Claims with replication_status='partial' (mixed evidence)." },
        "untested": { "type": "integer", "minimum": 0, "description": "Claims with replication_status='untested' or unset." },
        "status": {
          "type": "string",
          "enum": ["preprint", "untested", "replicated", "contested", "retracted"],
          "description": "Paper-level rollup derived from claim replication_status and paper retraction state."
        },
        "computed_at": {
          "type": "string",
          "format": "date-time",
          "description": "When this stats snapshot was computed. Servers SHOULD include; clients MUST treat as a hint, not a cache key."
        }
      }
    }
  }
}
```

### Paper-level status rollup

`stats.status` is derived from the claims and paper retraction state, per this precedence:

| Condition | Resulting `status` |
|---|---|
| The paper has a retraction annotation (target_type=paper, annotation_type=erratum with `structured_payload.retracted=true`) | `retracted` |
| `claims == 0` *or* every claim is `untested` and the paper has no annotations at all | `preprint` |
| `claims > 0` and every claim is `untested` (annotations exist but no replications/contradictions) | `untested` |
| `replicated > 0` *and* `contradicted == 0` *and* `contested == 0` | `replicated` |
| `replicated > 0` *and* (`contradicted > 0` *or* `contested > 0`) | `contested` |
| `contradicted > 0` *and* `replicated == 0` | `contested` (contradiction without replication is still a contested paper, not a "contradicted" paper — the paper's *claims* are contradicted, not the paper as a whole; only retraction marks the paper itself contradicted) |

The "claim-level enum (`untested`/`partial`/`replicated`/`contradicted`/`retracted`) vs paper-level enum (`preprint`/`untested`/`replicated`/`contested`/`retracted`)" split is intentional. Claim-level captures evidence about an individual assertion; paper-level captures *discovery-time browsability*. They have different cardinalities and different consumers.

### Endpoint shape changes

| Endpoint | Before | After |
|---|---|---|
| `GET /api/v0/papers` | `{ items: Paper[], next_cursor: null }` | `{ items: PaperListItem[], next_cursor: null }` |
| `GET /api/v0/papers/{id}` | `Paper` | `Paper` (unchanged) |
| `GET /api/v0/papers/{id}?include=stats` | (n/a) | `PaperListItem` (Paper + stats inline) |

The `include=stats` query param pattern leaves the canonical `Paper` shape unchanged for callers that want it, and avoids defining a second route purely for stats. `GET /api/v0/papers/{id}/stats` returning just the stats object is a candidate future addition but is not required for v0.1.

### Filters on list endpoint

`GET /api/v0/papers` accepts these query params for v0.1 (additive, none required):

- `?scope=<id>` — one of the instance's defined scopes (see [`GET /api/v0/scopes`](https://github.com/random-walks/rrxiv-web-official) — instance-specific, not protocol-binding).
- `?topic=<id>` — papers whose `topics[]` contains the given topic id.
- `?cursor=<opaque>` — pagination. v0.1 servers MAY ignore (return all) but MUST accept the param.

### Computation

`stats.computed_at` is a hint. Servers MAY compute on-read (cheap for small corpora, simpler) or memoise with a TTL (necessary at scale). The shape is identical either way. Clients MUST NOT use `computed_at` as a cache key — the same paper can have different `computed_at` on consecutive calls without other fields changing.

## Alternatives considered

### Extend `paper.schema.json` with optional `stats`

Rejected — muddles immutability. A `Paper` is the authored record; aggregates are server-derived state. Same reason annotations and claim graphs are separate schemas: derived state must not commingle with authored state.

### Add the aggregate fields to CIR

Rejected — CIR is the document-level shape, including full claim and annotation arrays. A list-view client doesn't want the full claim payload per item; it wants just the count and rollup. CIR also has the same immutability premise as `Paper`.

### Make clients aggregate client-side from CIR

Rejected — pushes O(corpus_size) computation to every client, requires every client to write the same aggregation logic, and produces inconsistent results across implementations. Servers compute once and serve consistent rollups.

### Per-aggregate endpoints (`/papers/{id}/replication-count`, etc.)

Rejected — explodes the API surface for what is conceptually one shape. The projection captures the cohesive UI need ("show me a row of paper metadata + counts") in one response.

## Drawbacks

- **Computation cost.** A naive server computes stats on every list request; for a 10k-paper corpus that's 10k claim-aggregate queries per request. v0.1 reference server can do this in-memory in <50ms; production deployments need memoisation. The schema doesn't dictate strategy.
- **Schema sprawl.** One more schema file, one more set of generated types in clients. Acceptable cost — the alternative is bespoke per-client aggregation, which is strictly worse.
- **Subtle status rollup rules.** The `contested` definition is a judgement call (we chose: "any mix of replication + non-replication evidence"). Servers may disagree at the margin. The enum is small enough that disagreement is detectable in conformance tests.

## Impact on existing code and content

| Surface | Change |
|---|---|
| `schema/paper_list_item.schema.json` | New file. |
| `schema/README.md` | Add row to the schemas table; update composition diagram. |
| `schema/api.openapi.yaml` | Update `GET /papers` response to reference the new schema. Add `?scope`, `?topic`, `?include=stats` query params. |
| `rrxiv-python/src/rrxiv/_schemas/` | Sync new schema. Pydantic model regeneration. |
| `rrxiv-python/src/rrxiv/server/papers/router.py` | Return list-item shape; honour `?include=stats` on detail. |
| `rrxiv-python/src/rrxiv/server/papers/projection.py` | New: `compute_stats(paper_id, store) -> Stats`, `to_list_item(paper, store) -> PaperListItem`. |
| `rrxiv-web-official/packages/protocol-types/` | Regenerate TS types; export `PaperListItem`. |
| Existing CIRs | No change. Existing `Paper` records validate against `paper.schema.json` unchanged. |

## Open questions

- **Caching headers.** Should responses set `Cache-Control: max-age=...` for the stats shape? Probably yes with a short TTL, but the value depends on annotation traffic. Deferred to a future RRP once we have telemetry from a public instance.
- **Pagination cursor format.** v0.1 reference server returns `next_cursor: null`. A future RRP defines the cursor shape (keyset-based, opaque, server-encoded).
- **Per-scope stats.** Should the rollup status differ when filtered by scope (e.g., "agent-authored" papers have their own contested threshold)? v0.1 says no — stats are global per paper, scopes only filter which papers appear.

## Reference implementation

`rrxiv-python` (forthcoming PR adding `papers/projection.py` and updated `papers/router.py`). `rrxiv-web-official` `packages/protocol-types/` for the TS-side consumer.

## Process note

This RRP follows v0.x accelerated review: rrxiv is pre-1.0 with a single maintainer group, the change is purely additive (no field removals, no narrowed enums, no behavioural surprises for prior endpoints), and the implementation is well-scoped. The 14-day Discussion window is shortened to "merge when implementation is verified end-to-end against the reference client." This note exists to make the deviation from the standard process explicit in the historical record; the standard process resumes for v1.0+.

## References

- [RRP-0008 — Reference server](0008-reference-server.md)
- [RRP-0001 — Claim graph design](0001-claim-graph.md)
- [`schema/paper.schema.json`](../schema/paper.schema.json)
- [`schema/claim.schema.json`](../schema/claim.schema.json)

## Changelog

- **2026-05-18**: Created. Status: Accepted under v0.x accelerated review.
