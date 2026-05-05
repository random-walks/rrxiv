# Migrations — rrxiv schemas

When a JSON schema bumps version, this file records what changed and how a CIR or implementation written against the old version can be migrated to the new one. Pre-1.0 minor bumps may include breaking changes (per the project's SemVer disclaimer in [`CHANGELOG.md`](CHANGELOG.md)); each entry below describes the migration path.

Organised newest-first.

## v0.1.0 — initial schema set

No migrations required; this is the baseline.

The v0.1.0 schemas are:

| Schema | $id |
|--------|-----|
| paper.schema.json | `https://rrxiv.com/schema/v0/paper.schema.json` |
| claim.schema.json | `https://rrxiv.com/schema/v0/claim.schema.json` |
| annotation.schema.json | `https://rrxiv.com/schema/v0/annotation.schema.json` |
| citation.schema.json | `https://rrxiv.com/schema/v0/citation.schema.json` |
| section.schema.json | `https://rrxiv.com/schema/v0/section.schema.json` |
| figure.schema.json | `https://rrxiv.com/schema/v0/figure.schema.json` |
| cir.schema.json | `https://rrxiv.com/schema/v0/cir.schema.json` |

## Pre-rename note (rrvix → rrxiv)

This isn't a *schema* migration but it affects existing artifacts:

- **Sidecar files** with the `.rrvix.aux` extension and `RRVIX:`-prefixed lines are still parseable by the rrxiv-python reference parser. The parser emits a `DeprecationWarning` per parse call and normalises the prefix; existing CIRs are unchanged.
- **Schema `$id` URLs** that point at `https://rrvix.org/schema/v0/...` were never published; nothing references them externally. Update local copies of the schemas to the `rrxiv.com` URLs.
- **Source files** that use `\documentclass{rrvix}` and `\rrvixid{...}` etc.: rename to `rrxiv` / `\rrxivid{...}` / etc. The cls is no longer named `rrvix.cls`. The `rrxiv init` scaffold can produce a fresh template.

## Future migrations (placeholder structure)

When v0.1.x → v0.2.0 lands, this section documents:

- **Breaking field removals** with the deprecation timeline.
- **New required fields** with a recipe to backfill existing CIRs (where automatable).
- **Enum tightening** (e.g., a value that was previously valid is now rejected) with the list of affected values and the recommended replacement.
- **Cross-schema `$ref` rearrangements** that affect how composite documents validate.

Each entry should include:

1. **What changed** in the schema(s).
2. **What an existing CIR / paper / annotation needs to do** to validate against the new version.
3. **Tooling**: a script or function in `rrxiv-python` that automates the migration where possible.
4. **The accepting RRP** (per `proposals/README.md` §"When you need an RRP").

## See also

- [`CHANGELOG.md`](CHANGELOG.md) — what changed and when.
- [`proposals/`](proposals/) — RRPs documenting the *why* behind breaking changes.
- [`spec/0008-governance.md`](spec/0008-governance.md) — the locked principles that constrain what migrations are even allowed.
