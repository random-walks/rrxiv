# RRP-0004 — AST-based TeX parser

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-05
- **Last updated:** 2026-05-05
- **Affects:** rrxiv-python parser, conformance behavior
- **Supersedes:** none
- **Superseded by:** none

## Summary

Replace the v0.1 regex-based TeX parser in `rrxiv-python` with an AST-based parser built on [`pylatexenc`](https://pylatexenc.readthedocs.io/). The public surface (`TexDocument`, `parse_tex`, `parse_tex_file`, `tex_env_to_sidecar_kind`) is preserved; what changes is *correctness* — the parser now respects LaTeX comment and math-mode boundaries, and unknown macros pass through cleanly instead of confusing the regex.

## Motivation

The v0.1 parser used a stack of compiled regexes to find `\title`, `\author`, `\section`, `\begin{claim}`, `\cite`, etc. This worked for the canonical whitepaper and the synthetic test fixtures but had three problems that the conformance suite would eventually hit:

1. **Comments leak.** A line like `% example: \cite{ghost}` gets matched as a citation. We worked around this with a "TeX-to-text" pre-pass that stripped comments, but the fix was fragile (it had to run before *every* extractor) and easy to forget for new extractors.
2. **Math mode leaks.** `$\sum_{i=1}^n x_i$` contains a `_` and braces that don't mean what `\section`'s regex thinks they mean. The regex parser worked because the canonical paper happened to not have title-shaped strings inside math, but real papers will.
3. **Optional-arg edge cases.** `\section[short]{Long Title}` was handled. `\author[1,2]{Name}` was handled. But `\cite[p.~5][see also]{key}` (two optionals) was not, and the failure mode was silent — the citation was simply missed.

`pylatexenc` is a well-tested LaTeX-aware tokenizer + walker (used by Jupyter, Sphinx, mathjax-node, etc.). It produces a tree of `LatexMacroNode`, `LatexEnvironmentNode`, `LatexGroupNode`, `LatexCharsNode`, `LatexCommentNode`, `LatexMathNode` nodes that we walk explicitly. Comments and math nodes are simply skipped; group/macro args are addressed by name; unknown macros become opaque chars to the rest of the walker.

This is the right primitive for a parser that has to be conservative about what it claims — false positives in CIR are worse than false negatives.

## Design

### Library choice

`pylatexenc 2.10` (already an indirect dep via `bibtexparser`-adjacent tooling, now direct). Pinned `>=2.10`. Pure-Python, BSD-3, no native dependencies, well-maintained, AST stable across our v3.11+ Python target.

### Custom macro spec for rrxiv-specific macros

`pylatexenc`'s default `LatexContextDb` knows about most stdlib macros but not about:

- `\author[opt]{name}` — pylatexenc's default `\author` declares only `{name}`, so `\author[1]{Foo}` would be parsed with `[` as a chars node and the optional silently lost.
- `\affil[N]{...}` — not in defaults at all.
- `\rrxivid{...}`, `\rrxivversion{...}`, `\rrxivprotocolversion{...}`, `\rrxivlicense{...}`, `\rrxivtopics{...}` — rrxiv.cls macros.

The parser builds an extended context once at module load and reuses it. New rrxiv-cls macros that take args must be registered there or they'll be parsed as bare names with siblings consumed greedily.

### Walker shape

A single recursive `_walk(nodes, …)` function over the top-level node list. Per-extractor concerns are split into helpers:

- `_macro_required_arg(node)` — first `{...}` arg from the macro's `nodeargd.argnlist`.
- `_macro_optional_arg(node)` — first `[...]` arg from the same.
- `_sibling_group_arg(nodes, i)` — fallback for unknown macros: scan following siblings.
- `_next_group_arg(nodes, i)` — combined: try the macro's declared args first, fall back to siblings.

`\cite` and `\bibliography` are scanned recursively (they appear inside environments). `\label` is scanned recursively scoped to each environment (the label belongs to its containing environment, not the outer doc).

### Behavior preserved

The conformance fixture suite passed against the regex parser; it must pass against the AST parser. The `TexDocument` dataclass is unchanged. `build_cir(tex_path, sidecar_path)` produces byte-identical CIR for the canonical whitepaper after this change.

### Behavior changed (intentionally)

- **Comments are properly ignored.** A `% \cite{x}` in a comment no longer produces a phantom citation.
- **Math mode is properly skipped.** `$\section{x}$` no longer creates a section.
- **Unknown macros pass through.** A `\customcommand{foo}{bar}` that the regex parser would have stumbled on (or ignored, depending on order) now reliably passes through as opaque text.

These are not breaking changes for any conformance fixture in the suite as of v0.1.

## Alternatives considered

### Stay with regex, harden the strip pass

We could extend the TeX-to-text pre-pass to be more aggressive: strip math, strip comments, strip unknown macros' arg groups. Considered and rejected — every extension makes the strip pass more like a real parser, with no termination point. We'd be reinventing pylatexenc, badly.

### Parse via a real LaTeX engine (Tectonic + log scraping)

We *do* run Tectonic, but for compilation only — the `.rrxiv.aux` sidecar is what the engine produces and the parser reads alongside the source. The CIR build does not require structural information from the engine, only from the source. Engine-based extraction would couple "can we read this paper" to "does the engine compile it", which is a worse failure mode for partial papers.

### Roll our own AST parser

LaTeX is famously hard to parse. `pylatexenc` is the established Python library for this niche; reinventing it would be substantial scope creep for marginal benefit.

## Drawbacks

- **New required dep.** `pylatexenc>=2.10`. Pure Python, no native code, tiny install footprint, BSD-3.
- **Slightly larger startup cost.** Building the `LatexContextDb` runs once per process. Negligible (<5ms in practice) for CLI use.
- **Custom macro registration is a foot-gun.** A new rrxiv.cls macro with args won't be picked up automatically — see "Open questions" below.

## Impact on existing code and content

| Surface | Change |
|---------|--------|
| `rrxiv-python/src/rrxiv/parser/tex.py` | Rewritten. Public API unchanged. |
| `rrxiv-python/pyproject.toml` | `pylatexenc>=2.10` added to deps. |
| `rrxiv-python/tests/test_tex.py` | Same fixtures, same assertions; all pass. |
| `rrxiv-python/tests/test_build.py` | All pass against the canonical fixture. |
| `rrxiv.cls` | None. |
| `whitepaper/` | None. |
| Conformance fixtures | None added; existing ones verify the change. |
| Downstream consumers | None — the public `TexDocument` shape is preserved. |

## Open questions

- **Schema-driven macro registration.** Today the rrxiv.cls macro list lives in the parser as a tuple. If the cls grows new structural macros, the parser silently misses them until someone updates the tuple. A future RRP could publish a machine-readable cls manifest (e.g., `rrxiv.cls.json`) and have both the cls and the parser load from it. Out of scope for this RRP.
- **`pylatexenc` v3.** A v3 is in alpha; it changes the AST API materially. We pin `>=2.10,<3` for now and revisit when v3 stabilizes.

## Reference implementation

`rrxiv-python` `src/rrxiv/parser/tex.py`, branch `rrp-0004/pylatexenc-parser`.

## References

- [`spec/0001-overview.md`](../spec/0001-overview.md) §"Why TeX/Typst source as the source of truth"
- [`spec/0004-tex-template.md`](../spec/0004-tex-template.md) §"Class macros"
- pylatexenc docs: https://pylatexenc.readthedocs.io/en/latest/

## Changelog

- **2026-05-05**: Created. Status: Accepted (replaces a known-fragile regex parser with the established Python LaTeX-AST library; preserves public surface; all existing conformance fixtures pass).
