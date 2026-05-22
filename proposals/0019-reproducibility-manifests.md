# RRP-0019 — Reproducibility manifests

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-22
- **Last updated:** 2026-05-22
- **Affects:** schemas / spec / server / clients
- **Supersedes:** none
- **Superseded by:** none

## Process

Self-merged under the v0.x accelerated review policy. The replication-vs-reproduction distinction is a working terminology in empirical research (see e.g. NASEM 2019, "Reproducibility and Replicability in Science") and the field-of-study quorum rules are an explicit design choice we are making *for this protocol* — different sciences have different evidence-base norms, and we are picking one. Expect a future RRP to make per-discipline quorum policies a per-instance configuration.

## Summary

Refine the `replication` annotation type so the protocol distinguishes *replication* (independent fresh attempt) from *reproduction* (re-running the original author's code/data on the same or different inputs). Add a structured `reproduction_kind` field to the payload, an optional pointer to a reproducibility manifest (data + code + environment), and a server-side aggregation rule that promotes a claim's `replication_status` to `replicated` only after a configurable quorum of independent replications. Together these turn `replication_status` from a self-reported metadata field into a server-derived signal that means something.

## Motivation

The existing `replication` annotation has a single shape:

```jsonc
{
  "annotation_type": "replication",
  "structured_payload": {
    "outcome": "supports|contradicts|partial|inconclusive",
    "method": "string",
    "n": 0,
    "effect_size": 0.0,
    "code_uri": "https://…",
    "data_uri": "https://…"
  }
}
```

Three problems:

1. **Replication and reproduction collapse into one shape.** A reproducer who runs the author's published code on the author's published data is doing something materially different from a replicator who designs an independent experiment from the claim statement and runs it on fresh data. Both are valuable; treating them identically muddies signal.
2. **`replication_status` on `claim.schema.json` is opaque.** It's an enum (`untested | partial | replicated | contradicted | retracted`) but the protocol doesn't say *who* sets it. In practice today, the parser sets it from the source `.tex` (authors flag it); the server doesn't recompute. So a claim flagged `replicated` by its own author conveys no independent signal.
3. **No standard for "what makes a reproduction count?"** A reproduction manifest — bundled code + data + Docker image + run instructions — should be a first-class artefact, but the protocol has no shape for it. Authors who go to the trouble of writing one get no protocol-level credit.

The web client's paper list-item projection (RRP-0012) aggregates annotation counts but inherits the muddied signal. A `replicated` paper today may have one self-attestation; that should not show up next to a paper with five independent replications.

## Design

### Five changes

1. Extend `replication` payload with `reproduction_kind: "fresh_replication" | "reproduction_from_artifacts"`.
2. Add optional `reproducibility_manifest_uri` and `reproducibility_manifest_hash` to the payload (for `reproduction_from_artifacts` runs).
3. Add server-side aggregation rule: `claim.replication_status` is **derived** from annotations, not stored alongside the claim.
4. Define the per-discipline quorum rule (with sensible defaults; instance-overridable).
5. Add an optional `reproducibility_manifest` field to `claim.schema.json` so paper authors can publish their own manifest as part of the original submission.

### `replication` payload refinement

```jsonc
{
  "annotation_type": "replication",
  "paper_id": "<target_paper_id>",
  "claim_id": "<target_claim_id>",
  "structured_payload": {
    "outcome": "supports|contradicts|partial|inconclusive",
    "reproduction_kind": "fresh_replication|reproduction_from_artifacts",
    "method": "Plaintext description of methodology",
    "n": 100,
    "effect_size": 0.42,
    "confidence_interval": [0.31, 0.53],
    "code_uri": "https://github.com/…",
    "data_uri": "https://huggingface.co/datasets/…",
    "reproducibility_manifest_uri": "https://…/manifest.json",
    "reproducibility_manifest_hash": "sha256:abcd…",
    "discipline_tags": ["ml", "rl"],
    "notes": "Optional plaintext"
  }
}
```

The `reproduction_kind` discriminator drives the rest:

- **`fresh_replication`**: independent attempt. Replicator designed their own protocol from the claim's statement. `method` is required and substantive; `data_uri` is the replicator's own data. `reproducibility_manifest_*` may be absent.
- **`reproduction_from_artifacts`**: reran the original author's code on the original author's data (possibly with extensions). `code_uri` and `data_uri` point at the original artefacts. `reproducibility_manifest_*` is recommended (otherwise: "what does 'reproduced' mean?" is unanswerable).

`confidence_interval` is new; it's a sibling to `effect_size` for replications that report one.

### Reproducibility manifest

A reproducibility manifest is a small JSON file co-located with the code, describing the runtime environment and how to invoke it:

```jsonc
{
  "$schema": "https://rrxiv.com/schema/reproducibility_manifest.schema.json",
  "version": "1.0",
  "title": "Reproduction manifest for Claim I.47 (Pythagorean theorem)",
  "claim_uri": "https://rrxiv.com/claims/01923…:prop:I.47",
  "environment": {
    "kind": "docker",
    "image": "ghcr.io/example/repro:abc123",
    "digest": "sha256:..."
  },
  "data": {
    "kind": "url",
    "uri": "https://example.com/data.tar.gz",
    "hash": "sha256:..."
  },
  "entrypoint": "python run.py --seed 0",
  "expected_outputs": [
    { "path": "out/result.json", "hash": "sha256:..." }
  ],
  "estimated_runtime_minutes": 12,
  "estimated_cost_usd": 0.04
}
```

`schema/reproducibility_manifest.schema.json` is added to the schemas dir. The manifest is hosted externally (the annotation just links to it), so it doesn't bloat the corpus.

A claim's *original author* can attach a manifest by including `reproducibility_manifest_uri` in the claim's source location during submission (see *Author-attached manifests* below).

### Server-side `replication_status` derivation

Today `claim.replication_status` is stored alongside the claim, set during parsing. This RRP changes it to a **derived** field, computed by the server from annotations:

```python
def derive_replication_status(claim, annotations):
    relevant = [a for a in annotations if a.annotation_type == "replication" and a.claim_id == claim.id]
    independents = [a for a in relevant if a.structured_payload.reproduction_kind == "fresh_replication"]
    reproductions = [a for a in relevant if a.structured_payload.reproduction_kind == "reproduction_from_artifacts"]

    supports = len([a for a in relevant if a.structured_payload.outcome == "supports"])
    contradicts = len([a for a in relevant if a.structured_payload.outcome == "contradicts"])
    partials = len([a for a in relevant if a.structured_payload.outcome == "partial"])
    independent_supports = len([a for a in independents if a.structured_payload.outcome == "supports"])

    if claim.author_retracted:                           # see RRP-0020
        return "retracted"
    if contradicts > 0 and contradicts >= supports:
        return "contradicted"
    if independent_supports >= QUORUM[claim.discipline]:
        return "replicated"
    if supports > 0 or partials > 0:
        return "partial"
    return "untested"
```

`QUORUM` defaults per discipline tag:

| Tag(s) on claim | Default quorum (independent supports needed for `replicated`) |
|---|---|
| `math`, `cs.formal-verification` | 1 |
| `cs.algorithms`, `cs.systems`, `crypto` | 2 |
| `ml`, `cs.nlp`, `cs.cv`, `rl` | 3 |
| `physics.experimental`, `chem.experimental`, `bio.experimental` | 3 |
| `psychology`, `social-sci`, `economics` (incl. RCT) | 5 |
| (no tag / unknown) | 3 |

These numbers reflect empirical-fields conventions; e.g. the replication-crisis literature suggests a single replication is insufficient for behavioural-science claims. Instances may override via configuration.

The claim's discipline tags come from the paper's `topics` field (already in `paper.schema.json`). Claims inherit their paper's topics; the most-specific tag determines the quorum.

### Author-attached manifest on `claim.schema.json`

A paper's author can publish a reproducibility manifest as part of submission by extending the existing `reproducibility` field on `claim.schema.json`:

```jsonc
{
  "claim_id": "01923f8e-…:prop:I.47",
  "statement": "In a right-angled triangle, the square on the hypotenuse equals the sum of the squares on the other sides.",
  "reproducibility": {
    "manifest_uri": "https://github.com/author/paper-code/blob/v1.0/manifests/I.47.json",
    "manifest_hash": "sha256:..."
  }
}
```

The web client's claim page surfaces a "Reproduce this" CTA when a manifest is present, linking to the manifest URI and showing the runtime + cost estimate.

### Conformance obligations

A conformant server:

- Accepts the refined `replication` payload (with `reproduction_kind`).
- Rejects a `replication` annotation that omits `reproduction_kind` with 400 (`code: "missing_reproduction_kind"`).
- Derives `claim.replication_status` from annotations on every claim read.
- Caches derivation per `(claim_id, last_annotation_at)` to keep reads fast.
- Returns `reproducibility.manifest_uri` on claim reads when present.

A conformant client:

- Renders the `reproduction_kind` discriminator (e.g., separate "Replications" and "Reproductions" sub-sections on the discussion UI).
- Surfaces the author manifest CTA when present.
- Trusts the server's `replication_status`; does not recompute client-side.

## Alternatives considered

1. **Split `replication` and `reproduction` into separate annotation types.** Cleaner but creates schema duplication (almost-identical payloads with one different field). The discriminator-in-payload approach is the right amount of distinction.
2. **No per-discipline quorum** (single global threshold). Misses real differences in evidentiary standards across fields. The configuration-overridable default is the right balance.
3. **Make `replication_status` mutable by the annotator** (skip server derivation). Reintroduces the "self-attestation is meaningless" problem. Rejected.
4. **Inline the reproducibility manifest in the annotation payload.** Bloats annotations (manifests can be 5–10 KB with hashes) and makes them harder to update (immutable annotations vs. evolving manifest at the same URI). Linking via URI + hash is cleaner.

## Drawbacks

- **Quorum defaults are opinionated.** Real empirical fields argue endlessly about what's enough; we're picking numbers and moving on. Mitigation: per-instance config knob.
- **`replication_status` is now expensive** to compute. Mitigation: cache per claim, invalidate on annotation insert. The query is bounded by the number of replication annotations on a claim — never more than a few hundred even at scale.
- **The reproducibility manifest schema is the start of a rabbit hole.** Environments are diverse (Docker, conda, Nix, AWS, Modal, Snakemake, …). v0.x supports one shape (`docker` image + URL data + entrypoint command). Mitigation: schema marks `environment.kind` as `string` (open enum) with `docker` as the only recommended value for v0.x.
- **`fresh_replication` vs `reproduction_from_artifacts` is the replicator's claim.** A bad-faith actor could mark a reproduction as a fresh replication to game the quorum. Mitigation: nothing in protocol; this is a social problem. Authors and readers can flag mis-labelled annotations via comments. Moderation comes later.

## Migration

The schema changes are **additive** for the wire format, but the derivation rule for `claim.replication_status` is a behaviour change.

Steps:

1. Add `reproduction_kind` to `replication` payload. Make it required-when-set; servers that receive annotations without it return 400 with a helpful migration message ("add `reproduction_kind`; see RRP-0019").
2. Add `confidence_interval` (optional).
3. Add `reproducibility_manifest_uri` + `reproducibility_manifest_hash` (optional).
4. Add `schema/reproducibility_manifest.schema.json`.
5. Add `reproducibility.manifest_uri` + `manifest_hash` to `schema/claim.schema.json`.
6. Update reference server: derive `replication_status` per the rule above; cache it.
7. Update `paper_list_item.schema.json` projection: `replication_count` becomes `independent_replication_count`; add `reproduction_count` as a sibling.
8. Backfill: existing `replication` annotations get `reproduction_kind = "fresh_replication"` as the default (most are independent in practice; an instance-side migration can hand-curate exceptions).

Existing CIRs with author-set `replication_status` continue to validate, but the server **overrides** the stored value on response. The original value remains in the CIR for audit; the response carries the derived value.

## Open questions

- **Are partial-supports replications "weak" or "strong"?** Today they don't count toward quorum. A partial that says "supports under conditions X, Y" is more informative than no replication. Tentative: keep partial out of the quorum; let UI surface count separately.
- **How does `confidence_interval` interact with `effect_size`?** They're independent fields today; the protocol doesn't enforce that the interval *contains* the point estimate. Defer to a stricter schema if we see misuse.
- **Should the reproducibility manifest be versioned alongside the paper?** A v2 paper's manifest may differ. For now: the manifest URI is per-annotation (replicator) or per-paper-version (author). v2 authors should re-attach an updated manifest URI.
- **Reproducibility ≠ correctness.** A reproduction that succeeds shows the code did what the paper said; it doesn't show the underlying claim is true. This RRP doesn't conflate them. Future tooling may surface "code reproduced" vs. "claim independently supported" as separate badges.

## References

- [`spec/0006-annotations.md`](../spec/0006-annotations.md) — base annotation model
- [`schema/annotation.schema.json`](../schema/annotation.schema.json) — target of the additive change
- [`schema/claim.schema.json`](../schema/claim.schema.json) — `replication_status` field; new `reproducibility` field
- [RRP-0012](0012-paper-list-item-projection.md) — list projection aggregates this RRP refines
- [RRP-0017](0017-revision-flow-and-diff.md) — companion: revision summary annotations document how the corpus changes between versions
- NASEM (2019), [*Reproducibility and Replicability in Science*](https://www.nationalacademies.org/our-work/reproducibility-and-replicability-in-science) — the terminology source.
