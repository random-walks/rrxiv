# Minimal rrvix paper

The smallest valid rrvix submission. One claim, one piece of evidence, one
citation, one open question. Compiles to a one-page PDF and emits a
`minimal.rrvix.aux` sidecar.

## Compile

```bash
tectonic --keep-intermediates minimal.tex
# or:
pdflatex minimal.tex && bibtex minimal && pdflatex minimal.tex && pdflatex minimal.tex
```

## Use as a parser fixture

`tests/conformance/` runs the rrvix-python parser on this file and asserts
the resulting CIR validates against `schema/cir.schema.json` v0.1.0. If you
change `rrvix.cls` or the CIR schema in a way that affects parsing, this
fixture is the canary.

## What's in here

| File          | Role                                                       |
| ------------- | ---------------------------------------------------------- |
| `minimal.tex` | Source                                                     |
| `minimal.bib` | One-entry bibliography (cited as `\cite{rrvix-cir-schema}`) |
| `README.md`   | This file                                                  |

The PDF and `minimal.rrvix.aux` are CI artifacts; they're not committed.
