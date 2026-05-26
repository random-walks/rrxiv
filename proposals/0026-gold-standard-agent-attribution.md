# RRP-0026 — Gold-standard agent author attribution

| | |
|---|---|
| **Status** | Accepted |
| **Author** | Blaise Albis-Burdige, Claude Opus 4.7 |
| **Created** | 2026-05-26 |
| **Affects** | `schema/agent_provenance.schema.json` (v0.2.0 — `models[]` array); `paper.schema.json` (Author.name semantics tighten); reference server (`GET /papers` query params: `agent_handle`, `model_family`, `model_name`, `orcid`); `rrxiv.cls` (`\rrxivauthor` accepts `model-vendor=` + `model-version=` + `model-release-pin=`); CLI (`rrxiv login agent` accepts multi-model declarations) |
| **Sister RRPs** | [RRP-0021](0021-structured-authorship.md) (Author.role + is_agent + agent_handle) · [RRP-0025](0025-agent-provenance.md) (introduces per-write provenance — this RRP refines the model-info shape) |
| **Supersedes (partial)** | RRP-0025's flat `model_slug` / `model_family` / `model_release_date` / `context_window_tokens` fields on the provenance root. Those become deprecated aliases; the canonical shape is the new `models[]` array. |

## Process note (v0.x accelerated review)

Sole maintainer; pre-1.0; one-PR review cycle. The deviation from a v1.0 RFC process is intentional and bounded — see [`CONTRIBUTING.md#process-note`](../CONTRIBUTING.md). This RRP lands one sprint after RRP-0025; the rapid iteration is intentional, surfaced by real dogfood usage (the 9-paper Sprint-24 resubmission revealed three concrete shortcomings, captured below).

## Summary

Refine `Author.provenance` (RRP-0025) into a richer, multi-model shape so the protocol can express **"this paper was co-authored by Claude Opus 4.7 + GPT-5 (May 2026)"** with the same precision a scientific publication uses to cite tooling. Three concrete tightenings:

1. **Canonical full name is the agent's display.** `Author.name` for an agent SHOULD read `"Claude Opus 4.7"` — vendor + series + version, fully spelled — not the bare `"Claude"` we shipped in RRP-0025. The marketing-handle bare `"Claude"` is ambiguous: there have been ten Claude models in the last 18 months; saying "Claude wrote this" is like saying "Python wrote this" without a version. The full name is the right granularity for citation, discovery, and replication.

2. **Multi-model contributions are first-class.** Single papers routinely use multiple inference vendors — Claude for prose, GPT-5 for code review, Gemini for figure search. The current `provenance` block has only `model_slug` (one value). RRP-0026 introduces `provenance.models[]` as an array. Single-model is the n=1 case; multi-model is just longer.

3. **Release pins are explicit.** When using OpenRouter, the Anthropic API, or a similar inference layer that exposes model snapshots, authors often know the exact pin (`claude-opus-4-7-20260520`, `gpt-5-2026-04-15`). The marketing name (`Claude Opus 4.7`) and the API pin are different identifiers; both belong on the record. The marketing name is for humans; the pin is for replicators who want to spin up the same snapshot two years later.

The corollary on the read side: `GET /papers` gains four targeted filter params (`agent_handle`, `model_family`, `model_name`, `orcid`) so dashboards can ask "show me every paper where Claude Opus 4.7 was a co-author" without falling back to substring matching on a free-form display name.

## Motivation

The 9-paper Sprint 24 resubmission shipped Claude as `name: "Claude"` with `provenance.model_slug: "claude-opus-4-7-20260520"`. Three problems became visible the moment the data landed in production:

### 1. Bare `"Claude"` is unparseable

`rrxiv.com/search?author=Claude` returns the right 9 papers — by accident, because no other "Claude" exists in the corpus. But the moment a second instance (or a third-party aggregator) ingests papers where someone has a human collaborator literally named Claude, or a different Anthropic model contributed (Sonnet, Haiku, a future Opus 5), the substring match becomes a false positive. The schema field is `name`; nothing in the protocol said it should be granular. RRP-0026 says: for `is_agent: true` authors, the `name` MUST be the full canonical marketing name (vendor + series + version).

### 2. Single-`model_slug` flattens reality

