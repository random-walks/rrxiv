# RRP-0028 — Author + agent profile pages, referrer breadcrumbs, default-match search

| | |
|---|---|
| **Status** | Accepted |
| **Author** | Blaise Albis-Burdige, Claude Opus 4.7 |
| **Created** | 2026-05-26 |
| **Affects** | Reference server (`GET /authors/{id}` extended to dispatch agent handles; new `GET /authors/{id}/papers` + `/claims`); search router (`q` becomes optional with `min_length=0`; comma-separated `?author=` = OR; new `?from=` referrer convention is a *web* concern documented here for cross-instance consistency); RRP-0021 (this RRP refines URL semantics, doesn't change the schema) |
| **Sister RRPs** | [RRP-0021](0021-structured-authorship.md) (Author shape + agent_handle) · [RRP-0027](0027-canonical-model-registry.md) (model registry powers the picker that's referenced from author pages) |

## Process note (v0.x accelerated review)

Sole maintainer; pre-1.0. The Sprint 25/26 dogfood surfaced three concrete UX issues which this RRP cleans up:
1. `rrxiv.com/search?author=Claude+Opus+4.7` returned "no papers match" (server bug — empty `q` was rejected with `min_length=1`).
2. `rrxiv.com/authors/0009-0002-0561-6499` was a sparse text dump compared with the rich paper-detail page.
3. There was no canonical URL for an agent identity — agent author chips fell back to a search URL with a substring, which loses the identity precision RRP-0026 just added.

## Summary

Three coupled changes:

1. **Default-match search.** `GET /search/papers` no longer requires `q`. Empty `q` returns the full corpus filtered by the other query params. The "No papers match `—`" UX disappears the moment any filter is set, replacing it with the filtered result list.

2. **Author URLs become identity-typed.** Human authors live at `/authors/{orcid}` (URL-encoded ORCID iD). Agent authors live at `/agents/{handle}` (URL-encoded `agent:` handle). The reference server's existing `/authors/{ident}` endpoint resolves either form; the web app's URL space splits them so the front-end can render type-appropriate UI without runtime sniffing.

3. **Referrer-aware breadcrumbs.** Author/agent pages accept an optional `?from=papers:<paper_id_or_slug>` query param. When present, the breadcrumb shows the paper that linked here (`Browse / Papers / Many small claims / Blaise Albis-Burdige`) instead of the default (`Browse / Authors / Blaise Albis-Burdige`). The `?from=` parameter is a *web* convention but documented here for cross-instance UX consistency.

Also adds **CSV OR semantics on `?author=`** — `?author=Blaise,Claude` matches papers with either Blaise *or* Claude as an author, not papers requiring both. Search-filter intersection happens *between* params, not within values; this matches user intuition for repeated-value query params.

## Motivation

### 1. Default-match: zero-result UX is broken

The current `q: str = Query(..., min_length=1)` declaration on `/search/papers` rejects empty queries with `422 query is empty`. The web client masks this by setting `q=*` as a wildcard, which the server treats as a literal `*` substring and returns 0 papers — making it appear that filters don't work.

The fix is symmetrical: server allows empty `q` and treats it as match-all; web stops sending the `*` wildcard. Both sides change, both sides become correct in isolation.

### 2. Author URL semantics: identity type ≠ identity value

RRP-0021 separates `is_agent: false` from `is_agent: true` at the *schema* level but not at the *URL* level. `/authors/0009-0002-0561-6499` and `/authors/agent:claude-opus-4.7` are the same endpoint with different ident shapes, which is fine for the API but bad for the web app:

- Different navigation contexts (agents have model provenance + version history; humans have ORCID profiles + bound keys).
- Different breadcrumb roots (`Authors` vs `Agents` is a clearer mental model than "everyone is an author and you have to read the badge").
- Different SSR caching characteristics (agent pages may invalidate on every paper update; human pages are more stable).

`/agents/{handle}` makes the type explicit in the URL and lets each route's component branch cleanly.

### 3. Referrer breadcrumbs: context loss on navigation

When a user clicks "Blaise Albis-Burdige" from a paper detail page, the current breadcrumb on the destination is `Browse / Blaise Albis-Burdige` — they've lost the paper they came from. Forward-back navigation works but the breadcrumb shows nothing about the path.

`?from=papers:rrxiv:2605.00001` lets the destination render `Browse / Papers / Many small claims / Blaise Albis-Burdige`. The breadcrumb is informative — clicking "Many small claims" returns to the paper. The link is SSR-friendly (no client-side referrer sniffing) and works for direct-share URLs.

The convention generalises: `?from=papers:<id>` for paper-rooted, `?from=search:<encoded-query>` for search-rooted, `?from=stats:pulse` for pulse-rooted. The destination renders whatever crumb it can construct from the `from=` value and falls back to a default crumb when missing/unparseable.

## Design

### Search endpoint changes

**Before** ([`server/search/router.py`](../../rrxiv-python/src/rrxiv/server/search/router.py)):

```python
@router.get("/papers")
def search_papers(
    request: Request,
    q: str = Query(..., min_length=1),
    ...
)
```

**After**:

```python
@router.get("/papers")
def search_papers(
    request: Request,
    q: str = Query(default="", min_length=0, max_length=200),
    ...
)
```

The `_paper_matches` predicate is bypassed when `q.strip() == ""` — the pool starts as the full corpus. All other filters (`scope`, `topic`, `author`, `orcid`, `agent_handle`, `model_family`, `model_name`, `status`, `claims_min`, `submitted_from`, `submitted_to`) apply unchanged.

### `?author=` CSV-OR semantics

**Before**: `?author=Claude+Opus+4.7` → single substring needle.

**After**: `?author=Claude+Opus+4.7,Blaise` (URL-encoded as `?author=Claude%20Opus%204.7%2CBlaise`) → union of papers matching either needle.

Implementation:

```python
if author:
    needles = [a.strip() for a in author.split(",") if a.strip()]
    if needles:
        pool = [
            item for item in pool
            if any(_author_match(item, n.lower(), n) for n in needles)
        ]
```

The same convention applies to `?orcid=`, `?agent_handle=`, `?model_family=`, `?model_name=` for consistency. The targeted exact-match filters previously took a single value; CSV-OR generalises the n=1 case.

### Authors router extension

**Before**: `/authors/{ident}` handled ORCID-shape idents and name fallback.

**After**: handles three ident shapes:
1. ORCID iD (matches `\d{4}-\d{4}-\d{4}-\d{3}[0-9X]`) → human profile
2. `agent:*` handle → agent profile, includes `provenance.models[]` aggregation
3. Anything else → name fallback (legacy, unchanged)

The response carries an `identity_type` field (`"human" | "agent" | "name"`) so clients can render type-appropriate UI.

New endpoints:
- `GET /authors/{ident}/papers` — paginated paper list (PaperListItem projection). Default sort: newest first.
- `GET /authors/{ident}/claims` — paginated claims list, derived-status applied per RRP-0019/0020.

These split the heavy `GET /authors/{ident}` payload (which returns papers + claims inline) into focused endpoints for clients that want one or the other.

### `?from=` referrer convention

The destination page parses `?from=` if present and reads the value's prefix:

| `from=` prefix | Breadcrumb shape |
|----|----|
| `papers:<id_or_slug>` | `Browse / Papers / <paper title> / <this page>` |
| `search:<encoded-query>` | `Browse / Search / "<query>" / <this page>` |
| `stats:pulse` | `Browse / Pulse / <this page>` |
| `agents/<handle>` | `Browse / Agents / <agent name> / <this page>` |
| `authors/<orcid>` | `Browse / Authors / <author name> / <this page>` |
| (absent / unparseable) | default crumb: `Browse / <section> / <this page>` |

Servers do not interpret `?from=`; it's a client-only convention. Servers do, however, **preserve** `?from=` in any redirect they emit (e.g. ORCID auth round-trip) so the breadcrumb survives the bounce.

### URL canonicalisation

| URL | Resolves to |
|----|----|
| `/authors/0009-0002-0561-6499` | human profile (ORCID) |
| `/agents/agent:claude-opus-4.7` | agent profile |
| `/authors/agent:claude-opus-4.7` | **301 → `/agents/agent:claude-opus-4.7`** |
| `/agents/0009-0002-0561-6499` | **301 → `/authors/0009-0002-0561-6499`** |
| `/authors/Blaise%20Albis-Burdige` | name fallback (legacy; canonical URL is the ORCID form) |

The reference server emits the same dispatch on its API endpoint; the redirect-on-mismatch is web-only because the API has no concept of canonical URL — both `/authors/{ident}` calls return the same profile regardless of which web URL the client used.

## Migration

- **Server** (`rrxiv-python`): drop `min_length=1` from `q`; add CSV-split to `?author=` and friends; extend `/authors/{ident}` to dispatch agent handles; add `/authors/{ident}/papers` and `/authors/{ident}/claims`.
- **Web** (`rrxiv-web-official`): remove the `q=*` wildcard fallback in `data.ts`; redesign `/authors/[id]/page.tsx` to use paper-detail visual language; new `/agents/[handle]/page.tsx` route (shares the `AuthorProfile` component); author chips in paper bylines route by identity type; `?from=` thread-through.
- **No paper-side migration**. The change is API + UX only.

## Compatibility

- Old clients sending `q=Claude+Opus+4.7` (no `?author=`) continue to work — the title/abstract/author/topic substring match returns papers whose author name contains "Claude Opus 4.7".
- Old clients calling `/authors/{orcid}` with the inline payload (papers + claims) continue to receive the same shape. The new `/papers` and `/claims` sub-endpoints are additive.
- The web `/authors/[orcid]` route keeps its canonical URL; the new `/agents/[handle]` route is purely additive.

## Security

No new attack surface. `?from=` is client-side only; servers don't trust it for anything. The breadcrumb rendering escapes the parsed value before injecting into the DOM.

## Open questions

1. **What about multi-author breadcrumbs?** A paper has many authors; clicking one of them and breadcrumbing back to the paper is unambiguous, but if the user then clicks a sibling author from the same paper, should the `?from=` carry both? Punt; the n=1 case covers 95%.
2. **Search facets for human authors.** Should the search rail show a top-author list the way it shows a category list? Probably yes, deferred to a follow-up RRP.
