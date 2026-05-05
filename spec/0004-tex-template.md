# 0004 — `rrxiv.cls` LaTeX template

**Status:** v0.1 draft.
**Reference:** [`template/rrxiv.cls`](../template/rrxiv.cls).
**Skeleton paper:** [`template/rrxiv-template.tex`](../template/rrxiv-template.tex).
**Minimal example:** [`template/examples/minimal/`](../template/examples/minimal/).

## Purpose

`rrxiv.cls` is a thin LaTeX class layered on `article` that adds:

1. **Required metadata commands** — `\rrxivid`, `\rrxivversion`, `\rrxivprotocolversion`, `\rrxivlicense`, `\rrxivtopics`. Authors set these once in the preamble.
2. **Six semantic environments** — `claim`, `evidence`, `observation`, `scope`, `openquestion`, `rrxivremark`. These render normally in the PDF and emit structured markers in a sidecar file.
3. **Four inline edge declarations** — `\dependson`, `\supports`, `\extendsclaim`, `\contradicts`. These produce no visible output; they only emit sidecar markers.
4. **A sidecar `\write` channel** — every compile produces `<basename>.rrxiv.aux` containing the markers. The rrxiv parser reads this file to build the CIR.

The class is intentionally minimal. It does not theme the paper, define a custom title page, or impose a citation style. Authors layer their own preferences on top.

## Required metadata

Set these once in the preamble:

```latex
\rrxivid{my-paper-0001}             % stable paper ID
\rrxivversion{v1}                   % paper revision
\rrxivprotocolversion{0.1.0}        % rrxiv protocol version
\rrxivlicense{CC-BY-4.0}            % SPDX license identifier
\rrxivtopics{topic-1,topic-2}       % comma-separated topic IDs
```

The class emits these to the sidecar at `\begin{document}`. They populate the CIR's top-level metadata fields.

| Command | Sidecar marker | CIR field |
|---------|----------------|-----------|
| `\rrxivid{X}` | `RRXIV:meta:id:X` | `id` |
| `\rrxivversion{X}` | `RRXIV:meta:version:X` | `version` |
| `\rrxivprotocolversion{X}` | `RRXIV:meta:protocol:X` | `rrxiv_version` |
| `\rrxivlicense{X}` | `RRXIV:meta:license:X` | `license` |
| `\rrxivtopics{X}` | `RRXIV:meta:topics:X` | `topics` (comma-split) |

`\rrxivid` and `\rrxivversion` are required. The others have defaults (`v1`, `0.1.0`, `CC-BY-4.0`, empty topics) but explicit declaration is recommended.

## Semantic environments

| Environment | Sidecar marker | Purpose | CIR mapping |
|-------------|----------------|---------|-------------|
| `claim` | `RRXIV:claim:N` | Single falsifiable assertion | `claims[]` |
| `evidence` | `RRXIV:evidence:N` | Evidence for the most recent claim | (associated with adjacent claim) |
| `observation` | `RRXIV:observation:N` | Factual observation, no claim | (an annotation of type `claim_extraction` may promote it) |
| `scope` | `RRXIV:scope:N` | Conditions under which following claims hold | `claims[].scope` |
| `openquestion` | `RRXIV:openquestion:N` | Question this paper does not resolve | (annotation target candidate) |
| `rrxivremark` | `RRXIV:remark:N` | Aside / methodological note | (carried as commentary, not a claim) |

`N` is the LaTeX counter value at `\begin{...}` time. The parser pairs the Nth sidecar marker of a given kind with the Nth source occurrence of that environment.

### Usage

```latex
\begin{claim}[A short label for the claim]
\label{claim:my-claim}
State the claim as a single falsifiable assertion in plain language. A reader
should be able to read this paragraph in isolation and know what is being
asserted.
\end{claim}

\begin{evidence}[Evidence for claim:my-claim]
\label{ev:my-evidence}
Sketch or describe the evidence supporting the claim above.
\end{evidence}
```

The optional argument in `[brackets]` is a human-readable title shown in the rendered PDF. The `\label{...}` inside the body is the user-chosen anchor; the parser uses it to construct the canonical claim ID `<paper_id>:<label>`. If you omit `\label`, the parser falls back to `<paper_id>:claim:N` (using the sidecar index).

**Recommended labelling convention:**

