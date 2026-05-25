# RRP-0021 — Structured authorship + embedded-from

| | |
|---|---|
| **Status** | Accepted |
| **Author** | Blaise Albis-Burdige, Claude |
| **Created** | 2026-05-25 |
| **Affects** | `paper.schema.json` (Author + Paper) |
| **Sister RRPs** | [RRP-0013](0013-id-slug.md) (id semantics) · [RRP-0017](0017-revision-flow-and-diff.md) (revisions) |

## Process note (v0.x accelerated review)

Sole maintainer; pre-1.0; one-PR review cycle. The deviation from a v1.0 RFC process is intentional and bounded — see [`CONTRIBUTING.md#process-note`](../CONTRIBUTING.md).

## Summary

Add two structured fields to the paper model so the protocol can express *who* contributed *what kind of work* to a rrxiv paper:

1. **`Author.role`** — an enum on each author entry distinguishing original creators (`author`, `coauthor`) from people whose contribution is a translation, edit, encoding, or agent action.
2. **`Paper.embedded_from`** — an optional object that, when present, says "this rrxiv paper is the encoding of a prior work" and names that work's author, year, source, and (where applicable) the translation we used.

Both fields are optional and default-compatible: existing papers without `role` are treated as `author`; existing papers without `embedded_from` are treated as fully original to rrxiv.

## Motivation

The Euclid Elements paper (`rrxiv:2605.00009`) exposes the gap. The CIR currently lists `authors: [Blaise Albis-Burdige, Claude]`, which is wrong on three counts:

1. **Euclid is the actual author.** The ideas, the structure of the proofs, the choice of postulates — all are c. 300 BCE. Listing only the 2026 encoders erases two thousand years of authorship.
2. **Heath is the translator.** The English text we encoded is the 1908 public-domain Heath translation. Without naming Heath, anyone reproducing the encoding can't trace which English version we used (and they would matter — Heath's choices differ from Fitzpatrick's, Densmore's, etc).
3. **Blaise and Claude are encoders, not authors.** They wrote the LaTeX wrapping, picked the CIR claim boundaries, and emitted the `\dependson` edges. That's real work, but it's structurally different from authoring the proofs.

The same shape recurs for any encoded classic — Newton's *Principia*, Mendel's pea papers, Darwin's *Origin*, anything past US copyright (1928 cutoff at the time of writing). Without structured embed-from metadata:

- **Citation graphs over-credit the encoder.** A naive `who has the most-cited paper?` query returns Albis-Burdige & Claude (because the encoder is listed as the author) instead of Euclid.
- **Claim attribution is wrong.** A replication edge on `rrxiv:2605.00009:claim:Book.I.Proposition.47` is replicating *Euclid's claim*, not "the encoder's claim." Downstream readers need to know that.
- **Translation disputes can't be expressed.** A scholar who thinks Heath mistranslated a passage in Book V can't post a `contradicts` edge against the right thing — the contradiction is with Heath's English rendering, not with Euclid's original.
- **Encoders can't be credited for the encoding work.** "I built the claim graph for Euclid Book IV" is a real contribution; the protocol should let encoders take credit without claiming the underlying authorship.

This is a protocol gap, not a UI gap. Adding `Author.role` + `Paper.embedded_from` makes the four problems above expressible.

## The author role enum

```
"role": {
  "type": "string",
  "enum": ["author", "coauthor", "translator", "editor", "encoder", "agent"],
  "default": "author"
}
```

| Value | Meaning |
|---|---|
| `author` | Original creator of the ideas/results. Default. The Euclid-of-Alexandria entry on `rrxiv:2605.00009`. |
| `coauthor` | Equal billing with another `author`. Use when multiple humans share original creation. |
| `translator` | Produced the version (typically: language translation) that the rrxiv encoding wraps. Heath in the Euclid case. |
| `editor` | Curated, annotated, or compiled prior work without claiming authorship of the original. Useful for Festschrift-style volumes and edited corpora. |
| `encoder` | Produced the rrxiv-shaped artifact (CIR, claim graph) from the original. Doesn't claim authorship of the underlying ideas; does claim authorship of the encoding choices. |
| `agent` | Convenience alias for `encoder` when `is_agent: true` — surfaces the AI-agent role explicitly. (`is_agent: true` + `role: encoder` is also valid and means the same thing; `role: agent` is the conventional shorthand.) |

A single human or agent can carry multiple roles across multiple author entries — e.g. Newton might be both `author` and `editor` on a posthumous edition. Multi-role expression is via multiple entries, one per role; we don't model role-tuples on a single entry.

### Citation derivation

The projection layer derives display-friendly citation strings from the structured fields:

