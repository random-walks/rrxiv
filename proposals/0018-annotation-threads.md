# RRP-0018 — Annotation threads (`in_reply_to`)

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-22
- **Last updated:** 2026-05-22
- **Affects:** schemas / spec / server / clients
- **Supersedes:** none
- **Superseded by:** none

## Process

Self-merged under the v0.x accelerated review policy. Threading is the kind of feature where the social shape (how people actually use it) shapes the protocol shape; we may revisit once we have real comment traffic on the canonical instance. The conservative `in_reply_to`-only design here is intentionally the smallest possible step.

## Summary

Add an optional `in_reply_to: annotation_id | null` field to `schema/annotation.schema.json`. The field, when set, points at another annotation on the same paper or claim. Servers verify the target exists and is on the same artefact; clients render reply chains as indented threads. The change is fully additive; existing annotations and tooling continue to work unchanged.

## Motivation

[`spec/0006-annotations.md`](../spec/0006-annotations.md) defines nine annotation types covering replications, errata, comments, extensions, and code/dataset links. The schema treats annotations as immutable atoms with a `supersedes` pointer for corrections — but no pointer for *replies*.

The cost of not having threading shows up in three places:

1. **Errata + author response.** An external reader files an erratum. The paper's author wants to acknowledge it, accept it, or contest it. Today the author posts a standalone `comment` annotation with no protocol-level link to the erratum — the relationship is implicit in the text (and lost to tooling).
2. **Replication discussion.** Reader A files a replication with `outcome: contradicts`. Reader B, looking at the same claim, wants to point out that A's protocol may have been flawed. With only `supersedes` (which means "I'm replacing my own earlier annotation"), there's no way for B to formally respond to A.
3. **Comment chains.** A general `comment` on a paper sparks discussion. Without threading, every reply is a sibling — readers can't tell which comments are conversation and which are independent observations.

Threading also makes the web client's discussion UI dramatically better: indented replies are a 25-year-old design pattern, and the cost of supporting them is one optional schema field plus a server-side existence check.

## Design

### Schema change

Add to `schema/annotation.schema.json`:

```jsonc
{
  "properties": {
    "in_reply_to": {
      "type": ["string", "null"],
      "format": "uuid",
      "description": "Annotation ID of the annotation this one replies to. Must be on the same paper (and, if both are claim-targeted, on the same claim). Null/absent means this is a top-level annotation."
    }
  }
}
```

### Validation rules

A server accepting an annotation with `in_reply_to: <target_id>`:

1. **Target exists**. The annotation referenced by `<target_id>` is in the store. Otherwise: 400 with `code: "in_reply_to_not_found"`.
2. **Same artefact**. The target annotation's `paper_id` matches. If both annotations specify `claim_id`, they must match. Otherwise: 400 with `code: "in_reply_to_artefact_mismatch"`.
3. **Not a self-reply**. The new annotation's ID (if client-proposed) does not match `<target_id>`. (Self-replies via re-posting the same ID would also be blocked by the existing duplicate-ID check.)
4. **Depth bound** (optional, server-policy). The reference server allows arbitrary depth. Hosted instances may cap depth (e.g., 32) to prevent pathological chains; this is policy, not protocol.

The target annotation is **not** required to share `annotation_type` with the reply. A `comment` may reply to a `replication`; an `erratum` may reply to an earlier `comment`. The convention is that the *first* annotation in a thread sets the topic; replies elaborate.

### Aggregation

Servers expose a thread via existing list endpoints. No new endpoint is required:

- `GET /papers/{id}/annotations` returns all annotations including their `in_reply_to`.
- `GET /annotations/{id}/replies` (new convenience endpoint) returns the direct children of `{id}`, ordered by `created_at`. Optional but reduces client-side filtering.

Clients reconstruct the tree:

```
discussion = list of root annotations (in_reply_to is null), sorted by created_at desc
each root → children (in_reply_to == root.id), sorted by created_at asc
each child → grandchildren, recursive
```

