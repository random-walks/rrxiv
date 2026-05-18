# RRP-0011 — SQLite persistent store

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-06
- **Last updated:** 2026-05-06
- **Affects:** rrxiv-python reference server
- **Supersedes:** none
- **Superseded by:** none

## Summary

Add `SqliteStore` — a concrete implementation of the `Store` Protocol from RRP-0008 backed by SQLite. Closes the open question RRP-0008 §"Open questions" punted: today the reference server is in-memory only and loses everything on restart.

## Motivation

The reference server is increasingly useful for local development (`rrxiv serve` + `rrxiv login` end-to-end tests), but losing all state on restart limits its utility. SQLite is the right next step:

- Stays single-file, portable, no daemon to install.
- Supported on every platform Python runs on (`sqlite3` is stdlib).
- Adequate for single-node, modest-scale deployments — exactly the "self-hosted preview instance" use case the reference server is shaped for.
- Storage decision is encapsulated behind the `Store` Protocol; routers don't change.

## Design

### Configuration

```
RRXIV_STORE_URL=memory://                   # default; in-process MemoryStore
RRXIV_STORE_URL=sqlite:///./rrxiv.db        # SQLite at ./rrxiv.db
RRXIV_STORE_URL=sqlite:///:memory:          # ephemeral SQLite (used by tests)
```

`ServerSettings.store_url` parses the URL; `build_app(store=...)` accepts an explicit store override (for tests).

### Schema

One table per dataclass in `store/protocol.py`:

```sql
CREATE TABLE tokens (
  token TEXT PRIMARY KEY,
  identity_type TEXT NOT NULL,
  identity_payload TEXT NOT NULL,  -- JSON of the identity dataclass
  issued_at_unix INTEGER NOT NULL,
  expires_at_unix INTEGER NOT NULL
);
CREATE INDEX idx_tokens_expires ON tokens(expires_at_unix);

CREATE TABLE agents (
  handle TEXT PRIMARY KEY,
  public_key_b64 TEXT NOT NULL,
  contact TEXT,
  enrolled_at_unix INTEGER NOT NULL
);

CREATE TABLE papers (id TEXT PRIMARY KEY, payload TEXT NOT NULL);
CREATE TABLE cirs   (id TEXT PRIMARY KEY, payload TEXT NOT NULL);
CREATE TABLE claims (id TEXT PRIMARY KEY, payload TEXT NOT NULL);
CREATE TABLE annotations (id TEXT PRIMARY KEY, payload TEXT NOT NULL);

CREATE TABLE sources (paper_id TEXT PRIMARY KEY, blob BLOB NOT NULL);
CREATE TABLE snapshot_blobs (snapshot_id TEXT PRIMARY KEY, blob BLOB NOT NULL);

CREATE TABLE challenges (
  challenge_id TEXT PRIMARY KEY,
  payload TEXT NOT NULL
);
CREATE TABLE paste_codes (
  code TEXT PRIMARY KEY,
  payload TEXT NOT NULL
);

CREATE TABLE idempotency (
  token TEXT NOT NULL,
  key TEXT NOT NULL,
  body_sha256 TEXT NOT NULL,
  response_status INTEGER NOT NULL,
  response_body TEXT NOT NULL,
  created_at_unix INTEGER NOT NULL,
  PRIMARY KEY (token, key)
);

CREATE TABLE rate_window (
  bucket TEXT PRIMARY KEY,
  timestamps TEXT NOT NULL  -- JSON array
);

CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
-- key='latest_snapshot' → JSON of the manifest
-- key='schema_version' → integer
```

The "everything as JSON in a single TEXT column" approach keeps the schema simple and avoids ORM complexity. Where the dataclass has fields the routers query on (e.g., `expires_at_unix` for sweep), we duplicate those into typed columns.

### Migrations

Stamped via `PRAGMA user_version`. v0.1 schema is `user_version=1`; future migrations bump and run incremental SQL. Crashes mid-migration are detectable; recovery is "delete the db and re-init" for v0.1 (acceptable for a reference server). Real Alembic-style migrations are a future RRP.

### Concurrency

SQLite has reader/writer locks. v0.1 reference server uses a single-process uvicorn; concurrent writes serialize. Multi-process deployments need a Postgres backend (future RRP).

### Connection lifecycle

A single `sqlite3.Connection` per server instance, shared across requests via `threading.local` for safety on the FastAPI thread pool. We use `isolation_level=None` and explicit `BEGIN/COMMIT` so writes don't autocommit between dataclass-row updates.

### Tests

A parameterised `tests/test_store_backends.py` runs the same set of operations against both `MemoryStore` and `SqliteStore` (using `:memory:`). Anything one supports the other must too.

## Alternatives considered

### Roll our own JSON-on-disk

Considered (a single big JSON file). Rejected — easy to corrupt on partial writes, no concurrency story, no querying.

### LMDB / RocksDB

Faster than SQLite for some workloads but adds a native dep and ergonomic complexity. SQLite is the right "first persistent backend".

### Postgres directly

Right answer for the canonical rrxiv.com instance; wrong answer for the reference server's "single file, drop-in" use case. Future RRP for the Postgres backend.

## Drawbacks

- **No multi-process support.** Single-uvicorn-worker only.
- **Migrations are minimal.** v0.1 ships with schema_version=1; future schema changes require a deliberate version bump and migration code.
- **Blob storage in SQLite is suboptimal at scale** — large source archives bloat the database. v0.1 reference server is bounded; production deployments switch to a filesystem-backed `Store` that puts blobs on disk.

## Impact on existing code and content

| Surface | Change |
|---|---|
| `rrxiv-python/src/rrxiv/server/store/sqlite.py` | New impl, ~400 LOC |
| `rrxiv-python/src/rrxiv/server/store/__init__.py` | Export `SqliteStore`, factory function |
| `rrxiv-python/src/rrxiv/server/settings.py` | New `store_url` field |
| `rrxiv-python/src/rrxiv/server/app.py` | `build_app(store=...)` honours `settings.store_url` |
| `rrxiv-python/src/rrxiv/cli/serve.py` | `--store sqlite:///...` flag |
| `rrxiv-python/tests/test_store_backends.py` | New parameterised test |

## Open questions

- **Connection pool sizing for SQLite.** v0.1 uses a single connection; for higher concurrency we may want a small WAL-mode pool.
- **Vacuum / sweep.** Expired tokens, consumed challenges, old idempotency entries — none are auto-deleted today. Future RRP can add a periodic sweep task.

## Reference implementation

`rrxiv-python` `feature/cli-login-sigs-server`.

## References

- [RRP-0008 — Reference server](0008-reference-server.md)

## Changelog

- **2026-05-06**: Created. Status: Accepted.
