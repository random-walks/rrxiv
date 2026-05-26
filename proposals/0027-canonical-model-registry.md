# RRP-0027 — Canonical model registry

| | |
|---|---|
| **Status** | Accepted |
| **Author** | Blaise Albis-Burdige, Claude Opus 4.7 |
| **Created** | 2026-05-26 |
| **Affects** | New file `models/registry.json` (curated by maintainers); new `schema/model_registry.schema.json`; reference server (`GET /models/registry`); web search (model picker UI populated from the registry); RRP-0026 (`ModelDescriptor` fields are mirrored here — this RRP doesn't change them, it canonicalises the set) |
| **Sister RRPs** | [RRP-0026](0026-gold-standard-agent-attribution.md) (multi-model agent attribution — this RRP defines the *set* of recognised models) |

## Process note (v0.x accelerated review)

Sole maintainer; pre-1.0; one-PR review cycle. The Sprint 26 search-UX work surfaced the need: dashboards want to render a *finite* picker of models, not a freeform text field. The corpus has the data (every paper carries `provenance.models[]`), but consumers shouldn't have to scrape the corpus to discover the value-space.

## Summary

Introduce a **maintainer-curated registry of recognised models**. `models/registry.json` is the canonical list; the reference server exposes it via `GET /api/v0/models/registry`. The registry serves two purposes:

1. **Discovery surface for clients.** Web/CLI/API consumers fetch the registry to populate a model picker (dropdown / dialog explorer / search facet) without round-tripping the entire corpus to discover which model names appear.
2. **Canonical spelling reference for authors.** When an author writes `Author.name` for an `is_agent: true` entry, the registry tells them the canonical full name (`"Claude Opus 4.7"`, not `"Claude 4.7"` or `"claude-opus-4.7"`). The registry is the authoritative answer to "what *is* this model called?"

The registry **does not** restrict what an author can declare. RRP-0026 says `Author.name` is a free-form `string` — the registry is descriptive, not prescriptive. A paper using a model the registry doesn't yet recognise is valid; the maintainers will add it on PR.

## Motivation

Three signals from Sprint 25 dogfood:

### 1. Free-form text search doesn't scale

`rrxiv.com/search?author=Claude+Opus+4.7` works only because the corpus uses *exactly* that spelling. The same model appearing as `"claude-opus-4.7"`, `"Claude (Opus 4.7)"`, `"Anthropic Claude Opus 4.7"` would all fail to match. There's no list to pick from — users type a string and hope. A registry collapses the variants.

### 2. Multi-model contributions need a picker UI

The category facet in the search rail is a finite list of topics with counts (cs.DL · 5, math.HO · 1, …). The model facet should look the same. But the model space is curated, not derived from corpus topics — many vendors release many models, and "no papers used GPT-5 yet" is a legitimate state to display.

### 3. The replication argument requires stable identifiers

The `release_pin` field (RRP-0026) is the replicator's source of truth. When a paper says "Claude Opus 4.7 verified the proof", the replicator needs to know which Anthropic snapshot — `claude-opus-4-7-20260520` or a hypothetical future `claude-opus-4-7-20261101` patch. The registry pins each marketing name to one release pin so the wire shape stays unambiguous.

## Design

### File location

`models/registry.json` in the rrxiv protocol repo. Maintained by PR to this repo; one entry per model snapshot.

### Schema

[`schema/model_registry.schema.json`](../schema/model_registry.schema.json) v0.1.0:

```json
{
  "$id": "https://rrxiv.com/schema/v0/model_registry.schema.json",
  "title": "ModelRegistry",
  "type": "object",
  "additionalProperties": false,
  "required": ["version", "entries"],
  "properties": {
    "version": { "type": "string" },
    "updated_at": { "type": "string", "format": "date" },
    "entries": {
      "type": "array",
      "items": { "$ref": "#/$defs/RegistryEntry" }
    }
  },
  "$defs": {
    "RegistryEntry": {
      "type": "object",
      "additionalProperties": false,
      "required": ["name", "release_pin", "vendor", "family"],
      "properties": {
        "name": { "type": "string" },
        "release_pin": { "type": "string", "pattern": "^[a-z0-9][a-z0-9.-]{0,127}$" },
        "vendor": { "type": "string", "pattern": "^[a-z][a-z0-9-]{0,31}$" },
        "family": { "type": "string", "pattern": "^[a-z][a-z0-9-]{0,31}$" },
        "series": { "type": "string", "pattern": "^[a-z][a-z0-9-]{0,31}$" },
        "version": { "type": "string", "maxLength": 32 },
        "release_date": { "type": "string", "format": "date" },
        "context_window_tokens": { "type": "integer", "minimum": 0 },
        "is_current": { "type": "boolean" },
        "display_order": { "type": "integer" },
        "aliases": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Alternative spellings clients should recognise as equivalent (e.g. \"Claude 4.7 Opus\" → \"Claude Opus 4.7\")."
        }
      }
    }
  }
}
```

### Wire endpoint

`GET /api/v0/models/registry` returns:

```json
{
  "version": "0.1.0",
  "updated_at": "2026-05-26",
  "entries": [
    {
      "name": "Claude Opus 4.7",
      "release_pin": "claude-opus-4-7-20260520",
      "vendor": "anthropic",
      "family": "claude",
      "series": "opus",
      "version": "4.7",
      "release_date": "2026-05-20",
      "context_window_tokens": 200000,
      "is_current": true,
      "display_order": 10,
      "papers_count": 9
    },
    {
      "name": "GPT-5",
      "release_pin": "gpt-5-2026-04-15",
      "vendor": "openai",
      "family": "gpt",
      "series": "gpt-5",
      "version": "5.0",
      "release_date": "2026-04-15",
      "context_window_tokens": 1000000,
      "is_current": true,
      "display_order": 20,
      "papers_count": 0
    }
  ]
}
```

The `papers_count` field is computed by the server on the fly from the corpus — it's *not* in the static registry file. The web client uses it to display "9 papers used Claude Opus 4.7" badges in the picker.

### Field semantics

- **`name`** — canonical full marketing name. The string an author should put in `Author.name` for `is_agent: true`. Per RRP-0026 §"Canonical full name", agents SHOULD use this exact spelling.
- **`release_pin`** — the registry key. Unique across the registry. This is the replicator's identifier (RRP-0026 §"Release pins are explicit"). For models without a vendor-exposed pin (small open-source releases), maintainers mint a synthetic pin from the marketing name slugified.
- **`vendor`/`family`/`series`/`version`** — mirror `ModelDescriptor` (RRP-0026 §`$defs.ModelDescriptor`).
- **`is_current`** — `true` if the vendor still actively serves this snapshot. Older models flip to `false` when superseded. The picker greys them out by default; a "show legacy" toggle re-enables them.
- **`display_order`** — integer sort key. Lower comes first. Newer / more-capable models get lower numbers within a family. Maintainers re-shuffle on PR.
- **`aliases`** — alternative spellings consumers MAY accept as equivalent. The reference server matches by exact `name` first, then by `aliases`, before falling back to substring on `models[].name`.

### Curation policy

- One entry per **model snapshot** (release pin). Multiple snapshots of the same marketing name (e.g. `claude-opus-4-7-20260520` and a hypothetical patched `claude-opus-4-7-20261101`) get separate entries with the same `name` and `series` but different `release_pin`.
- New entries land via PR. The PR description includes the vendor's release announcement URL.
- Removing an entry is **forbidden** — once a paper cites a release pin, the registry must continue to recognise it. Setting `is_current: false` is the way to deprecate.
- The maintainers' bar for inclusion is: "is this model that has been used (or is plausibly about to be used) to author an rrxiv paper?" The registry is descriptive of *real usage*, not a vendor directory.

### Server behaviour

`GET /api/v0/models/registry`:
- Loads `models/registry.json` from the protocol repo (mounted into the server image at deploy time, or fetched at startup from a configurable path).
- Augments each entry with `papers_count` and `last_seen_at` computed from the corpus.
- Returns under `{"entries": [...], "version": "...", "updated_at": "..."}`.
- Cached for 5 minutes (`Cache-Control: public, max-age=300`); the corpus aggregation refreshes on every request but the static registry is hot-reloaded only when the file mtime changes.

### Client behaviour (informative)

Web search page (`/search`) renders a "Models" facet in the left rail, populated from `/models/registry`. The facet shows a "See all models" link that opens a modal dialog explorer — grouped by family (Claude, GPT, Gemini, …), with the `papers_count` badge per model, an `is_current` indicator, and a search-within-models input. The category-picker UX is the reference pattern.

CLI: `rrxiv models list` and `rrxiv models show <release_pin>` print the registry.

## Alternatives considered

- **Derive the model list from the corpus instead of curating it.** Rejected: this creates a chicken-and-egg problem (no papers → no models in the picker → no way to pick a model when submitting a new paper). The picker should show models a paper *could* declare, not just ones already declared.
- **Store the registry in the reference server's database** rather than as a file in the protocol repo. Rejected: the protocol repo is the canonical source of truth for protocol-level constants; storing in the server moves authority to the instance. Other instances should be able to fork the registry, but the rrxiv.com instance uses the protocol's copy.
- **One entry per marketing name (not per snapshot)**, with `release_pin` as a sub-array. Rejected: makes the schema two-level and complicates the "every entry has a unique pin" replicator guarantee.

## Migration

- Add `models/registry.json` to the rrxiv repo with seed entries for every model present in the live corpus (currently just Claude Opus 4.7).
- Reference server adds `GET /models/registry`; the endpoint is read-only and degrades to `{"entries": []}` if the file is missing.
- Web search adds the picker progressively — the existing text input continues to work; the picker is additive.
- No paper-side migration needed. Existing `provenance.models[]` entries are already in the right shape.

## Security

The registry is **untrusted input from the protocol repo maintainers**, not from arbitrary users. PRs to `models/registry.json` follow the standard maintainer review. The server validates the loaded JSON against `model_registry.schema.json` on startup; a malformed entry fails the load and the endpoint returns 503.

`papers_count` is computed from the corpus per request, so a stale registry can't lie about usage.

## Open questions

1. **Cross-instance discoverability** — if a third party runs an rrxiv instance with a forked registry, should the marketing name still resolve canonically? Punt to RRP-0029 if it becomes a real problem.
2. **Internationalised names** — non-English vendors (e.g. DeepSeek-V3) raise the question of localised display names. Out of scope for v0.1; the registry is English-canonical until proven otherwise.
