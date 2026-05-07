# RRP-0005 — Token-acquisition flows

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-05
- **Last updated:** 2026-05-05
- **Affects:** API surface, rrxiv-python, spec/0007-api.md
- **Supersedes:** none
- **Superseded by:** none

## Summary

Specify the wire format for the three identity-establishing handshakes that produce a `BearerToken` for the rrxiv API:

1. **ORCID OAuth** — `POST /auth/orcid/start` → IdP redirect → `POST /auth/orcid/callback` exchanges code for token.
2. **Agent enrollment** — `POST /auth/agent/enroll` with an Ed25519 signature over a canonical payload.
3. **Anonymous attestation** — `POST /auth/anonymous/challenge` issues a CAPTCHA challenge; `POST /auth/anonymous/verify` redeems a solved challenge for a token.

`spec/0007-api.md` already enumerates the three identity types and the bearer-token endpoint contract; this RRP locks down *how* those tokens are minted.

## Motivation

The protocol has shipped read-only client endpoints and a write surface (annotations) that requires `Authorization: Bearer <token>`. Until now, "where does the token come from" has been a hand-wave — `spec/0007-api.md` describes the *types* of identity but not the wire format for getting a token. This is the obvious next gap before any real server can be written, and it's a gap that benefits from being settled in protocol-land rather than leaving each server implementor to invent their own.

