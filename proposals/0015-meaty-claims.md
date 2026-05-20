# RRP-0015 — Meaty claims (proof, figures, source-location)

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-20
- **Last updated:** 2026-05-20
- **Affects:** schemas / parser / docs
- **Supersedes:** none
- **Superseded by:** none

> Originally tracked as RRP-0014 in early drafts; the number was already taken by RRP-0014 (cursor pagination), so this proposal landed as RRP-0015. The intent — make a `Claim` carry the proof, figures, and source-line span — is unchanged.

## Summary

Extend `claim.schema.json` with four optional fields so a `Claim` can carry the same content a careful human reader would expect: not just the statement, but the proof, the figures the proof relies on, and where to look in the source. The fields are `proof` (string), `figures` (array of `{path, caption?}`), `source_location` (object — adds `file`/`line_start`/`line_end` to the existing provenance fields), and `pdf_anchor` (string fragment such as `#page=N`). All four are optional; existing CIRs remain valid against the new schema; instances that do not populate them keep working.

## Motivation

A `Claim` in the v0.1 schema carries `id`, `paper_id`, `statement`, `claim_type`, `evidence_type`, optional graph edges, and a minimal `source_location` projection (section id + paragraph + raw excerpt). The web client's claim detail page (`/claims/[id]`) is a function of that data — and it shows: a one-line statement, the edge graph, and nothing else.

For a paper like Euclid's *Elements*, clicking through to "Proposition I.10 — To bisect a given finite straight line" today returns:

```jsonc
{
  "id": "01923f8e-0009-7c4d-9e1f-3a2b1c0d4e5f:prop:I.10",
  "statement": "To bisect a given finite straight line.",
  "claim_type": "theoretical",
  "evidence_type": "proof",
  "depends_on": ["…:prop:I.1", "…:prop:I.9", "…:post:1"]
}
```

The proof is in the `\begin{evidence}…\end{evidence}` block right next to the claim in the .tex source, but the parser drops it on the floor: only the `\dependson` lines escape, as edges. Readers who want to inspect the proof must fetch the source tarball, untar it, find the relevant book file, and scroll to the proposition. That's a wrong-shape ask for a *claim browser*; a careful claim page should show the proof inline, with its figures, with a deep link back to the source for verification.

The four new fields close that gap.

## The four fields

### `proof` — proof text extracted from `evidence`

```jsonc
"proof": "Let $AB$ be the given finite straight line. With centre $A$ and distance $AB$ describe the circle $BCD$ (Postulate 3). With centre $B$ and distance $BA$ describe the circle $ACE$ (Postulate 3). …"
```

The plain-text body of the `\begin{evidence}…\end{evidence}` block that follows the claim in the source. Cleaned via the same `tex_to_text` pass we already use for `statement` and `abstract`: cosmetic macros (`\textit`, `\Large`, …) are stripped; inline math (`$AB \cdot CD$`) and display math (`\[ \]`) are preserved verbatim so a downstream renderer (the web client uses KaTeX) can hand the formulas off to a math layout engine; `\dependson{…}{…}` lines are dropped because that information already rides on the `depends_on` edges; `\label{}` macros are dropped because the label is captured separately. Multi-paragraph: paragraph breaks are encoded as a blank line, matching `abstract`.

Optional. Claims with no paired evidence block (definitions, scopes, conventions) omit the field rather than emit an empty string — `null`/absent means "no proof attached," whereas `""` would imply "an empty proof was attached," which is a different and confusing assertion.

### `figures` — figures referenced inside the proof

```jsonc
"figures": [
  {
    "path": "figures/fig-i-10.tex",
    "caption": "Proposition I.10. The construction bisecting the segment $AB$ at the point $D$."
  }
]
```

Each entry records the source-archive-relative path of a figure that the proof references via `\input{figures/...}`. Path resolution: relative to the root of the paper's source tarball (the artefact at `source.uri`), so a client can pluck the file directly out of the bundle for in-browser TikZ-to-SVG rendering, or link readers to the file in the source viewer.

`caption` is optional. When the parser can find a `\caption{...}` macro inside the figure file (TikZ-rendered figures use the standard LaTeX `figure` environment) it captures the caption text. Otherwise the caption is omitted; the renderer is expected to handle a captionless figure entry.

Why a separate `figures` array on `Claim` rather than using the existing top-level `Paper.figures`? Two reasons. First, claim-scoped figures are a tighter relationship than paper-scoped figures — a reader on the claim page wants "the diagrams for *this* proposition", not "every figure in the paper". Second, the existing `Paper.figures` (figure.schema.json) is keyed by `label` and aimed at section-level cross-referencing; the parser doesn't currently populate it consistently across papers, and overloading it here would push two different consumer needs through one shape. Keeping them separate keeps each shape honest.

### `source_location` — file + line span

The existing `source_location` carries `section_id`, `paragraph`, and `raw_source_excerpt`. We extend it with three additional fields so a client can deep-link into the source viewer:

```jsonc
"source_location": {
  "file": "books/book01.tex",
  "line_start": 234,
  "line_end": 268
}
```

