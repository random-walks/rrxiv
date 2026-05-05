---
title: Whitepaper
description: The rrxiv whitepaper is itself a valid rrxiv submission.
---

# Whitepaper

The whitepaper is the foundational design document for rrxiv. It is itself a
valid rrxiv submission — written in `rrxiv.cls` LaTeX, parsed by the rrxiv
client into a Canonical Intermediate Representation, validated against the
CIR schema. Dogfooding from day one.

## Read it

The latest PDF is built by CI on every push to `main`:

[:octicons-cloud-download-24: Download latest PDF (CI artifact)](https://github.com/random-walks/rrxiv/actions/workflows/compile-whitepaper.yml){ .md-button .md-button--primary }

The TeX source is the canonical artifact:

- [`whitepaper/rrxiv-whitepaper.tex`](https://github.com/random-walks/rrxiv/blob/main/whitepaper/rrxiv-whitepaper.tex)

Compile locally with:

```bash
cd whitepaper
tectonic --keep-intermediates rrxiv-whitepaper.tex
# or:  pdflatex rrxiv-whitepaper.tex && pdflatex rrxiv-whitepaper.tex
```

## Why dogfood the whitepaper

Every protocol's foundational document tends to drift from the protocol it
defines. By making the whitepaper a valid rrxiv submission and round-tripping
it through the parser in CI, the protocol can't drift from its own canonical
example without the test suite breaking.

The whitepaper uses the semantic environments — every load-bearing claim is a
`\begin{claim}`, every observation is `\begin{observation}`, etc. — and the
`rrxiv.cls` `\write` channel emits a sidecar `*.rrxiv.aux` file that the
parser consumes to extract the CIR.

## Versioning

The whitepaper has its own revision history independent of the protocol
version. v0.1 is the first draft. Substantive revisions go through the [RRP
process](../proposals/index.md) (see M0.6).
