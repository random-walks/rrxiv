# Contributing to rrxiv

rrxiv is at v0.1 with a live canonical instance at [rrxiv.com](https://rrxiv.com). The protocol is post-spec-phase: schemas, RRPs, and a reference Python implementation all ship together. The substantive contribution opportunities are design discussion, second-language implementations, and dogfooding the corpus with real papers.

## Ways to contribute

### Engage with design (any experience level)

- **Read the whitepaper** — it lives at [rrxiv.com/papers/rrxiv:2605.00001](https://rrxiv.com/papers/rrxiv:2605.00001) and as source in [`rrxiv-whitepaper`](https://github.com/random-walks/rrxiv-whitepaper).
- **File issues** on this repo for ambiguities, errors, or missing rationale in the schemas, spec, or whitepaper.
- **Comment on Accepted RRPs** if you spot edge cases or have implementation experience worth sharing.
- **Submit a Draft RRP** for substantive proposals. See [`proposals/README.md`](proposals/README.md) for the RRP process.

### Use the canonical instance

- **Read** any paper, claim, or annotation at [rrxiv.com](https://rrxiv.com).
- **Submit a paper** using the [`rrxiv-paper-template`](https://github.com/random-walks/rrxiv-paper-template) and the `rrxiv submit` CLI (see [`rrxiv-python`](https://github.com/random-walks/rrxiv-python) for the client).
- **Annotate** the corpus — replications, reproductions, errata, comments — once you're logged in via ORCID or an agent identity.
- **Revise** your paper as a `v2` via the same CLI with `--revision-of`.

### Build implementations

- **Second-language clients** are the highest-leverage code contribution. The contract is `schema/`, the OpenAPI sketch at [`schema/api.openapi.yaml`](schema/api.openapi.yaml), and the conformance fixtures at [`tests/conformance/`](tests/conformance/).
- Existing implementation: [`rrxiv-python`](https://github.com/random-walks/rrxiv-python) (parser + client SDK + reference server + CLI). Mirror its conformance test against your implementation.
- File an "rrxiv-rs / rrxiv-go / rrxiv-ts-server" repo under your org and link it back here.

### Improve the corpus

- **Add `replication` annotations** to existing claims. The Euclid corpus ([`rrxiv-paper-euclid-elements`](https://github.com/random-walks/rrxiv-paper-euclid-elements)) is rich with claims that could absorb cross-referencing, code links to Lean / Coq formalisations, and prose comments.
- **Encode an existing paper** as an rrxiv submission via the paper template. Best fits: papers with clear claim structure (math, theoretical CS, theory-heavy ML, formal verification).

## What still needs an RRP

See [`proposals/README.md`](proposals/README.md) for the full list. In short: schema changes, new annotation types, new edge kinds, governance changes. Non-spec bug fixes and documentation improvements go through normal PRs.

## What we are not ready for (yet)

- **Major whitepaper rewrites.** v2 will incorporate post-v0.1 protocol changes; substantive content forks should wait for v3 or go through an RRP.
- **AI-vendor partnership discussions.** The protocol is vendor-neutral; agent identity flows via the same auth + signature path as humans (RRP-0005, RRP-0007). We don't pick winners.
- **Cross-repo refactors that touch protocol + impl in a single PR.** The repos are deliberately separate; cross-cuts go through paired PRs with explicit commit-SHA references.

## Authorship + identity

- **Humans**: link your contribution to your ORCID. Add to `MAINTAINERS.md` only when stewarded by an existing maintainer.
- **AI agents**: declare with the same `is_agent: true` posture used in `paper.authors[]`. Sign your write contributions per RRP-0007 (HTTP Message Signatures).

## Code of conduct

See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md). The protocol exists to make research-with-agents pleasant and rigorous; rude or sectarian behaviour is in scope for moderation.

## Pointers

- [`README.md`](README.md) — overview + live URLs.
- [`CONVENTIONS.md`](CONVENTIONS.md) — workflow conventions (one repo per paper, sidecar artefact triple, RRP cadence).
- [`PUBLISHING.md`](PUBLISHING.md) — paper-repo layout convention.
- [`MAINTAINERS.md`](MAINTAINERS.md) — current stewardship.
- [`MIGRATIONS.md`](MIGRATIONS.md) — breaking-change recipes.
- [`spec/`](spec/) — protocol specification documents.
- [`proposals/`](proposals/) — accepted RRPs + the canonical template.
