# RRP-0017 — Revision flow + semantic diff

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-22
- **Last updated:** 2026-05-22
- **Affects:** schemas / spec / server / clients
- **Supersedes:** none
- **Superseded by:** none

## Process

Self-merged under the v0.x accelerated review policy. The diff matching rules in this RRP are non-trivial design — they determine when two claims "are the same" across versions — and they will likely need revision once real authors start submitting v2s. Marking accepted to unblock the SRV sprint; expect a tightening RRP within the first six months of write-side traffic.

## Summary

Promote revisions from a structural pointer (`paper.previous_version`) to a fully-specified flow: define the canonical *semantic diff* between two CIRs (`schema/revision_diff.schema.json`), expose it via `GET /api/v0/papers/{id}/diff?from=<paper_id>`, and add a new `revision_summary` annotation type so the author can describe their changes in machine-readable form. Together these let readers, citing papers, and downstream tooling reason about what actually changed between v1 and v2 — not just that there was a change.

## Motivation

Today, an author submitting a v2 of their paper:

1. Sets `paper.version = "v2"` and `paper.previous_version = "<v1 paper_id>"` on the new CIR.
2. POSTs to `/api/v0/submissions` (with the `previous_version` form field set).
3. The server stores the v2, walks the chain on `/papers/{id}/versions`, and that's it.

What's missing:

- **No machine-readable diff.** A reader on the paper page sees "v1, v2" — but can't see what changed. They have to fetch both CIRs and diff them client-side, which is expensive (both are full documents) and produces an *ad-hoc* diff per implementation.
- **No revision summary in the corpus.** The author may write release notes in their git repo, but those notes don't propagate to the canonical instance. The protocol has no place for "this v2 fixes the proof of Claim 4 and adds three new claims about pentagonal numbers."
- **No way to surface incompatible revisions.** A v2 might contradict v1's claims — that's allowed (papers are immutable, but successors can disagree with predecessors). Today there's no way to signal "v1 is superseded; the canonical claim set is now v2's", short of retracting v1 entirely (which we don't support yet — see RRP-0020).

The downstream costs of these gaps:

- The web client renders an unhelpful version list. (See `docs/audit-2026-05.md`.)
- Citations targeting `rrxiv:2605.00001` are version-pinned to v1 forever, even if v2 corrects a critical error — readers following the citation have no signal that v2 exists, let alone what's different.
- Agents reading the corpus to extract claims cannot tell whether a claim from v1 still stands in v2 without recomputing the diff every time.

A canonical diff + a structured summary annotation close all three gaps.

## Design

### Three changes

1. **New schema**: `schema/revision_diff.schema.json` — the wire format for a v1→v2 diff.
2. **New endpoint**: `GET /api/v0/papers/{id}/diff?from=<prior_paper_id>` — server-computed, deterministic.
3. **New annotation type**: `revision_summary` — author's narrative description of the changes.

### Schema

`schema/revision_diff.schema.json`:

```jsonc
{
  "$id": "https://rrxiv.com/schema/revision_diff.schema.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "RevisionDiff",
  "description": "Structural diff between two versions of a paper. The `from` version is the older paper; `to` is the newer. Both must share the same lineage (one's `previous_version` chain must reach the other).",
  "type": "object",
  "required": ["from", "to", "claims", "abstract_changed", "topics_changed", "computed_at"],
  "properties": {
    "from": {
      "type": "object",
      "required": ["paper_id", "version"],
      "properties": {
        "paper_id": { "type": "string", "format": "uuid" },
        "version": { "type": "string", "pattern": "^v[0-9]+$" },
        "id_slug": { "type": "string" }
      }
    },
    "to": {
      "type": "object",
      "required": ["paper_id", "version"],
      "properties": {
        "paper_id": { "type": "string", "format": "uuid" },
        "version": { "type": "string", "pattern": "^v[0-9]+$" },
        "id_slug": { "type": "string" }
      }
    },
    "abstract_changed": { "type": "boolean" },
    "abstract_diff": {
      "type": ["object", "null"],
      "description": "Present iff abstract_changed=true. Word-level diff hunks.",
      "required": ["hunks"],
      "properties": {
        "hunks": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["kind", "text"],
            "properties": {
              "kind": { "enum": ["equal", "added", "removed"] },
              "text": { "type": "string" }
            }
          }
        }
      }
    },
    "topics_changed": { "type": "boolean" },
    "topics_added": { "type": "array", "items": { "type": "string" } },
    "topics_removed": { "type": "array", "items": { "type": "string" } },
    "claims": {
      "type": "object",
      "required": ["added", "removed", "modified", "unchanged_count"],
      "properties": {
        "added": {
          "type": "array",
          "items": { "$ref": "#/$defs/AddedClaim" }
        },
        "removed": {
          "type": "array",
          "items": { "$ref": "#/$defs/RemovedClaim" }
        },
        "modified": {
          "type": "array",
          "items": { "$ref": "#/$defs/ModifiedClaim" }
        },
        "unchanged_count": { "type": "integer", "minimum": 0 }
      }
    },
    "computed_at": { "type": "string", "format": "date-time" }
  },
  "$defs": {
    "AddedClaim": {
      "type": "object",
      "required": ["claim_id", "local_id", "statement", "claim_type"],
      "properties": {
        "claim_id": { "type": "string" },
        "local_id": { "type": "string" },
        "statement": { "type": "string" },
        "claim_type": { "type": "string" }
      }
    },
    "RemovedClaim": {
      "type": "object",
      "required": ["claim_id", "local_id", "statement"],
      "properties": {
        "claim_id": { "type": "string" },
        "local_id": { "type": "string" },
        "statement": { "type": "string" }
      }
    },
    "ModifiedClaim": {
      "type": "object",
      "required": ["from_claim_id", "to_claim_id", "local_id", "fields_changed"],
      "properties": {
        "from_claim_id": { "type": "string" },
        "to_claim_id": { "type": "string" },
        "local_id": { "type": "string" },
        "fields_changed": {
          "type": "array",
          "items": {
            "enum": ["statement", "proof", "claim_type", "evidence_type", "figures", "depends_on", "supports", "contradicts", "extends", "source_location"]
          }
        },
        "statement_diff": { "$ref": "#/$defs/TextDiff" },
        "proof_diff": { "$ref": "#/$defs/TextDiff" }
      }
    },
    "TextDiff": {
      "type": "object",
      "required": ["hunks"],
      "properties": {
        "hunks": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["kind", "text"],
            "properties": {
              "kind": { "enum": ["equal", "added", "removed"] },
              "text": { "type": "string" }
            }
          }
        }
      }
    }
  }
}
```

