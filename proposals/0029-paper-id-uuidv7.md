# RRP-0029 — Paper identifier model: machine `id` (UUIDv7, opaque) + citable `id_slug`

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-30
- **Last updated:** 2026-05-30
- **Affects:** schemas / spec docs / API / instance data
- **Supersedes:** none (complements [RRP-0013](0013-id-slug.md))
- **Superseded by:** none

## Summary

Resolve the long-standing "Format TBD" on paper `id` by ratifying what [RRP-0013](0013-id-slug.md) and [`spec/0005-submission.md`](../spec/0005-submission.md) already assert — the machine `id` is a **server-minted UUIDv7 ([RFC 9562](https://www.rfc-editor.org/rfc/rfc9562)), opaque to clients** — and correct the v0.1 reference implementation and canonical-instance data, both of which had drifted off it. Tighten the schemas so every paper-id-bearing field is a consistent **opaque string**, removing two stray `format: uuid` annotations that contradicted the opaque-id model and RRP-0013's dual-resolution rule. The citable `id_slug` (`rrxiv:YYMM.NNNNN`) is unchanged.

## Motivation

The protocol already decided this — twice — but the implementation and the live data never honoured it, and a third "decision" leaked into the data:

- **Schema:** `paper.id` / `cir.id` say *"Format TBD; for v0 use UUIDv7"* — but RRP-0013 §Alternatives ("Use the slug as the canonical `id`" → **rejected**) and `spec/0005` §ID-assignment ("v0.1 uses **UUIDv7** … Until that RRP, UUIDv7 is the canonical format") already settled it. The "TBD" is stale.
- **Reference server:** `_mint_paper_id()` returns `paper-{uuid4().hex[:12]}` — a 48-bit **v4 truncation**, not the time-ordered 128-bit UUIDv7 the spec mandates.
- **Canonical instance (observed 2026-05-30):** the 9 seeded papers store a **slug-shaped string as `id`** (`rrxiv:2605.0000N`, plus one repo-name `rrxiv-paper-euclid-elements`), and their `id_slug` is a *different, scrambled* slug — the on-ingest slug minter assigned slugs in seed-ingest order, so the flagship whitepaper is served at `id_slug = rrxiv:2605.00008` instead of `…00001`.

So three id shapes coexist across the repos (UUIDv7, `paper-<hex>`, slug, repo-name) and "nothing agrees." Concrete harm:

- **Claim graph stability.** Claim ids are citable and slug-based — `<id_slug>:<local_label>` (e.g. `rrxiv:2605.00002:claim:c1`) — and are authored client-side, since the machine `id` doesn't exist until submission. Cross-paper edges therefore reference *slugs*, which this RRP preserves; re-minting the machine `id` leaves the claim graph fully wired with no edge rewriting. Keying claims off the stable citable id (not the volatile machine id) is the point.
- **Latent endpoint break.** `revision_diff.VersionRef.paper_id` is declared `format: uuid`, which `datamodel-code-generator` renders as a Python `UUID`. The live slug-shaped ids are **not** valid UUIDs, so the diff response cannot be constructed for the current corpus (masked only by `revisions_count: 0`).
- **Federation.** A per-instance slug cannot be the global graph anchor (RRP-0013 §Federation ambiguity). The claim graph needs the opaque, globally-unique `id`.

## Design

### Ratified identifier model

| field | format | role |
|---|---|---|
| **`id`** | server-minted **UUIDv7** (RFC 9562) | The canonical machine identifier and claim-graph anchor (`<id>:<local_label>`). **Opaque to clients** — clients MUST NOT parse, derive, or construct it. Time-ordered, 128-bit, globally unique. Once assigned, NEVER changes. |
| **`id_slug`** | `rrxiv:YYMM.NNNNN` | The human-facing, citable identifier (URLs, citations). Server-minted, per-instance. Unchanged from RRP-0013. |

This restates `spec/0005` and RRP-0013; it introduces no new policy. The new normative bit is the explicit **opaque-to-clients** rule for `id`, and the schema-level consistency below.

### Claim ids (citable, slug-based)

A claim's `id` is `<id_slug>:<local_label>` (e.g. `rrxiv:2605.00002:claim:c1`), and `claim.paper_id` is the owning paper's `id_slug`. Claim ids are built **client-side at authoring time**, before any machine `id` exists, so they key off the stable, human-citable slug — consistent with claims being first-class *citable* artifacts. Cross-paper edges (`depends_on`/`supports`/`contradicts`/`extends`) reference slug-based claim ids; because slugs are preserved by the migration below, the entire cross-paper claim graph survives re-minting with **no edge rewriting**. Globally-unique (instance-qualified) claim ids for cross-instance federation are deferred to the v1.0 federation RRP, consistent with RRP-0013 §Federation.

### Schema changes (every paper-id field is an opaque string)

The fields that hold a paper machine id — `paper.id`, `cir.id`, `paper.previous_version`, `cir.previous_version`, `submission_request.previous_version`, `revision_diff.$defs.VersionRef.paper_id`, `claim.paper_id`, `citation.target_paper_id` — are all typed `"type": "string"` (nullable where they already were), described as the opaque server-assigned UUIDv7.

We **remove** the `format: uuid` annotation from `submission_request.previous_version` and `revision_diff.VersionRef.paper_id` because it:

1. contradicts the opaque-id model (the id's *shape* is a server-production rule, not a wire-validation rule — clients never mint ids);
2. breaks RRP-0013 dual-resolution — a `previous_version` may legitimately be supplied as an `id_slug`, which `format: uuid` would reject; and
3. couples the wire contract (and the generated `UUID`-typed models) to a format that `spec/0005` explicitly says *may evolve via RRP* (content-hash / DOI candidates).

The UUIDv7 **production** requirement lives where it belongs: the spec, this RRP, and the server's minting code. The `id_slug` `pattern` is retained (it is a genuine, stable wire format that clients *do* construct into URLs).

### Reference-server fixes (rrxiv-python)

- `_mint_paper_id()` mints a real UUIDv7.
- Seed/ingest carries the CIR's `id_slug` verbatim rather than re-minting it in ingest order (the cause of the live scramble). A CIR that genuinely lacks a slug still gets one minted, per RRP-0013.

### Canonical-instance migration (rrxiv-instance)

The instance has **no third-party data** (observed: `annotations_total: 0`, `revisions_count: 0`, one human + one agent identity, both the maintainer; all 656 claims are seed-derived). A wipe-and-reseed is therefore both safe and maximally correct:

1. Snapshot the live Fly DB.
2. Regenerate the seed CIRs so each carries a fresh **UUIDv7 `id`** and its **correct canonical `id_slug`**.
3. Reseed with `--reset`.

Canonical slug assignment (de-scrambled, de-collided):

| slug | paper |
|---|---|
| `rrxiv:2605.00001` | whitepaper |
| `rrxiv:2605.00002` | claim-graph-first-class |
| `rrxiv:2605.00003` | reproducibility-budgets |
| `rrxiv:2605.00004` | shrinkage-estimators |
| `rrxiv:2605.00005` | agents-as-editors |
| `rrxiv:2605.00006` | citation-vs-knowledge-graphs |
| `rrxiv:2605.00007` | retraction-as-data |
| `rrxiv:2605.00008` | active-replication |
| `rrxiv:2605.00009` | euclid-elements *(was colliding at `…00005`)* |

The citable ids (slugs) are **preserved and corrected**; only the internal machine `id` changes, and nothing external references it.

## Alternatives considered

- **Collapse to a slug-only id.** Already rejected in RRP-0013 §Alternatives (federation collisions, graph-reference opacity, 100k/month overflow). RRP-0029 adds the claim-id colon-ambiguity argument. Rejected.
- **Keep `paper-<12hex>`.** 48 bits is not future-proof at federation scale (birthday collision ≈ 16M papers), it is not time-ordered (`spec/0005` wants lexical ordering), and it needs a fresh spec. UUIDv7 is already canonical. Rejected.
- **Go fully strict: add `format: uuid` everywhere + UUID-typed models.** Couples the wire contract and generated models to a format the spec says may evolve, breaks RRP-0013 dual-resolution on `previous_version`, and cascades a `UUID`-typing refactor (store keys, claim-id construction) through the server. Opaque-string modeling is more forward-compatible. Rejected.
- **Grandfather the live ids (fix only going forward).** Leaves the corpus permanently split across id shapes — the exact "mucked up" state this RRP removes. Cheap to avoid pre-launch. Rejected.

## Drawbacks

- A one-time wipe-and-reseed of the canonical instance. Acceptable: no third-party data; snapshot taken first.
- Two identifiers per paper (already true under RRP-0013; documented).
- A JSON-Schema-only consumer no longer learns the UUID shape *from the schema* — it is in the spec, this RRP, and the field descriptions instead. Acceptable for an opaque, server-minted id.

## Impact on existing code and content

| Surface | Change | Bump |
|---|---|---|
| `schema/paper.schema.json` | `id` + `previous_version` descriptions resolved to UUIDv7-opaque | 0.2.0 → 0.2.1 |
| `schema/cir.schema.json` | same | 0.2.0 → 0.2.1 |
| `schema/submission_request.schema.json` | remove `format: uuid` on `previous_version` | 0.1.0 → 0.2.0 |
| `schema/revision_diff.schema.json` | remove `format: uuid` on `VersionRef.paper_id` | 0.1.0 → 0.2.0 |
| `schema/claim.schema.json` | `id` + `paper_id` documented as citable slug-based; examples updated | 0.2.0 → 0.2.2 |
| `schema/citation.schema.json` | `target_paper_id` description clarified | 0.1.0 → 0.1.1 |
| `spec/0005-submission.md` | cite RRP-0029; add the opaque-to-clients rule | — |
| `spec/0002-cir.md` | reference the dual-identifier model | — |
| `rrxiv-python` | real UUIDv7 mint; ingest carries slug; re-vendor schemas; regen models (`VersionRef.paper_id` `UUID`→`str`); tests | — |
| `rrxiv-instance` | regenerate seed (UUIDv7 + canonical slugs); snapshot; reseed `--reset` | — |
| `rrxiv-web-official` | re-vendor `protocol-types`; fix fixture ids | — |
| 9 paper repos | reconcile `rrxiv-meta.json` (canonical slug; lineage drift) | — |
| Existing CIRs | reseeded; no in-place migration script needed | — |

## Open questions

- **Federation instance-hint for slugs.** Deferred to the v1.0 federation RRP, per RRP-0013 §Federation ambiguity.
- **Formal claim-id grammar.** `spec/0002` open question. A UUID paper-id makes the `<paper_id>:<label>` split unambiguous (single colon after a colon-free UUID); a formal grammar can be specified in a later RRP.

## Reference implementation

Landed together (merge order: schema → python → instance → web → paper repos):

- `rrxiv` — this RRP + the schema/spec changes.
- `rrxiv-python` — UUIDv7 mint + ingest-slug fix + re-vendored schemas + regen models + tests.
- `rrxiv-instance` — regenerated seed + reseed.
- `rrxiv-web-official` — re-vendored `protocol-types` + fixtures.

## References

- [RRP-0013 — Human-friendly paper slugs (`id_slug`)](0013-id-slug.md)
- [`spec/0005-submission.md`](../spec/0005-submission.md) §ID assignment
- [`spec/0002-cir.md`](../spec/0002-cir.md)
- [RFC 9562 — Universally Unique IDentifiers (UUIDs)](https://www.rfc-editor.org/rfc/rfc9562)

## Process note

Per the RRP-0013 / RRP-0024 precedent: v0.x accelerated review. This RRP is corrective (it aligns code and data with two already-Accepted decisions) and pre-launch, so it merges with `Status: Accepted` without the 14-day Discussion window. Standard process resumes for v1.0+.

## Changelog

- **2026-05-30**: Created. Status: Accepted under v0.x accelerated review. Drafted with AI assistance (Claude) per the project's AI-collaboration honesty norm.
