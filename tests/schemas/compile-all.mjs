// Sanity-compile every schema under ../../schema/ to catch typos that
// `test.mjs`'s fixture suite wouldn't surface on its own (e.g. an
// invalid $ref that no fixture happens to exercise).
//
// We load every sibling first via addSchema, then compile each by $id,
// so cross-file `$ref`s (cir.schema.json -> paper.schema.json#/$defs/Author)
// resolve cleanly. The validate-schemas GH workflow runs this immediately
// after `npm ci` so `ajv` + `ajv-formats` are already in local node_modules.

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCHEMA_DIR = join(__dirname, "..", "..", "schema");

const ajv = new Ajv2020({ strict: false, allErrors: true });
addFormats.default(ajv);

const files = readdirSync(SCHEMA_DIR).filter((f) => f.endsWith(".schema.json"));

// Phase 1 — load every schema so cross-refs are registered.
for (const f of files) {
  ajv.addSchema(JSON.parse(readFileSync(join(SCHEMA_DIR, f), "utf-8")));
}

// Phase 2 — retrieve each compiled schema by $id. addSchema above
// already validated each one's structure + compiled it into the
// registry; getSchema confirms retrieval works and surfaces any
// `$ref` that failed to resolve at compile time.
let failed = 0;
for (const f of files) {
  const schema = JSON.parse(readFileSync(join(SCHEMA_DIR, f), "utf-8"));
  const id = schema.$id;
  if (!id) {
    console.log(`ERR ${f}: missing $id`);
    failed++;
    continue;
  }
  const validate = ajv.getSchema(id);
  if (!validate) {
    console.log(`ERR ${f}: getSchema(${id}) returned undefined`);
    failed++;
    continue;
  }
  console.log(`OK  ${f}`);
}

if (failed > 0) {
  console.log(`\n${failed} schema(s) failed to compile.`);
  process.exit(1);
}
console.log(`\nAll ${files.length} schemas compile cleanly.`);
