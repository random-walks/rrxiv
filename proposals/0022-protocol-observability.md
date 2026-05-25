# RRP-0022 — Protocol observability + community pulse

| | |
|---|---|
| **Status** | Accepted |
| **Author** | Blaise Albis-Burdige, Claude |
| **Created** | 2026-05-25 |
| **Affects** | new endpoint `GET /api/v0/stats/pulse`; new schema [`schema/pulse_snapshot.schema.json`](../schema/pulse_snapshot.schema.json); operational `/metrics` (non-protocol) recommended for instances |
| **Sister RRPs** | [RRP-0008](0008-reference-server.md) (reference-server shape), [RRP-0012](0012-paper-list-item-projection.md) (projection patterns) |

## Process note (v0.x accelerated review)

Sole maintainer; pre-1.0; one-PR review cycle. The deviation from a v1.0 RFC process is intentional and bounded — see [`CONTRIBUTING.md#process-note`](../CONTRIBUTING.md). Sprint 20–21 shipped the implementation; this RRP codifies the wire format and self-exclusion semantics so third-party rrxiv instances can implement the same surface and the results stay comparable.

## Summary

Add a single canonical KPI endpoint to the protocol surface — `GET /api/v0/stats/pulse?window={7d|30d|90d|all}` — that returns a `PulseSnapshot` JSON object covering three time horizons:

1. **`pulse`** — activity in the chosen window: distinct human + agent writers, submissions, revisions, annotation breakdown, replications + retractions posted.
2. **`health`** — full-corpus rates: replication coverage, partial-replication rate, contradiction rate, third-party annotation rate, agent participation rate, reproduction-kind breakdown.
3. **`growth`** — lifetime aggregates: unique identities ever, papers with third-party engagement, claim-graph density, cross-paper extends count.

Plus leaderboards: top 5 most-annotated papers, top 5 claims by replication count, top 5 topics by paper count.

Self-exclusion via the operator-controlled `ServerSettings.exclude_identities` list: writes attributed to listed ORCID iDs / agent handles are dropped from the activity aggregates. Maintainers add their own identities here so the public pulse reflects *real* community participation, not their own dogfooding.

The `PulseSnapshot` shape is codified in [`schema/pulse_snapshot.schema.json`](../schema/pulse_snapshot.schema.json) — every rrxiv instance MUST emit the documented fields with the documented types so cross-instance comparisons are sound.

## Motivation

Sprint 20 audit surfaced three independent gaps:

1. **The maintainer can't see real users.** Plausible was anonymous-by-design with zero custom events; Sentry's only signal was un-attributed stack traces. There was no way to answer "how many ORCIDs annotated this week?" without grep-fu on the SQLite store.
2. **Maintainer dogfood polluted whatever signal did exist.** Every paper submitted, every annotation posted, every page view came from one ORCID. The dashboard was 100% noise.
3. **Federation pressure.** Once a second rrxiv instance exists — a university hosting a topic-specific shard, or someone running a private instance behind a paywall — the question "how does our instance compare?" needs comparable numbers. Without a documented contract, every instance would emit its own ad-hoc dashboard and the field-level aggregates wouldn't roll up.

A public KPI endpoint solves all three. It's the operator's debugging surface, the federation's comparability layer, and the community's trust signal (anyone can verify "this protocol is being used by N humans + M agents this week") in one shape.

## Design

### Endpoint contract

```
GET /api/v0/stats/pulse[?window={7d|30d|90d|all}]
```

- Public read, no auth.
- Default `window=7d`.
- Response body validates against `pulse_snapshot.schema.json`.
- `Cache-Control: max-age=60` is RECOMMENDED; reference implementation caches in-process for 60s with a key that includes corpus size so a fresh submission invalidates immediately.
- 200 only — there is no failure mode that should leak; empty corpora return zero-filled aggregates.

### Self-exclusion semantics

The reference implementation reads `ServerSettings.exclude_identities` (a tuple of strings, env: `RRXIV_EXCLUDE_IDENTITIES` as comma-separated) and drops records where `created_by.identity` matches one of the listed values from:

- `pulse.distinct_human_authors` / `distinct_agent_authors`
- `pulse.submissions_count` / `revisions_count`
- `pulse.annotations_by_type` / `annotations_total` / `replications_posted` / `retractions_posted`
- `growth.unique_human_identities_ever` / `unique_agent_identities_ever`