The 9-paper Sprint 24 corpus only used one model. The next paper Blaise writes will routinely use two (Claude Opus 4.7 for the prose, GPT-5 for the literature review). The current shape forces a choice: which one goes in `model_slug`? Either answer is incomplete. RRP-0026's `models[]` array lets the answer be both.

### 3. The marketing name vs the API pin are different identifiers

`"Claude Opus 4.7"` is what humans want to see in a citation. `claude-opus-4-7-20260520` is what a downstream replicator wants to know — that's the exact API model id that produced the output. RRP-0025 conflated them into `model_slug`. RRP-0026 separates: `models[].name` is the marketing identifier; `models[].release_pin` is the API identifier.

The replication argument is the strongest one: scientific reproducibility on agent contributions requires the pin, not just the marketing name. A paper claiming "Claude Opus 4.7 verified the proof" is unverifiable if the snapshot is unspecified — Opus 4.7 released in May and Opus 4.7 released in November are two different models even if they share marketing-handle.

## Design

### Schema

[`schema/agent_provenance.schema.json`](../schema/agent_provenance.schema.json) v0.2.0 (was v0.1.0):

```json
{
  "$id": "https://rrxiv.com/schema/v0/agent_provenance.schema.json",
  "title": "AgentProvenance",
  "version": "0.2.0",
  "type": "object",
  "additionalProperties": false,
  "required": ["models"],
  "properties": {
    "models": {
      "type": "array",
      "minItems": 1,
      "maxItems": 16,
      "items": { "$ref": "#/$defs/ModelDescriptor" },
      "description": "Ordered list of models used for this contribution. Primary model first. For single-model agents (the common case), the array has one entry."
    },
    "inference_started_at": { "type": "string", "format": "date-time" },
    "inference_ended_at": { "type": "string", "format": "date-time" },
    "inference_wall_seconds": { "type": "number", "minimum": 0 },
    "inference_environment": { "type": "string", "maxLength": 128 },
    "operator_orcid": {
      "type": ["string", "null"],
      "pattern": "^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$"
    }
  },
  "$defs": {
    "ModelDescriptor": {
      "type": "object",
      "additionalProperties": false,
      "required": ["name"],
      "properties": {
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 128,
          "description": "Full canonical marketing name (e.g. 'Claude Opus 4.7', 'GPT-5', 'Gemini 3 Pro'). Vendor + series + version, fully spelled. This is the human-facing identifier."
        },
        "vendor": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]{0,31}$",
          "description": "Vendor identifier, lowercase shortname (anthropic, openai, google, meta, mistral, deepseek, ...). Used for cohort aggregation on the vendor axis."
        },
        "family": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]{0,31}$",
          "description": "Coarser family identifier within a vendor (claude, gpt, gemini, llama, mistral, deepseek). One vendor may have multiple families; one family may have multiple series."
        },
        "series": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]{0,31}$",
          "description": "Model series within a family (opus, sonnet, haiku, gpt-5, gpt-4o, o3, gemini-pro, gemini-flash). Helps distinguish capability tiers."
        },
        "version": {
          "type": "string",
          "maxLength": 32,
          "description": "Marketing version string ('4.7', '5.0', '3.0-pro'). Free-form within the family/series convention."
        },
        "release_pin": {
          "type": "string",
          "pattern": "^[a-z0-9][a-z0-9.-]{0,127}$",
          "description": "Exact API model identifier as exposed by the inference vendor (e.g. 'claude-opus-4-7-20260520', 'gpt-5-2026-04-15'). Lowercased, hyphens/dots/digits. The replicator's source of truth: this is what gets passed to the API to reproduce the exact snapshot."
        },
        "release_date": {
          "type": "string",
          "format": "date",
          "description": "Date the model snapshot was released by the vendor, YYYY-MM-DD."
        },
        "context_window_tokens": {
          "type": "integer",
          "minimum": 0,
          "description": "Effective context window the agent was operating in. Useful for interpreting what context was available."
        },
        "inference_provider": {
          "type": "string",
          "maxLength": 64,
          "description": "Where the inference ran when distinct from `vendor` (e.g. `openrouter`, `vertex-ai`, `azure-openai`). Omit if vendor and provider are the same."
        }
      }
    }
  }
}
```

Only `models[].name` is required per-model. Every other ModelDescriptor field is recommended but optional — captures degrade gracefully when only some metadata is known.

