# RRP-0030 — Claim authoring keys (`type=`, `evidence=`, `confidence=`, `labels=`, scope keys)

| | |
|---|---|
| **Status** | Accepted |
| **Author** | Blaise Albis-Burdige, Claude |
| **Created** | 2026-07-14 |
| **Affects** | `rrxiv.cls` (0.7 → 0.8), TeX parser (`rrxiv-python`). **No schema changes.** |
| **Sister RRPs** | [RRP-0015](0015-meaty-claims.md) (the fields being exposed) · [RRP-0021](0021-structured-authorship.md) (precedent: key=value authoring in `\rrxivauthor`) |

## Process note (v0.x accelerated review)

Sole maintainer; pre-1.0; one-PR review cycle. The deviation from a v1.0 RFC process is intentional and bounded — see [`CONTRIBUTING.md#process-note`](../CONTRIBUTING.md).

## Summary

Give authors a LaTeX path to the claim fields that already exist in
`claim.schema.json` but today can only be set by the parser's title-inference
or the `rrxiv-meta.json` merge:

```tex
\begin{claim}[type=empirical, evidence=experiment, confidence=0.72,
              labels={negative-result, small-n}, title=Main result]
  \label{claim:c4}
  Positive-part James–Stein shrinkage does not reduce MSE in our K=6 regime.
\end{claim}
```

The optional argument of the `claim` environment becomes a key=value list.
**Backwards compatible**: an optional argument containing no top-level `=` is a
plain display title, exactly as in cls 0.7. No schema fields are added; this is
authoring surface for fields that shipped in RRP-0015 and the 0.2.x claim
schema.

## Motivation

The July-2026 corpus audit found that **every claim in all 9 published papers
carries the default `claim_type: theoretical` / `evidence_type: argument` /
no `confidence` / no `labels` / no structured `scope`** — including claims the
prose describes as operational negative results. The cause is not author
neglect: there is **no LaTeX authoring path** for these fields. The parser
infers `claim_type`/`evidence_type` from title prefixes ("Definition",
"Postulate", …) tuned for the Euclid corpus, and `confidence`/`labels`/`scope`
sub-lists are reachable only via the meta-merge, which no paper uses.

A protocol whose thesis is machine-readable claims should let authors state
claim epistemology where they state the claim.

## Recognized keys (claim environment)

| Key | Maps to | Value form |
|---|---|---|
| `title` | display title (theorem note) + title-inference input | free text |
| `type` | `claim_type` | one of `empirical, theoretical, definitional, methodological, computational` |
| `evidence` | `evidence_type` | one of `proof, experiment, simulation, observation, argument, definition, convention` |
| `confidence` | `confidence.point` | float in [0,1] |
| `confidence-low` | `confidence.lower` | float in [0,1] |
| `confidence-high` | `confidence.upper` | float in [0,1] |
| `rationale` | `confidence.rationale` | free text (brace-protect commas) |
| `labels` | `labels[]` | comma-separated list in braces |
| `models` | `scope.models[]` | comma-separated list in braces |
| `datasets` | `scope.datasets[]` | comma-separated list in braces |
| `regimes` | `scope.regimes[]` | comma-separated list in braces |
| `assumptions` | `scope.assumptions[]` | comma-separated list in braces |

## Semantics

1. **Back-compat detection.** If the optional argument contains no `=` at
   brace depth 0, the whole argument is the display title (cls 0.7 behavior).
   Titles that themselves contain `=` must be written via `title={...}`.
2. **Parsing lives in the parser, not the sidecar.** The AST parser already
   captures the optional argument verbatim (`TexEnvironment.title`); it splits
   keys at depth-0 commas and applies them to the claim record. `rrxiv.cls`
   only extracts `title` for visual rendering (keyval); the semantic keys are
   render-inert. No new sidecar line format.
3. **Explicit beats inferred.** `type=`/`evidence=` override title-inference;
   absent keys keep today's inference + defaults, so re-parsing existing
   corpora is byte-identical.
4. **Validation is loud.** Unknown keys or enum-invalid values are a parse
   ERROR (`rrxiv parse` fails), not a silent default — a typo'd
   `type=emprical` must not publish as `theoretical`. Out-of-range confidence
   floats likewise.
5. **Precedence vs meta-merge.** Keys set in TeX win over `rrxiv-meta.json`
   claim patches (the meta-merge remains for fields with no TeX syntax and for
   post-hoc corrections).
6. Other semantic environments (`evidence`, `observation`, `scope`,
   `openquestion`, `rrxivremark`) keep plain-title optional args in 0.8.
   Structured scope belongs to the *claim* (it is `claim.scope` in the
   schema), so scope keys ride the claim environment; the `scope` environment
   remains prose + foundational-claim materialization.

## `rrxiv.cls` changes (0.7 → 0.8)

- `\RequirePackage{keyval}`; define the key family `rrxiv@claim` with `title`
  as the only render-affecting key (all semantic keys are declared as no-ops
  so `\setkeys` accepts them).
- `claim`'s optional argument: if it contains no `=`, pass through as the
  theorem note (0.7 path); otherwise `\setkeys{rrxiv@claim}` and pass only the
  extracted `title` (if any) to the theorem.
- Class version string bumped to 0.8; sidecar format unchanged.

## Parser changes (`rrxiv-python`)

- `parser/build.py`: a `_parse_claim_keys(optional: str) -> ClaimKeys` helper
  (depth-0 comma split, brace stripping, enum + float validation raising
  `ParseError`); applied where the claim dict is built; `title` participates
  in the existing title-inference path unchanged.
- Tests: back-compat (plain title unchanged), each key maps, override vs
  inference, invalid enum → error, brace-protected commas, floats.

## Not in scope

- No new schema fields; no server or web-client changes (fields already
  render/serve wherever RRP-0015 fields do).
- No `\rrxivbudget` macro — per-claim budgets are already expressible as
  reproducibility manifests (RRP-0019, `estimated_cost_usd` /
  `estimated_runtime_minutes`); authoring aids for manifests can be a future
  RRP if manifest adoption stalls for tooling reasons.
- No keyval on the other semantic environments (see Semantics §6).

## Rollout

cls 0.8 + parser land together (two repos, two commits, cross-referenced; the
parser change is forward-compatible with 0.7 documents). Published papers pick
up cls 0.8 with their next revision — the July-2026 corpus enrichment pass is
the intended first consumer.
