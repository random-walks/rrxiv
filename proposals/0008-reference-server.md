# RRP-0008 — Reference server (FastAPI)

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-06
- **Last updated:** 2026-05-06
- **Affects:** rrxiv-python (new `rrxiv.server` package), conformance, dev experience
- **Supersedes:** none
- **Superseded by:** none

## Summary

Ship a reference HTTP server in `rrxiv-python` that implements the OpenAPI spec end-to-end — `rrxiv.server`. FastAPI-based, in-memory storage, dev-mode stubs for third-party integrations (ORCID, hCaptcha). Real Ed25519 verification for agent auth (RRP-0007).

The reference server is **not** the canonical instance — that's a downstream concern with deployment, real ORCID OAuth registration, persistent storage, etc. The reference server's job is:

1. **Conformance target.** Other-language client implementations have something concrete to test against.
2. **Dev experience.** A developer iterating on `rrxiv-python` can `rrxiv serve` locally and `rrxiv login orcid --server http://127.0.0.1:8000` for a fully self-contained loop.
3. **Cross-validation.** `RrxivClient` driving the reference server through `httpx.ASGITransport` exercises the protocol end-to-end and catches any client/server/spec disagreements.

## Motivation

We have a wire format (RRP-0001 through RRP-0005), schemas (`*.schema.json`), an OpenAPI spec (`schema/api.openapi.yaml`), a Python client, and a Python mock for tests. What's missing is a real server that:

- Validates against the same schemas the client validates against.
- Exercises the entire HTTP path (ASGI dispatch, header parsing, content negotiation) the way a real deployment would.
- Provides a runnable target for `rrxiv login` to talk to in development.

A FastAPI-based reference implementation gives us all of this for less effort than maintaining the existing `MockTransport`-based stand-in plus a hypothetical separate canonical-instance codebase.

## Design

### Layout

```
rrxiv-python/src/rrxiv/server/
├── __init__.py
├── app.py                # FastAPI() construction; main entry
├── settings.py           # BaseSettings — env-driven config
├── deps.py               # Common dependencies (auth resolution, store handle)
├── errors.py             # RFC 9457 problem-details exception handlers
├── auth/
│   ├── __init__.py
│   ├── router.py         # /auth/* routes
│   ├── service.py        # token issuance, OAuth proxying
│   ├── identity.py       # Bearer/agent identity resolution dependency
│   ├── signatures.py     # RFC 9421 verifier (RRP-0007)
│   ├── orcid.py          # ORCID OAuth client (real or dev-stub)
│   └── schemas.py
├── papers/
│   ├── router.py
│   └── service.py
├── claims/
│   ├── router.py
│   └── service.py
├── annotations/
│   ├── router.py
│   ├── service.py
│   └── idempotency.py
├── snapshots/
│   ├── router.py
│   └── service.py
└── store/
    ├── __init__.py       # Store protocol + factory
    └── memory.py         # In-memory Store impl
```

### Storage

`Store` is a `typing.Protocol` declaring just enough operations: `get_paper`, `list_papers`, `add_paper`, `get_claim`, `list_claims`, `add_claim`, `add_annotation`, etc. v0.1 ships `MemoryStore`; persistent backends (SQLite, Postgres) are future RRPs that just provide a different `Store` impl.

Per-domain `service.py` modules are the only callers of `Store`. Routers are thin (parse → call service → return).

### Settings

```python
class ServerSettings(BaseSettings):
    api_base: str = "http://127.0.0.1:8000/api/v0"
    dev_mode: bool = False
    orcid_client_id: str | None = None
    orcid_client_secret: str | None = None
    orcid_token_url: str = "https://orcid.org/oauth/token"
    orcid_authorize_url: str = "https://orcid.org/oauth/authorize"
    orcid_redirect_uri: str | None = None  # registered URL on ORCID; required in prod
    hcaptcha_secret: str | None = None
    hcaptcha_site_key: str = "10000000-ffff-ffff-ffff-000000000001"
    signature_clock_skew_seconds: int = 300
    rate_limit_anonymous_read_rpm: int = 120
    rate_limit_orcid_read_rpm: int = 240
    rate_limit_agent_read_rpm: int = 600
    # …
```

`dev_mode=true` disables real ORCID + hCaptcha calls and uses fake successful responses, suitable for `rrxiv serve` running locally.

### Auth identity resolution

A FastAPI dependency `current_identity()` returns one of `OrcidIdentity | AgentIdentity | AnonymousIdentity | None`:

1. Read `Authorization: Bearer …`.
2. Look up token in store; resolve to identity.
3. For agent identities on a write path: also verify the RFC 9421 signature (RRP-0007) before returning.
4. On failure: raise `Unauthorized` (handled by `errors.py` → RFC 9457).

Routers depend on `current_identity` (or sub-deps `requires_orcid_or_agent`, `requires_agent_with_signature`). Per-route permission matrix is enforced via these deps.

### Idempotency

`Idempotency-Key` header on writes. Per RRP-0001/RFC-9457 mention. Server stores a hash of (`token`, `idempotency_key`, `body_sha256`) → response for 24 hours. Replay with same key + same body returns the cached response; replay with same key + different body returns 409.

### Rate limiting

Sliding-window per token: in-memory deque of timestamps per token, evicted on each call. Simple and correct for v0.1. A real deployment swaps this out for Redis or similar.

### Snapshots

