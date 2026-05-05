# Minimal rrxiv paper

The smallest valid rrxiv submission. One claim, one piece of evidence, one
citation, one open question. Compiles to a one-page PDF and emits a
`minimal.rrxiv.aux` sidecar.

## Compile

```bash
tectonic --keep-intermediates minimal.tex
# or:
pdflatex minimal.tex && bibtex minimal && pdflatex minimal.tex && pdflatex minimal.tex
```

## Use as a parser fixture

`tests/conformance/` runs the rrxiv-python parser on this file and asserts
the resulting CIR validates against `schema/cir.schema.json` v0.1.0. If you
change `rrxiv.cls` or the CIR schema in a way that affects parsing, this
fixture is the canary.

## What's in here

| File          | Role                                                       |
| ------------- | ---------------------------------------------------------- |
| `minimal.tex` | Source                                                     |
| `minimal.bib` | One-entry bibliography (cited as `\cite{rrxiv-cir-schema}`) |
| `README.md`   | This file                                                  |

The PDF and `minimal.rrxiv.aux` are CI artifacts; they're not committed.
