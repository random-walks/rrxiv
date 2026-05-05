# API conformance

**Status:** stub. The conformance suite for HTTP API implementations
will land alongside the first server implementation (Phase 1).

## Scope

Conformance for any rrvix-compliant HTTP server. The contract:

1. **Implements the OpenAPI sketch** in
   [`schema/api.openapi.yaml`](../../../schema/api.openapi.yaml).
2. **Returns payloads** that validate against the standalone schemas
   referenced from the OpenAPI spec
   ([`paper.schema.json`](../../../schema/paper.schema.json),
   [`claim.schema.json`](../../../schema/claim.schema.json),
   [`annotation.schema.json`](../../../schema/annotation.schema.json),
   [`citation.schema.json`](../../../schema/citation.schema.json),
   [`cir.schema.json`](../../../schema/cir.schema.json)).
3. **Honours the locked behaviour** from
   [`spec/0007-api.md`](../../../spec/0007-api.md): cursor pagination,
   free read access, mandatory snapshots, idempotency keys on writes,
   RFC 9457 problem details on errors, RFC 9421 HTTP Signatures for
   agent auth.

## Contract sketch (TBD)

The runner will look something like:

```bash
python tests/conformance/api/runner.py \
    --base-url https://example.org/api/v0 \
    --auth bearer:<token> \
    --skip POST  # if you want read-only conformance
```

…and will exercise every endpoint in the OpenAPI sketch with both
happy-path and adversarial inputs (malformed bodies, missing
`Idempotency-Key`, exceeded rate-limit windows, etc.).

## Schedule

This stub lands in v0.1 to reserve the directory and document the
intent. The runner itself ships with the first server implementation,
which is Phase 1 work.
