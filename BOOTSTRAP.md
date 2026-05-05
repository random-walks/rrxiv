# rrvix — Bootstrap Document

This is the kickoff document for the `rrvix` repo. Read this end-to-end before making changes. If you're an AI agent (Claude Code, etc.) executing on this repo, treat the **Phase 0 Milestones** section as your task list.

---

## What rrvix is

rrvix is an open protocol for research preprints and structured scientific knowledge, designed for the era where both humans and AI agents are heavy producers and consumers of research. It pairs the immutability and citability of arXiv with a Wikipedia-style commentary layer, plus a structured *claim graph* that makes the corpus natively queryable by agents.

The core insight: a research paper is not the right atomic unit. Papers contain many claims of varying evidentiary status. rrvix keeps papers immutable (so citation works) but layers a structured representation of their claims, with explicit dependency edges, replication status, and annotations on top. This makes "where are the load-bearing unverified claims in topic X" a tractable query instead of a vibe.

rrvix is a protocol, not a product. There will be one canonical instance hosted at rrvix.org for now, but the data is CC-licensed, the code is permissive open source, and snapshot exports are mandatory and free. If the official instance ever fails its users, anyone can fork the corpus and run a clean version.

## What this repo is

This repo (`rrvix`) is the canonical home for:

- The **rrvix whitepaper** — the foundational design document, written in TeX, itself a valid rrvix submission (dogfooding from day one)
- The **rrvix protocol spec** — Markdown documents describing each component of the protocol
- **JSON Schema** files for the Canonical Intermediate Representation (CIR), claims, annotations, papers, and all other data objects
- An **OpenAPI 3.1** spec for the HTTP API
- The **rrvix LaTeX class** (`rrvix.cls`) — the recommended submission template with semantic environments
- **RRPs (rrvix Proposals)** — RFC/BIP-style improvement proposals
- **Conformance tests** — a test suite any rrvix implementation must pass

This repo does NOT contain server implementations, client SDKs, or the actual rrvix.org website. Those live in separate repos (`rrvix-python`, eventually `rrvix-server`, `rrvix-web`, etc.).

## Design principles

1. **Papers are immutable atoms.** Once submitted, a paper's source and metadata cannot be changed. Errata are separate linked objects. This is non-negotiable; it's what makes citation work over decades.
2. **Claims are the unit of structured knowledge.** Each paper decomposes into one or more claims, each with stable IDs, scope conditions, evidence type, and explicit dependency edges to other claims.
3. **Annotations are cheap and structured.** Replications, contradictions, extensions, errata, summaries — all first-class, all signed, all queryable.
4. **TeX (and Typst) source is the source of truth.** PDFs are a rendering target. The CIR is extracted from source, not from PDF. Diff-friendly contributions are possible because the source is plain text.
5. **Agents are first-class users.** Read access is free. Write access is symmetric to humans (annotations, claim extractions). The API is designed for agent throughput, not just human browsers.
6. **The corpus is a public good.** CC-BY licensed, mandatory snapshot exports, fork-friendly architecture. We cannot sell what we don't exclusively own.
7. **Boring correct standards over novel ones.** OpenAPI 3.1, JSON Schema 2020-12, plain Markdown, plain TeX. No bespoke serialization formats. No blockchain.

## Repo structure

