# `rrxiv.cls` — the rrxiv LaTeX class

Use this class when authoring papers for submission to a rrxiv instance. It
provides the semantic environments that the rrxiv parser extracts into the
Canonical Intermediate Representation (CIR).

## Files

| File                          | Role                                          |
| ----------------------------- | --------------------------------------------- |
| [`rrxiv.cls`](rrxiv.cls)      | The LaTeX class itself                        |
| [`rrxiv-template.tex`](rrxiv-template.tex) | A skeleton paper using every environment      |
| [`rrxiv-template.bib`](rrxiv-template.bib) | Stub bibliography for the skeleton            |
| [`examples/minimal/`](examples/minimal/) | Smallest valid rrxiv paper (parser fixture) |

## Quick start

```bash
cp template/rrxiv-template.tex my-paper.tex
cp template/rrxiv-template.bib my-paper.bib   # rename and replace entries
# edit my-paper.tex, then:
tectonic --keep-intermediates my-paper.tex
```

## Semantic environments

| Environment      | Sidecar marker | Purpose                                                |
| ---------------- | -------------- | ------------------------------------------------------ |
| `claim`          | `RRXIV:claim`  | A single falsifiable assertion                         |
| `evidence`       | `RRXIV:evidence` | The evidence supporting the most recent claim         |
| `observation`    | `RRXIV:observation` | A factual observation, no claim attached            |
| `scope`          | `RRXIV:scope`  | Conditions under which following claims hold           |
| `openquestion`   | `RRXIV:openquestion` | A question this paper does not resolve            |
| `rrxivremark`    | `RRXIV:remark` | Aside or methodological note (not a claim)             |

## Inline edges

Declare typed edges between claims without producing visible output:

```latex
\dependson{paper-id:claim:foo}{other-paper:claim:bar}
\supports{paper-id:claim:foo}{paper-id:claim:bar}
\extendsclaim{paper-id:claim:foo}{other-paper:claim:base}
\contradicts{paper-id:claim:foo}{other-paper:claim:opposite}
```

Each emits a sidecar marker the parser turns into a graph edge.

## Required metadata

```latex
\rrxivid{my-paper-0001}            % stable paper ID
\rrxivversion{v1}                  % paper revision
\rrxivprotocolversion{0.1.0}       % rrxiv protocol version
\rrxivlicense{CC-BY-4.0}           % SPDX license identifier
\rrxivtopics{topic-1,topic-2}      % comma-separated topic IDs
```

These are emitted to the sidecar at `\begin{document}` and the parser uses
them to populate the CIR's top-level metadata fields.

## Compilation

With Tectonic (recommended, single binary, auto-fetches packages):

```bash
tectonic --keep-intermediates paper.tex
```

With a traditional TeX Live install:

```bash
pdflatex paper.tex
bibtex paper           # if you have citations
pdflatex paper.tex
pdflatex paper.tex     # second pass for cross-references
```

You'll get `paper.pdf` and `paper.rrxiv.aux` (the sidecar metadata file the
rrxiv parser reads).

## Examples

- [`examples/minimal/`](examples/minimal/) — the smallest valid rrxiv paper.
  Used as a parser conformance fixture.
- The [whitepaper](../whitepaper/rrxiv-whitepaper.tex) itself is a non-trivial
  example that uses every environment.
