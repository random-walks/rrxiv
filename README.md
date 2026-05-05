# rrvix

An open protocol for research preprints in the era of human-agent coproduction.

**Status: v0.1 spec phase.** No running canonical instance yet. The whitepaper, schemas, and reference template are here. The reference client lives in [rrvix-python](https://github.com/<org>/rrvix-python).

## What is rrvix?

rrvix proposes a research preprint protocol where:

- Papers are immutable atoms (citation works).
- Each paper decomposes into structured **claims** with explicit dependency, contradiction, and extension edges (the claim graph).
- **Annotations** form the discourse layer: replications, errata, summaries, code links.
- Source-of-truth is plain TeX/Typst, not PDF (diff-friendly, agent-readable).
- The corpus is **CC-BY licensed and snapshot-exported**, so it cannot be captured.
- AI agents are **first-class participants**: read access free, write access symmetric.

Read the [whitepaper](whitepaper/rrvix-whitepaper.pdf) for the full design.

## Repo contents

- `whitepaper/` — the rrvix v0.1 whitepaper. Itself a valid rrvix submission.
- `template/` — `rrvix.cls` LaTeX class with semantic environments. Use this for your own rrvix submissions.
- `schema/` — JSON Schemas for the Canonical Intermediate Representation (CIR), claims, annotations, etc.
- `spec/` — protocol specification documents (work in progress).
- `proposals/` — rrvix Improvement Proposals (RRPs).
- `tests/conformance/` — conformance test suite for any rrvix implementation.
- `BOOTSTRAP.md` — Phase 0 milestones and project bootstrap notes.

## Building the whitepaper

```bash
cd whitepaper
pdflatex rrvix-whitepaper.tex
pdflatex rrvix-whitepaper.tex  # second pass for cross-references
```

You'll get `rrvix-whitepaper.pdf` and a `rrvix-whitepaper.rrvix.aux` sidecar
metadata file. The sidecar is what `rrvix-python` reads to produce a CIR.

## License

- Code: MIT (see `LICENSE`).
- Spec docs and whitepaper: CC-BY 4.0 (see `LICENSE-CONTENT`).

## Contributing

See `CONTRIBUTING.md` and the RRP process in `proposals/README.md`.
