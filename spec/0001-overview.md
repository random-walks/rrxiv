# 0001 — Overview

**Status:** v0.1 draft.
**Audience:** anyone who wants to understand what rrxiv is in twenty minutes.
**Reading order:** start here. Then [`0002-cir.md`](0002-cir.md) if you want the data model, [`0003-claim-graph.md`](0003-claim-graph.md) for how knowledge composes, [`0004-tex-template.md`](0004-tex-template.md) for how authors write rrxiv papers.

## What rrxiv is

rrxiv is an open protocol for research preprints. It pairs the immutability and citability of arXiv with a Wikipedia-style commentary layer, plus a structured **claim graph** that makes the corpus natively queryable by software agents.

The intent is straightforward: the volume and velocity of research has outgrown the human-only-readers assumption built into the existing preprint stack. Search and citation analysis are the only ways the corpus is currently structured at scale, and both are coarse — they treat a paper as the atomic unit. But papers contain dozens of distinct claims of varying evidentiary status, and the load-bearing question for almost any researcher (or agent) is *"which claims in topic X are well-supported, contested, or load-bearing for what I'm doing?"* — a question the current stack can't answer because the corpus doesn't expose claims as first-class entities.

rrxiv proposes a different atom. A paper is still immutable (because citation has to work over decades), but each paper decomposes into **claims** — falsifiable assertions with stable IDs, scope conditions, and explicit edges to other claims (`depends_on`, `supports`, `contradicts`, `extends`). Around the claims, there's an **annotation layer**: replications, errata, summaries, code links, contradictions — all signed, all queryable, all versioned. The result is a corpus that's structured all the way down, not just at the paper level.

## What rrxiv is not

- **Not a journal**, not peer review. Authors submit when they choose. The reputation signal is replication count and annotation density, not editorial gatekeeping.
- **Not a research data repository.** Papers can link to data and code; the data and code live elsewhere.
- **Not a platform** in the rent-extraction sense. The corpus is CC-BY licensed, snapshot exports are mandatory and free, and the protocol is permissively-licensed open source. If the canonical instance ever fails its users, anyone can fork the corpus and run a clean version.
- **Not a chat interface to papers.** Read access via the API is symmetric for humans and agents, but rrxiv doesn't itself host conversational agents. It's a protocol for a structured corpus that any agent can read.

## The core insight

A research paper is not the right atomic unit. Papers contain many claims of varying evidentiary status. Treating a paper as one citable thing forces the load-bearing claims to be re-extracted by every reader, by hand. The cost of that re-extraction is paid quadratically in the number of (reader, paper) pairs.

If claims themselves were first-class entities — with stable IDs, scope conditions, dependency edges, and signed annotations — three things become tractable:

1. **Replication tracking** — when claim X is replicated, the annotation hangs off the claim, not buried in some footnote of a paper that cites the original.
2. **Contradiction tracking** — claim Y in paper B contradicting claim X in paper A is now an explicit, queryable edge.
3. **Load-bearing analysis** — *"which claims in topic Z are most depended-upon by other claims, AND have not been replicated?"* is a graph query, not a literature review.

The whitepaper makes the case for why this is worth doing now. This document is the spec-level summary of what rrxiv actually *is*.

## How rrxiv is shaped

### Papers

A **paper** in rrxiv is an immutable submission. It has:

- Plain-text source (LaTeX or Typst) as the canonical artifact. PDFs are a rendering target, not the source of truth.
- A stable `id` (UUIDv7 in v0; the format may evolve via RRP) that does not change once assigned.
- Author metadata, including ORCID where available, and a mandatory `is_agent` flag for AI co-authors.
- A single revision string (`v1`, `v2`, …); revisions of the same paper share an `id` lineage but each revision is itself immutable once submitted.
- A `license` (SPDX identifier; CC-BY-4.0 is the recommended default).
- An optional list of topic IDs from the rrxiv controlled vocabulary.