```
rrvix/
├── README.md                          # Project intro, links, quickstart
├── LICENSE                            # MIT (for code)
├── LICENSE-CONTENT                    # CC-BY 4.0 (for spec docs and whitepaper)
├── CONTRIBUTING.md                    # How to contribute, RRP process
├── CODE_OF_CONDUCT.md                 # Standard contributor covenant
├── .github/
│   ├── workflows/
│   │   ├── compile-whitepaper.yml     # CI: build whitepaper PDF on push
│   │   ├── validate-schemas.yml       # CI: validate JSON Schemas, lint OpenAPI
│   │   └── conformance-tests.yml      # CI: run conformance tests
│   └── ISSUE_TEMPLATE/
├── whitepaper/
│   ├── rrvix-whitepaper.tex           # The first whitepaper (TBD - written next)
│   ├── rrvix-whitepaper.bib           # Bibliography
│   ├── figures/                       # Figure source files
│   └── README.md                      # How to compile
├── spec/
│   ├── README.md                      # Index of spec documents
│   ├── 0001-overview.md               # High-level protocol overview
│   ├── 0002-cir.md                    # Canonical Intermediate Representation
│   ├── 0003-claim-graph.md            # Claim graph data model
│   ├── 0004-tex-template.md           # rrvix LaTeX class spec
│   ├── 0005-submission.md             # Submission flow
│   ├── 0006-annotations.md            # Annotation model
│   ├── 0007-api.md                    # HTTP API design
│   └── 0008-governance.md             # Stewardship, RRPs, dispute resolution
├── schema/
│   ├── README.md                      # Schema index, versioning policy
│   ├── cir.schema.json                # The Canonical Intermediate Representation
│   ├── paper.schema.json              # Paper object
│   ├── claim.schema.json              # Claim object
│   ├── annotation.schema.json         # Annotation object
│   ├── citation.schema.json           # Citation object
│   └── api.openapi.yaml               # OpenAPI 3.1 spec
├── template/
│   ├── rrvix.cls                      # LaTeX class file with semantic environments
│   ├── rrvix-template.tex             # Skeleton paper using the class
│   ├── README.md                      # How to use the template
│   └── examples/
│       └── minimal/                   # Smallest valid rrvix paper
├── proposals/
│   ├── README.md                      # The RRP process
│   ├── 0000-template.md               # RRP template
│   └── 0001-claim-graph.md            # First real RRP (probably retroactive)
├── examples/
│   └── README.md                      # Pointers to real example papers
├── tests/
│   ├── conformance/                   # Cross-implementation conformance tests
│   │   ├── README.md
│   │   ├── parsers/                   # TeX → CIR parser tests
│   │   ├── api/                       # API conformance
│   │   └── fixtures/                  # Test data
│   └── schemas/                       # JSON Schema validation tests
└── docs/
    ├── architecture.md                # Big-picture architecture
    ├── glossary.md                    # Terms and definitions
    └── faq.md
```

## Standards and tooling

**Schema definitions:** JSON Schema 2020-12 (`$schema: https://json-schema.org/draft/2020-12/schema`). Every schema file has a stable `$id` and a `version` field. Schemas are versioned independently and use semantic versioning at the schema level (additive changes are minor, breaking changes major).

**API definition:** OpenAPI 3.1 in YAML. References JSON Schema files via `$ref`. Generates client code via `openapi-generator` or language-specific tools. The reference Python client (`rrvix-python`) consumes this spec.

**Spec docs:** Markdown with optional Mermaid diagrams. No HTML, no proprietary formats. Each doc has a stable filename prefix (`0001-`, `0002-`, etc.) and is referenced by that ID in proposals and code.

**LaTeX class:** Standard LaTeX with `\NeedsTeXFormat{LaTeX2e}`. Provides custom environments: `claim`, `evidence`, `replicates`, `contradicts`, `extends`, `scope`, `methodological`, `theoretical`, `empirical`. Each environment has a label and a content payload that the parser maps to a CIR claim object. Compile with `pdflatex` or `tectonic`.

**CI:** GitHub Actions. On push: validate all JSON Schemas, lint OpenAPI, compile whitepaper to PDF, run conformance test suite, publish docs to GitHub Pages.

**Versioning:** The protocol itself uses `MAJOR.MINOR.PATCH`. Schemas are versioned independently. The whitepaper has its own revision history (v0.1, v0.2, etc.). RRPs are numbered sequentially and immutable once accepted.

## Phase 0 Milestones (in order)

These are the milestones to ship before the repo goes public. Each has a clear definition of done.

### M0.1 — Repo skeleton
- [ ] Create directory structure as specified above
- [ ] Add `LICENSE` (MIT), `LICENSE-CONTENT` (CC-BY 4.0), `README.md` (placeholder), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1)
- [ ] Set up GitHub Actions workflow files (initially passing no-op)

**Done when:** repo can be cloned, builds nothing yet, but structure is right.

### M0.2 — Minimum viable CIR schema
- [ ] Write `schema/cir.schema.json` covering: paper metadata, sections, claims, annotations, citations
- [ ] Write `schema/paper.schema.json`, `schema/claim.schema.json`, `schema/annotation.schema.json`, `schema/citation.schema.json` as standalone JSON Schemas referenced from CIR
- [ ] Add JSON Schema validation tests in `tests/schemas/` using `ajv` or `python-jsonschema`

**Done when:** Schemas validate against meta-schema, tests pass in CI.

