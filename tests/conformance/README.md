# rrxiv conformance test suite

This directory contains the cross-implementation conformance tests that any
rrxiv-compliant parser, client, or server must pass.

The suite is **implementation-agnostic**: tests are expressed as input
fixtures (paper sources, sidecars, expected CIRs / API responses) plus a
small runner that drives the implementation under test through a thin
command-line shim.

## Layout

```
tests/conformance/
├── README.md                  ← this file
├── runner.py                  ← runs the suite against an --impl command
├── fixtures/
│   └── minimal/               ← the smallest valid rrxiv paper
│       ├── minimal.tex
│       ├── minimal.bib
│       ├── rrxiv.cls          ← bundled so the example is drop-in
│       └── expected.cir.json  ← canonical CIR a compliant parser must emit
├── parsers/
│   └── README.md              ← TeX → CIR parser conformance (this PR scaffolds)
└── api/
    └── README.md              ← API conformance (Phase 1)
```

## Parser conformance

A parser implementation is **conformant** if, for every fixture in
`fixtures/`, it produces a CIR JSON that:

1. **Validates against `schema/cir.schema.json`** in this repo.
2. **Matches `expected.cir.json`** at the load-bearing fields (paper id,
   version, license, topics, claims[].id, claim graph edges). The
   suite's diff is *semantic* — fields that vary by implementation
   (`submitted_at` is server-set; `source.uri` is environment-specific)
   are excluded from the comparison.

## Running the suite

```bash
# Against the reference rrxiv-python parser:
python tests/conformance/runner.py --impl 'uv run rrxiv parse'

# Against a hypothetical other implementation:
python tests/conformance/runner.py --impl '/path/to/your/parse-rrxiv'
```

The runner invokes:

```
<impl> <path/to/fixture.tex> --output /tmp/result.cir.json
```

…and compares the result against `expected.cir.json` for that fixture.
The comparison uses the rules in *Comparison rules* below.

## Comparison rules

Implementations vary on fields that are environment-specific. The
suite ignores:

- `submitted_at` (server-set; varies per ingestion).
- `source.uri` (file-path-dependent; the parser is a local tool, not a server).
- Any other field listed in the fixture's `_ignore_fields` array if present.

Everything else must match. The runner reports per-field diffs on
failure.

## Adding a fixture

1. Create `fixtures/<name>/` with the paper source files and any
   ancillary files (`.bib`, bundled `rrxiv.cls`).
2. Run the reference parser to generate the expected CIR:
   ```
   uv run rrxiv parse fixtures/<name>/<paper>.tex --output fixtures/<name>/expected.cir.json
   ```
3. Hand-edit `expected.cir.json` if needed (e.g. to redact
   environment-specific fields, adjust ID conventions).
4. Optionally add `_ignore_fields` to the fixture's expected JSON to
   exclude additional fields from the comparison.
5. Document the fixture's purpose in `fixtures/<name>/README.md`
   (what does this fixture exercise?).

## Status

v0.1: parser conformance only. The `parsers/` and `api/` subdirectories
are stubs for future work:

- **`parsers/`** will hold parser-specific runners as more implementations
  exist (e.g. a hypothetical `rrxiv-rust` parser).
- **`api/`** will hold HTTP API conformance tests (request/response shape
  checks against `schema/api.openapi.yaml`) once a server implementation
  exists.

CI runs the suite via `.github/workflows/conformance-tests.yml`. Until
the reference rrxiv-python parser is co-located in CI, the workflow is a
placeholder; the local invocation above is the canonical execution path.