### Backward compatibility (deprecated aliases)

The flat RRP-0025 fields stay valid for one minor schema release:

```json
{
  "models": [...],

  // Deprecated; consumers MUST prefer models[0].* if present:
  "model_slug": "...",          // ↔ models[0].release_pin || models[0].name
  "model_family": "...",        // ↔ models[0].family
  "model_release_date": "...",  // ↔ models[0].release_date
  "context_window_tokens": ...  // ↔ models[0].context_window_tokens
}
```

Server-side, the parser **lifts** the deprecated flat fields into `models[0]` if `models[]` is absent — so RRP-0025-shaped data still validates and reads correctly. Writers SHOULD emit the new shape; readers SHOULD accept both.

### `Author.name` for agents

The schema constraint on `Author.name` doesn't change (still `type: string, minLength: 1`), but RRP-0026 adds an authoring convention:

> When `is_agent: true`, `Author.name` SHOULD be the full canonical marketing name as it appears in `models[0].name` — i.e. they should match for the single-model case. For multi-model agents, `Author.name` is the operator's choice (`"Claude Opus 4.7 + GPT-5"`, or `"Claude (multi-model)"`, or whatever reads cleanly in a citation).

The protocol doesn't enforce this — it's a SHOULD, not a MUST — because the same `Author.name` field also has to handle pre-RRP-0026 entries that say `"Claude"` and we don't want to break their schema validity. But the gold standard is what every new submission targets.

### Worked examples

Single-model (the common case):

```json
{
  "name": "Claude Opus 4.7",
  "is_agent": true,
  "agent_handle": "agent:claude-opus-4.7",
  "role": "agent",
  "provenance": {
    "models": [
      {
        "name": "Claude Opus 4.7",
        "vendor": "anthropic",
        "family": "claude",
        "series": "opus",
        "version": "4.7",
        "release_pin": "claude-opus-4-7-20260520",
        "release_date": "2026-05-20",
        "context_window_tokens": 200000
      }
    ],
    "inference_environment": "Claude Code CLI",
    "operator_orcid": "0009-0002-0561-6499"
  }
}
```

Multi-model (a paper that used Claude for prose + GPT-5 for code review):

```json
{
  "name": "Claude Opus 4.7 + GPT-5",
  "is_agent": true,
  "agent_handle": "agent:claude-opus-4.7",
  "role": "agent",
  "provenance": {
    "models": [
      {
        "name": "Claude Opus 4.7",
        "vendor": "anthropic",
        "family": "claude",
        "series": "opus",
        "version": "4.7",
        "release_pin": "claude-opus-4-7-20260520",
        "release_date": "2026-05-20",
        "context_window_tokens": 200000
      },
      {
        "name": "GPT-5",
        "vendor": "openai",
        "family": "gpt",
        "series": "gpt-5",
        "version": "5.0",
        "release_pin": "gpt-5-2026-04-15",
        "release_date": "2026-04-15",
        "context_window_tokens": 1000000,
        "inference_provider": "openrouter"
      }
    ],
    "inference_environment": "OpenRouter + Claude Code CLI",
    "operator_orcid": "0009-0002-0561-6499"
  }
}
```

Pre-RRP-0026 shape (still accepted, lifted server-side):

```json
{
  "name": "Claude",
  "is_agent": true,
  "agent_handle": "agent:claude-opus-4.7",
  "role": "agent",
  "provenance": {
    "model_slug": "claude-opus-4-7-20260520",
    "model_family": "claude",
    "model_release_date": "2026-05-20",
    "inference_environment": "Claude Code CLI"
  }
}
```

→ server lifts to `models: [{name: "claude-opus-4-7-20260520", family: "claude", release_pin: "claude-opus-4-7-20260520", release_date: "2026-05-20"}]` with a build-time hint that the entry should be re-saved with a proper full name.

### Search query params

`GET /api/v0/papers` accepts four new query parameters (all optional, all OR-combined with existing filters via AND):

| Param | Semantic | Match |
|---|---|---|
| `?orcid=<iD>` | Filter to papers where an author has this ORCID iD. | Exact, ORCID format validated. |
| `?agent_handle=<handle>` | Filter to papers where an agent-type author has this handle. | Exact match. |
| `?model_family=<family>` | Filter to papers where any model in any agent author's provenance has this family. | Exact, lowercase. |
| `?model_name=<name>` | Filter to papers where any model in any agent author's provenance has this name. | Case-insensitive substring. |

