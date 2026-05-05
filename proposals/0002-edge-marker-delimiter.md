# RRP-0002 — Edge marker delimiter in `rrxiv.cls`

- **Status:** Accepted
- **Champion:** rrxiv maintainers
- **Created:** 2026-05-05
- **Last updated:** 2026-05-05
- **Affects:** `rrxiv.cls`, parser implementations
- **Supersedes:** none
- **Superseded by:** none

## Summary

Replace the colon (`:`) used as the field separator in sidecar edge markers with a non-colon character (proposed: `|`), so that edge markers are unambiguously parseable when claim IDs themselves contain colons. The current format `RRXIV:edge:<type>:<src>:<dst>` is ambiguous because the canonical claim-ID convention `<paper_id>:claim:<label>` puts colons *inside* `<src>` and `<dst>`.

## Motivation

`rrxiv.cls` v0.1 emits edge markers as colon-joined strings:

```
RRXIV:edge:depends_on:rrxiv-0001:claim:queryability:rrxiv-0001:claim:volume-structure
```

The reference parser (`rrxiv-python/src/rrxiv/parser/sidecar.py`) handles this by splitting on `:` and assuming both `<src>` and `<dst>` have the same number of colon-separated tokens (the canonical `paper:claim:label` shape). This works for canonical IDs but breaks on:

- IDs that don't follow the convention (e.g. an external `arxiv:2305.12345`).
- Claim labels that contain colons themselves (the schema doesn't forbid this).
- Mixed-shape pairs where the src and dst have different colon counts (e.g. a paper with `claim:foo` linking to an external `arxiv:2305.12345:claim:bar`).

The current FIXME in `sidecar.py`:

```python
# FIXME(v0.2): rrxiv.cls writes RRXIV:edge:<type>:<src>:<dst> with `:`
# joining src and dst, but `:` is ALSO the conventional separator inside
# IDs (paper_id:claim:label). The format is genuinely ambiguous without
# a delimiter change. The midpoint-split heuristic below works as long
# as src and dst have the same colon count — which is true for the
# canonical <paper_id>:claim:<label> shape but breaks otherwise.
```

This is a real correctness issue, not just a code smell. A future paper that uses any non-canonical ID will silently produce wrong edges, and the parser won't notice.

## Design

Change the separator between `<src>` and `<dst>` in edge markers from `:` to `|`. The `RRXIV:edge:<type>:` prefix stays colon-joined (the prefix's tokens never contain `:` by construction), but the `<src>|<dst>` join uses `|`:

**Before:**
```
RRXIV:edge:depends_on:rrxiv-0001:claim:queryability:rrxiv-0001:claim:volume-structure
```

**After:**
```
RRXIV:edge:depends_on:rrxiv-0001:claim:queryability|rrxiv-0001:claim:volume-structure
```

`|` is chosen because:

- It's not in the JSON Schema or LaTeX label conventions for any current rrxiv component.
- It's an ASCII character with no LaTeX special meaning (unlike `\`, `{`, `}`, `&`).
- It survives `\write` without escaping (verified locally).
- It's visually distinct from `:` in the sidecar so authors and tool authors can tell at a glance which version they're reading.

### `rrxiv.cls` changes

The four edge macros are updated:

```diff
-\newcommand{\dependson}[2]{\immediate\write\rrxiv@sidecar{RRXIV:edge:depends_on:#1:#2}}
-\newcommand{\contradicts}[2]{\immediate\write\rrxiv@sidecar{RRXIV:edge:contradicts:#1:#2}}
-\newcommand{\extendsclaim}[2]{\immediate\write\rrxiv@sidecar{RRXIV:edge:extends:#1:#2}}
-\newcommand{\supports}[2]{\immediate\write\rrxiv@sidecar{RRXIV:edge:supports:#1:#2}}
+\newcommand{\dependson}[2]{\immediate\write\rrxiv@sidecar{RRXIV:edge:depends_on:#1|#2}}
+\newcommand{\contradicts}[2]{\immediate\write\rrxiv@sidecar{RRXIV:edge:contradicts:#1|#2}}
+\newcommand{\extendsclaim}[2]{\immediate\write\rrxiv@sidecar{RRXIV:edge:extends:#1|#2}}
+\newcommand{\supports}[2]{\immediate\write\rrxiv@sidecar{RRXIV:edge:supports:#1|#2}}
```

The cls bumps from v0.1 to v0.2.

### Parser changes

`rrxiv-python`'s sidecar reader gains pipe-delimited edge handling. For backward compatibility with v0.1 sidecars (which already exist on disk for any paper compiled before this RRP lands), the parser supports both formats:

```python
if "|" in id_tokens_joined:  # v0.2 format
    src, dst = id_tokens_joined.split("|", 1)
else:  # v0.1 format — apply midpoint-split heuristic
    # ... existing fallback
```

The fallback emits a `DeprecationWarning` so authors know to recompile.

## Alternatives considered

### Use `;` as the separator instead of `|`

Rejected. `;` is fine in LaTeX but appears in some BibTeX entries that authors might paste into edge IDs by mistake. `|` is rarer in practice.

### Use a multi-character separator like `-->`

Rejected. Verbose and easy to mistype. `|` is single-character and unambiguous.

### Keep the colon and disambiguate by counting

This is the v0.1 status quo. It works for the canonical case but fails on degenerate cases (different shapes for src and dst), and silently — which is the worst kind of failure.

### Use JSON-encoded edge markers

Considered: `RRXIV:edge:depends_on:{"src":"...","dst":"..."}`. Rejected — opens a large can of worms (escape rules in `\write`, JSON parsing in the cls's parser layer). Pipe-separated is dramatically simpler.

### Embed marker payload in `\write` as one string with internal `\rrxiv@sep` macro

Possible but adds cls complexity for marginal gain. Just changing the literal character is cheaper.

## Drawbacks

- **Compatibility break for tools that consume the sidecar directly** (other than the reference parser). Any third-party tool that hard-codes `:` as the edge separator needs an update. We've shipped exactly one parser implementation as of this RRP, so the blast radius is small — but it's worth noting.
- **Existing on-disk sidecars use the v0.1 format.** The parser's backward-compat fallback handles them, but anyone who shipped a CIR and wants to re-derive it needs to recompile with v0.2 of the cls.

## Impact on existing code and content

| Surface | Change |
|---------|--------|
| `template/rrxiv.cls` | 4 lines (the four edge macros). Version bumped to v0.2. |
| `template/rrxiv-template.tex` | None (the template doesn't depend on the marker format). |
| `template/examples/minimal/rrxiv.cls` | Same as `template/rrxiv.cls` (sync via `scripts/sync-cls.sh` once that lands). |
| `whitepaper/rrxiv.cls` | Same as `template/rrxiv.cls`. |
| `rrxiv-python/src/rrxiv/parser/sidecar.py` | Add pipe-delimited path; keep v0.1 fallback with deprecation warning. |
| `rrxiv-python/tests/test_sidecar.py` | New tests for v0.2 format; existing v0.1 tests stay (verify backcompat). |
| Existing CIRs | Not affected; the CIR doesn't carry the on-disk marker format. |
| Compiled-but-unsubmitted papers | Need recompilation against v0.2 cls before submission. |

Schema changes: **none**. The CIR's edge fields are unchanged.

## Open questions

- **When does the v0.1 fallback get removed?** Suggest: at v1.0 of the cls, alongside the first stable rrxiv release.
- **Should the cls expose `\rrxiv@edge@sep` as a configurable macro for power users who want a different separator?** Probably no — universality matters more than flexibility.

## Reference implementation

A PR will follow this RRP touching:

- `template/rrxiv.cls` (and its two duplicates)
- `rrxiv-python/src/rrxiv/parser/sidecar.py`
- `rrxiv-python/tests/test_sidecar.py`

## References

- Existing FIXME in [`rrxiv-python/src/rrxiv/parser/sidecar.py`](https://github.com/random-walks/rrxiv-python/blob/main/src/rrxiv/parser/sidecar.py).
- [`spec/0004-tex-template.md`](../spec/0004-tex-template.md) §"Inline edges" — describes the current format.
- The whitepaper section on the sidecar mechanism.

## Changelog

- **2026-05-05**: Created. Status: Draft.
- **2026-05-05**: Accepted. cls bumped to v0.2; reference parser updated with v0.1 fallback + DeprecationWarning. Implementation PRs: rrxiv-python#4 (parser), rrxiv#7 (cls).
