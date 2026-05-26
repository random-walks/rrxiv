# RRP-0024 — ORCID ↔ Ed25519 key binding

| | |
|---|---|
| **Status** | Accepted |
| **Author** | Blaise Albis-Burdige, Claude |
| **Created** | 2026-05-26 |
| **Affects** | new schema [`schema/orcid_signing_key.schema.json`](../schema/orcid_signing_key.schema.json); new endpoints `POST/GET/DELETE /api/v0/auth/orcid/keys`; `server/auth/signature_middleware.py` (polymorphic keyid resolver); `cli/auth.py` (new `bind-key`, `keys list`, `keys revoke` commands) |
| **Sister RRPs** | [RRP-0005](0005-token-acquisition.md) (identity types) · [RRP-0006](0006-cli-login.md) (CLI login) · [RRP-0007](0007-message-signatures.md) (HTTP signatures) · [RRP-0010](0010-agent-key-rotation.md) (agent key lifecycle — the human analog of this RRP) |

## Process note (v0.x accelerated review)

Sole maintainer; pre-1.0; one-PR review cycle. The deviation from a v1.0 RFC process is intentional and bounded — see [`CONTRIBUTING.md#process-note`](../CONTRIBUTING.md).

## Summary

Bridge ORCID identities to Ed25519 signing keys so humans can cryptographically sign CLI submissions identically to how agents already do. Today the protocol exposes three identity types — anonymous, ORCID, agent — but only the agent type carries a signing key. ORCID identities authenticate via opaque bearer only, which means human submissions ride bearer-auth (replayable if the bearer leaks) while agent submissions ride RFC-9421 signatures (non-replayable, key-bound).

This RRP defines:

1. A **proof-of-possession enrollment flow** (`POST /api/v0/auth/orcid/keys`) gated on a fresh ORCID bearer, mirroring the agent-enroll handshake from RRP-0005.
2. A **soft-revoke lifecycle** (`DELETE /api/v0/auth/orcid/keys/{key_id}`) that tombstones a key without breaking historical signature verification.
3. A **polymorphic keyid resolver** in the signature middleware so signed requests can name either an ORCID-bound key (`key:<32-hex>`) or an agent handle (`@handle`).

After acceptance, `rrxiv submit --identity orcid` will produce signed requests indistinguishable in security properties from agent submissions.

## Motivation

Three concrete problems with the status quo:

1. **Bearer-only auth for humans is unaudible.** If a human's bearer leaks (laptop theft, CI log exfil, a Vercel preview that proxied the token through), the attacker can submit until the bearer TTL expires (24h default). A signed request signs *the request body* — a leaked bearer alone is insufficient to forge an authentic-looking submission.
2. **The same human cannot have multiple devices.** Today, `rrxiv login orcid` on a second machine invalidates the bearer on the first. With key-binding, each device gets its own keypair under one ORCID account; revoking one device doesn't invalidate the others.
3. **Federation comparability requires signed human writes.** A future federation aggregator pulling from two rrxiv instances needs to verify that "submission attributed to ORCID X on instance A" was actually authorised by ORCID X (not by instance A's operator forging the record). Bearer-auth is unverifiable across instance boundaries; signed writes are.

## Design

### 1. New record: `OrcidKeyRecord`

```json
{
  "$id": "https://rrxiv.org/schema/v0/orcid_signing_key.schema.json",
  "type": "object",
  "required": ["orcid_id", "key_id", "public_key_b64", "created_at_unix"],
  "additionalProperties": false,
  "properties": {
    "orcid_id":        { "type": "string", "pattern": "^\\d{4}-\\d{4}-\\d{4}-\\d{3}[0-9X]$" },
    "key_id":          { "type": "string", "pattern": "^key:[0-9a-f]{32}$" },
    "public_key_b64":  { "type": "string", "contentEncoding": "base64" },
    "label":           { "type": "string", "maxLength": 64, "default": "" },
    "created_at_unix": { "type": "integer", "minimum": 0 },
    "revoked_at_unix": { "type": ["integer", "null"], "default": null }
  }
}
```

`key_id` is 32 hex chars (128 bits of randomness). 8-hex was considered (compact, matches Git short-SHAs) but birthday-collision at ~65k keys is too close for a public namespace. 128 bits is comfortable.

The `key:` prefix is non-coincidental — it disambiguates from agent handles (regex `^@[a-z0-9][-a-z0-9]{0,31}$`). Server-side rejects any `label` that starts with `@` so a future schema bug can't mint colliding ids.

### 2. Enrollment flow

```
POST /api/v0/auth/orcid/keys
Authorization: Bearer <orcid-bearer-issued-by-rrxiv-after-orcid-callback>
Content-Type: application/json

{
  "public_key_b64": "<base64-of-Ed25519-public-key>",
  "label": "blaise-laptop",
  "payload_b64": "<base64-of-canonical-payload>",
  "signature_b64": "<base64-of-Ed25519-signature-over-payload>"
}
```

The `payload_b64` decodes to a canonical JSON object:

```json
{
  "purpose": "orcid_key_binding",
  "orcid_id": "0009-0002-0561-6499",
  "public_key_b64": "...same as outer field...",
  "issued_at_unix": 1748419200,
  "nonce": "<128-bit-random-hex>"
}
```

The server validates the signature with the proposed public key — proof-of-possession of the corresponding private key. The `orcid_id` in the payload MUST equal the ORCID iD bound to the bearer (rejects 401 otherwise). `issued_at_unix` MUST be within `±300s` of the server's clock (replay window).

On success the server:

1. Mints `key_id = "key:" + secrets.token_hex(16)`.
2. Inserts `OrcidKeyRecord{ orcid_id, key_id, public_key_b64, label, created_at_unix=now, revoked_at_unix=null }`.
3. Returns the record as `200 application/json`.

### 3. Listing + revocation

- `GET /api/v0/auth/orcid/keys` (ORCID bearer): returns the non-revoked records for the calling ORCID.
- `DELETE /api/v0/auth/orcid/keys/{key_id}` (ORCID bearer): sets `revoked_at_unix = now`. The row stays in the store so historical signatures (annotations and submissions made before revocation) remain verifiable for audit replay. Read endpoints return revoked keys via the list endpoint only when `?include_revoked=true` is passed.
- A future RRP MAY add `POST /api/v0/auth/orcid/keys/{key_id}/rotate` for in-place rotation; deferred until the operator UX demands it.

### 4. Signature middleware change

Today's middleware (`server/auth/signature_middleware.py`) has two bugs that this RRP fixes:

- **Line 98**: early `isinstance(identity, AgentIdentity)` skip — ORCID identities currently *cannot be signers* even if they wanted to be. Remove the skip.
- **Line 143**: `verified.keyid != identity.handle` — assumes `identity.handle` exists. `OrcidIdentity` doesn't have a `.handle`. Replace with a polymorphic resolver:

```python
if keyid.startswith("key:"):
    record = store.get_orcid_key(keyid)
    if record is None or record.revoked_at_unix is not None:
        return _reject_401(...)
    if not isinstance(identity, OrcidIdentity) or record.orcid_id != identity.orcid_id:
        return _reject_401(...)
elif keyid.startswith("@"):
    # existing agent path
    ...
else:
    return _reject_401(...)
```

The "ORCID bearer + forged `key:` signature → 401" case is the regression test that must accompany this RRP's PR. Concretely: attacker has Alice's bearer; signs a request with their own (Bob's) bound key. Without the middleware fix, the signature is *valid* (Bob's key signs the request) and the bearer is *valid* (Alice's), but the cross-check would have caught the mismatch. With the bug present, the request gets through.

### 5. CLI flow

```
$ rrxiv login orcid                       # one-time OAuth (existing)
$ rrxiv auth bind-key --label "$(hostname)"
  ✓ generated Ed25519 keypair
  ✓ signed proof-of-possession payload
  ✓ POST /auth/orcid/keys → key:7d8e9f10a1b2c3d4e5f6a7b8c9d0e1f2
  ✓ persisted in OS keyring under (api_base, orcid_id)
$ rrxiv auth keys list
  key:7d8e9f10a1b2c3d4e5f6a7b8c9d0e1f2  blaise-laptop   2026-05-26
$ rrxiv submit --identity orcid build/main.cir.json
  ✓ signed with key:7d8e9f10... (active for 0009-0002-0561-6499)
  → submission 7c4f...: accepted
```

`rrxiv submit --identity orcid` decision tree:

- Bound key in keyring → sign with it (RFC-9421 covered components per RRP-0007).
- No bound key → fall back to bearer-only auth with a `WARNING: this submission is unsigned; bind a key with rrxiv auth bind-key for cryptographic auditability` message.

### 6. Web UI

A new page `https://rrxiv.org/account/keys` (gated on ORCID web session):

- Lists active + revoked keys for the calling identity.
- "Add a key" → modal with a paste-back snippet:
  ```
  rrxiv auth bind-key --label "MyLaptop"
  ```
  The CLI reads the bearer from its own keyring; the web doesn't need to leak the bearer into a copy-pasted command.
- "Revoke" per-row.

Web is the discovery surface; CLI is the *only* surface that knows the private key.

## Security analysis

### Attack 1 — ORCID account hijack

**Attacker** has phished Alice's ORCID OAuth bearer.

**Result without this RRP**: attacker can submit / annotate for 24h as Alice.

**Result with this RRP**: attacker *can also* bind a long-lived key. Once bound, even bearer rotation doesn't remove their access.

**Mitigation**: `POST /auth/orcid/keys` requires the proof-of-possession payload to include `issued_at_unix` within ±300s of server time. An attacker with a stale bearer still passes the auth check but must craft the payload at attack-time, which is fine — that's what PoP is for. The deeper mitigation is **second-factor at binding time**: a future RRP MAY require a one-time code shown on `rrxiv.org/account/keys` that the CLI must echo back, ensuring the user is actively at both the browser and the terminal during binding. Out of scope for v0.1; documented as a known gap.

### Attack 2 — Cross-instance key reuse

**Attacker** runs a hostile rrxiv instance and convinces Alice to bind her key there.

**Result**: attacker now has Alice's public key but not the private. They CAN'T sign as Alice on the canonical instance. They CAN observe which key_id Alice uses (it's instance-scoped server-side, but if Alice reuses the same private key across instances, the public key is observable).

**Mitigation**: `cli/credentials.py` already scopes stored keys per `(api_base, orcid_id)`. Operators should NOT reuse a single Ed25519 key across instances. The CLI generates a fresh keypair per `(api_base, orcid_id)` tuple unless explicitly overridden with `--key-file`.

### Attack 3 — Revoked-key signature replay

**Attacker** has a leaked private key. Alice revokes it. Attacker tries to submit with the old key.

**Result with this RRP**: middleware checks `revoked_at_unix is not None` and rejects with 401.

**Historical verification**: existing annotations signed by the now-revoked key MUST still verify (otherwise revocation would corrupt audit history). The store keeps the record; only the *active set* changes. Read endpoints expose this via the optional `?include_revoked=true` query.

### Attack 4 — Forged key_id

**Attacker** crafts a request with `Signature: keyid="key:0000...0000", ..."` against a non-existent key_id.

**Result with this RRP**: `store.get_orcid_key("key:0000...0000")` returns `None`; middleware rejects with 401.

## Migration

- **Existing agent flow**: untouched. Agent handles continue to work; their keys live in `AgentRecord`, not `OrcidKeyRecord`. No data migration for agents.
- **Existing ORCID bearers**: still work for read endpoints + bearer-auth writes. Users opt into signing by running `rrxiv auth bind-key` at their leisure.
- **SqliteStore schema**: new `orcid_keys` table via `_ensure_schema` (CREATE IF NOT EXISTS); no separate migration script. Mirrors the Sprint-22 pattern when `claim_views` was added.

## Drawbacks

- **CLI complexity**: one more identity primitive (`orcid + key`) to document. Mitigated by `docs/identity.md` (new doc landing alongside this RRP).
- **Server complexity**: the middleware polymorphism is the highest-risk change in the sprint. Mitigated by a dedicated regression test (forged-keyid case) + landing the middleware change in its own commit so revert is surgical.
- **Lost-key recovery**: a user who loses their laptop loses access to that bound key. They can recover by re-`login orcid` + `bind-key` on a new device, but historical signatures from the lost device are unrecoverable. This is a feature: lost-key compromise is bounded by revocation, not by being able to "recover" the key.

## Alternatives considered

1. **Reuse the agent enrollment flow with an `orcid_id` field on AgentRecord.** Rejected — conflates two identity scopes that should remain crisp. An agent handle has continuity guarantees (annotations attributed to `@handle`); an ORCID identity uses the iD as the principal. Sharing one record-shape means a compromise of one credential file leaks both scopes.
2. **`POST /me/keys` instead of `/auth/orcid/keys`.** Rejected — no `/me` namespace exists today; auth lifecycle lives under `/auth`. Mirrors `/auth/agent/{handle}/rotate-key` symmetry.
3. **Short keyids (`key:<8-hex>`).** Rejected — birthday-collision at ~65k keys. 128 bits is the right floor for a public namespace.
4. **Hard-delete on revocation.** Rejected — corrupts historical signature verification. Soft-revoke (tombstone) preserves audit.
5. **Public-key publishing (so external verifiers can resolve `key:` ids without hitting our server).** Deferred to a future RRP. v0.1 doesn't have federation, so the resolver-is-our-server constraint is acceptable.

## Open questions

1. **Should bind-key require a second factor?** Currently relies on bearer auth alone. Acceptance does not require resolution; the RRP notes the gap and signals a follow-up. Recommended follow-up RRP-25 (numbering TBD).
2. **Per-key rate limits?** A bound key with low traffic should arguably get the same write rate as an unbound ORCID bearer. v0.1 applies the same per-identity limit (60 RPM); a future RRP MAY differentiate.
3. **Multi-ORCID per key?** A research team sharing one signing key across multiple ORCIDs? Rejected as a feature; if you need shared signing, use an agent handle that represents the team.

## Impact on existing code and content

- **Schemas**: `orcid_signing_key.schema.json` is new (additive); other schemas unaffected.
- **Spec docs**: `docs/identity.md` (new) describes the full identity lifecycle including this RRP.
- **`rrxiv.cls`**: no change required (the `\rrxivauthor` macro from RRP-0021 already carries the human's ORCID iD; the binding lives in the protocol, not in LaTeX).
- **`rrxiv-python`**: `Store` protocol gains 4 methods; `signature_middleware.py` gains polymorphic resolver; `cli/auth.py` is new; `cli/credentials.py` gains `StoredOrcidKey` dataclass.
- **Existing CIRs**: zero impact.
- **Existing bearer auth**: continues to work; binding is opt-in.

## Reference implementation

To be linked once Sprint 24 PRs land — expected:

- `rrxiv-python#TBD` — Store + middleware + endpoints + CLI.
- `rrxiv-web-official#TBD` — `/account/keys` page + API route.
- `rrxiv#TBD` — this RRP + schema + docs.

## References

- [RFC 9421](https://www.rfc-editor.org/rfc/rfc9421) — HTTP Message Signatures.
- [RRP-0005](0005-token-acquisition.md) — identity types.
- [RRP-0010](0010-agent-key-rotation.md) — agent key lifecycle (this RRP is its human analogue).
- ORCID OAuth 2.0 reference: <https://info.orcid.org/documentation/integration-guide/registering-a-public-api-client/>

## Changelog

- **2026-05-26**: Created during Sprint 24.