Papers can be authored in any compile-friendly format (LaTeX is the v0.1 reference; Typst is on the v0.2 roadmap). The reference LaTeX class — [`rrxiv.cls`](../template/rrxiv.cls) — provides semantic environments that the parser extracts into structured form.

### Claims

A **claim** is a falsifiable assertion extracted from a paper. Claims are the unit of structured knowledge. Each claim has:

- A stable, globally unique ID. The convention is `<paper_id>:<local_label>` (e.g. `rrxiv-0001:claim:queryability`), but any globally unique string is valid.
- A natural-language `statement` that should be standalone-readable.
- A `claim_type` (empirical, theoretical, definitional, methodological, computational).
- An `evidence_type` (proof, experiment, simulation, observation, argument, definition, convention).
- Optional `scope` — the regimes, models, datasets, or assumptions under which the claim is asserted to hold.
- Optional `confidence` — the author's stated confidence with optional bounds and rationale.
- Edges to other claims: `depends_on`, `supports`, `contradicts`, `extends`.
- A `replication_status` (server-set, derived from annotations).
- An `extracted_by` field (`author`, `agent`, or `annotator`) and a `canonical` boolean — author-extracted claims are canonical from submission; others require confirmation.

A paper can declare claims directly in its source via `\begin{claim}…\end{claim}`. Claims can also be added later via `claim_extraction` annotations, with author confirmation flipping `canonical` to `true`. This is how a corpus of older papers can grow claim-graph coverage over time without needing every prior author to come back.

See [`0003-claim-graph.md`](0003-claim-graph.md) for the graph model.

### Annotations

An **annotation** is a post-submission attachment to any paper, section, claim, figure, or another annotation. Annotation types:

- `replication` — independent attempt to replicate a claim, with outcome and method.
- `contradiction` — a claim from another paper or a piece of new evidence that contradicts the target.
- `extension` — a generalization or refinement of the target claim's scope.
- `erratum` — author-acknowledged errors. Errata are linked from the original; the original itself never changes.
- `summary` — a structured plain-language summary of the target.
- `comment` — free-form discussion. The least structured annotation type; the rest of the corpus relies on it least.
- `code_link` and `dataset_link` — typed links to external code or datasets implementing or supporting the target.
- `claim_extraction` — a proposed claim derived from an existing paper. Becomes a canonical claim if confirmed by the paper's author or by quorum of credentialed annotators.

Annotations are signed (`created_by` is always populated) and immutable. Disputes over an annotation are themselves annotations — the discourse layer is recursive.

### The claim graph

Claims and the typed edges between them form the **claim graph**. Edges cross paper boundaries; *the graph spans the corpus*. This is the structure that makes agent-style queries tractable. Examples:

- *"Which claims in `claim_type: empirical` with `replication_status: untested` are depended on by 5+ other claims?"* — a degree query over the graph filtered by claim metadata.
- *"Where do claims in topic Z that depend on a particular foundational result diverge in their conclusions?"* — a path-finding query.
- *"Surface contradictions between recent claims and older established results."* — a query joining `created_at` ranges with `contradicts` edges.

These queries are first-class in the rrxiv API. They are not feasible against an unstructured PDF corpus, with or without LLM mediation.

See [`0003-claim-graph.md`](0003-claim-graph.md) for graph semantics, edge typing rules, and worked examples.

## How a paper becomes a CIR

The **Canonical Intermediate Representation (CIR)** is the agent-readable form of a paper. Every paper in rrxiv has exactly one canonical CIR per submitted revision. The CIR is produced by the rrxiv parser from the paper's plain-text source plus a sidecar metadata file that the LaTeX class emits during compilation.

The flow:

1. Author writes the paper in `rrxiv.cls` LaTeX. They use `\begin{claim}` and similar environments for the structured pieces.
2. On compile, `rrxiv.cls` writes a `<basename>.rrxiv.aux` sidecar containing structured markers — paper metadata, sequential markers for each claim/evidence/observation/scope/openquestion/remark block, and inline edge declarations.
3. The rrxiv parser (reference implementation: `rrxiv-python`) reads the source plus the sidecar and produces a CIR JSON object.
4. The CIR validates against [`schema/cir.schema.json`](../schema/cir.schema.json). If it doesn't validate, submission is rejected.
5. The CIR is stored alongside the source. Servers serve both.

See [`0002-cir.md`](0002-cir.md) for the CIR schema in detail and [`0004-tex-template.md`](0004-tex-template.md) for the LaTeX class.

## Why these choices

### Why TeX/Typst source as the source of truth

PDFs are a rendering target. Extracting structure from rendered PDFs is unreliable even with the best modern OCR; extracting it from plain-text source is direct. Every annotation, every claim, every edge has provenance back to a source line. Diffs work. Version control works. Agents read source, not PDFs.

### Why immutability

Citation has to work over decades. The moment any paper revision can mutate, every downstream citation graph becomes lying. rrxiv preserves citation integrity by making submitted papers (and their claims) immutable. Errors get errata; revisions get new versions with explicit version chains. Nothing ever silently changes.

### Why claims, not full-text search

Full-text search returns a paper. The reader still has to identify which claim in the paper is the relevant one. rrxiv returns *the claim* — with its scope, evidence, replications, contradictions, and extensions inline. The unit of retrieval matches the unit of reasoning.

### Why annotations are first-class

Replications, contradictions, errata, and summaries are intellectually critical and currently scattered across blog posts, follow-on papers' related-work sections, Twitter threads, lab wikis, and informal notes that decay. Bringing these into the protocol — signed, structured, queryable — captures discourse that would otherwise rot.

### Why the corpus is CC-BY and snapshot-exported

A protocol whose canonical implementation can be captured is not a public good. Mandatory free snapshot exports plus CC-BY licensing on submitted content make the corpus genuinely fork-able. If rrxiv.com is ever run badly, the community can mirror the corpus and run a competing instance the next day. This is the same property that protects DNS and email from any single operator.

### Why agents are first-class

Agents *are* heavy producers and consumers of research today. Pretending otherwise produces incoherent design choices — pricing tiers, rate limits, "no scraping" terms — that punish exactly the use case the corpus is most useful for. rrxiv's stance is that read access is free and unlimited (modulo abuse mitigation), write access is symmetric (agents can submit annotations, claim extractions, even papers, with the `is_agent` flag), and the API is shaped for agent throughput rather than browser interaction.

## How to read this spec

Each numbered document focuses on one concern. Read in order if you're new; jump to the topic you need if you're not.

| Doc | Topic |
|-----|-------|
| [0001](0001-overview.md) | This document |
| [0002](0002-cir.md) | Canonical Intermediate Representation |
| [0003](0003-claim-graph.md) | Claim graph data model |
| [0004](0004-tex-template.md) | `rrxiv.cls` reference |
| [0005](0005-submission.md) | Submission flow (stub) |
| [0006](0006-annotations.md) | Annotation model (stub) |
| [0007](0007-api.md) | HTTP API (stub) |
| [0008](0008-governance.md) | Governance and the RRP process (stub) |

## How to contribute

Substantive design changes go through the RRP process — see [`proposals/README.md`](../proposals/README.md). Issues, typo fixes, and clarifications are welcome via PR.

The whitepaper ([`whitepaper/rrxiv-whitepaper.tex`](../whitepaper/rrxiv-whitepaper.tex)) is the authoritative narrative of why this is built. The schemas under [`schema/`](../schema/) are the authoritative data model. This spec sits between them: prose-level, but precise about what's in scope for v0.

## Status

v0.1. This document and the spec series are live drafts. The whitepaper is at v0.1; CIR schema is v0.1.0; `rrxiv.cls` is v0.1. None of these are stable yet — the whole point of the v0.x series is to find the rough edges before anyone builds a serious instance.
