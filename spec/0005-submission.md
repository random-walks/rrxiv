# 0005 — Submission flow

**Status:** v0.1 draft.
**Schema:** [`schema/paper.schema.json`](../schema/paper.schema.json).
**Prereqs:** [`0001-overview.md`](0001-overview.md), [`0002-cir.md`](0002-cir.md), [`0004-tex-template.md`](0004-tex-template.md).

## What submission is

**Submission** is the atomic operation by which a paper enters the rrvix corpus. After a successful submission, the server has stored the paper's source bundle, computed and stored its CIR, assigned a stable paper ID, and made the paper available for read access.

Submission is **immutable**. A submission cannot be edited; mistakes are corrected through:

- A **revision** (`v2`, `v3`, …) — a new immutable submission whose `previous_version` field points at the prior version's ID. The lineage is queryable but neither version mutates.
- An **erratum annotation** (see [`0006-annotations.md`](0006-annotations.md)) — for errors that don't warrant a full revision.
- A **withdrawal** — see *Withdrawals* below. A withdrawal does not delete the submission; it marks it withdrawn and serves a notice instead of the content.

## Source bundle format

A submission is uploaded as a **source bundle**: a single tarball (`.tar.gz`) containing every file required to compile the paper. The minimum manifest:

```
my-paper-0001/
├── my-paper-0001.tex     ← the paper source
├── my-paper-0001.bib     ← bibliography (if any)
├── rrvix.cls             ← bundled with submission (see 0004 §"Distributing the class")
└── figures/              ← any included figures, optional
    └── ...
```

Constraints:

- **No symbolic links.** Servers reject bundles containing symlinks.
- **No file outside the top-level directory.** Bundles unpack into a single directory whose name matches the paper's working ID; no `../` paths.
- **Maximum bundle size: 100 MB** (uncompressed). Larger bundles must use external dataset links (see [`0006-annotations.md`](0006-annotations.md) §"`dataset_link`").
- **No executables** — `.exe`, `.so`, `.dylib`, etc. are rejected. Source files only.
- **Encoding: UTF-8.** No BOMs.

The server **reproduces the compile** before storing — it must produce a PDF and `*.rrvix.aux` sidecar from the bundle deterministically. If the bundle compiles in the author's environment but not in the server's reference environment, the submission fails with diagnostic logs.

## Pre-submission validation (client side)

