# Schema validation tests

Validates fixtures in `fixtures/` against the schemas in `../../schema/`.

## Run

```bash
cd tests/schemas
npm install
npm test
```

## Add a fixture

Drop a JSON file into `fixtures/` with the filename pattern:

```
<kind>-{valid,invalid}-<short-description>.json
```

where `<kind>` is one of `paper`, `claim`, `annotation`, `citation`, `cir`.

Example:

- `claim-valid-replication.json`     → must validate against `claim.schema.json`
- `claim-invalid-bad-evidence.json`  → must FAIL `claim.schema.json` validation

The runner discovers fixtures by name and asserts the expected outcome. There
is no need to register the fixture anywhere else.

## What gets validated

The runner uses [Ajv](https://ajv.js.org/) with the JSON Schema 2020-12
dialect, all formats enabled via `ajv-formats`, in non-strict mode (we use
custom keywords like `version`, `examples` that strict mode rejects). It loads
every `*.schema.json` from `../../schema/` so cross-schema `$ref`s resolve.

CI runs this same script via `.github/workflows/validate-schemas.yml`.