| Environment | Label prefix |
|-------------|--------------|
| `claim` | `claim:` |
| `evidence` | `ev:` |
| `observation` | `obs:` |
| `scope` | `scope:` |
| `openquestion` | `oq:` |
| `rrxivremark` | `rem:` |

These are conventional, not enforced. The parser accepts any unique label.

## Inline edges

Declare typed edges between claims with no visible output:

```latex
\dependson{my-paper-0001:claim:foo}{other-paper:claim:bar}
\supports{my-paper-0001:claim:foo}{my-paper-0001:claim:baz}
\extendsclaim{my-paper-0001:claim:foo}{some-foundational-paper:claim:base}
\contradicts{my-paper-0001:claim:foo}{another-paper:claim:opposite}
```

Each emits a `RRXIV:edge:<type>:<src>|<dst>` marker the parser turns into a graph edge. The IDs follow the `<paper_id>:<label>` convention. Cross-paper edges are first-class — declare them whenever a claim of yours depends on, supports, extends, or contradicts a claim from another rrxiv paper.

The `|` separator was introduced in cls v0.2 (per [RRP-0002](../proposals/0002-edge-marker-delimiter.md)). v0.1 used `:` to join src and dst, which was ambiguous for IDs that themselves contained colons. The reference parser still accepts the v0.1 format with a `DeprecationWarning`; recompile any v0.1-era papers with the v0.2 cls to clear the warning.

## Compilation

With Tectonic (recommended — single binary, auto-fetches packages):

```bash
tectonic --keep-intermediates paper.tex
```

With a traditional TeX Live install:

```bash
pdflatex paper.tex
bibtex paper            # if you have citations
pdflatex paper.tex
pdflatex paper.tex      # second pass for cross-references
```

You'll get `paper.pdf` and `paper.rrxiv.aux`. The sidecar is what the rrxiv parser reads. The PDF is the human rendering target.

## Compile dependencies

`rrxiv.cls` v0.1 loads:

- `geometry` (a4paper, 1in margins; override at `\documentclass[]{rrxiv}`)
- `inputenc` (utf8) and `fontenc` (T1)
- `amsmath`, `amsthm`, `amssymb`, `mathtools`
- `graphicx`, `xcolor`, `enumitem`
- `natbib` (numbered citations)
- `booktabs`
- `authblk` (author affiliations via `\affil[]{...}`)
- `hyperref` (colored links)

These are widely available. A standard TeX Live or Tectonic install has them. If you need to add packages, `\usepackage{...}` after `\documentclass{rrxiv}` is fine.

## Distributing the class with your paper

When submitting to rrxiv, you upload the source bundle (.tex, .bib, figures, **and** `rrxiv.cls`). Don't rely on the server having the class installed. The bundle convention is:

```
my-paper-0001/
├── my-paper-0001.tex
├── my-paper-0001.bib
├── rrxiv.cls           ← bundled with submission
└── figures/
    └── ...
```

The submitting tool (`rrxiv submit`, future) checks that `rrxiv.cls` is present in the bundle and that its version matches a server-supported range.

## v0.1 limitations

- Sidecar markers carry only the LaTeX counter index, not the user's label. The parser pairs by ordinal-within-kind; this means rearranging the order of `\begin{claim}` blocks in source rearranges the implicit ordinals. Use stable `\label{...}` calls inside each block to anchor identity.
- Citations don't emit sidecar markers; the parser scans the source for `\cite{...}` directly and resolves keys against the .bib file. This is fine for v0.1.
- Math mode inside environments is preserved as raw TeX in the CIR's claim `statement` field. A v0.2 RRP will specify TeX-to-text or TeX-to-MathML for the public-facing renders.
- Figures are CIR-internal in v0.1 — they don't participate in the claim graph. A figure can be the `target` of an annotation (e.g., a `dataset_link`).

## See also

- [`0001-overview.md`](0001-overview.md) — high-level protocol overview.
- [`0002-cir.md`](0002-cir.md) — the CIR schema produced from `rrxiv.cls` papers.
- [`0003-claim-graph.md`](0003-claim-graph.md) — how the inline edges compose into the graph.
- [`template/rrxiv-template.tex`](../template/rrxiv-template.tex) — skeleton paper using every feature.
- [`template/examples/minimal/`](../template/examples/minimal/) — smallest valid rrxiv paper, used as the parser conformance fixture.
