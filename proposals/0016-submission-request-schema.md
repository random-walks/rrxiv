# RRP-0016 — Submission request schema

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-22
- **Last updated:** 2026-05-22
- **Affects:** schemas / spec / server / clients
- **Supersedes:** none
- **Superseded by:** none

## Process

Self-merged under the v0.x accelerated review policy (single maintainer, pre-1.0 protocol). The design borrows directly from working code in `rrxiv-python/src/rrxiv/server/submissions/router.py`; this proposal codifies what shipped without a schema. Future RRPs may revisit the bundle constraints (file count, encoding rules) as the corpus scales.

## Summary

Codify the `POST /api/v0/submissions` request shape into a new `schema/submission_request.schema.json`. The endpoint already works in `rrxiv-python`'s reference server but no JSON Schema documents the wire format: clients reverse-engineer it from the Python source. This RRP adds the schema, defines a `dry_run` mode for client-side validation against the server's reference compiler, and locks the multipart structure (CIR + bundle + form metadata) so additional clients (web upload, agent SDKs in other languages) implement the same contract.

## Motivation

[`spec/0005-submission.md`](../spec/0005-submission.md) describes the submission flow in prose: pre-flight checks, multipart upload, server-side ingestion, ID minting, ack. The companion schemas describe the artefacts that submission *produces* — `paper.schema.json` for the minted paper, `cir.schema.json` for the stored CIR. There is no schema for the *request*.

This worked in v0.1 because the only client was the reference server's own conformance test, which constructed the multipart payload in-Python by reading the router code. But the v0.2 surface needs three more clients:

1. **`rrxiv submit` CLI** (RRP-0016a in the implementation backlog) — needs a clear input shape so the Typer command can validate before transmitting.
2. **Web `/submit` page** — needs a contract so the Next.js client can build a multipart `FormData` and validate it client-side.
3. **Agent SDKs in other languages** — Go/Rust/TS-server clients need a wire-format spec they can implement against without reading Python.

A `submission_request.schema.json` solves all three. It also lets the server return better 400 responses when an upload is malformed, citing the schema field that failed.

A second-order need: **`dry_run`**. Authors today have no way to validate their bundle against the server's reference compiler without committing to a submission. A 200-MB bundle that fails on `tectonic` compile in the server's sandbox wastes both author and server resources. A dry-run mode returns the validation result + (if compile succeeds) the *would-be* CIR and *would-be* paper ID, without persisting anything. Composes well with CI: a paper repo's CI can dry-run against staging on every commit.

## Design

### Schema

`schema/submission_request.schema.json`:

```jsonc
{
  "$id": "https://rrxiv.com/schema/submission_request.schema.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SubmissionRequest",
  "description": "Wire format for POST /api/v0/submissions. Multipart-encoded: the `cir` and `bundle` fields are file parts; the rest are form fields.",
  "type": "object",
  "required": ["cir", "bundle"],
  "properties": {
    "cir": {
      "type": "string",
      "contentMediaType": "application/json",
      "description": "JSON-encoded CIR validating against cir.schema.json. Uploaded as a multipart file part named `cir`."
    },
    "bundle": {
      "type": "string",
      "contentMediaType": "application/gzip",
      "description": "Source bundle as a `.tar.gz` file part named `bundle`. Constraints in spec/0005 §Source bundle format."
    },
    "previous_version": {
      "type": ["string", "null"],
      "description": "Paper ID of the prior version when submitting a revision. Server sets `previous_version` on the stored paper to this value; null/absent means this is v1.",
      "format": "uuid"
    },
    "revision_summary": {
      "type": ["string", "null"],
      "description": "Optional plaintext summary of changes when submitting a revision. The server may turn this into a `revision_summary` annotation (see RRP-0017) authored by the submitter.",
      "maxLength": 8192
    },
    "dry_run": {
      "type": "boolean",
      "default": false,
      "description": "When true, the server performs all validation + compile + parse steps but does NOT persist the submission. Returns the would-be paper_id, would-be id_slug, computed CIR, and any revision_diff. Useful for CI."
    },
    "client_compile_hash": {
      "type": ["string", "null"],
      "pattern": "^[a-f0-9]{64}$",
      "description": "SHA-256 of the bundle as computed by the submitting client. Server recomputes and rejects on mismatch."
    }
  }
}
```

The schema is deliberately small. The bulk of the validation is delegated:

- The `cir` part validates against [`cir.schema.json`](../schema/cir.schema.json).
- The `bundle` constraints (no symlinks, no executables, ≤100 MB, UTF-8) live in [`spec/0005-submission.md`](../spec/0005-submission.md) §Source bundle format and are enforced by the server during ingestion.

### Multipart encoding

The HTTP request:

```
POST /api/v0/submissions
Authorization: Bearer <token>
Signature: …                   # RFC 9421, agent identities only
Content-Type: multipart/form-data; boundary=…
Idempotency-Key: <uuid>        # optional, recommended

--<boundary>
Content-Disposition: form-data; name="cir"; filename="paper.cir.json"
Content-Type: application/json

{…CIR JSON…}
--<boundary>
Content-Disposition: form-data; name="bundle"; filename="paper.tar.gz"
Content-Type: application/gzip

<binary>
--<boundary>
Content-Disposition: form-data; name="previous_version"

01923f8e-0009-7c4d-9e1f-3a2b1c0d4e5f
--<boundary>
Content-Disposition: form-data; name="revision_summary"

Fixed an off-by-one in the proof of Claim 4; new code archive at https://github.com/…
--<boundary>
Content-Disposition: form-data; name="dry_run"

false
--<boundary>--
```

Form-field encoding for `previous_version`, `revision_summary`, `dry_run`, and `client_compile_hash` matches HTML form conventions: bare scalar values, no JSON wrapping. The server tolerates missing optional fields.

