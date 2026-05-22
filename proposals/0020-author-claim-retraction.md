# RRP-0020 — Author claim retraction

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-22
- **Last updated:** 2026-05-22
- **Affects:** schemas / spec / server / clients
- **Supersedes:** none
- **Superseded by:** none

## Process

Self-merged under the v0.x accelerated review policy. Retraction is a sensitive surface — it directly affects how the corpus is read — and the design here intentionally constrains retraction to the original author. Future RRPs may add editor-led retraction, retraction-for-fraud (third-party), or paper-level retraction (this RRP is claim-scoped only).

## Summary

Add a new `claim_retraction` annotation type so a paper's original author can retract a specific claim without publishing a full v2. The retraction is a signed annotation that, when accepted, causes the server to derive the claim's `replication_status` as `retracted` (overriding any other annotations). Retraction does **not** delete the claim from the corpus (immutability holds); it marks the claim as withdrawn and surfaces a notice. Companion: an author can un-retract by submitting a `revision_summary` reply or, more commonly, by submitting a v2 that re-states the claim cleanly.

## Motivation

Paper immutability is a load-bearing protocol invariant — without it, citations rot. But it creates an awkward path for one common case: the author discovers their own claim is wrong. Today their options are:

1. **Publish a v2** with the claim removed or corrected. Heavy: requires a full new submission, breaks every external citation that points at v1's claim ID, and is gratuitous if the rest of the paper is unaffected.
2. **Submit an `erratum` annotation**. Light, but doesn't change the claim's `replication_status` — readers still see the claim as `untested` or `replicated` even though the author has disowned it. The signal is buried in text.
3. **Do nothing.** Real-world default. The wrong claim sits in the corpus and accumulates citations.

A claim-scoped retraction closes the gap: lightweight (one annotation), explicit (changes status), and reversible (the author can supersede their own retraction).

## Design

### Annotation type

Extend `schema/annotation.schema.json` to recognise `annotation_type: "claim_retraction"` with this structured payload:

```jsonc
{
  "annotation_type": "claim_retraction",
  "paper_id": "<paper_id>",
  "claim_id": "<claim_id>",
  "structured_payload": {
    "reason": "Plain-text justification — required, ≥ 32 characters.",
    "kind": "error|withdrawal|superseded_by_revision|other",
    "recommended_action": "use_v2|file_v2|no_action|see_replications",
    "see_also_paper_id": "<paper_id>"
  }
}
```

Fields:

- `reason` — required, plaintext, minimum 32 chars (forces an actual explanation).
- `kind` — discriminator. `error` = "I found a bug in my proof"; `withdrawal` = "I'm no longer confident in this claim's framing"; `superseded_by_revision` = "see the v2 version that corrects this"; `other` = catch-all.
- `recommended_action` — what should a reader do? Free-form values to start; can become enum once patterns settle.
- `see_also_paper_id` — optional pointer to a v2 that addresses the retraction.

### Authorisation

The server accepts a `claim_retraction` annotation **only** if:

1. The submitting identity is **on the author list** of the paper (`paper.authors[].orcid` or `paper.authors[].agent_handle` matches the authenticated identity), OR the identity holds a special `paper_admin` role for that paper (out of scope for v0.x; placeholder for moderation later).
2. The annotation is signed (agent identity) or bearer-authenticated to an ORCID that matches an author.
3. The claim exists on the paper.

Other identities attempting to retract: 403 with `code: "not_paper_author"`.

External readers who want to flag a claim as wrong have other tools: `contradiction` annotation (their independent finding), `replication` with `outcome: contradicts`, or `erratum` (for typos).

### Derivation rule