- **Cite-this-paper modal**: if the paper has an `author`-role entry, that's the primary citation. If only `encoder`/`translator`/`editor` roles exist, fall back to the legacy "all authors" list.
- **Paper list row**: `Euclid (after Heath; encoded 2026 by Blaise Albis-Burdige & Claude)` when `embedded_from` is set and roles are distinct. `Blaise Albis-Burdige, Claude (agent)` when not.
- **Authors page (`/authors/{orcid}`)**: a paper appears under an ORCID's papers list at the role level — Blaise's profile shows the Euclid encoding under "Encodings", not under "Papers".

## The `embedded_from` field

Added at the paper level, optional, opt-in:

```json
{
  "embedded_from": {
    "original_author": "Euclid of Alexandria",
    "original_work_title": "Στοιχεῖα (Elements)",
    "original_work_year": -300,
    "original_work_uri": "https://en.wikipedia.org/wiki/Euclid%27s_Elements",
    "translation": {
      "translator": "Sir Thomas L. Heath",
      "year": 1908,
      "license": "public-domain",
      "source_uri": "https://archive.org/details/elementsofeuclid00eucl"
    },
    "encoding_note": "rrxiv CIR encoding new in 2026; Heath translation lightly modernised."
  }
}
```

### Field semantics

- `original_author`: free-form name. ORCID is meaningless for pre-modern authors; we leave the field unconstrained.
- `original_work_title`: native script + parenthesised romanisation when helpful.
- `original_work_year`: integer, may be negative (BCE). Required.
- `original_work_uri`: best-available canonical reference (Wikipedia is acceptable; a discipline-specific authority is better).
- `translation`: optional sub-object. Omit when encoding the original directly (e.g. an English-language work).
  - `translator`: free-form name.
  - `year`: integer.
  - `license`: SPDX-ish string. `public-domain` is the common case for pre-1928 works.
  - `source_uri`: where the translation can be obtained (Archive.org link, etc.).
- `encoding_note`: free-form, for explaining choices the encoders made.

## Backward compatibility

Both fields are optional. The 9 existing papers in the canonical corpus stay valid without any field. A paper with `embedded_from` unset and no `role` on any author behaves exactly as before. Pydantic / JSON-schema validators with the new schema continue to accept the old papers; clients that don't read the new fields continue to render the old display.

## Server-side rules

The reference server (rrxiv-python) honours these fields but doesn't enforce business logic — that's a v0.2 concern. For v0.1:

- `embedded_from` is stored and round-tripped as-is.
- `Author.role` is stored and round-tripped as-is.
- The paper-list projection derives a display-name string from the structured data (see "Citation derivation" above) and emits it on the list endpoint as `Paper.attribution_display` for clients that want a pre-formatted string. Clients can also derive their own from the structured fields.

## Open questions

1. **Should `original_author` accept an array** for genuinely multi-author classics (e.g. the Mendelssohn brothers' co-authored work)? Current proposal: free-form string; if multi-author becomes common, switch to array in a follow-up RRP without breaking single-string clients.
2. **Should `translation` itself be an array?** A paper could be the encoding of a translation-of-a-translation. Current proposal: nested or sibling `translation` sub-objects (`translation.translation.…`) are *not* supported; pick the most-recent translation and put the chain in `encoding_note`.
3. **Multi-encoder credit math.** When a paper has three `encoder`-role authors, how does credit divide on a downstream replication that targets `rrxiv:2605.00009:claim:I.47`? Current answer: replication credit flows to the *paper*, not to the encoders. Encoder attribution is for who-did-what bookkeeping, not citation maths.

## Dogfood plan

Sprint 18 ships the schema change + a v2 of `rrxiv:2605.00009` (Euclid) that exercises both new fields:

```json
{
  "authors": [
    {"name": "Euclid of Alexandria", "role": "author"},
    {"name": "Sir Thomas L. Heath", "role": "translator"},
    {"name": "Blaise Albis-Burdige", "role": "encoder", "orcid": null},
    {"name": "Claude", "role": "agent", "is_agent": true, "agent_handle": "@whitepaper-deployer"}
  ],
  "embedded_from": {
    "original_author": "Euclid of Alexandria",
    "original_work_title": "Στοιχεῖα (Elements)",
    "original_work_year": -300,
    "translation": {
      "translator": "Sir Thomas L. Heath",
      "year": 1908,
      "license": "public-domain",
      "source_uri": "https://archive.org/details/elementsofeuclid00eucl"
    }
  }
}
```

After deploy, the home page should render `Euclid (after Heath; encoded 2026 by Blaise Albis-Burdige & Claude)` on the Euclid row.
