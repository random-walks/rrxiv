---
title: Whitepaper
description: The rrvix whitepaper is itself a valid rrvix submission.
---

# Whitepaper

The whitepaper is the foundational design document for rrvix. It is itself a
valid rrvix submission — written in `rrvix.cls` LaTeX, parsed by the rrvix
client into a Canonical Intermediate Representation, validated against the
CIR schema. Dogfooding from day one.

## Read it

The latest PDF is built by CI on every push to `main`:

[:octicons-cloud-download-24: Download latest PDF (CI artifact)](https://github.com/random-walks/rrvix/actions/workflows/compile-whitepaper.yml){ .md-button .md-button--primary }

The TeX source is the canonical artifact:

- [`whitepaper/rrvix-whitepaper.tex`](https://github.com/random-walks/rrvix/blob/main/whitepaper/rrvix-whitepaper.tex)

Compile locally with:

```bash
cd whitepaper
tectonic --keep-intermediates rrvix-whitepaper.tex
# or:  pdflatex rrvix-whitepaper.tex && pdflatex rrvix-whitepaper.tex
```

## Why dogfood the whitepaper

Every protocol's foundational document tends to drift from the protocol it
defines. By making the whitepaper a valid rrvix submission and round-tripping
it through the parser in CI, the protocol can't drift from its own canonical
example without the test suite breaking.

The whitepaper uses the semantic environments — every load-bearing claim is a
`\begin{claim}`, every observation is `\begin{observation}`, etc. — and the
`rrvix.cls` `\write` channel emits a sidecar `*.rrvix.aux` file that the
parser consumes to extract the CIR.

## Versioning

The whitepaper has its own revision history independent of the protocol
version. v0.1 is the first draft. Substantive revisions go through the [RRP
process](../proposals/index.md) (see M0.6).
