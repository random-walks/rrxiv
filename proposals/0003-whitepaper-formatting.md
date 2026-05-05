# RRP-0003 — Whitepaper formatting cleanup

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-05
- **Last updated:** 2026-05-05
- **Affects:** whitepaper
- **Supersedes:** none
- **Superseded by:** none

## Summary

Strip cosmetic LaTeX formatting (`\Large`, `\\[0.2em]`, `\small`, etc.) from the whitepaper's title and date blocks. The default LaTeX title rendering is sufficient; the inline formatting was carrying through to downstream consumers — early CIR outputs from the parser had `\Large` text in the title field — which is the wrong tradeoff for a paper that's positioning itself as the canonical agent-readable artifact.

## Motivation

The v0.1 whitepaper title was:

```latex
\title{\Large rrxiv: An Open Protocol for Research Preprints \\[0.2em]
\large in the Era of Human--Agent Coproduction}
```

This produces a nice two-line PDF rendering, but:

1. **The source is the source of truth.** Per the protocol's own design principle 4, agents read source, not PDF. Cosmetic macros in the source contaminate the agent-readable representation.
2. **The parser's TeX-to-text cleaner already strips these** (`\Large`, `\\[0.2em]`, `\small`), so the PDF and the CIR diverge unnecessarily — the CIR has the cleaner title; the source still carries the formatting.
3. **The whitepaper itself argues that papers should round-trip cleanly through the parser.** The author should not need a TeX-to-text pass to get a usable title.

A whitepaper that violates its own design principles in its title block sets a bad example for downstream papers.

## Design

Replace the formatted title and date blocks with their natural-LaTeX forms. The article class's default `\maketitle` produces an acceptable rendering; the previous size differentiation was decoration, not information.

**Before:**
```latex
\title{\Large rrxiv: An Open Protocol for Research Preprints \\[0.2em]
\large in the Era of Human--Agent Coproduction}
\date{\today\\[0.5em]
\small Whitepaper v0.1 \textbullet{} Protocol v0.1.0 \textbullet{} \texttt{rrxiv.com}}
```

**After:**
```latex
\title{rrxiv: An Open Protocol for Research Preprints in the Era of Human--Agent Coproduction}
\date{\today}
```

The "Whitepaper v0.1 / Protocol v0.1.0 / rrxiv.com" line was decorative; the same information is in the front-matter `\rrxivversion{}` and `\rrxivprotocolversion{}` commands, which the parser captures structurally.

## Alternatives considered

### Leave the source alone, rely on the parser's cleaner

The current pipeline already produces a clean CIR title. But this means the canonical source-of-truth disagrees with itself — the rendered PDF says "rrxiv: …" in big bold-ish letters; the CIR says it as plain prose. The redundancy is fragile (the parser's strip list could miss a future macro) and confusing (which is canonical?). Cleaner: make the source itself match what the CIR will say.

### Use a custom title macro that emits both rendered and structured forms

E.g. `\rrxivtitle{Display title}{Plain title}`. Considered and rejected — it adds complexity to the cls for marginal benefit. The simpler rule "the title is the title" wins.

### Convert to a custom title page with explicit layout

Out of scope for v0.1. The article-class default is fine.

## Drawbacks

- **PDF rendering changes slightly.** The two-line size differentiation is gone; the title renders at the article-class default size. Some readers may prefer the old visual weight. In return, the title in CIR / search results / external citations is consistent with the source.
- **The version line is no longer in the rendered PDF subtitle.** The information is still in the structured metadata; readers who want it can look at the protocol-version stamp emitted by the cls. (A more substantive Phase-1 RRP could add a real "metadata footer" macro to the cls if this becomes annoying.)

## Impact on existing code and content

| Surface | Change |
|---------|--------|
| `whitepaper/rrxiv-whitepaper.tex` | Title and date blocks rewritten. ~5 lines. |
| `template/rrxiv-template.tex` | None — the template already uses a clean title. |
| `rrxiv.cls` | None. |
| Parser / CIR | None directly; the CIR was already clean post-TeX-to-text. The whitepaper's CIR is now clean from source, not from the cleaner pass. |
| Conformance fixtures | None. |
| External readers | The PDF the renderer produces is visually different — slightly less imposing title — but readable. No ID, claim, or schema field changed.

## Open questions

- **Should the cls provide a structured `\rrxivsubtitle{}` macro** for the "Whitepaper vX / Protocol vY / instance" stamp the old date-block carried? Possibly, in v0.2. For now, that information lives in `\rrxivprotocolversion{}` etc. and downstream renderers can compose a footer from those if they want.

## Reference implementation

This RRP and the whitepaper edit ship together in PR random-walks/rrxiv#... ([opened with this RRP](#)).

## References

- [`spec/0001-overview.md`](../spec/0001-overview.md) §"Why TeX/Typst source as the source of truth".
- [`spec/0004-tex-template.md`](../spec/0004-tex-template.md) §"Distributing the class with your paper".
- The whitepaper itself (this RRP modifies it).

## Changelog

- **2026-05-05**: Created. Status: Accepted (the change is small, scoped, and well-aligned with locked design principles; landed alongside the implementation).