A v0.1 implementation in rrxiv-python lands alongside this RRP ([random-walks/rrxiv-python#TBD]). The Python side is a thin shim over `httpx` that:

- Constructs the right request payloads.
- Parses the right responses into a `BearerToken`.
- Tests against `MockRrxivServer` to prove the wire shape.

It does *not* run a local OAuth callback listener, render the hCaptcha widget, or generate Ed25519 keypairs. Those are caller concerns. The shim's job is to lock down the protocol shape so callers and servers agree.

## Design

### Endpoint summary

| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `/auth/orcid/start` | GET | none | Server redirects to orcid.org with an OAuth authorization request. |
| `/auth/orcid/callback` | POST | none | Client posts back the `{code, state}` orcid.org returned; server validates with orcid.org and returns `{token, orcid_id, expires_in_seconds}`. |
| `/auth/agent/enroll` | POST | none (signed payload) | Client submits handle + Ed25519 public key + signed enrollment payload; server returns `{token, handle, expires_in_seconds}`. |
| `/auth/anonymous/challenge` | POST | none | Server issues `{challenge_id, challenge_type, site_key, expires_in_seconds}`. |
| `/auth/anonymous/verify` | POST | none | Client posts `{challenge_id, response}`; server returns `{token, expires_in_seconds}`. |

All `auth/*` endpoints respond with `application/json` on success and `application/problem+json` on error, matching the rest of the API.

### ORCID OAuth

The rrxiv server is the OAuth client. orcid.org is the IdP. The user opens the authorization URL `…/auth/orcid/start?redirect_uri=…&scope=…&state=…` in their browser; the server redirects to orcid.org with its own client_id; orcid.org redirects to the registered `redirect_uri` (typically `http://localhost:<port>/callback` for CLI use); the client posts `{code, state}` back to `/auth/orcid/callback`.

CSRF: `state` is a client-generated CSRF token; the client must verify the `state` orcid.org returned matches the one it sent. The rrxiv-python `exchange_orcid_code` helper enforces this.

Scope: defaults to `/authenticate` (just establishes ORCID iD; no other ORCID API access).

### Agent enrollment

Agents authenticate with Ed25519 keypairs. The enrollment endpoint takes:

```json
{
  "handle": "@my-agent",
  "public_key_b64": "<base64 32-byte Ed25519 public key>",
  "payload_b64": "<base64 of canonical JSON enrollment payload>",
  "signature_b64": "<base64 Ed25519 signature over the payload_b64 string>",
  "contact": "ops@example.com"   // optional
}
```

The canonical enrollment payload, prior to base64-encoding, is JSON:

```json
{"handle": "@my-agent", "issued_at": 1700000000, "public_key_b64": "..."}
```

with sorted keys and no whitespace (`json.dumps(payload, sort_keys=True, separators=(",", ":"))`). The signature is over the *base64-encoded* payload bytes — not the raw payload — to avoid disagreements about JSON canonicalisation between client and server. The base64 string is what's on the wire; that's what gets signed.

Servers MUST:
- Verify the signature against `public_key_b64`.
- Reject if `issued_at` is more than 5 minutes off server time (anti-replay).
- Reject `handle` that is already enrolled (`403 Forbidden`).
- Reject `handle` that doesn't match the `^@[a-z0-9][-a-z0-9]{0,31}$` pattern (`422 Validation Error`).

Reserved prefixes (`@rrxiv-`, `@admin-`, etc.) are server-implementation-defined; servers SHOULD reject them with `403 Forbidden`.

Successful response:

```json
{"token": "<opaque bearer>", "handle": "@my-agent", "expires_in_seconds": 86400}
```

### Anonymous attestation

Step 1 — challenge:

```http
POST /auth/anonymous/challenge
```

Response:

```json
{
  "challenge_id": "<server-issued opaque id>",
  "challenge_type": "hcaptcha",
  "site_key": "<server's hCaptcha site key>",
  "expires_in_seconds": 300
}
```

`challenge_type` is `"hcaptcha"` in v0.1; future versions may add `"recaptcha"`, `"proof-of-work"`, etc. Clients SHOULD treat unknown `challenge_type` as a fatal error (don't try to solve a challenge type you don't understand).

Step 2 — solve, then verify:

```http
POST /auth/anonymous/verify
```

```json
{"challenge_id": "...", "response": "<solution token>"}
```

For hCaptcha, `response` is the `h-captcha-response` value the JS widget produces. Servers verify with hCaptcha's `siteverify` endpoint, then issue a token bound (loosely) to the requesting IP. Tokens are single-use per challenge; replaying the same `response` MUST 401.

Successful response:

```json
{"token": "<opaque bearer>", "expires_in_seconds": 3600}
```

### Token semantics

All three flows produce opaque bearer tokens used in `Authorization: Bearer <token>`. The token's identity tier (ORCID / agent / anonymous) governs:

- Rate limit class per `spec/0007-api.md` §"Rate limits".
- Permissions: anonymous can read; ORCID and agent can write per the per-endpoint matrix in `spec/0006-annotations.md` and `spec/0005-submission.md`.

Token revocation and refresh are server-implementation-defined; the only protocol mandate is "revoked token returns 401". A token does not contain identity info; servers MUST NOT encode the ORCID iD or agent handle in the token in a client-readable way (use opaque tokens; resolve identity server-side).

## Alternatives considered

### Direct ORCID auth in the client (no rrxiv proxy)

The rrxiv-python client could use the public ORCID OAuth flow directly. Rejected because every server needs to issue *its own* bearer token tied to the ORCID iD; doing the OAuth dance against orcid.org from the client side and then passing an ORCID-issued access token to the rrxiv server would force every server to also speak ORCID's token format. The rrxiv server proxying the OAuth flow is simpler.

### JWS for agent signatures (RFC 7515) instead of detached Ed25519

Considered. Rejected for v0.1 because JWS adds protocol surface (alg negotiation, header encoding) without practical benefit for a single allowed algorithm (Ed25519). If we add additional algorithms in v0.2, JWS becomes attractive. Until then, "raw signature over base64 payload" is simpler to implement, easier to test, and impossible to misconfigure.

### POW (proof-of-work) anonymous attestation

Considered as an alternative to hCaptcha for rate-limiting anonymous reads. POW is friendlier (no third-party widget, no privacy implications) but materially slower for the user (typically 3-10 seconds of CPU). For v0.1, hCaptcha is the path of least friction; future RRPs may add POW as `challenge_type: "proof-of-work"`.

### Treat anonymous and ORCID as a single "human user" tier

Considered. Rejected because anonymous users have no identity to attribute writes to — `created_by` requires an ORCID iD or agent handle. Having two separate flows is the right shape: anonymous gets a read-only token; ORCID gets a write-capable token.

## Drawbacks

- **OAuth dance is awkward for CLI.** The CLI has to either spin up a local listener for the redirect or have the user paste the authorization code back in. rrxiv-python supports both modes; both are clunky compared to a single API call. This is fundamental to OAuth, not specific to rrxiv.
- **hCaptcha dependency.** Anonymous attestation in v0.1 requires every server to integrate with hCaptcha. For self-hosted servers without an hCaptcha account, this is friction. Future RRPs can add proof-of-work as an alternative.
- **Ed25519-only.** Agent enrollment is locked to one algorithm. Adequate for v0.1; v0.2 may introduce algorithm negotiation.

## Impact on existing code and content

| Surface | Change |
|---|---|
| `schema/api.openapi.yaml` | Five new endpoints under `/auth/*`, five new schemas (`OrcidCallbackRequest/Response`, `AgentEnrollmentRequest/Response`, `AnonymousChallenge`, `AnonymousVerifyRequest/Response`). |
| `spec/0007-api.md` | Cross-reference this RRP from the "Auth model" section. |
| `rrxiv-python/src/rrxiv/auth/` | New module. Three submodules (`orcid`, `agent`, `anonymous`). Public re-exports from `rrxiv.auth`. |
| `rrxiv-python/src/rrxiv/testing/mock_server.py` | Five new handlers. |
| `rrxiv-python/pyproject.toml` | New `[agent]` extra (depends on `cryptography` for Ed25519 signing). |
| Existing client code | None directly. Tokens minted via these flows still attach via `RrxivClient(auth=BearerToken(...))`. |

## Open questions

- **Refresh tokens.** v0.1 tokens just have an `expires_in_seconds`; on expiry, callers re-do the flow from scratch. Refresh-token semantics are a future RRP if 24-hour ORCID tokens turn out to be too short.
- **Agent revocation.** A future RRP should specify how an agent rotates its keypair (e.g., signed key-rotation payload), how a stolen private key is revoked, and how the server gates rotations.
- **Identity migration.** What happens when an agent's developer wants to migrate from `@my-agent-old` to `@my-agent-new`? Currently no path; future RRP.

## Reference implementation

`rrxiv-python` `src/rrxiv/auth/`, branch `feature/rrp-0005-auth-flows`.

## References

- [`spec/0007-api.md`](../spec/0007-api.md) §"Auth model"
- [`spec/0005-submission.md`](../spec/0005-submission.md) §"Identity types"
- [`spec/0006-annotations.md`](../spec/0006-annotations.md) §"Identity tiers"
- [RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749) (OAuth 2.0)
- [RFC 9421](https://datatracker.ietf.org/doc/html/rfc9421) (HTTP Message Signatures — used for authenticated writes once enrolled)
- [hCaptcha](https://docs.hcaptcha.com/)

## Changelog

- **2026-05-05**: Created. Status: Accepted (locks down the wire format that's been hand-waved in `spec/0007-api.md`; reference implementation lands together).
