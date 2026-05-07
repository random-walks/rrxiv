# RRP-0006 — `rrxiv login` CLI flows

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-06
- **Last updated:** 2026-05-06
- **Affects:** rrxiv-python CLI, end-user UX
- **Supersedes:** none
- **Superseded by:** none

## Summary

Specify the user-facing CLI subcommands and behaviors for minting and managing rrxiv API tokens from a terminal. RRP-0005 locked down the wire format; this RRP says how the typing-on-the-keyboard layer wraps it.

Three subcommands: `rrxiv login orcid`, `rrxiv login agent`, `rrxiv login anonymous`. Plus `rrxiv login status` and `rrxiv logout`.

Tokens persist in the OS-native secure store (macOS Keychain / Windows Credential Locker / Linux Secret Service via [`keyring`](https://pypi.org/project/keyring/)) with a `0600` JSON-file fallback when no system keyring is available.

## Motivation

After RRP-0005, the protocol has wire-format-specified token-acquisition flows and a Python module (`rrxiv.auth`) that implements them. But "implements them" stops at "given a code, exchange it for a token" — the user still has to wire up an OAuth listener, generate an Ed25519 keypair, render hCaptcha, etc. That's not a usable product.

`rrxiv login` is the layer that makes the protocol meet a developer at a terminal:

- Hides the loopback OAuth listener / paste-fallback choice.
- Generates Ed25519 keypairs and signs the enrollment payload.
- Persists tokens (and agent private keys) in the OS keychain.
- Multi-instance: a developer can be logged in to `rrxiv.com` and a self-hosted preview at the same time, with separate credentials per instance.

## Design

### Subcommand summary

| Subcommand | Purpose |
|---|---|
| `rrxiv login orcid` | OAuth dance, persist `BearerToken` keyed on the ORCID iD. |
| `rrxiv login agent --handle @<h>` | Generate Ed25519 keypair, enroll, persist `BearerToken` + private key. |
| `rrxiv login anonymous` | Open browser to challenge URL, paste solved-token back, persist anon `BearerToken`. |
| `rrxiv login status` | Show currently-stored identities for the configured server. |
| `rrxiv logout [--all]` | Clear stored credentials for the current server (or all). |
| All of above | Common `--server URL` flag; defaults to the value of `RRXIV_API_BASE` env var, then to `https://rrxiv.com/api/v0`. |

### ORCID flow (default — loopback)

1. Generate a `state` token (`secrets.token_urlsafe(24)`).
2. Bind a TCP socket to `127.0.0.1:0` to obtain an OS-assigned ephemeral port `P`.
3. Construct `redirect_uri = http://127.0.0.1:P/callback`.
4. Open `{api_base}/auth/orcid/start?redirect_uri=…&state=…` in the user's default browser via `webbrowser.open()`.
5. Spin up a one-shot `http.server` on `127.0.0.1:P`. Wait up to 5 minutes for `GET /callback?code=…&state=…`.
6. Validate `state` matches; otherwise show an error page in the browser and exit.
7. Render a "you can close this window" success page in the browser.
8. Call `rrxiv.auth.exchange_orcid_code(...)` → `BearerToken`.
9. Persist the token via `rrxiv.cli.credentials.store(api_base, token)`.

Per [RFC 8252](https://datatracker.ietf.org/doc/html/rfc8252) §7.3, we use `127.0.0.1` (not `localhost`) as the loopback IP literal. Per RFC 8252 §7.2, the port is OS-assigned, not hardcoded.

### ORCID flow (`--no-browser` fallback)

For SSH sessions, containers, restricted CI environments — anywhere `webbrowser.open()` won't work or 127.0.0.1 isn't reachable from the user's browser:

1. CLI prints the authorization URL with a marker that tells the rrxiv server to use the **paste-back** redirect mode (a server-side render that displays a one-time paste code rather than redirecting to localhost).
2. User opens the URL on whatever device they want, completes OAuth, copies the displayed paste code (e.g., `RRXIV-A4F7-D2K3`).
3. CLI prompts: "Paste the code:". User pastes.
4. CLI exchanges the paste code via `POST /auth/orcid/exchange-paste {code: "..."}` for a `BearerToken`.
5. Persist as in the loopback flow.

The paste-back redirect mode is a server feature — the OAuth `redirect_uri` points at the server itself, which renders an HTML page with the paste code instead of redirecting to a CLI listener. Keeps the OAuth registration with ORCID minimal (one HTTPS redirect URI, no `*.localhost` registrations).

### Agent enrollment

1. CLI prompts for handle (or `--handle @x` flag); validates against `^@[a-z0-9][-a-z0-9]{0,31}$`.
2. Optional `--contact email` flag for ops contact.
3. Generate Ed25519 keypair via `cryptography.hazmat.primitives.asymmetric.ed25519.Ed25519PrivateKey.generate()`.
4. Build canonical enrollment payload via `rrxiv.auth.agent.build_enrollment_payload`.
5. Sign with `sign_enrollment_payload`.
6. POST to `/auth/agent/enroll` via `enroll_agent()` → `BearerToken`.
7. Persist:
   - `BearerToken` under the standard credentials key.
   - The Ed25519 private key bytes under a dedicated agent-signing-key key (separately, since it's used for signing every write, not just auth).

### Anonymous attestation

1. CLI calls `request_anonymous_challenge()` → `AnonymousChallenge`.
2. Prints the rendered challenge URL: `{api_base}/auth/anonymous/render?challenge_id=…&site_key=…`.
3. CLI says: "Open this URL, solve the puzzle, copy the displayed token, paste below."
4. User opens, solves, copies, pastes.
5. CLI calls `verify_anonymous_challenge(...)` → `BearerToken`.
6. Persist.

The render endpoint (server-side HTML that hosts the hCaptcha widget and displays the resulting `h-captcha-response` for copying) is a server v0.1 feature. Sketch only — full design in RRP-0008.

### Token storage

- **Library:** [`keyring`](https://pypi.org/project/keyring/) (`>=25`). macOS Keychain / Windows Credential Locker / Linux Secret Service.
- **Service name:** `"rrxiv"` (string literal). User-resolvable across multiple Python installations.
- **Username (slot key):** `"<api_base>:<identity_type>"`, e.g., `"https://rrxiv.com/api/v0:orcid"`. Lets a single keyring host credentials for multiple servers and multiple identity types simultaneously.
- **Stored value:** JSON: `{"token": "...", "identity_type": "...", "identity": "...", "expires_at_unix": int|null, "created_at_unix": int}`. JSON because keyring stores strings and we want richer metadata; the JSON serialization is internal — callers see a `BearerToken`.
- **Agent private key:** stored under a separate slot, key `"<api_base>:agent:<handle>:private-key"`, value = base64 of the 32-byte raw Ed25519 private key.

### File fallback

When `keyring.get_keyring()` returns the null/fail backend, fall back to `~/.config/rrxiv/credentials.json`:

```json
{
  "version": 1,
  "credentials": {
    "https://rrxiv.com/api/v0": {
      "orcid": {"token": "…", "identity": "0000-0001-…", "expires_at_unix": …},
      "agent": {"@my-bot": {"token": "…", "private_key_b64": "…"}}
    }
  }
}
```

File mode `0600`, parent dir `0700`. Read-modify-write with file-locking via `fcntl.flock` on POSIX (Windows: best-effort — most CLI users are single-process per machine).

### `rrxiv login status`

Lists the slots currently stored for the configured server. Format:

```
$ rrxiv login status
Server: https://rrxiv.com/api/v0
  ORCID:    0000-0001-2345-6789  (expires 2026-05-07 14:23:11Z, 23h 5m left)
  Agent:    @my-extractor        (no expiry; private key on hand)
  Anon:     —                    (no anon token stored)
```

Does not display the token bytes themselves. Storage backend (keyring vs file) noted in `--verbose` output.

### `rrxiv logout`

```
$ rrxiv logout                    # all identity types for current server
$ rrxiv logout --identity orcid   # just one
$ rrxiv logout --all              # all servers, all identity types — explicit
```

For agent identities: deletes both the `BearerToken` slot and the private-key slot (irreversible — the user will need to re-enroll with a fresh handle).

## Alternatives considered

### Device authorization grant ([RFC 8628](https://datatracker.ietf.org/doc/html/rfc8628)) instead of loopback + paste

The device flow is the "correct" OAuth way to handle CLI auth and works in any environment. Rejected for v0.1 because:
- It adds two new endpoints to the server (`/oauth/device_authorization`, modified `/oauth/token`).
- It requires polling — clients call `/oauth/token` until the user completes OAuth, with backoff per the RFC.
- The UX is no better than loopback for the common desktop case.

May revisit in a future RRP if the paste-fallback proves awkward.

### PKCE between CLI and rrxiv server

PKCE protects against another local process intercepting the authorization code. In our design, the rrxiv server is the OAuth client (it talks to ORCID); the CLI never sees the ORCID code, only the rrxiv server's mint. Inter-process interception of the rrxiv-server bearer token at the loopback step is mitigated by `state` (CSRF protection); PKCE between CLI and server wouldn't add meaningful protection given the design.

PKCE between **rrxiv server and orcid.org** is the server's responsibility; out of scope for this RRP.

### Plaintext file storage as primary (no keyring)

Considered for simplicity. Rejected because storing OAuth bearer tokens in plaintext in `~/.config` is inferior to OS-native secure storage on every supported platform, and `keyring` is mature, cross-platform, and a small dep. File fallback exists for headless environments where keyring isn't available.

### Separate `rrxiv-cli` companion CLI

Considered: ship `rrxiv-cli` alongside the library and keep the library import-only. Rejected — the existing `rrxiv` CLI is already established and has many subcommands (`init`, `parse`, `diff`, etc.). Adding `login` is the consistent move.

## Drawbacks

- **CI/headless dev environments hit the paste-fallback path,** which has worse UX than fully automated. Documented; a future device-flow RRP can address this.
- **Browser auto-open behaviour varies** — in some Linux desktop environments without `xdg-open`, `webbrowser.open()` fails. Detect and fall back to printing the URL.
- **Agent private keys stored in keyring are exportable.** A user with shell access can extract them. This is true of any local key storage; mitigation is OS-level access control. Documenting this trade-off in `rrxiv.cli.credentials`'s docstring.
- **Token expiry not auto-refreshed.** RRP-0005 left refresh tokens out of v0.1; users re-`login` on expiry.

## Impact on existing code and content

| Surface | Change |
|---|---|
| `rrxiv-python/src/rrxiv/cli/login.py` | New module: subcommands wiring. |
| `rrxiv-python/src/rrxiv/cli/credentials.py` | New module: keyring + file fallback storage. |
| `rrxiv-python/src/rrxiv/cli/app.py` | Register the new subcommands with the existing typer app. |
| `rrxiv-python/pyproject.toml` | Add `keyring>=25` to base deps. `cryptography` already in `[agent]` extra (RRP-0005). |
| `rrxiv-python/src/rrxiv/doctor.py` | New checks: `keyring` available, OS keychain backend works. |
| Server (RRP-0008) | Provide the paste-redirect render endpoint + the anonymous-render endpoint that the CLI's fallback flows expect. |

## Open questions

- **Is the paste-redirect endpoint worth maintaining for ORCID forever, or is RFC 8628 device flow a better fallback long-term?** For v0.1 paste is simple. v0.2 may add device flow as the primary fallback.
- **Where does an agent's signing key live for cross-machine use?** Today the keyring is per-machine; an agent that runs on three CI workers needs the same private key on all three. RRP-0007 needs to address this (key import/export, or fanning a single key out via secrets management).

## Reference implementation

`rrxiv-python` `src/rrxiv/cli/login.py`, branch `feature/cli-login-sigs-server`.

## References

- [RFC 8252 — OAuth 2.0 for Native Apps](https://datatracker.ietf.org/doc/html/rfc8252)
- [RFC 8628 — OAuth 2.0 Device Authorization Grant](https://datatracker.ietf.org/doc/html/rfc8628) (alternative considered)
- [RRP-0005 — Token-acquisition flows](0005-token-acquisition.md)
- [`keyring`](https://pypi.org/project/keyring/) library
- [`webbrowser`](https://docs.python.org/3/library/webbrowser.html) stdlib module

## Changelog

- **2026-05-06**: Created. Status: Accepted.
