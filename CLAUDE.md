# rrxiv — protocol motherepo

The public protocol surface. Start here for spec/schema/RRP work. This file
complements the workspace-level rules in `../../CLAUDE.md` and
`../../.agent-context/README.md` (multi-repo, never-commit-across-repos).

## What's here

- `spec/` — prose specification (numbered docs, e.g. `0005-submission.md`).
- `proposals/` — **RRPs** (IETF-RFC-style). Immutable once `Accepted`; never edit an accepted RRP's decision — write a new RRP that supersedes it. Index + lifecycle in `proposals/README.md`. Next number is the highest + 1.
- `schema/` — the **canonical** JSON Schemas. Everything else vendors these.
- `whitepaper/` — the shipped whitepaper (`.tex`, built with tectonic).
- `rrxiv.cls` + `template/` — the LaTeX class + paper starter.

## Toolchain

- **Schemas:** validate via `tests/schemas/` — `node compile-all.mjs` (compiles all 15, resolves cross-file `$ref`s) + `npm test` (fixtures). Run both before committing a schema change. `npm ci` in `tests/schemas` first if needed.
- **Whitepaper:** `tectonic` / `pdflatex`.
- CI: `validate-schemas.yml`, `conformance-tests.yml`, `compile-whitepaper.yml`, `docs.yml`.

## Conventions

- A schema change needs an **RRP** (per `proposals/README.md` "When you need an RRP" — anything touching id minting, a breaking change, a new top-level field). Bump the schema's own `version` field; add fixtures.
- `schema/api.openapi.yaml` is a **generated** artifact (synced from the rrxiv-python server via `scripts/sync-openapi.sh`). Do NOT hand-edit it; the running server's `app.openapi()` is ground truth.
- Branch protection requires a PR (no required checks). Merge with `gh pr merge --squash --admin`.

## Identifier model (RRP-0029)

`paper.id` = opaque server-minted **UUIDv7** (clients must not parse it). `id_slug` = the citable `rrxiv:YYMM.NNNNN` (RRP-0013). Claim ids are citable + slug-based: `<id_slug>:<local_label>`; every paper-id field is an opaque `string` (no `format: uuid`). See `proposals/0029-paper-id-uuidv7.md`.