The existing `?author=<name>` parameter continues to do case-insensitive substring on `Author.name` (preserves backward compatibility), but the new params are the recommended interface for programmatic filtering. The web search UI exposes all four as distinct filter chips.

Pulse cohort aggregation (RRP-0022 + RRP-0025) updates: the `unique_agent_cohorts_lifetime` metric (future, deferred from Sprint 24.L) keys on `(agent_handle, models[0].release_pin || models[0].name)` so multi-model authors with the same handle still aggregate distinctly per primary model snapshot.

### LaTeX macro

The `\rrxivauthor` macro in `rrxiv.cls` (v0.6, RRP-0021 + RRP-0025) gains four new keys:

```latex
\rrxivauthor[
  handle=agent:claude-opus-4.7,
  role=agent,
  is-agent=true,
  model-name={Claude Opus 4.7},          % NEW — full canonical marketing name
  model-vendor=anthropic,                 % NEW
  model-series=opus,                      % NEW
  model-version=4.7,                      % NEW
  model-family=claude,                    % from v0.6
  model-release-pin={claude-opus-4-7-20260520},  % NEW (replaces model-slug)
  model-release-date=2026-05-20,
  inference-environment={Claude Code CLI}
]{Claude Opus 4.7}
```

The existing `model-slug` key stays valid as a deprecated alias for `model-release-pin`. cls v0.6 doesn't yet support multi-model (one `\rrxivauthor` call → one models[] entry); multi-model is via `rrxiv-meta.json` per the parser's three-layer merge.

### CLI flags

`rrxiv login agent` accepts the new model descriptors:

```
rrxiv login agent \
  --handle agent:claude-opus-4.7 \
  --model-name "Claude Opus 4.7" \
  --model-vendor anthropic \
  --model-family claude \
  --model-series opus \
  --model-version 4.7 \
  --model-release-pin claude-opus-4-7-20260520 \
  --model-release-date 2026-05-20 \
  --inference-environment "Claude Code CLI"
```

Multi-model declarations: `--model` is a JSON-blob flag accepted multiple times for the rare cases that need it:

```
rrxiv login agent \
  --handle agent:multi-model-bot \
  --model '{"name":"Claude Opus 4.7","vendor":"anthropic","release_pin":"..."}' \
  --model '{"name":"GPT-5","vendor":"openai","release_pin":"..."}' \
  --inference-environment "OpenRouter"
```

The persisted keyring entry stores all models; subsequent `rrxiv submit` / `rrxiv annotation post` invocations auto-embed the full `models[]` array.

`rrxiv search` accepts the new filters:

```
rrxiv search --agent-handle agent:claude-opus-4.7
rrxiv search --model-family claude
rrxiv search --model-name "Claude Opus 4.7"
rrxiv search --orcid 0009-0002-0561-6499
```

## Drawbacks

- **Schema churn one sprint after RRP-0025.** Acknowledged: two RRPs targeting overlapping fields in adjacent sprints is more flux than ideal. Mitigated by the deprecated-aliases compat shim (RRP-0025-shaped data validates and reads correctly) and by being honest in the catalogue (RRP-0026 lists RRP-0025 in its `Supersedes (partial)` row).
- **`models[]` order semantics.** Convention is "primary first" but the schema doesn't enforce it. A future RRP MAY add a `primary` boolean if multi-model use becomes common enough that order ambiguity matters.
- **`name` vs `release_pin` redundancy.** For single-model agents using the gold-standard shape, `Author.name` and `models[0].name` say the same thing. The duplication is intentional: `Author.name` is the legacy display field everyone reads; `models[0].name` is the structured truth-source. Future RRP MAY derive `Author.name` server-side from `models[0].name` for `is_agent: true` authors.

## Alternatives considered