`claim.replication_status` derivation gets a new branch (extends RRP-0019's rule):

```python
if any(a.annotation_type == "claim_retraction" and not_superseded(a) for a in annotations):
    return "retracted"
```

`not_superseded` checks that the retraction itself isn't superseded by a later annotation from the same author with `annotation_type == "comment"` and `in_reply_to == retraction.id` + a `lifts_retraction: true` flag in the payload. (See *Reversing a retraction* below.)

Retraction takes precedence over all other derivations — a retracted claim is `retracted` regardless of how many replications support it. The protocol prioritises author intent over crowd evidence.

### Reversing a retraction

Annotations are immutable, but a retraction can be lifted by a later annotation from the same author:

```jsonc
{
  "annotation_type": "comment",
  "paper_id": "<paper_id>",
  "claim_id": "<claim_id>",
  "in_reply_to": "<retraction_annotation_id>",
  "structured_payload": {
    "lifts_retraction": true,
    "reason": "On further analysis, the claim holds; the bug was in my supporting calculation, not the claim itself."
  }
}
```

Same authorisation rules apply (must be an author of the paper). After a lift, the derivation reverts to the normal rule. The lift annotation is also immutable — it cannot itself be reversed by another lift, only by a new retraction.

### Web UI implications

A retracted claim renders with:

- A pinned banner at the top of the claim page: "Retracted by author on 2026-06-15."
- The retraction's reason in the banner body.
- The recommended action as a CTA (link to v2 paper, or "see contradicting replications", etc.).
- The original statement struck through (visual styling: dimmed + line-through, but legible — readers need to see what was retracted).
- The dependents section warning that downstream claims may be affected.

A claim page in the corpus that's retracted by an external reader (via `replication` with `outcome: contradicts` reaching the quorum) renders differently — that's `contradicted`, not `retracted`. Retraction is author-only.

### Conformance obligations

A conformant server:

- Accepts `claim_retraction` annotations from authorised identities.
- Enforces authorship check; returns 403 with the correct code on rejection.
- Includes retractions in the derivation rule.
- Surfaces the retraction's `structured_payload` on `GET /claims/{id}`.
- Recognises the `lifts_retraction: true` convention in subsequent comments.

A conformant client:

- Renders the retraction banner on retracted claim pages.
- Disables "Reproduce this" / "Add replication" CTAs on retracted claims (or wraps them with a "this claim is retracted — proceed?" interstitial).
- Renders the lift banner on lifted-retraction claims with the same prominence as the retraction itself.

## Alternatives considered

1. **Allow any signed identity to retract.** Equivalent to letting any reader vandalise the status field. Rejected.
2. **Use the `erratum` type for retraction.** Errata cover typos and minor corrections; retraction is categorical ("the whole claim is wrong"). Different signal; different type.
3. **Paper-level retraction.** Heavier — a paper-level retraction is essentially a formal withdrawal and may need a different process (editorial board, public notice, etc.). Out of scope. This RRP is claim-scoped.
4. **Allow retraction by a co-author without notifying the lead.** Real co-authorship politics out of protocol scope. We require an author identity; humans co-ordinate on the side.
5. **Forbid lifting a retraction.** Cleaner but punishes the human path. "On second thought, the claim does hold" is a real story; the protocol should accommodate it.

## Drawbacks

- **Authorship check is only as strong as identity provenance.** If an author's ORCID is compromised or their agent key is stolen, the attacker can retract claims. Mitigation: the protocol already trusts ORCID + signature flows for write integrity (RRP-0007); retraction inherits whatever guarantees those provide. Key rotation (RRP-0010) is the recovery path.
- **`lifts_retraction` is a convention encoded in a comment payload**, not a distinct annotation type. Slight ad-hocness. Mitigation: if usage becomes common, a future RRP can promote it to a first-class type (e.g., `claim_unretraction`).
- **Retractions persist forever in the audit log.** Authors who lift their retraction can't erase the original. This is the right design (corpus integrity) but worth flagging.
- **No retraction-of-retraction.** If a malicious actor compromises an author key and posts a fake retraction, the only recovery is the lift. There's no third-party mechanism to nullify a bad retraction. Out of scope for v0.x.

## Migration

Fully additive:

- New `annotation_type` recognised in `annotation.schema.json` discriminator.
- New derivation branch in the server's `derive_replication_status`.
- New banner UI in the web client; gracefully absent if the schema is older.
- No changes to existing claims, papers, or annotations.

Existing instances continue to work; they don't recognise `claim_retraction` and treat it as an unknown type (per the schema's open-discriminator convention) until they upgrade.

## Open questions

- **Should retraction trigger downstream alerts** on papers that cite the retracted claim? The data shape supports it (we have `depends_on` edges in the claim graph + citation links). Notification infrastructure is out of scope, but the static query is cheap.
- **Are co-author retractions distinguishable from lead-author retractions?** The `authors` array has order today but no role markers. Distinguishing matters when co-authors disagree. Tentative: any author can retract; the annotation records which identity did so; UI doesn't need to enforce a hierarchy at the protocol level.
- **What happens to claims whose `depends_on` target gets retracted?** The dependent claim's `replication_status` is unaffected by the dependency's retraction (they are separately evaluated). But the dependent's `claim_status_warning` could surface a flag: "depends on a retracted claim." Defer until we have real cases.

## References

- [`spec/0006-annotations.md`](../spec/0006-annotations.md) — base annotation model
- [`schema/annotation.schema.json`](../schema/annotation.schema.json) — target of the additive change
- [`schema/claim.schema.json`](../schema/claim.schema.json) — `replication_status` field
- [RRP-0008](0008-reference-server.md) — server idempotency + auth
- [RRP-0017](0017-revision-flow-and-diff.md) — when to retract vs. publish v2
- [RRP-0018](0018-annotation-threads.md) — `in_reply_to`, used by retraction-lift convention
- [RRP-0019](0019-reproducibility-manifests.md) — derivation rule companion
