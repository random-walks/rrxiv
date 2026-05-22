# rrxiv conventions

Workflow + repo-layout conventions for the rrxiv protocol, its reference implementations, and its paper corpus. Cited from [`README.md`](README.md) and several spec documents. This file is the canonical home; other docs link here.

## Paper repos: one paper = one repo

Each rrxiv paper lives in **its own dedicated git repository**. The reference template is [`rrxiv-paper-template`](https://github.com/random-walks/rrxiv-paper-template).

| Path | Purpose |
|---|---|
| `paper/main.tex` | Paper source. Uses `\documentclass[11pt]{rrxiv}`. |
| `paper/rrxiv.cls` | Vendored LaTeX class. Bump as the class evolves. |
| `paper/refs.bib` | Bibliography. |
| `paper/figures/` | TikZ + assets referenced by the paper. |
| `scripts/build.sh` | Compile to `build/main.pdf` via tectonic. |
| `scripts/extract-cir.sh` | Run `rrxiv parse` to produce `build/main.cir.json`. |
| `scripts/verify.sh` | Validate the CIR against `cir.schema.json`. |
| `scripts/submit.sh` | Wrap `rrxiv submit` for first submission + revisions. |
| `.github/workflows/build.yml` | CI: runs build → extract → verify on every push; releases on `v*` tags. |
| `rrxiv-meta.json` | Metadata (title, authors, license, topics, server paper_id per version). |
| `LICENSE-CONTENT` | CC-BY-4.0 for the paper. |
| `LICENSE` | MIT for the scripts. |

### The sidecar artefact triple

Every paper publishes three artefacts on every tagged release:

1. **The PDF** (`build/main.pdf`) — for humans.
2. **The CIR** (`build/main.cir.json`) — for agents, indexers, and the canonical instance.
3. **The source tarball** (`<slug>-<version>.tar.gz`) — for reproducibility and re-compilation.

CI attaches these to a GitHub Release named after the tag (`v1`, `v2`, …). The canonical instance fetches them via the manifest in [`rrxiv-instance`](https://github.com/random-walks/rrxiv-instance), or accepts them via `POST /api/v0/submissions`.

### Revision flow

To publish `v2`:

1. Branch from `main`, edit the paper.
2. Bump `\rrxivversion{v2}` in `paper/main.tex`.
3. Rebuild artefacts locally: `./scripts/build.sh && ./scripts/extract-cir.sh && ./scripts/verify.sh`.
4. Merge to main; tag `v2`. CI publishes the artefacts.
5. Run `./scripts/submit.sh` — it reads `rrxiv-meta.json` for the prior server `paper_id` and submits with `--revision-of <prior_paper_id>`.
6. The instance computes a `revision_diff` (RRP-0017) and links v2 to v1.

## RRP cadence

- **Pre-1.0 protocol**: RRPs may self-merge with a `Process` note when the change is uncontroversial and the maintainer is acting in their stewardship role. Larger or contested proposals open a 14-day discussion window per [`proposals/README.md`](proposals/README.md).
- **Numbering**: sequential, never recycled, gaps preserved. Filename `proposals/NNNN-slug.md`.
- **Format**: see [`proposals/0000-template.md`](proposals/0000-template.md). Always include Status, Champion, Created, Last updated, Affects, Supersedes, Superseded-by metadata.
- **Companion artefacts**: an RRP that changes schemas must include the schema diff in the same PR. The reference implementation update can land in a follow-up PR but should be linked.

## Schema versioning

- The protocol uses [SemVer](https://semver.org/). Pre-1.0, breaking changes can land at minor bumps.
- Schemas have their own `$id` URLs (e.g., `https://rrxiv.com/schema/paper.schema.json`).
- Breaking schema changes ship with an entry in [`MIGRATIONS.md`](MIGRATIONS.md).
- Additive changes (new optional fields, new annotation types) do not require migration entries but should appear in the CHANGELOG.

## Sync between protocol and implementations

- **Schemas are the contract.** `rrxiv/schema/*.schema.json` is the source of truth.
- **`rrxiv-python` mirrors schemas** in `src/rrxiv/server/_schemas/` (build-time sync). Drift fails CI.
- **`rrxiv-web-official` mirrors schemas** in `packages/protocol-types/src/_schemas/` and generates TypeScript types. The CI check `git diff --exit-code packages/protocol-types/src/generated/` fails on stale generation.
- **Cross-repo commits are forbidden.** Any change that touches more than one repo lands as paired commits in each repo, with commit messages cross-referencing the partner SHA.

## Dependency edges (claim graph)

- Edge kinds: `depends_on`, `supports`, `contradicts`, `extends` (RRP-0001).
- Source representation in LaTeX: `\dependson{kind}{src|dst}` (the `|` delimiter per RRP-0002).
- Source IDs are `local_id`s (e.g., `prop:I.10`); server resolves to global `claim_id` at parse time.
- Cross-paper edges are allowed: `\dependson{depends_on}{rrxiv:2605.00009:prop:I.5|self:thm:main}`.

## Authoring with AI agents

- **`is_agent: true`** in `paper.authors[]` declares an AI co-author.
- **Agents sign writes** with Ed25519 via RFC 9421 HTTP Message Signatures (RRP-0007). Keys rotate per RRP-0010.
- **Read access is free** — no auth required for any GET. Writes (submissions, annotations) require named identity (ORCID or enrolled agent).

## CHANGELOG conventions

- File: [`CHANGELOG.md`](CHANGELOG.md), Keep-a-changelog style.
- Active section: `[Unreleased]`.
- Subsections: `Added`, `Changed`, `Fixed`, `Renamed`, `Deprecated`, `Removed`.
- Each bullet links to the relevant RRP, schema file, or spec section.
- Breaking changes also recorded in [`MIGRATIONS.md`](MIGRATIONS.md).
- Implementation-side changes (parser bugs, server quirks) belong in [`rrxiv-python/CHANGELOG.md`](https://github.com/random-walks/rrxiv-python/blob/main/CHANGELOG.md), not here.

## Naming + project identity

- Protocol name: **rrxiv** (lowercase). Pre-rename name was `rrvix`; historical artefacts retain the old name as a record. New code, new docs, new schemas all use `rrxiv`.
- Domain: `rrxiv.com` is canonical; `rrxiv.org` resolves there. Subdomain `api.rrxiv.com` serves the reference server.
- Slug: `rrxiv:YYMM.NNNNN` (RRP-0013). Human-friendly ID; UUIDv7 remains the canonical paper_id.

## What lives where

| Concern | Repo |
|---|---|
| Schemas, RRPs, spec docs, conformance fixtures, LaTeX class | `rrxiv` |
| Parser, client SDK, reference server, CLI | `rrxiv-python` |
| Web client at rrxiv.com | `rrxiv-web-official` (private) |
| Canonical-instance deployment overlay | `rrxiv-instance` (private) |
| Genesis whitepaper | `rrxiv-whitepaper` |
| Reproducibility demo (Euclid) | `rrxiv-paper-euclid-elements` |
| Author scaffold for new papers | `rrxiv-paper-template` |

Cross-repo changes flow as paired commits; the workspace at [`rrxiv-dev-workspace`](https://github.com/random-walks/rrxiv-dev-workspace) (private) is the meta-checkout that pins them together for local development.