- `file` is the source-archive-relative path to the file containing the claim. For single-file papers (the whitepaper, the minimal fixture) this is just `main.tex`. For multi-file papers (Euclid, where each book is its own .tex `\input` from `main.tex`) this is the book file. The parser resolves the path via the marker comments that `flatten-tex.py` emits — `% [flatten-tex.py] inlined: books/book01.tex` and `% [flatten-tex.py] end: books/book01.tex` — and translates the flattened-file line numbers back to the original-file line numbers. If no marker comment surrounds the claim (because the paper is single-file and didn't go through flatten-tex) the parser reports the input filename.
- `line_start` is the 1-indexed line of `\begin{claim}` in `file`.
- `line_end` is the 1-indexed line of `\end{evidence}` (the closing of the paired evidence block). When the claim has no paired evidence, `line_end` is the line of `\end{claim}` — the span collapses to the claim itself.

The existing fields (`section_id`, `paragraph`, `raw_source_excerpt`) are preserved unchanged for back-compat. A consumer that only reads the old fields still sees the same data it saw before.

### `pdf_anchor` — URL fragment for the rendered PDF

```jsonc
"pdf_anchor": "#page=12"
```

A URL fragment intended to be appended to the paper's `source.rendered_pdf_uri`. Two flavours are anticipated:

- `#page=N` — raw page anchor. Universal: any PDF viewer that honours the PDF Open Parameters specification opens to page N on this fragment. The downside is that page numbers shift when the paper is recompiled or the typesetter changes; the field is therefore a hint, not a stable identifier.
- `#nameddest=<id>` — named destination. Stable across recompiles if the paper's typesetter emits `pdf:dest` markers (the `hyperref` package does this automatically when claims have labels). Preferred when available.

The parser **does not populate this field** in v0.1. Computing the page number requires the rendered PDF's cross-reference table, which the .tex → CIR path doesn't see. The field is specified in the schema so:

1. Operators or downstream pipelines (e.g. a `compute-pdf-anchors.py` post-processor that reads the compiled PDF and maps `\label{}` to page numbers) have a stable place to write the result.
2. Future generators (a Typst-based or markdown-based renderer that produces both the PDF and the CIR in one pass) can populate the field directly.

Until then, the field is `null`/absent in production CIRs, and the web client treats absence as "no deep-link to the PDF available" (it can still show the PDF, just without a jump-to-page).

## Why all four are optional

The schema additions are strictly additive. Existing CIRs validate against the new schema without modification — none of the existing fields move or change cardinality. An instance that ingests a v0.1 corpus and never re-parses it sees `proof`/`figures`/`source_location.file`/`pdf_anchor` as missing on every claim, which is exactly the behaviour it had before this RRP. The web client renders the claim page using whatever is present and degrades gracefully when fields are absent.

This is the same "additive minor bump" pattern RRP-0012 (paper list-item projection) and RRP-0013 (id-slug) used: the schema's `version` field steps from `0.1.0` to `0.2.0`; the minor bump signals "new optional surface area," not a breaking change.

## Encoding guidance

The parser's pairing rule from `claim` to `evidence` is **shared label suffix**: a claim whose `\label{prop:X.Y}` matches an evidence block's `\label{ev:X.Y}` pairs by the `X.Y` tail. The convention is documented in `PUBLISHING.md`; here it is restated for the spec record:

```latex
\begin{claim}[Proposition I.10: To bisect a given finite straight line]
\label{prop:I.10}
To bisect a given finite straight line.
\end{claim}

\begin{evidence}[Proof of I.10]
\label{ev:I.10}
\input{figures/fig-i-10}
Let $AB$ be the given finite straight line. …
\dependson{I.10}{I.1}
\dependson{I.10}{I.9}
\end{evidence}
```

- The claim uses `\label{prop:X.Y}` and the evidence uses `\label{ev:X.Y}`. `X.Y` matches across the two.
- The figure is referenced via `\input{figures/...}` inside the evidence block. The parser captures the path relative to the .tex source root.
- `\dependson{X.Y}{target}` lines emit edges via the sidecar but are stripped from the captured proof text.

Claims that are not propositions (definitions, common notions, postulates) typically have no paired evidence and therefore no `proof` field. The schema accepts this.

When the pairing is ambiguous (e.g. an evidence block has no label, or two evidence blocks share the same label suffix) the parser falls back to a positional rule: the evidence associates to the most-recently-opened unsatisfied claim. This is documented in the parser's docstring and is intended as a guardrail for legacy papers; new papers should always label both blocks.

## Backward compatibility

| Layer | Effect |
|-------|--------|
| `claim.schema.json` | Bumps to v0.2.0. All new fields are optional; the `required` list is unchanged. Existing CIRs continue to validate. |
| `cir.schema.json` | Bumps to v0.2.0. No surface changes — the bump records that one of its referenced schemas (claim) changed. |
| `paper.schema.json`, `paper_list_item.schema.json` | Unchanged. The aggregate `stats` shape is independent of per-claim payload size. |
| `rrxiv.cls` | Unchanged. The class already provides the `claim`/`evidence` environments and `\dependson` macro; the parser change reads more of what's already there. |
| Existing CIRs in production | Continue to validate. Re-parse to populate the new fields; until re-parsed, claims have `proof`/`figures`/`source_location.file`/`pdf_anchor` absent. |
| Web client (`rrxiv-web-official`) | Reads the new fields when present, falls back to today's render when absent. Implemented in a sibling PR. |

## Drawbacks

- **CIR size grows.** A claim with a Heath-density proof can run to a kilobyte of text; figures and source-locations add a few hundred bytes each. For Euclid (~465 claims), the CIR balloons from ~120 KB to ~400-500 KB. Still negligible for HTTP transit and SQLite storage; would not justify a structural redesign.
- **Math markers are renderer-specific.** Preserving `$AB$` verbatim assumes the client can render TeX math. The current web client uses KaTeX, which is well-known. Other clients (a hypothetical CLI viewer) may print the raw markers. Documented in the field's description rather than re-interpreted at the protocol layer.
- **`pdf_anchor` is unpopulated in v0.1.** The field is specified but the parser doesn't fill it. This is deliberate (the .tex → CIR path doesn't see the PDF), but it's a footgun for downstream consumers expecting page numbers everywhere. The fix is a downstream pipeline; specifying the field now means we don't need a schema bump when one lands.