The reference client (`rrvix-python`'s future `rrvix submit` command) checks the following before contacting the server:

1. **Compile locally.** `tectonic` runs against the bundle. If the paper doesn't compile locally, fix it before submitting.
2. **Sidecar present.** `*.rrvix.aux` was produced by the local compile.
3. **Parse to CIR.** `rrvix parse <main.tex>` produces a CIR JSON.
4. **CIR validates.** The CIR validates against `cir.schema.json`.
5. **No obvious anti-pattern signals.** No `\input{/etc/passwd}`-style suspicious paths in the source. No claim labels containing reserved characters.
6. **Bundle the directory.** Tarball produced.
7. **Hash the bundle.** SHA-256 over the tarball, recorded as the bundle's `compile_hash`.

A failing pre-submission check is a hard error; the client does not contact the server.

## Server-side ingestion

1. **Receive the bundle** at `POST /api/v0/submissions` (see [`0007-api.md`](0007-api.md)).
2. **Authenticate** the submitting identity (ORCID / agent / anonymous-with-attestation).
3. **Re-validate** the bundle against the constraints in *Source bundle format* above.
4. **Re-compile** in the server's reference environment (a sandboxed Tectonic invocation; no network during compile).
5. **Re-parse** the source + sidecar to a CIR. Compare against the client-provided CIR; if they diverge by anything beyond the trivial `submitted_at` and `id` fields, reject the submission.
6. **Mint an ID.** v0.1 uses **UUIDv7** — see *ID assignment* below. The minted ID becomes the paper's `id` and is stamped into the stored CIR.
7. **Sign and store** the canonical CIR.
8. **Index** the CIR for query: claim graph edges, citations, search terms.
9. **Snapshot eligibility.** The new submission is included in the next snapshot export (per [`0008-governance.md`](0008-governance.md)).
10. **Acknowledge** with the assigned ID and the canonical retrieval URI.

If any step after 6 fails, the assigned ID is **retired** — never recycled — and the submission is rejected with a server error. Authors retry with a fresh client-initiated submission; the previous attempt's ID is dead.

## ID assignment

v0.1 uses **UUIDv7** for paper IDs. Properties:

- **Time-ordered** — IDs minted later sort lexicographically after IDs minted earlier. Useful for lazy "latest first" queries.
- **128 bits, plenty of entropy** — sybil-resistant against accidental collisions.
- **Unrecyclable** — if a submission is retired during ingestion (steps 4–9 fail), its ID is never reused. The gap is a feature; UUIDv7 has so much entropy that gaps are not a problem.
- **Server-minted** — clients do not propose IDs. This means an author resubmitting a rejected attempt gets a fresh ID.

The ID format may evolve via RRP. Candidate alternatives for v1.0:

- Content-addressed hashes (SHA-256 over the source bundle).
- arXiv-style readable identifiers (`rrvix-2026.05-1234`).
- Authority-allocated DOIs.

Until that RRP, UUIDv7 is the canonical format.

## Identity verification

The submitter's identity is required and must be one of:

- **ORCID** — verified via OAuth handshake with `orcid.org`. The submission stores the verified ORCID iD; the iD is what shows up in `paper.authors[].orcid` if the author claims it.
- **Agent handle** — a server-recognised agent identity of the form `<handle>@<instance>`. Agents must be enrolled in the rrvix instance's agent registry; enrollment requires a public key the agent signs submissions with. The agent's `is_agent: true` is enforced server-side: the corresponding `Author` record must declare itself.
- **Anonymous-with-attestation** — anonymous submitters get an opaque server token after passing a CAPTCHA-style anti-abuse gate. Anonymous submissions are accepted but flagged in the API; some annotations on anonymous submissions may be disabled (e.g., `claim_extraction` requires a non-anonymous author).

A submission's authorship list (the `authors[]` field) is checked against the submitter's identity:

- The submitter's own identity (ORCID or agent handle) **must** appear as one of `authors[]`.
- Other authors listed need not be enrolled — the submitting author asserts them, with optional ORCID verification on a per-author basis.
- A submission may have a single author or multiple; `minItems: 1` per the schema.

## Withdrawals

Withdrawal is the closest thing to deletion in rrvix, and it is *not* deletion.

A withdrawn submission:

- Stays in the corpus with `withdrawal_notice` populated (a structured object containing reason, date, withdrawing party).
- Has its source bundle preserved server-side but no longer served from the canonical retrieval URI; instead the URI returns the withdrawal notice with a stable redirect to the source bundle for any party who can demonstrate continuing legitimate access.
- Has its claims marked `replication_status: retracted`.
- Continues to appear in citation graphs (citations to it are not silently broken).

A withdrawal can be initiated by:

- **The submitting author** — by their ORCID-authenticated request. Includes a reason.
- **A maintainer** — only for narrow grounds: copyright violation, plagiarism, or content violating the locked governance principles in [`0008-governance.md`](0008-governance.md).
- **A court order** — handled per the operating instance's legal posture, with the withdrawal notice naming the legal grounds where doing so is itself legal.

Withdrawals never affect prior snapshots — those are immutable artifacts that the corpus has already published.

## Submission as an annotation

In a future RRP, **submissions themselves may be implementable as a special kind of annotation** with `target_type: corpus` and `annotation_type: submission`. This unifies the data model: everything in the corpus is either a paper or an annotation, and submissions are the annotation type that brings new papers in. v0.1 keeps submissions as a separate API surface for clarity; the unification is a v0.2+ design exercise.

## Open questions

- **Source format extensions.** Typst is on the v0.2 roadmap; what does Typst submission ingestion look like? Probably the same flow with a different reference compiler.
- **Multi-file bundles with internal cross-references.** A paper that splits into chapters (`\input{ch1}`, `\input{ch2}`) — handled in v0.1 but the server needs to verify all referenced files are within the bundle root.
- **Resubmit-rate limits.** A bot-protection mechanism needs to throttle high-volume retry attempts. Concrete numbers TBD.
- **Cross-instance submissions.** If federated, how does an author submit once and have the paper appear on multiple instances? Probably out of scope for v0; revisit when federation lands.
- **Attribution chain for AI co-authored papers.** v0.1 says "agents must declare via `is_agent: true`"; but the chain of which agent did what (extracted claims, drafted prose, suggested edits) needs a structured record. Likely a v0.2 RRP.

These are tracked in [`proposals/`](../proposals/) once they crystallise.
