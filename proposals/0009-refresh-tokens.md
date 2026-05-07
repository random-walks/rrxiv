# RRP-0009 — Bearer-token refresh

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-06
- **Last updated:** 2026-05-06
- **Affects:** API surface, rrxiv-python client, spec/0007-api.md
- **Supersedes:** none
- **Superseded by:** none

## Summary

Add `POST /auth/refresh` so a client can exchange a still-valid bearer token for a fresh one with a renewed TTL. Closes the open question RRP-0005 §"Open questions" punted: today, tokens expire and the user re-runs `rrxiv login` from scratch.

## Motivation

For long-running agents and for ORCID identities used across multi-day workflows, the v0.1 "expire-and-relogin" model is the wrong UX. Refresh tokens are standard for OAuth bearer flows and let clients keep working without user interaction.

The simpler design — versus full OAuth refresh — is "extend the token's TTL by minting a new bearer". The old token is revoked atomically; the new token has the same identity tier and a fresh `expires_in_seconds`.

## Design

### Wire format

```
POST /auth/refresh
Authorization: Bearer <still-valid-token>

→ 200
{
  "token": "<new-opaque-bearer>",
  "expires_in_seconds": 86400
}
```

No body. The Authorization header is the entire input; the server reads it, looks up the token record, mints a fresh one, and revokes the old.

### Server invariants

1. Old token must still be valid (not revoked, not expired, not rate-limit-blocked).
2. Refresh is idempotent within reason: a server MAY refuse refresh if the old token is more than 90% through its TTL (anti-thrash); v0.1 reference server has no minimum-age check, but documents the option.
3. New token has the same identity tier and a fresh `expires_in_seconds` matching the tier's TTL config.
4. Old token is revoked at the moment of new-token issuance.
5. Anonymous tokens cannot be refreshed (anti-abuse; the user re-solves a CAPTCHA).
6. Refresh consumes the same rate-limit budget as a write (one tick).

### Client side

`RrxivClient.refresh_auth()` returns the new `BearerToken` and updates the client's cached auth header. An opt-in `auto_refresh=True` constructor flag triggers a refresh when the local clock indicates >80% of the TTL has elapsed (relative to issued_at the client tracks).

CLI: `rrxiv login refresh` is a thin wrapper that loads the stored bearer for the configured server, calls refresh, and writes back. Useful in cron-driven workflows.

### Stored bearers

`rrxiv.cli.credentials.StoredBearer` already carries `expires_at_unix`; the refresh flow updates that field on success. No schema change.

## Alternatives considered

### Two-token model (access + refresh)

OAuth's standard pattern: a short-lived access token + a long-lived refresh token, separately stored. Strictly correct but adds complexity (two storage slots per identity, refresh-token-only endpoint, separate revocation flows). v0.1 uses the simpler "single rolling bearer" because the threat model is symmetric — a leaked bearer and a leaked refresh token have similar blast radius for our use cases.

If we add granular permissions later (e.g., "this token can only read"), separating access from refresh becomes useful and we'll revisit.

### Sliding TTL on every request

Auto-extend the token on each successful authenticated call. Simpler from the client's POV but obscures session age, complicates revocation, and is nonstandard. Explicit `/auth/refresh` is the right move.

### Refresh-only-once-per-window

Forbid refresh more than once per N minutes to prevent thrash. v0.1 doesn't enforce this; the rate limiter does the job indirectly.

## Drawbacks

- **Refresh tokens raise the cost of a leaked bearer** modestly: an attacker can keep extending. Mitigation: explicit revocation on the original ORCID/agent enrollment endpoint can be added if needed (a future RRP).
- **CLI must track issued_at locally** to know when to auto-refresh, since `expires_at_unix` is stored but `issued_at` was previously implicit. We update `StoredBearer` to carry both (already does as of RRP-0006).

## Impact on existing code and content

| Surface | Change |
|---|---|
| `schema/api.openapi.yaml` | New `POST /auth/refresh` route |
| `spec/0007-api.md` §"Auth model" | Cross-reference RRP-0009 |
| `rrxiv-python/src/rrxiv/server/auth/router.py` | New route handler |
| `rrxiv-python/src/rrxiv/auth/refresh.py` | New helper `refresh_token(api_base, current_bearer)` |
| `rrxiv-python/src/rrxiv/client/{client,async_client}.py` | `auto_refresh=True` flag + `refresh_auth()` method |
| `rrxiv-python/src/rrxiv/cli/login.py` | `rrxiv login refresh` subcommand |

## Open questions

- **Should refresh be available for tokens that have already expired but were valid recently?** v0.1 says no — once expired, full re-login. A grace window is a future RRP.

## Reference implementation

`rrxiv-python` `feature/cli-login-sigs-server`.

## References

- [RRP-0005 — Token-acquisition flows](0005-token-acquisition.md)
- [RFC 6749 §6](https://datatracker.ietf.org/doc/html/rfc6749#section-6) — OAuth 2.0 refreshing an access token

## Changelog

- **2026-05-06**: Created. Status: Accepted.