### M0.3 — rrvix LaTeX class v0.1
- [ ] Write `template/rrvix.cls` with semantic environments: `claim`, `evidence`, `replicates`, `contradicts`, `extends`, `scope`
- [ ] Each environment accepts a `label` and emits both human-readable rendered output AND a machine-readable side-channel (suggestion: write a parallel `.rrvix.json` file during compilation, OR use `\write` to a special log file the parser reads)
- [ ] Write `template/rrvix-template.tex` demonstrating every environment
- [ ] Write `template/examples/minimal/` — the smallest valid rrvix paper (one claim, one citation, abstract, conclusion)

**Done when:** `pdflatex template/rrvix-template.tex` produces a clean PDF and `template/examples/minimal/` compiles.

### M0.4 — Spec documents
- [ ] Write `spec/0001-overview.md` (~2000 words, the whole protocol in plain English)
- [ ] Write `spec/0002-cir.md` referencing the JSON Schemas, with worked examples
- [ ] Write `spec/0003-claim-graph.md` with diagrams of dependency edges, contradiction edges, etc.
- [ ] Write `spec/0004-tex-template.md` — the spec for the LaTeX class as a separate doc
- [ ] Stub out `spec/0005-`, `0006-`, `0007-`, `0008-` with one-paragraph summaries and `TODO` markers

**Done when:** Someone unfamiliar with the project can read `0001-overview.md` and understand what rrvix is.

### M0.5 — The whitepaper (the main event)
- [ ] Write `whitepaper/rrvix-whitepaper.tex` using `rrvix.cls`
- [ ] Whitepaper itself uses the semantic environments — every claim it makes about rrvix is a `\begin{claim}`, every reference to prior art is properly cited, etc.
- [ ] Whitepaper compiles cleanly to PDF in CI
- [ ] Whitepaper, when fed through the (yet-to-exist) `rrvix-python` parser, produces a valid CIR JSON object — this is the dogfooding milestone

**Done when:** `whitepaper/rrvix-whitepaper.pdf` is produced by CI, AND the same source produces a valid CIR via `rrvix-python` parser, AND the resulting CIR validates against `cir.schema.json`.

### M0.6 — RRP process
- [ ] Write `proposals/README.md` describing the RRP lifecycle (draft → discussion → accepted/rejected/withdrawn)
- [ ] Write `proposals/0000-template.md` as the canonical template
- [ ] Optionally write `proposals/0001-claim-graph.md` retroactively documenting the claim graph design as the first RRP

**Done when:** Anyone can submit a new RRP by following the template and process.

### M0.7 — Public launch
- [ ] Repo made public
- [ ] README has a clear "what this is, what it isn't, how to read this repo, how to contribute" section
- [ ] rrvix.org points to the whitepaper PDF and the spec docs
- [ ] Announcement post (separate concern; don't optimize for HN)

**Done when:** External contributors can find the project, understand it, and submit issues or RRPs.

## What is explicitly NOT in scope for Phase 0

- A running rrvix.org server
- A web UI for browsing claims
- Any actual ingested papers other than the whitepaper itself and the minimal example
- Authentication, accounts, ORCIDs integration
- Annotation moderation
- Federation
- The agent API beyond the OpenAPI spec
- Karma, reputation, voting

These are real and important and they are all Phase 1+. Phase 0 is about getting the spec right. Code without spec is technical debt; spec without code is honest.

## Notes for AI agents executing on this repo

- When in doubt, prefer plain text formats (Markdown, TeX, JSON, YAML).
- When writing schemas, include `$id`, `$schema`, `title`, `description`, `version`, and worked examples in `examples` field.
- When writing spec docs, lead with rationale before mechanics. Future contributors need to understand *why* before *how*.
- The whitepaper is the most important artifact in this repo. Spend disproportionate effort on it. It will be read by orders of magnitude more people than any other file here.
- If a design decision is unclear, write up the alternatives as a draft RRP and surface to the human maintainer rather than guessing. The cost of a wrong early commitment is high.
- Resist scope creep. If something isn't in the milestones above, file an issue and move on.

## Open questions (to surface as issues or RRPs as the project develops)

- How are claim IDs assigned (UUIDv7? Content-addressed hash? Author-chosen string with collision detection?)
- How does the LaTeX class export the structured claim data — sidecar `.rrvix.json` written via `\write18`, post-hoc parser, or a dedicated build tool?
- What's the canonical paper ID scheme? (DOI is the obvious answer but DOIs cost money; arXiv-style identifiers are free but require central allocation; UUIDs are free but not human-readable)
- How are author identities verified? ORCID is the obvious answer but introduces a dependency.
- What are the exact content moderation rules for the main namespace?
- What's the federation story, if any, in the long term?

These are not blockers for Phase 0. They are the substance of Phase 1+.