## Alternatives considered

### Stuff the proof into `source_location.raw_source_excerpt`

Rejected. `raw_source_excerpt` is positioned as a debugging aid ("here's the raw chunk we extracted from"), not a rendered field. Repurposing it conflates two needs and forces the web client to detect whether the field is "raw" or "processed."

### Capture the proof on a sibling `Evidence` schema rather than on `Claim`

Considered. The evidence block could be its own first-class object, joined to `Claim` by a foreign key. This is a more "normalised" model and supports future cases like multi-evidence claims (one claim, several independent proofs/experiments). Rejected for v0.1 because:

1. The 1:1 majority case is overwhelmingly the common one (every proposition in Euclid, every theorem in a typical math paper, every result in a typical experimental paper).
2. The sibling-schema model needs new endpoints (`GET /api/v0/claims/{id}/evidence`) and a new ID space, doubling the surface area.
3. The web client's "show the proof on the claim page" rendering becomes a join across two resources, slowing every claim view.

If multi-evidence claims become common (multiple independent replication packages attached to one claim, say) a future RRP can promote `proof`/`figures` to a sibling shape; the migration is straightforward because the inline fields can be deprecated in favour of the sibling-resource cardinality.

### Store the proof in HTML / Markdown rather than TeX-with-math

Rejected. Pre-converting at the parser layer fixes the renderer choice at extraction time; today's rrxiv-web uses KaTeX, but a future client might want pandoc-style rich rendering or pure Markdown. Storing the source-faithful TeX with cosmetic macros stripped keeps options open.

## Impact on existing code and content

| Surface | Change |
|---------|--------|
| `schema/claim.schema.json` | `version` → 0.2.0; new fields `proof`, `figures`, `pdf_anchor`; extended `source_location` with `file`/`line_start`/`line_end`; new `$defs/ClaimFigure`. |
| `schema/cir.schema.json` | `version` → 0.2.0 (referenced-schema bump). |
| `PUBLISHING.md` | New "Writing meaty claims" section documenting the `\begin{evidence}` pairing convention, figure references, and the optional fields. |
| `rrxiv-python` parser (`src/rrxiv/parser/tex.py`, `src/rrxiv/parser/build.py`) | Pair `claim` ↔ `evidence` by label suffix; capture body, figures, and source-line span; emit the new fields on each `Claim`. |
| `rrxiv-python/_schemas/` | Synced from this schema; pydantic models regenerated. |
| `rrxiv-web-official` (claim detail page) | Read the new fields; render proof + figures; deep-link `source_location.file` to the source viewer. Sibling PR. |
| Seeded corpora (`rrxiv-instance/seed/euclid-elements.cir.json` etc.) | Re-parsed with the updated parser so the new fields are populated for the live deployment. |

## Process note

This RRP follows the v0.x accelerated-review pattern set by RRP-0012 / RRP-0013 / RRP-0014: rrxiv is pre-1.0 with a single maintainer group, the change is purely additive (no removed fields, no narrowed enums, no behavioural surprises for prior consumers), and the implementation is well-scoped and lands alongside the RRP. The 14-day Discussion window is collapsed to "merge when the implementation is verified end-to-end against the reference client." Standard process resumes for v1.0+.

## References

- [`schema/claim.schema.json`](../schema/claim.schema.json)
- [`schema/cir.schema.json`](../schema/cir.schema.json)
- [`PUBLISHING.md`](../PUBLISHING.md)
- [RRP-0001 — Claim graph design](0001-claim-graph.md)
- [RRP-0004 — AST-based TeX parser](0004-tex-parser-ast.md)

## Changelog

- **2026-05-20**: Created. Status: Accepted under v0.x accelerated review.