### Response shape

The submission response is **not** changed by this RRP, but for completeness the new fields it gains as a function of this proposal are:

```jsonc
{
  "paper_id": "01923f8e-…",
  "id_slug": "rrxiv:2605.00042",
  "retrieval_uri": "https://api.rrxiv.com/api/v0/papers/01923f8e-…",
  "version": "v2",
  "previous_version": "01923f8e-0009-…",
  "revision_diff": {…},        // present when previous_version is set; see RRP-0017
  "dry_run": false,            // mirrors the request flag
  "would_persist": true        // false when dry_run=true
}
```

### Dry-run semantics

When `dry_run=true`:

1. All steps 1–5 of `spec/0005-submission.md` §Server-side ingestion run normally (authenticate, re-validate, re-compile, re-parse, compare).
2. Steps 6–9 (mint ID, sign, store, index, snapshot) **do not happen**.
3. The server returns 200 with:
   - `paper_id: null` (no real minting)
   - `would_persist: true` if validation passed; `false` if it would have failed (with diagnostic detail)
   - `revision_diff` (if `previous_version` set): the diff that *would* have been recorded
4. The Idempotency-Key, if present, is **not** stored — a real submission with the same key still gets a fresh ID.

A dry-run failure is still HTTP 400; the diagnostics tell the author exactly what would have prevented a real submission.

### Conformance obligations

A conformant server:

- Accepts multipart with `cir` (JSON file) and `bundle` (tar.gz file) parts.
- Tolerates extra unknown form fields (forward-compat).
- Returns the new response fields (`version`, `previous_version`, `revision_diff`, `dry_run`, `would_persist`).
- Honours `dry_run=true` without persisting.
- Rejects mismatched `client_compile_hash` with 400 (if present).
- Honours `Idempotency-Key` per existing RRP-0008 semantics (the dry-run carve-out above).

### Schema sync

Add `submission_request.schema.json` to:

- `rrxiv/schema/`
- `rrxiv-web-official/packages/protocol-types/src/_schemas/`
- `rrxiv-python/tests/conformance/fixtures/` (test fixtures for dry-run + real submission)

## Alternatives considered

1. **No schema, just prose in spec/0005**. Status quo. Rejected because four+ clients need the same contract and reverse-engineering the Python server doesn't scale.
2. **JSON body instead of multipart**. Encoding the bundle as base64 in a JSON request would simplify the schema but bloat the payload by ~33% and force two parses (JSON, then base64 decode, then tar). The multipart shape matches existing HTTP file-upload conventions; clients have library support.
3. **Separate endpoints for v1 vs revision**. `POST /papers` vs `POST /papers/{id}/versions`. Cleaner REST but doubles the auth + signature surface and makes the dry-run mode redundant on the v1 path. The single endpoint with `previous_version` is what the server already implements; we keep it.
4. **Streaming uploads**. For ≥100 MB bundles, multipart is awkward; gRPC-style streaming would be cleaner. Out of scope for v0.x — the 100 MB limit makes multipart fine. Revisit if datasets-in-bundle becomes a v1 concern.

## Drawbacks

- **Dry-run doubles server compile cost** if authors run it on every CI commit. Mitigation: server may rate-limit dry-runs per identity; the existing rate-limit middleware suffices. For the canonical instance, monthly dry-run cost is bounded by the corpus growth rate.
- **`client_compile_hash` is advisory until the server enforces it**. The field is optional; the reference server validates when present but doesn't require it. A future RRP could require it for write integrity.
- **Schema doesn't capture multipart structure perfectly** — JSON Schema describes JSON, and multipart is not JSON. The schema documents the fields; the structural encoding is documented in spec prose. Acceptable but slightly awkward.

## Migration

The new schema is **additive**. Existing submissions made before this RRP continue to work because:

- All existing fields (`cir`, `bundle`, `previous_version`) are unchanged in name and type.
- All new fields (`revision_summary`, `dry_run`, `client_compile_hash`) are optional with sensible defaults.
- The response gains new fields but no old fields are removed or renamed.

Servers upgrade by:

1. Materialising the schema in `schema/submission_request.schema.json`.
2. Implementing `dry_run` short-circuit logic in their submission handler.
3. Implementing `client_compile_hash` validation (advisory at first; can become required later).
4. Computing `revision_diff` on revision submissions (see RRP-0017 for the diff contract).

The reference server's upgrade lives in `rrxiv-python` Phase 2 of the SRV sprint.

## Open questions

- **Should `revision_summary` be required when `previous_version` is set?** Today it's optional. The cost is one annotation skeleton with empty body; the benefit is forcing authors to explain what changed. Tentatively: optional in v0.x, may become required in v1.0 once we have data on whether authors write useful summaries.
- **Should servers expose dry-run as a separate endpoint** (`POST /api/v0/submissions/validate`) for clarity? Considered; the parameter flag keeps the surface smaller and lets clients toggle without changing endpoints. Revisit if dry-run usage demands its own resource.
- **What's the canonical `client_compile_hash` algorithm**? SHA-256 over the raw tarball bytes is unambiguous but ignores tarball-construction non-determinism (timestamps, ordering). A future RRP could specify a normalised bundle hash. For now: SHA-256 of the wire bytes.

## References

- [`spec/0005-submission.md`](../spec/0005-submission.md)
- [`schema/paper.schema.json`](../schema/paper.schema.json)
- [`schema/cir.schema.json`](../schema/cir.schema.json)
- [RRP-0007](0007-message-signatures.md) — HTTP message signatures (agent submissions)
- [RRP-0008](0008-reference-server.md) — reference server shape + idempotency
- [RRP-0017](0017-revision-flow-and-diff.md) — revision flow + diff (companion to dry-run on revision)