`/snapshots/latest` returns a manifest pointing at a tar.gz under `/snapshots/<id>.tar.gz`. v0.1 reference server: snapshots live on disk in a configured directory. The manifest is generated on demand from in-memory store state when none exists yet.

### Dev mode

When `dev_mode=true`:

- `/auth/orcid/start` skips redirecting to orcid.org and instead immediately redirects to the supplied `redirect_uri` with a fake `code=dev-orcid-code`.
- `/auth/orcid/callback` accepts any code starting with `dev-` and returns a token bound to a configurable dev ORCID iD (defaults to `0000-0001-0000-DEV1`).
- `/auth/anonymous/verify` accepts any non-empty `response` value.
- Real Ed25519 enrollment / signature verification stays on (no dev shortcut) — the crypto path is what we want to actually exercise.

This is the mode `rrxiv serve` uses by default. Production deployments set `dev_mode=false`.

### Cross-tests

`tests/test_server_cross.py` runs `RrxivClient` and `AsyncRrxivClient` against the FastAPI app via `httpx.ASGITransport(app=app)`. Drives:

- All read endpoints with each identity tier.
- Annotation creation under ORCID (bearer-only) and agent (bearer + signature).
- Idempotency replay.
- 401 on missing/invalid bearer; 401 on bad signature; 403 on tier-not-permitted; 404 on missing resources; 422 on schema-invalid bodies.
- Rate-limit hit produces 429 with `Retry-After`.

The cross-tests are the conformance suite for the wire format. If they all pass, client + server agree on every spec point.

### `rrxiv serve` CLI command

```
rrxiv serve [--host 127.0.0.1] [--port 8000] [--dev-mode/--no-dev-mode]
```

Starts uvicorn against the reference server. Defaults: dev mode on, 127.0.0.1, 8000.

## Alternatives considered

### Starlette directly, no FastAPI

FastAPI's pydantic-first request validation is the main reason. Skipping it and writing manual validators duplicates work the existing client-side schemas already do. Net cost of FastAPI as a dep is small (it pulls Starlette + pydantic, both already in the dep tree).

### Express/Node, Go, Rust reference server

Considered. Rejected because the rrxiv-python repo is the reference implementation home; another language's reference would split testing infrastructure. Other-language implementations are welcome — `rrxiv-go`, `rrxiv-rs`, etc. — and use the same OpenAPI + JSON Schemas; they're not protocol-defining.

### Keep the `MockRrxivServer` and not build a real server

`MockRrxivServer` works for client tests but doesn't catch ASGI/HTTP-path issues, doesn't validate the OpenAPI spec is correctly shaped, and can't host `rrxiv login` flows for development. The reference server replaces it (the mock stays for fast tests).

### Persistent store from day one (SQLite)

Considered. Adds migrations / ORM concerns to v0.1 scope. In-memory keeps the surface small and the testing fast; SQLite is a future RRP that provides a separate `Store` impl.

## Drawbacks

- **Adds FastAPI + uvicorn as deps.** Both are mature and widely used; the cost is small. Listed in a `[server]` extra so client-only consumers don't pay it.
- **Reference ≠ canonical.** Users may run the reference server in production without the production-grade features (TLS, multi-process, persistent storage, real CAPTCHA). Documenting clearly that v0.1 reference is a development tool, not a deployment target.
- **In-memory means data lost on restart.** Acceptable for a dev tool; surprising for a user who didn't read the docs. `rrxiv serve` prints a clear warning at startup.
- **Cross-tests slower than mock-based tests.** They exercise more of the stack. ~50ms per cross-test vs ~1ms per mock test. Acceptable; total cross-test suite stays under 10 seconds.

## Impact on existing code and content

| Surface | Change |
|---|---|
| `rrxiv-python/src/rrxiv/server/` | New package, ~1500 LOC. |
| `rrxiv-python/src/rrxiv/cli/serve.py` | New `rrxiv serve` subcommand. |
| `rrxiv-python/pyproject.toml` | `[server]` extra: `fastapi>=0.110`, `uvicorn[standard]>=0.30`. `[dev]` includes them. |
| `rrxiv-python/tests/test_server_*.py` | New test modules: per-router unit tests + cross-tests. |
| `rrxiv-python/src/rrxiv/testing/mock_server.py` | Stays as a fast in-process mock for client unit tests. Annotated as such. |
| Schema / spec | None — the reference server implements the existing spec. |

## Open questions

- **Where does the reference server live long-term?** Two options:
  1. Stays in `rrxiv-python` as a sibling package. Cheap to maintain, single repo.
  2. Forks into a `rrxiv-server` repo if it grows beyond a reference role.

  v0.1 picks (1). Revisit when the server gets persistent storage and starts to look canonical-shaped.
- **Conformance harness packaging.** The cross-tests are the de facto conformance suite. A future RRP could extract them into a `rrxiv-conformance` package that runs against any server URL — useful for testing other-language implementations.

## Reference implementation

`rrxiv-python` `src/rrxiv/server/`, branch `feature/cli-login-sigs-server`.

## References

- [FastAPI](https://fastapi.tiangolo.com/)
- [fastapi-best-practices](https://github.com/zhanymkanov/fastapi-best-practices) — production layout
- [RRP-0005 — Token-acquisition flows](0005-token-acquisition.md)
- [RRP-0007 — HTTP Message Signatures](0007-message-signatures.md)
- [`schema/api.openapi.yaml`](../schema/api.openapi.yaml)

## Changelog

- **2026-05-06**: Created. Status: Accepted.