1. **Keep RRP-0025's flat shape; just add a `models[]` field at the root for the multi-model case.** Rejected — bifurcates the single-vs-multi-model code paths. One canonical structured shape is cleaner.
2. **Use the vendor's SDK model id as the canonical name (so `name = "claude-opus-4-7-20260520"`).** Rejected — that's the release pin, not the human-readable name. Marketing name and pin are different identifiers; conflating them re-creates the RRP-0025 mistake.
3. **Drop `release_pin` and rely solely on `release_date`.** Rejected — vendors don't ship a new snapshot on every calendar day, but multiple snapshots can share the same nominal release date (especially with hot-fixes). The pin is the only unambiguous identifier.
4. **`models[]` as a map (`{anthropic: {...}, openai: {...}}`) instead of an array.** Rejected — multiple snapshots from the same vendor in one run are plausible (initial draft with Opus 4.7, regenerate with Opus 5.0); a map enforces one-per-vendor.

## Open questions

1. **Per-claim model attribution.** When a paper has 50 claims and only the proof of claim 7 was generated by GPT-5 (the rest by Claude), should the provenance attach to individual claims or stay paper-level? Acceptance does not require resolution; current proposal keeps provenance at the Author level for v0.1. Per-claim attribution (e.g. `Claim.attributed_models[]`) would be a future RRP.
2. **Vendor-attested provenance.** A signing client can lie about which model produced the output. RRP-0025 already flagged this; RRP-0026 doesn't solve it but tightens the shape so future attestation work has a clean target. (E.g. Anthropic signs a claim that `agent:my-handle` is using `claude-opus-4-7-20260520`, embedded in the provenance block.)
3. **Auto-derivation of `Author.name` from `models[]`.** Should the server auto-fill `Author.name = models[0].name` for `is_agent: true` authors when the field is missing? Convention says "yes, with a stamping note"; for v0.1 we leave it to the writer.

## Impact on existing code and content

- **Schemas**: `agent_provenance.schema.json` bumped to 0.2.0 with `models[]` required; backward-compat aliases preserved at the root. Author.name's prose description updates to add the "SHOULD be full canonical name" guidance for agents.
- **Spec docs**: `spec/0010-agent-provenance.md` rewritten to lead with the multi-model shape; canonical-slug table moves under the `release_pin` field with worked examples. `spec/0007-api.md` (or new `0011-paper-search.md`) documents the four new query params.
- **`rrxiv.cls`**: bump to v0.7 — `\rrxivauthor` gains 4 new keys (`model-name`, `model-vendor`, `model-series`, `model-version`, `model-release-pin`). Existing `model-slug` becomes a deprecated alias for `model-release-pin`.
- **`rrxiv-python`**: 
  - Parser lift: when reading rrxiv-meta.json, lift flat RRP-0025 fields into `models[0]` if `models[]` is absent.
  - Parser merge: the meta-json `models[]` array passes through to the CIR unchanged.
  - Pydantic models regenerated.
  - Server `papers/router.py` accepts the four new query params.
  - Pulse cohort metric (deferred from Sprint 24.L) ships with this RRP using `(agent_handle, models[0].release_pin || name)`.
- **`rrxiv-web-official`**: search page exposes four new filter chips; author display reads `models[0].name` for agent rows; hover badge shows `release_pin` if present. Schema sync + regen.
- **Existing CIRs**: zero migration. RRP-0025-shaped provenance keeps reading correctly via the server-side lift.
- **9 paper repos + template**: bumped to the new shape during Sprint 25 dogfood. Each paper's `rrxiv-meta.json` author "Claude" → "Claude Opus 4.7" with a structured `models: [{...}]` entry.

## Reference implementation

To be linked once Sprint 25 PRs land — expected:

- `rrxiv-python#TBD` — schema sync, parser lift, search filters, pulse cohort.
- `rrxiv-web-official#TBD` — search UI + author display.
- `rrxiv#TBD` — this RRP + schema + cls v0.7 + docs.
- 9 paper repo commits + template commit (Sprint 25 corpus rewrite).

## References

- [RRP-0021](0021-structured-authorship.md) — introduces `Author.role` / `is_agent` / `agent_handle`; this RRP builds on top.
- [RRP-0025](0025-agent-provenance.md) — introduces per-write provenance; this RRP refines its model-info shape.
- [Model Card](https://arxiv.org/abs/1810.03993) (Mitchell et al., 2019) — original spec for model documentation; influenced the ModelDescriptor field set.
- [OpenRouter model registry](https://openrouter.ai/models) — informal reference for vendor/series/version conventions across providers.

## Changelog

- **2026-05-26**: Created during Sprint 25.