It does NOT drop them from `health.*` (which are full-corpus rates — excluding maintainer claims would distort the replication coverage ratio) or from the leaderboards (which surface top-N papers; excluding the maintainer's own widely-read paper would obscure a real engagement signal).

Operators MUST document their exclusion list out-of-band (e.g. in the instance's README) so consumers know whose writes were filtered. Cross-instance comparisons should mention each instance's exclusion policy as a caveat.

### Bounded cardinality

Every label in the snapshot is bounded:

- `annotations_by_type` keys are the closed enum of annotation_type values (12 today: comment, replication, contradiction, erratum, extension, summary, code_link, dataset_link, claim_extraction, revision_summary, claim_retraction, paper_retraction).
- `reproduction_kind_breakdown` keys are the closed enum (`fresh_replication`, `reproduction_from_artifacts`).
- `top_papers_by_annotations` / `top_claims_by_replications` are capped at 5 entries.
- `top_topics` is capped at 5 entries.

No free-text fields, no unbounded ID lists. Snapshots are bounded ≈ 4–8 KB regardless of corpus size.

### What's intentionally NOT in the pulse

- **Per-IP-address counts.** Plausible handles anonymous pageviews; the pulse is about authored writes.
- **Geographic breakdowns.** Conflicts with the protocol's privacy posture (ORCIDs are global; geo would be misleading anyway).
- **Median time-to-first-annotation.** Useful but harder to compute over partial windows. Deferred to a future RRP.
- **Per-paper view counts.** Would require either pageview cookies (privacy regression) or a server-side counter table (RRP-future). The leaderboards expose engagement via *annotation count*, which is the structurally meaningful signal anyway.

## Implementation reference

The canonical instance (`api.rrxiv.com`) implements this RRP in rrxiv-python:

- [`src/rrxiv/server/stats/pulse.py`](https://github.com/random-walks/rrxiv-python/blob/main/src/rrxiv/server/stats/pulse.py) — pure `compute_pulse(store, window, *, exclude_identities)` function.
- [`src/rrxiv/server/stats/cache.py`](https://github.com/random-walks/rrxiv-python/blob/main/src/rrxiv/server/stats/cache.py) — 60s wall-clock TTL.
- [`src/rrxiv/server/stats/router.py`](https://github.com/random-walks/rrxiv-python/blob/main/src/rrxiv/server/stats/router.py) — mounts `GET /stats/pulse`.

The web dashboard at [`rrxiv.com/pulse`](https://rrxiv.com/pulse) is one consumer of this endpoint, but the protocol-level intent is that *anyone* — third-party dashboards, federation aggregators, the maintainer's local CLI — can hit `/api/v0/stats/pulse` and get the same shape.

## Operational metrics (RECOMMENDED but non-protocol)

Beyond `/api/v0/stats/pulse`, the reference implementation also exposes a Prometheus exposition endpoint at `/metrics` (no `/api/v0` prefix) with counters for `http_requests_total`, `annotations_posted_total`, `submissions_total`, `rate_limit_429_total`, plus a `pulse_compute_seconds` histogram. **These are operational, not protocol.** Third-party instances MAY expose `/metrics` in the same format (so Fly / Prometheus / Grafana stacks "just work") but it's not part of the conformance test.

The protocol-level wire is the JSON `/stats/pulse` endpoint; the binary `/metrics` endpoint is a hosting-stack convenience.

## Versioning

The `PulseSnapshot` shape is **additive-only** during v0.x. New fields MAY appear; existing fields MUST keep their shapes. The schema's `additionalProperties: true` lets servers ship richer aggregates ahead of clients.

A v1.0 stabilization RRP will close the schema (additionalProperties: false) once the field set is settled.

## Test plan

- Add `tests/test_stats_pulse.py` to the conformance suite — covers empty store, distinct writer counts, exclude-list behavior, replication-coverage math, third-party-rate, agent-participation-rate, reproduction-kind breakdown, leaderboards, revisions count, growth metrics, cache behavior. (Already shipped in rrxiv-python#60.)
- `pulse_snapshot.schema.json` validates the live response from `api.rrxiv.com` (round-trip).

## Sprint 22 amendment — per-claim view counter + cohort groundwork

Sprint 22 lands two additive expansions to this RRP:

### Per-claim view counter

- New optional `views_count` field on the [`claim.schema.json`](../schema/claim.schema.json) read response. Server-stamped only; submitters MUST NOT populate it (validators don't enforce, but the counter is reset on `clear_corpus`).
- Counter is bumped on every successful `GET /api/v0/claims/{id}`. Failures bumping the counter MUST NOT fail the read.
- New `leaderboards.top_claims_by_views` field on `PulseSnapshot`. Capped at 5; distinct signal from `top_claims_by_replications` (discovery engagement vs. contributed engagement).
- The counter is intentionally *server-side*, not derived from Plausible. Plausible records anonymous pageviews (the `claim.viewed` custom event from Sprint 20); the server-side counter is the authoritative number for downstream consumers including the federation aggregator (when it exists). Two surfaces, two purposes.
- Operators who want to dampen the counter for excluded identities MAY pass an `auth_kind != "orcid"` filter before bumping; the reference implementation counts all reads unconditionally, on the theory that excluded *writes* matter but excluded *reads* don't bias the leaderboard meaningfully at v0.1 scale.

### Cohort groundwork

Pure derivation from `created_at` + `created_by` on existing papers + annotations. No new tables, no migration. New `cohorts` block on `PulseSnapshot`:

- `first_write_by_iso_week`: map of ISO-week key (`YYYY-Www`) → count of identities whose earliest paper/annotation falls in that week. Self-exclusion applied. Empty weeks omitted.
- `weekly_active_humans` / `weekly_active_agents`: list of `{iso_week, distinct_identities}` for the last ~8 ISO weeks (inclusive of the current one). Sorted oldest-first.

These seed retention curves ("did the ORCIDs that wrote in week N also write in week N+4?") without committing to a time-series store. The full RRP-FUTURE for cohort retention will codify a `/stats/pulse/retention?from=YYYY-Www` endpoint once we have ≥6 weeks of real activity.

## Out of scope (deferred)

- `/stats/pulse/history` returning daily snapshots (storage cost; RRP-future once federation matters).
- Cross-instance federation aggregator (Sprint 22+ once a second instance exists).
- Full retention/cohort analysis with N+K week buckets (deferred until ≥6 weeks of real-user data).
