# RRP-0014 — Cursor pagination for list endpoints

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-18
- **Last updated:** 2026-05-18
- **Affects:** API / spec docs
- **Supersedes:** none
- **Superseded by:** none

## Summary

All list endpoints (`GET /papers`, `/claims`, `/annotations`, `/search/papers`, `/search/claims`, `/snapshots`, `/papers/{id}/claims`, `/papers/{id}/related`, `/claims/{id}/depends-on`, `/claims/{id}/dependents`) accept an opaque `cursor` query parameter and return an opaque `next_cursor` field in the response envelope. The cursor encodes a keyset position (`(submitted_at, id)` or analogous tuple per resource) as base64url-encoded JSON. Limit/offset pagination is explicitly NOT introduced — the protocol commits to keyset-stable pagination for a federated, growing corpus.

## Motivation

Today every list endpoint returns `{items: [...], next_cursor: null}` and capacities are bounded by an in-process `default_limit` (50–100). For v0.1 corpora (≤10 papers) this is fine, but:

- The UI claims "Page 1 of 18" in `apps/web/app/page.tsx` against fixture data; switching to real data shows "Page 1 of 1" forever.
- Searches that should return 200+ matches silently truncate.
- A user who wants to read the 51st-newest paper has no path to it.
- Once the corpus crosses 100 papers, offset pagination becomes unstable under concurrent inserts (a paper submitted while you're paginating shifts every offset by one).

Keyset (cursor) pagination is stable under concurrent writes, scales without page-counter caching, and is the conventional choice for append-mostly stores (the corpus is append-only by RRP-0001).

## Design

### Wire format

Every list endpoint accepts:

| Param | Type | Description |
|---|---|---|
| `cursor` | string | Opaque token returned in a prior response's `next_cursor`. When absent, list starts from the most-recent edge. |
| `limit` | integer (1–200) | Maximum items in this page. Server may return fewer. Default 50. |

Response envelope:

```jsonc
{
  "items": [/* PaperListItem | Claim | Annotation | … */],
  "next_cursor": "eyJzdWJtaXR0ZWRfYXQiOiIyMDI2LTA1LTE3VDE4OjAwOjAwWiIsImlkIjoiYWJjIn0",
  // Optional, server may include for diagnostics:
  "has_more": true
}
```

`next_cursor` is `null` (or omitted — clients MUST treat both as "no more pages") when the page exhausted the result set.

### Cursor encoding

Cursors are opaque to clients. A v0.1-conformant encoding:

```
cursor = base64url(JSON.stringify(payload))
```

Where `payload` depends on the resource:

| Endpoint | Payload shape | Order |
|---|---|---|
| `GET /papers`, `/search/papers` | `{"submitted_at": ISO-8601, "id": UUID}` | submitted_at DESC, id DESC |
| `GET /claims`, `/search/claims` | `{"paper_id": UUID, "id": string}` | paper_id DESC, id DESC |
| `GET /annotations` | `{"created_at": ISO-8601, "id": UUID}` | created_at DESC, id DESC |
| `GET /papers/{id}/claims` | `{"id": string}` | id ASC (claim ordering is stable within a paper) |
| `GET /papers/{id}/related` | `{"score": float, "id": UUID}` | score DESC, id ASC |
| `GET /claims/{id}/depends-on` etc. | `{"id": string}` | id ASC |
| `GET /snapshots` | `{"version": semver, "created_at": ISO-8601}` | version DESC |

Servers may evolve the payload shape — clients MUST NOT inspect or construct cursors. A future RRP can add encrypted/signed cursors if leakage of internal positions becomes a concern.

### Order is part of the contract

`sort=` parameters (e.g. `/search/papers?sort=replicated`) imply different keyset orders. The cursor's payload encodes whichever keys the sort requires. Servers MUST return cursors compatible with their own sort — a cursor minted under one sort can be rejected (400) when presented under a different sort.

### Cursor errors

A malformed or unrecognised cursor returns 400 `invalid_cursor`:

```jsonc
{
  "error": {
    "code": "invalid_cursor",
    "message": "Cursor could not be decoded or is incompatible with the current sort order.",
    "status": 400
  }
}
```

Clients that receive `invalid_cursor` MUST NOT retry with the same cursor; the conventional recovery is to drop the cursor and restart from the head.

### Total-counts: deliberately omitted

The response envelope intentionally does NOT include `total_count` or `total_pages`. Computing a stable total over a paginated, indexable, append-only corpus requires a full scan per page; on a 10M-paper corpus that's a per-request O(N) read. Clients that need an approximate corpus size SHOULD call `GET /api/v0/stats` once and cache.

Users get "Showing 50 of [N total in corpus, from /stats] — Next →" rather than "Page 3 of 218" — honest framing for an append-only graph.

## Alternatives considered

### Offset pagination (`?page=&limit=`)
Rejected. Unstable under concurrent inserts; clients reading slowly skip or duplicate items.

### Continuation tokens that include the search query
Considered — encode `q`, filters, AND position into the cursor so the server can be stateless. Rejected for v0.1: makes cursors larger and brittle to URL-length limits. Servers can adopt this later by extending the opaque payload.

### Signed cursors (HMAC)
Considered — sign the cursor so the server can detect tampering. Deferred. The cursor's contents are not security-sensitive (it's just a row position) and unsigned base64 is operationally simpler. A future RRP can add signing if a need emerges.

