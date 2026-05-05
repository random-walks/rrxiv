# `rrvix.cls` — the rrvix LaTeX class

Use this class when authoring papers for submission to a rrvix instance. It
provides the semantic environments that the rrvix parser extracts into the
Canonical Intermediate Representation (CIR).

## Files

| File                          | Role                                          |
| ----------------------------- | --------------------------------------------- |
| [`rrvix.cls`](rrvix.cls)      | The LaTeX class itself                        |
| [`rrvix-template.tex`](rrvix-template.tex) | A skeleton paper using every environment      |
| [`rrvix-template.bib`](rrvix-template.bib) | Stub bibliography for the skeleton            |
| [`examples/minimal/`](examples/minimal/) | Smallest valid rrvix paper (parser fixture) |

## Quick start

```bash
cp template/rrvix-template.tex my-paper.tex
cp template/rrvix-template.bib my-paper.bib   # rename and replace entries
# edit my-paper.tex, then:
tectonic --keep-intermediates my-paper.tex
```

## Semantic environments

| Environment      | Sidecar marker | Purpose                                                |
| ---------------- | -------------- | ------------------------------------------------------ |
| `claim`          | `RRVIX:claim`  | A single falsifiable assertion                         |
| `evidence`       | `RRVIX:evidence` | The evidence supporting the most recent claim         |
| `observation`    | `RRVIX:observation` | A factual observation, no claim attached            |
| `scope`          | `RRVIX:scope`  | Conditions under which following claims hold           |
| `openquestion`   | `RRVIX:openquestion` | A question this paper does not resolve            |
| `rrvixremark`    | `RRVIX:remark` | Aside or methodological note (not a claim)             |

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
\rrvixid{my-paper-0001}            % stable paper ID
\rrvixversion{v1}                  % paper revision
\rrvixprotocolversion{0.1.0}       % rrvix protocol version
\rrvixlicense{CC-BY-4.0}           % SPDX license identifier
\rrvixtopics{topic-1,topic-2}      % comma-separated topic IDs
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

You'll get `paper.pdf` and `paper.rrvix.aux` (the sidecar metadata file the
rrvix parser reads).

## Examples

- [`examples/minimal/`](examples/minimal/) — the smallest valid rrvix paper.
  Used as a parser conformance fixture.
- The [whitepaper](../whitepaper/rrvix-whitepaper.tex) itself is a non-trivial
  example that uses every environment.
