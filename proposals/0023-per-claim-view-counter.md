# RRP-0023 — Per-claim view counter

| | |
|---|---|
| **Status** | Accepted (retroactive — see Process note) |
| **Author** | Blaise Albis-Burdige, Claude |
| **Created** | 2026-05-26 |
| **Affects** | `schema/claim.schema.json` (additive `views_count`); `schema/pulse_snapshot.schema.json` (`leaderboards.top_claims_by_views`); reference server `GET /api/v0/claims/{id}` |
| **Sister RRPs** | [RRP-0022](0022-protocol-observability.md) (originally introduced this in its Sprint 22 amendment) · [RRP-0001](0001-claim-graph.md) (claim shape) |

## Process note (v0.x accelerated review + retroactive)

This RRP is retroactive: Sprint 22 shipped the per-claim view counter inline in [RRP-0022 §"Sprint 22 amendment"](0022-protocol-observability.md#sprint-22-amendment--per-claim-view-counter--cohort-groundwork) without a standalone proposal. The implementation is already in production at `api.rrxiv.com`. This RRP lifts the design out of that amendment block into a dense numbered proposal so the catalogue is contiguous and consumers can cite the wire shape by RRP number rather than as a sub-section of an unrelated proposal.

Process intentionally accelerated per [`CONTRIBUTING.md#process-note`](../CONTRIBUTING.md): sole maintainer, pre-1.0, one-PR review cycle.

## Summary

Add a server-stamped `views_count: integer` field to the claim read response. The counter is bumped on every successful `GET /api/v0/claims/{id}` and surfaces in a new `leaderboards.top_claims_by_views` array on the `PulseSnapshot`. Distinct in purpose from `replications_count` — replications measure contributed engagement (someone bothered to write an annotation), views measure discovery engagement (someone bothered to open the page).

## Motivation

Pre-Sprint-22 the protocol had two engagement signals on a claim:

1. `replications_count` — server-derived from annotation edges.
2. Plausible `claim.viewed` pageviews — anonymous, no server-side authority.

That gap matters because:

- **Plausible numbers are not reproducible across instances.** A federation aggregator pulling from two instances can't sum view counts if one instance uses Plausible and another uses Fathom — and the maintainer of either can adjust the cookie / dnt policy and silently change the number. The protocol needs a server-authoritative read counter.
- **Plausible numbers are not derivable by clients.** The CLI can't ask "which claims got the most attention this month?" without scraping a Plausible dashboard. A simple `GET /api/v0/stats/pulse` consumer can with a server-side counter.
- **Plausible numbers wash out with privacy controls.** A reader with DNT or an ad blocker doesn't count in Plausible; the same reader hitting the API endpoint *does* count in the server counter. The counter is the right authority for "how many times has this claim been opened by *any* HTTP client".

## Design

### Wire shape

`claim.schema.json` adds a single optional field:

```json
{
  "views_count": {
    "type": "integer",
    "minimum": 0,
    "description": "Number of times this claim has been returned via GET /claims/{id}. Server-stamped only; submitters MUST NOT populate it. Reset on store wipe."
  }
}
```

It's optional in the schema (older snapshots predate the field) but every fresh response from a v0.1+ server includes it.

### Counter semantics

- The counter is bumped on a successful 200 response from `GET /api/v0/claims/{id}` *after* the body is composed but *before* it's sent — failure to bump the counter MUST NOT fail the read (i.e. swallow store errors at the increment site).
- The counter is bumped exactly once per request, regardless of the auth_kind of the caller. Anonymous reads count; authenticated reads count; CLI reads count.
- The counter is *not* bumped by:
  - Bulk reads via `GET /api/v0/papers/{id}` (which embeds claims).
  - Search-result projections (which only return claim summaries).
  - The claim graph traversal endpoint.
  - Cache-revalidation HEAD requests.
  - Reads with `If-None-Match` that return 304.
- Self-exclusion (per RRP-0022) is NOT applied to the view counter. Excluding *writes* from a self-identified maintainer is meaningful; excluding *reads* would require trusting the user-agent string and would bias the leaderboard against papers the maintainer wrote (because the maintainer would never appear to read them).

### Leaderboard

`pulse_snapshot.schema.json` adds:

```json
{
  "leaderboards": {
    "top_claims_by_views": {
      "type": "array",
      "maxItems": 5,
      "items": {
        "type": "object",
        "required": ["claim_id", "views_count"],
        "properties": {
          "claim_id": { "type": "string" },
          "paper_id": { "type": "string" },
          "views_count": { "type": "integer", "minimum": 0 },
          "statement_excerpt": { "type": "string", "maxLength": 200 }
        }
      }
    }
  }
}
```

Capped at 5 entries. Bounded cardinality (RRP-0022 invariant).

### Storage

In the reference implementation (rrxiv-python), the counter lives in a `claim_views` table:

```sql
CREATE TABLE IF NOT EXISTS claim_views (
  claim_id TEXT PRIMARY KEY,
  views_count INTEGER NOT NULL DEFAULT 0,
  last_viewed_at_unix INTEGER
);
```

`last_viewed_at_unix` is informational (not exposed in the wire shape today) and lets the server distinguish "5 views all in 2023" from "5 views all yesterday" if a future RRP wants a recency-weighted ranking.

Increments use `INSERT … ON CONFLICT DO UPDATE` so the first read of a never-viewed claim doesn't need a pre-existing row.

### Cache invalidation

The 60s pulse cache is unaffected by single increments — the cache key includes corpus size but not view-count totals, so the cached snapshot reflects pre-increment leaderboards for up to 60s. This is acceptable: leaderboards are by definition lagging indicators.

## Backward compatibility

- `views_count` is optional. Pre-v0.1 clients reading the wire shape can ignore it.
- The counter starts at 0 for claims that existed before the counter was introduced; there is no back-fill from Plausible.
- A store wipe (`clear_corpus`) resets all counters. This is intentional — the counter is not durably attached to claim identity, only to the current copy of the claim graph in the live store.

## Drawbacks

- **Counter inflation by automated scrapers**: Bots crawling the API will inflate the count. Mitigation: rate-limit `/claims/{id}` reads (already at 60 RPM per identity); accept that some scraper traffic will pad the numbers. The signal stays useful for *relative* comparisons across claims even with absolute inflation.
- **Counter mismatch under concurrent reads**: `INSERT … ON CONFLICT DO UPDATE` is atomic in SQLite; no race. But under multi-process Postgres (deferred per RRP-future), we'd need `SELECT … FOR UPDATE` or an atomic counter primitive. Out of scope for v0.1.

## Alternatives considered

1. **Reuse Plausible's `claim.viewed` event for the leaderboard.** Rejected — requires a Plausible API key in the server, makes the leaderboard subject to Plausible's privacy filters (which would systematically under-count), and breaks federation comparability.
2. **Computed-from-annotations leaderboard only.** Rejected — annotations measure *contributed* engagement (someone wrote something). Views measure *discovery* engagement (someone arrived). They're distinct community-health signals; both should be visible.
3. **`X-View-Count` response header instead of body field.** Rejected — clients have to opt into custom-header parsing; embedded clients (Next.js fetch wrappers, the CLI) would silently drop the signal. Body field is canonical.

## Impact

- **Schemas**: `claim.schema.json` adds `views_count`; `pulse_snapshot.schema.json` adds `leaderboards.top_claims_by_views`. Both additive; existing clients unaffected.
- **Spec docs**: `docs/server.md` (claim endpoints) gains one paragraph noting the counter behaviour.
- **`rrxiv.cls`**: no change.
- **`rrxiv-python`**: already shipped (`src/rrxiv/server/store/sqlite.py` `_ensure_schema` adds the `claim_views` table; `src/rrxiv/server/papers/router.py` increments on read; `src/rrxiv/server/stats/pulse.py` derives the leaderboard).
- **Existing CIRs**: no migration needed; field starts at 0 on first read.

## Reference implementation

- [`rrxiv-python` Sprint 22 PR sequence](https://github.com/random-walks/rrxiv-python/pulls?q=is%3Apr+sprint-22) — `claim_views` table + counter + leaderboard.
- Production endpoint: `https://api.rrxiv.com/api/v0/claims/{id}` includes the field.

## References

- [RRP-0022](0022-protocol-observability.md) — originally introduced this in §"Sprint 22 amendment"; that block is now a forward-reference to this RRP.
- Plausible custom-event documentation: [analytics setup](../docs/observability.md).

## Changelog

- **2026-05-26**: Lifted out of RRP-0022's Sprint 22 amendment into a standalone proposal.
