# rrvix schemas

JSON Schema 2020-12 definitions for the rrvix protocol data model.

## Files

- `cir.schema.json` — the Canonical Intermediate Representation (CIR), the agent-readable
  form of a rrvix paper. The most important file in this directory.
- `claim.schema.json` — TBD, stand-alone schema for a Claim object (currently inlined in CIR).
- `annotation.schema.json` — TBD.
- `paper.schema.json` — TBD.
- `citation.schema.json` — TBD.

## Versioning

Schemas use semantic versioning at the schema level. The `version` field at the top of
each schema file indicates its version. Breaking changes require a major version bump
and a new RRP.

## Validation

```bash
# Using ajv (Node.js)
npx ajv-cli validate -s cir.schema.json -d ../examples/<paper>.cir.json

# Using python-jsonschema
python -m jsonschema -i ../examples/<paper>.cir.json cir.schema.json
```
