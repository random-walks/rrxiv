// Schema validation test runner.
//
// Loads every schema in ../../schema/ and validates each fixture in fixtures/
// against the schema implied by its filename:
//
//   <kind>-valid-*.json   must validate
//   <kind>-invalid-*.json must FAIL validation
//
// where <kind> is one of: paper, claim, annotation, citation, cir.
//
// Cross-schema $refs are resolved by loading every schema before compilation.
// Exit code 0 if all assertions hold, 1 otherwise.

import { readFileSync, readdirSync } from "node:fs";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCHEMA_DIR = join(__dirname, "..", "..", "schema");
const FIXTURES_DIR = join(__dirname, "fixtures");

const KIND_TO_SCHEMA_FILE = {
  paper: "paper.schema.json",
  paper_list_item: "paper_list_item.schema.json",
  claim: "claim.schema.json",
  annotation: "annotation.schema.json",
  citation: "citation.schema.json",
  section: "section.schema.json",
  figure: "figure.schema.json",
  cir: "cir.schema.json",
  // Sprint 17 onwards — these schemas have fixtures the test runner
  // was silently skipping until now (reported as "failed" by the
  // outer counter but never actually exercised).
  reproducibility_manifest: "reproducibility_manifest.schema.json",
  revision_diff: "revision_diff.schema.json",
  submission_request: "submission_request.schema.json",
  pulse_snapshot: "pulse_snapshot.schema.json",
  // Sprint 24 — RRP-0024 (ORCID key binding) + RRP-0025 (agent provenance).
  orcid_signing_key: "orcid_signing_key.schema.json",
  agent_provenance: "agent_provenance.schema.json",
  // Sprint 26 — RRP-0027 (canonical model registry).
  model_registry: "model_registry.schema.json",
};

function loadJson(path) {
  return JSON.parse(readFileSync(path, "utf-8"));
}

function buildAjv() {
  const ajv = new Ajv2020({
    strict: false,
    allErrors: true,
    validateFormats: true,
  });
  addFormats.default(ajv);

  for (const file of readdirSync(SCHEMA_DIR)) {
    if (!file.endsWith(".schema.json")) continue;
    const schema = loadJson(join(SCHEMA_DIR, file));
    ajv.addSchema(schema);
  }

  return ajv;
}

function classifyFixture(filename) {
  const m = filename.match(/^([a-z_]+)-(valid|invalid)-/);
  if (!m) return null;
  const [, kind, validity] = m;
  if (!(kind in KIND_TO_SCHEMA_FILE)) return null;
  return { kind, expectValid: validity === "valid" };
}

function getSchema(ajv, kind) {
  const file = KIND_TO_SCHEMA_FILE[kind];
  const path = join(SCHEMA_DIR, file);
  const id = loadJson(path)["$id"];
  return ajv.getSchema(id);
}

function main() {
  const ajv = buildAjv();
  const fixtures = readdirSync(FIXTURES_DIR).filter((f) => f.endsWith(".json"));

  let passed = 0;
  let failed = 0;
  const failures = [];

  for (const fixture of fixtures.sort()) {
    const cls = classifyFixture(fixture);
    if (!cls) {
      failures.push({
        fixture,
        reason: `filename does not match <kind>-{valid,invalid}-*.json convention`,
      });
      failed += 1;
      continue;
    }

    const validate = getSchema(ajv, cls.kind);
    if (!validate) {
      failures.push({
        fixture,
        reason: `no compiled schema for kind '${cls.kind}'`,
      });
      failed += 1;
      continue;
    }

    const data = loadJson(join(FIXTURES_DIR, fixture));
    const isValid = validate(data);

    if (isValid === cls.expectValid) {
      console.log(`  PASS  ${fixture}  (expected ${cls.expectValid ? "valid" : "invalid"}, got ${isValid ? "valid" : "invalid"})`);
      passed += 1;
    } else {
      const errs = validate.errors ? validate.errors.map((e) => `${e.instancePath || "/"} ${e.message}`).join("; ") : "(no errors)";
      console.log(`  FAIL  ${fixture}  (expected ${cls.expectValid ? "valid" : "invalid"}, got ${isValid ? "valid" : "invalid"})`);
      if (cls.expectValid) {
        console.log(`        errors: ${errs}`);
      }
      failures.push({ fixture, reason: errs });
      failed += 1;
    }
  }

  console.log("");
  console.log(`Result: ${passed} passed, ${failed} failed (out of ${fixtures.length} fixtures)`);

  if (failed > 0) {
    process.exit(1);
  }
}

main();