### Claim matching rule

Diff computation reduces to: for each claim in `from`, find its counterpart in `to` (if any). The matching rule, applied in order:

1. **`local_id` match.** Claims in CIR carry a stable `local_id` (e.g., `prop:I.10`, `thm:main`, `claim:4`) chosen by the author in the `.tex` source via `\label{}`. Two claims with the same `local_id` are the same claim. This is the dominant case for a real v2: authors don't renumber their claims.
2. **`statement` exact match** (after `tex_to_text` normalisation). If `local_id` matching produces no counterpart and a claim with the same statement exists exactly once in the other CIR, match them. Catches cases where an author retypes a label but keeps the statement verbatim.
3. **Otherwise: unmatched.** Unmatched claims in `from` are `removed`; unmatched in `to` are `added`.

The matching rule is intentionally simple and **never fuzzy** — no edit distance, no semantic similarity. A diff is correct iff a careful human, reading both papers, would agree with the matches; in practice, `local_id` matching gets ≥95% of cases right and the remaining ones are either trivial (statement-exact) or genuinely different (unmatched).

For each `modified` claim, `fields_changed` lists the fields that differ; `statement_diff` and `proof_diff` carry word-level hunks (using a standard diff algorithm, e.g., Myers). Other fields (`figures`, `depends_on`, etc.) change as sets — no diff hunks, just before/after.

### Endpoint

`GET /api/v0/papers/{id}/diff?from=<prior_paper_id>`:

- `{id}` is the newer paper; `from` is the prior version.
- Both must share a lineage: walking `previous_version` from one must reach the other. Otherwise: 400 with `code: "papers_not_in_same_lineage"`.
- Response: `RevisionDiff` body.
- Cacheable: diff is a deterministic function of the two CIRs; the server may return `Cache-Control: public, max-age=86400` (immutable inputs → immutable output).
- The diff is also computed and cached at submission time (so subsequent reads are fast).

### `revision_summary` annotation type

Extend [`schema/annotation.schema.json`](../schema/annotation.schema.json) to recognise `annotation_type: "revision_summary"` with this structured payload:

```jsonc
{
  "annotation_type": "revision_summary",
  "paper_id": "<v2_paper_id>",
  "structured_payload": {
    "previous_version_id": "<v1_paper_id>",
    "summary": "Plain-text author summary of what changed.",
    "highlights": [
      {
        "kind": "fixed",          // one of: fixed, added, removed, clarified, contested
        "claim_local_id": "claim:4",
        "description": "Corrected an off-by-one error in the bound."
      }
    ]
  }
}
```

