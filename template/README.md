# `rrvix.cls` — the rrvix LaTeX class

Use this class when authoring papers for submission to a rrvix instance. It
provides the semantic environments (`claim`, `evidence`, `observation`,
`scope`, `openquestion`, `rrvixremark`) that the rrvix parser extracts into
the Canonical Intermediate Representation.

## Usage

```latex
\documentclass{rrvix}

\rrvixid{my-paper-0001}
\rrvixversion{v1}
\rrvixprotocolversion{0.1.0}
\rrvixlicense{CC-BY-4.0}
\rrvixtopics{my-topic-1,my-topic-2}

\title{My Paper}
\author{Author Name}

\begin{document}
\maketitle

\begin{abstract}
...
\end{abstract}

\section{Introduction}

\begin{claim}[A short label]
\label{claim:my-claim}
Here is a claim, stated as a single falsifiable assertion.
\end{claim}

\begin{evidence}
Here is the evidence for the claim above.
\end{evidence}

\dependson{my-paper-0001:claim:my-claim}{some-other-paper:claim:foundational}

...

\end{document}
```

## Compilation

```bash
pdflatex paper.tex
pdflatex paper.tex  # second pass for cross-references
```

You'll get `paper.pdf` and `paper.rrvix.aux` (the sidecar metadata file the
rrvix parser reads).

## Examples

See `examples/minimal/` for the smallest valid rrvix paper.
