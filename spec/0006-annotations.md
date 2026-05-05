# 0006 — Annotation model

**Status:** stub. Full content TBD.
**Schema:** [`schema/annotation.schema.json`](../schema/annotation.schema.json) is fleshed out; this prose doc lags the schema.

## Scope

The annotation layer — replications, contradictions, errata, summaries, code/dataset links, claim extractions, comments, extensions. The discourse layer of rrvix.

## What's already specified

The annotation schema already covers: target type (paper / section / claim / figure / annotation), annotation type (9 kinds), structured payload (kind-specific), provenance (`created_by` with `orcid` / `agent` / `anonymous`), versioning (`supersedes`), and verification edges (`verified_by`, `disputed_by`).

## To be written

- **Per-type `structured_payload` schemas.** A `replication` annotation's payload should specify `outcome`, `method`, `n`. An `erratum` should specify the error and the corrected statement. v0.1 leaves these as free-form objects; v0.2 will tighten.
- **Verification quorum rules.** When does a `claim_extraction` annotation get promoted to a canonical claim? Author confirmation is the simplest rule; community quorum (with what credential definition?) is the harder case.
- **Anti-abuse.** Rate limits, sybil resistance, and how to handle annotations on retracted papers.
- **Annotation supersession.** Errata can supersede; what about replications that turn out to be flawed? The `supersedes` field is in the schema; the policy isn't.
- **Cross-instance annotations.** If rrvix federates, how do annotations move?

## Status

This document will land as part of a Phase 1 RRP that tightens the annotation `structured_payload` schemas and specifies the verification quorum rules. The current free-form payloads are intentional v0.1 placeholders.