### Range queries (`?from_id=&to_id=`)
Rejected. Range queries leak the ID space and assume the client understands ID ordering, breaking the opaqueness contract.

## Drawbacks

- **Stateful clients.** The cursor must round-trip exactly; clients can't reconstruct it. This is the cost of stable pagination.
- **No "jump to page 5".** Clients can only walk pages sequentially. Acceptable: research browsing is page-by-page, not by page number.
- **Cursor staleness on backfills.** If an old paper's metadata is mutated (unusual; the corpus is append-only) a cursor referencing it stays valid because the keyset doesn't depend on mutable fields.

## Impact on existing code and content

| Surface | Change |
|---|---|
| `schema/api.openapi.yaml` | Document `cursor` and `limit` params + `next_cursor` field on every list endpoint. |
| `rrxiv-python/src/rrxiv/server/pagination.py` | New module with `encode_cursor`/`decode_cursor` and a `paginate(items, cursor, limit, key_fn) -> (page, next_cursor)` helper. |
| `rrxiv-python/src/rrxiv/server/*/router.py` | Each list endpoint accepts `cursor`, `limit` Query params and threads them through the helper. |
| `rrxiv-python/src/rrxiv/server/store/protocol.py` | Optional: store-level keyset helpers. v0.1 reuses `list_*` and slices in the router. |
| `rrxiv-web-official/apps/web/lib/data.ts` | List helpers return `{items, next_cursor}` instead of bare arrays. |
| `rrxiv-web-official/apps/web/lib/api.ts` | `ApiPage<T>` already shaped this way; types just become more honest about `next_cursor` being non-null sometimes. |
| `rrxiv-web-official/apps/web/app/page.tsx` | "Page 1 of 18" replaced with prev/next driven by `next_cursor` + a "Showing 50 of N" line read from `/stats`. |

## Open questions

- **Reverse pagination (Previous page).** v0.1 doesn't support `?cursor_prev=`. Clients reconstruct the previous page by holding their own history. A future RRP can add a `prev_cursor` field if needed.
- **Cursor signing.** Deferred.
- **Cross-instance cursor portability.** A cursor minted on instance A is meaningless on instance B. The dual-identifier model from RRP-0013 already implies this; no extra rule needed.

## Reference implementation

`rrxiv-python` (forthcoming companion PR adding `pagination.py` + threading through all list routers).

## Process note

Per RRP-0012's process note: v0.x accelerated review. Additive (default behaviour without `cursor=` is unchanged: items + `next_cursor`); supports the first public deployment by unblocking honest "Page N" UX. Merging with `Status: Accepted` without the 14-day Discussion window; standard process resumes for v1.0+.

## References

- [`schema/api.openapi.yaml`](../schema/api.openapi.yaml)
- [RRP-0012 — Paper list-item projection](0012-paper-list-item-projection.md)
- [RRP-0013 — Human-friendly paper slugs](0013-id-slug.md)

## Changelog

- **2026-05-18**: Created. Status: Accepted under v0.x accelerated review.