### UI implications

The web client renders threads as left-indented stacks. A maximum visual indent (~3 levels) collapses further depth with an "expand thread" link to avoid horizontal overflow. The `AnnotationCard` component grows an `inReplyTo?: Annotation` prop and a small "in reply to <X>" link to the parent.

### Conformance obligations

A conformant server:

- Accepts the `in_reply_to` field on annotation create.
- Validates target existence + artefact match.
- Returns `in_reply_to` on annotation read endpoints.
- Optionally implements `GET /annotations/{id}/replies` (recommended).

A conformant client:

- Renders threaded view when `in_reply_to` is present.
- Sends `in_reply_to` on reply creation.
- Tolerates orphan replies (target annotation not in the local cache) by rendering as a top-level annotation with a "loaded out of context" hint.

## Alternatives considered

1. **Nested annotations** (the parent annotation contains its children as an array). Breaks immutability — the parent would mutate when a reply lands. Rejected.
2. **Thread IDs** (every annotation in a thread shares a `thread_id`). More work for clients (have to compute the tree from a flat list anyway) and harder to validate (what's the thread invariant?). The `in_reply_to` pointer is strictly simpler.
3. **Reactions instead of replies** (👍, 👎, 🤔 only). Lighter weight but limits expressiveness; replies cover reactions trivially ("👍 to this"). Keep both options open; reactions are a future RRP, not a substitute.
4. **`parent_id` instead of `in_reply_to`**. Same semantics, different name. `in_reply_to` is more specific and matches ActivityPub / Mastodon convention.

## Drawbacks

- **Moderation harder under threads.** A buried reply chain might hide abusive content. Mitigation: the canonical instance has a flat audit log of every annotation; moderation tools operate on that. UI threading is a presentation concern.
- **Pre-RRP annotations have no `in_reply_to`**. They're all roots, which is correct — the field is optional and absent.
- **Thread depth can explode in pathological cases.** Bot wars on a controversial claim could produce 1000-deep chains. Mitigation: depth cap as a server policy; the canonical instance starts with 32. Adjustable without protocol change.
- **`in_reply_to` is a one-way pointer.** To get all replies to an annotation, the server must do a reverse lookup. The new `GET /annotations/{id}/replies` endpoint or an index on the column handles it. Acceptable cost.

## Migration

Fully additive:

- Add `in_reply_to: string | null` to `schema/annotation.schema.json`.
- All existing annotations pass validation with `in_reply_to: null` (or absent).
- Reference server adds the field + reverse index; SqliteStore + MemoryStore both grow a `list_annotations_by_reply(annotation_id)` method.
- Web client renders threads when the field is present.

No existing endpoints change shape. No existing tests break.

## Open questions

- **Should the server prevent replies to retracted/superseded annotations?** A reply to an annotation that was later superseded points at "dead" content. Tentative answer: allow it; the UI surfaces the supersession state on the target annotation so the reader can see the context. Don't deny writes for editorial reasons.
- **Cross-paper replies?** A `comment` on paper A wants to reply to an `extension` annotation on paper B. The current rule denies cross-artefact replies. Real use case yet TBD; revisit if it comes up.
- **Notifications.** If A writes an annotation and B replies, should A be notified? Out of scope for this RRP (notifications are out of scope for v0.x entirely). The data shape supports it when we get there.

## References

- [`spec/0006-annotations.md`](../spec/0006-annotations.md) — base annotation model
- [`schema/annotation.schema.json`](../schema/annotation.schema.json) — target of the additive change
- [RRP-0008](0008-reference-server.md) — server idempotency + write semantics
- [RRP-0017](0017-revision-flow-and-diff.md) — `revision_summary` annotations are common reply targets
- [RRP-0020](0020-author-claim-retraction.md) — retraction annotations are also expected reply targets
