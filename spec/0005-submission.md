# 0005 — Submission flow

**Status:** stub. Full content TBD.

## Scope

How an author or agent submits a paper, a revision, or a withdrawal to a rrvix instance. Covers source bundle format, validation pipeline, ID assignment, content moderation hooks, signing of submissions, and replay protection.

## Open questions

- ID assignment: server-side UUIDv7 only, or an option for content-addressed hashes?
- Source bundle format: tar.gz only, or also support .zip / oci-image?
- Pre-submission validation: how much should the client tool do before talking to the server?
- Identity verification: ORCID linking flow; agent identity attestation.
- Withdrawal vs. retraction: legal limits on either, especially for CC-BY content already in third-party mirrors.

## Status

This document will be written alongside the submission API in a Phase 1 RRP.
