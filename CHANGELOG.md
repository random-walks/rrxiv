# Changelog — rrxiv protocol

This file tracks substantive changes to the rrxiv protocol — schemas, spec docs, the LaTeX class, the conformance suite. Implementation-side changes (the rrxiv-python client/parser/CLI) are tracked in [`rrxiv-python/CHANGELOG.md`](https://github.com/random-walks/rrxiv-python/blob/main/CHANGELOG.md).

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The protocol itself uses [SemVer](https://semver.org/spec/v2.0.0.html); pre-1.0 breaking changes can land at any minor version.

For breaking schema changes, see [`MIGRATIONS.md`](MIGRATIONS.md) for the migration recipe.

## [Unreleased]

### Added

- **Conformance test fixtures**: `multi-claim`, `with-edges`, `contradicts`, `multi-author` (was: only `minimal`). Cross-implementation parser conformance now exercises ordinal pairing, all four edge kinds, and multi-author + agent co-author patterns.
- **`Section` and `Figure` standalone schemas** (`schema/section.schema.json`, `schema/figure.schema.json`). Were inlined as `$defs` of `cir.schema.json` until v0.2-protocol; now `cir.schema.json` `$ref`s them.
- **`schema/api.openapi.yaml`** — OpenAPI 3.1 sketch of the HTTP API. 17 endpoints across papers / claims / annotations / snapshots / search / submissions. Companion prose in [`spec/0007-api.md`](spec/0007-api.md).
- **`MAINTAINERS.md`** at the repo root. Referenced from RRPs and `spec/0008-governance.md`.
- **`spec/0005-submission.md`**, **`spec/0006-annotations.md`**, **`spec/0007-api.md`**, **`spec/0008-governance.md`**: promoted from stub to v0.1 draft. Each ~1.5–2k words covering the locked design, open questions, and migration paths.
- [RRP-0001](proposals/0001-claim-graph.md): retroactive — formal record of the v0.1 claim graph design (claims as the unit, the four edge types, declaration paths, immutability).
- [RRP-0002](proposals/0002-edge-marker-delimiter.md): the cls's edge-marker `src`/`dst` separator changed from `:` to `|`. Parsers should accept both for back-compat. **Status: Accepted.**
- [RRP-0003](proposals/0003-whitepaper-formatting.md): whitepaper title and date stripped of inline cosmetic LaTeX formatting; the source now matches the CIR. **Status: Accepted.**

### Changed

- **`rrxiv.cls` v0.1 → v0.2**: edge-marker delimiter is `|` (RRP-0002).
- **Whitepaper v0.1 source**: title and date blocks no longer carry `\Large`, `\large`, `\\[0.2em]`, `\small` macros. Re-rendered PDF is slightly different visually (article-class default sizing); CIR title is now clean prose without needing the parser's TeX-to-text pass.
- **DOI regex in `citation.schema.json`**: now allows lowercase letters; the prior uppercase-only regex would reject most real-world DOIs.

### Fixed

- The whitepaper's inline `\begin{thebibliography}` block is now extractable by the parser (was: 0 citations in CIR; now: 17). This is a parser-side fix in rrxiv-python but worth recording here because it affects the canonical whitepaper's CIR.

### Renamed

- **rrvix → rrxiv across the entire protocol surface.** Schemas, IDs, the LaTeX class, the sidecar marker prefix, repository names. The user owns rrxiv.com; rrxiv riffs on arXiv (the protocol this is positioning against). Pre-rename `RRVIX:` markers and `.rrvix.aux` extensions remain parseable on the rrxiv-python side with a deprecation warning.

## [v0.1] — first protocol surface

The initial protocol artifacts, all v0.1 / v0.1.0 / v0.x as appropriate.

- Whitepaper v0.1 (15 pp), itself a valid rrxiv submission.
- `rrxiv.cls` v0.1 LaTeX class with semantic environments and the sidecar `\write` channel.
- JSON Schemas v0.1.0: `cir`, `paper`, `claim`, `annotation`, `citation`. CIR composes the others via `$ref`.
- Spec documents 0001 (overview), 0002 (CIR), 0003 (claim graph), 0004 (TeX template) at v0.1 draft.
- Bootstrap milestones 0.1 through 0.7 (M0.7 — public launch — pending).
- MkDocs Material docs site, GitHub Pages auto-deploy (gated on billing).
- CI workflows: `compile-whitepaper.yml`, `validate-schemas.yml`, `conformance-tests.yml`, `docs.yml`.
- RRP process: `proposals/README.md` + canonical template `proposals/0000-template.md`.
- LICENSE (MIT) and LICENSE-CONTENT (CC-BY-4.0).