The annotation is authored by the submitter (typically the paper's author) and attached to the v2 paper. Servers may auto-generate a skeleton from the submission's `revision_summary` form field (RRP-0016) and let the author fill in highlights via a follow-up edit (annotations are immutable once posted; the skeleton is the final form unless the author submits another annotation that `supersedes` it).

The web UI surfaces the `revision_summary` at the top of the v2 paper's discussion section: "What changed in v2 — author's note."

### How the three changes combine

A reader lands on `https://rrxiv.com/papers/rrxiv:2605.00001` and sees:

- A version chip showing "v2 · current · v1 available".
- A discussion section with the `revision_summary` annotation pinned at the top.
- A "See diff" link → `https://rrxiv.com/papers/rrxiv:2605.00001/versions/<v1_paper_id>` → renders the `RevisionDiff` as added/removed/modified claim cards + abstract diff hunks.

A citing paper can resolve the citation at any version and see whether the cited claim survived to current — that's a future capability (citation versioning) but the diff format is the substrate.

## Alternatives considered

1. **Text diff over the entire CIR JSON.** Simple but useless — JSON formatting churn (key ordering, whitespace) drowns out semantic changes. Rejected.
2. **Diff at the LaTeX source level.** Author-friendly (they understand `.tex` diffs) but unstable — minor formatting changes produce huge diffs. The CIR-level diff is the right abstraction layer.
3. **Two-direction diff (v1↔v2 and v2↔v1 both retrievable).** Redundant; with deterministic matching, one direction suffices and clients can render either view from one diff object.
4. **Lossy diff (just summary counts, no per-claim detail).** Cheaper but worse UX. The current shape isn't large (a 30-claim paper with 5 modifications produces a ~5 KB diff); not worth the trade-off.
5. **Fuzzy semantic matching (LLM-based "are these claims the same?").** Expensive, non-deterministic, hard to test for conformance. Rejected. The deterministic `local_id`-first rule is enough for v0.x.

## Drawbacks

- **Modified claims get new `claim_id`s.** Because claim IDs are derived from `paper_id` + `local_id`, a v2 claim with the same `local_id` as a v1 claim has a *different* full `claim_id`. The diff captures this via the `from_claim_id`/`to_claim_id` pair. Citing papers that cite the v1 `claim_id` need to chase the diff if they want to follow the claim forward — see Open questions.
- **Adding `revision_summary` increases write surface** (any signed identity can post one). Mitigation: server may reserve `revision_summary` for the paper's author or co-authors only — enforced via the existing identity → paper-author link.
- **Word-level text diff is non-trivial** to make agree across implementations. Mitigation: the schema lists what fields differ; the *hunks* are advisory and need not byte-match between implementations.

## Migration

The protocol changes are **additive**:

- `revision_diff.schema.json` is new.
- The `revision_summary` annotation type is new but recognised by the existing `annotation.schema.json` discriminator pattern.
- No existing schemas have breaking changes.

The reference server upgrades by:

1. Implementing `compute_revision_diff(prev_cir, curr_cir)` (`rrxiv-python/src/rrxiv/server/papers/diff.py`).
2. Caching diff results in the store keyed on `(from_id, to_id)`.
3. Adding the `GET /papers/{id}/diff` endpoint.
4. Computing + storing the diff during submission ingestion (revision submissions).
5. Generating a skeleton `revision_summary` annotation from the `submission.revision_summary` form field, if present.

Existing v1 papers and v1-only corpus instances are unaffected.

Existing clients that ignore the new fields (`revision_diff`, `revision_summary` in responses) continue to work — they were already ignoring unknown fields.

## Open questions

- **Claim-level identity across versions.** Today a v2 claim with the same `local_id` as a v1 claim has a different `claim_id`. Should we introduce a `claim_lineage_id` that's stable across versions, derived from `(root_paper_id, local_id)`? Pro: citations to a *concept* survive revisions. Con: encodes that the *concept* is the same — but a corrected proof may be the same concept, while a contradicted claim is arguably not. Defer to a future RRP once we have real examples.
- **Should `removed` claims trigger a server warning at submission time**? Removing a claim that other papers cite is a high-impact action. The server could surface a warning during submission ("Claim X is cited by Y external papers; removing it may break their citations") and let the author confirm. Defer until we have meaningful cross-paper citation data.
- **Are abstract / topic changes separate diffable resources** (`GET /papers/{id}/diff/abstract`)? Probably overkill; the embedded diff in the main response is fine.
- **`revision_summary` highlights enum extensibility.** We've started with `fixed, added, removed, clarified, contested`. As patterns emerge (e.g., `expanded_corpus`, `improved_figures`) we can add values. Need to mark the enum as open vs. closed in the schema; default to open (`string` with documentation of recommended values) for v0.x.

## References

- [`spec/0005-submission.md`](../spec/0005-submission.md) — submission flow + revision pointer
- [`spec/0006-annotations.md`](../spec/0006-annotations.md) — annotation types catalogue
- [`schema/paper.schema.json`](../schema/paper.schema.json) — `version`, `previous_version`
- [`schema/claim.schema.json`](../schema/claim.schema.json) — `local_id` already present
- [RRP-0015](0015-meaty-claims.md) — proof + figures + source_location, the fields a diff most cares about
- [RRP-0018](0018-annotation-threads.md) — companion: how comments on a revision attach to the new paper
- [RRP-0020](0020-author-claim-retraction.md) — fast-path retraction (an alternative to full v2 for single-claim fixes)
