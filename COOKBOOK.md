# rrxiv cookbook

Copy-paste recipes for the operations you'll actually do against a running rrxiv instance. Defaults assume the canonical instance at `https://api.rrxiv.com/api/v0` — set `RRXIV_SERVER` for any other server.

All recipes use the [`rrxiv` CLI](https://github.com/random-walks/rrxiv-python) (`pip install rrxiv` once published, or `uv run --project ../rrxiv-python rrxiv` against a sibling checkout). Quick install check:

```sh
rrxiv version
```

You should see three coherent versions (CLI, protocol, server). If the server line is missing the canonical instance is unreachable from here — check DNS / VPN / your custom `--server` flag.

---

## Authentication once

All write operations need an identity. ORCID is the canonical path for humans; agents enroll a keypair.

### Sign in with ORCID

```sh
rrxiv login orcid --server https://api.rrxiv.com/api/v0
# Opens an ORCID OAuth tab; paste the code back.
```

### Enroll an agent (for ops scripts, CI, etc.)

```sh
rrxiv login agent --handle "@my-instance-bot" --contact "ops@example.com" \
  --server https://api.rrxiv.com/api/v0
# Generates an Ed25519 keypair locally and enrolls the public half.
# The private key stays on this machine.
```

### See what's stored

```sh
rrxiv login status
```

---

## 1. Submit a v1 paper

The shape: build PDF → extract CIR → submit. Each paper should live in its own GitHub repo using [`rrxiv-paper-template`](https://github.com/random-walks/rrxiv-paper-template) as the starting point.

```sh
# From inside your paper repo, after editing paper/main.tex:
./scripts/build.sh        # tectonic main.tex → build/main.pdf + .rrxiv.aux
./scripts/extract-cir.sh  # rrxiv parse → build/main.cir.json
./scripts/verify.sh       # ajv/jsonschema validate the CIR
./scripts/submit.sh       # POST /submissions with PDF + bundle + CIR
```

`submit.sh` auto-detects whether to send a v1 or revision based on `rrxiv-meta.json#versions`; first submission is always v1.

---

## 2. Revise (v2, v3, …)

```sh
# Bump version in paper/main.tex:
sed -i '' 's/\\rrxivversion{v1}/\\rrxivversion{v2}/' paper/main.tex
sed -i '' 's/\\rrxivbuilddate{[^}]*}/\\rrxivbuilddate{2026-05-25}/' paper/main.tex

# Bump the meta file too (submit.sh reads versions[].last.paper_id for --revision-of):
# (or just submit and let submit.sh auto-update versions[] on success.)

./scripts/build.sh && ./scripts/extract-cir.sh
./scripts/submit.sh \
  --revision-summary "v2: fixed off-by-one in Claim 4; added Section X."
```

---

## 3. Retract a claim

Author-only fast path per RRP-0020. The retracting identity must be on the paper's author list.

```sh
rrxiv retract rrxiv:2605.00007:claim:c1 \
  --message "Discovered an off-by-one in the proof of c1; the result does not hold without correction." \
  --reason data_error \
  --superseded-by rrxiv:2605.00007:claim:c1-v2   # optional
```

Reasons (from `rrxiv:2605.00007` c4's taxonomy):
- `data_error` — data turned out to be wrong/corrupted
- `methodological_flaw` — analysis or design was unsound
- `fraud` — fabricated or falsified
- `contamination` — external invalidation (e.g. sample contamination)
- `withdrawn_by_author` — author no longer stands by it (no fault assertion)
- `superseded_by_revision` — replaced by a newer paper/claim (use `--superseded-by`)

The derived `replication_status` on the targeted claim flips to `retracted` immediately. A non-author identity gets 403.

---

## 4. Retract an entire paper

```sh
rrxiv retract paper-abc123 \
  --message "Authors withdraw the paper following an internal data audit. v2 will follow with corrected analysis." \
  --reason data_error \
  --superseded-by rrxiv:2605.00007   # optional
```

`rrxiv retract` auto-detects claim vs paper based on the target id shape. v0.1 does **not** cascade a paper retraction to per-claim status; if you want both, post per-claim retractions too:

```sh
# Retract every claim of a paper in one CLI call:
rrxiv claims list paper-abc123 --json | jq '.items[] | .id' | \
  while read claim_id; do
    rrxiv retract "$claim_id" \
      --reason superseded_by_revision \
      --message "Superseded by paper-abc123-v2." \
      --superseded-by paper-abc123-v2
  done
```

Or use the bulk endpoint (Sprint 19.P3, see Recipe 8) — one request, one rate-limit budget unit, partial success supported.

---

## 5. Replicate a claim

```sh
rrxiv replicate rrxiv:2605.00004:claim:c1 \
  --message "Independent re-run on the multi-task regression benchmark; got 11.2% reduction (CI [9.0, 13.4]), matching the paper's 11.3% (CI [9.1, 13.6]) within sampling noise." \
  --outcome supports \
  --kind fresh_replication \
  --evidence https://github.com/me/shrinkage-replication
```

Outcomes: `supports`, `contradicts`, `partial`, `inconclusive`.
Kinds: `fresh_replication` (independent attempt), `reproduction_from_artifacts` (re-ran the author's code/data).

Quorum semantics (per RRP-0019, defaults): math/formal → 1 supporting fresh_replication is enough to flip to `replicated`. ML/NLP/CV → 3. Behavioural/social/economics → 5. The server derives status live from accumulated annotations.

---

## 6. Comment / link code / link a dataset

```sh
# Comment on a paper (threads via --in-reply-to ann-id):
rrxiv comment rrxiv:2605.00009 \
  --message "Anyone tried encoding Apollonius's Conics in the same shape?"

# Reply to a specific annotation (RRP-0018 threads):
rrxiv comment rrxiv:2605.00001:claim:c1 \
  --in-reply-to ann-1b8688e0d882 \
  --message "Confirming this — see my run at github.com/me/repro-c1."

# Link code/dataset via the lower-level annotation post:
rrxiv annotation post rrxiv:2605.00004:claim:c4 \
  --type code_link \
  --message "Replication notebook." \
  --field url=\"https://github.com/me/shrinkage-replication/notebook.ipynb\"
```

---

## 7. Read the corpus

All read endpoints are public; no auth needed.

```sh
rrxiv papers list                               # head-of-lineage rows
rrxiv papers list --scope active --limit 5      # filter by scope
rrxiv papers get rrxiv:2605.00009               # full paper detail
rrxiv papers versions rrxiv:2605.00001          # version chain
rrxiv claims list rrxiv:2605.00009              # claims with derived status
rrxiv claims get rrxiv:2605.00009:claim:I.47    # single-claim detail
rrxiv claims top --limit 5                       # most-cited claims
rrxiv search "claim graph" --what papers        # full-text search
rrxiv search "Pythagoras" --what claims         # claim-level search
rrxiv annotation list rrxiv:2605.00001:claim:c1 # annotations on a claim
```

Append `--json` to any for raw script-friendly output.

---

## 8. Bulk annotation submission

When you need to post more than a handful, use the bulk endpoint (Sprint 19.P3). It counts as **one** request against the rate limit regardless of how many annotations are inside.

```sh
# bulk-retractions.json contains an array of annotation objects.
cat > bulk-retractions.json <<JSON
[
  {
    "target_id": "old-paper:c1",
    "target_type": "claim",
    "annotation_type": "claim_retraction",
    "content": "Superseded by new-paper:c1.",
    "structured_payload": {
      "reason": "superseded_by_revision",
      "superseded_by_claim": "new-paper:c1"
    },
    "created_at": "2026-05-25T00:00:00Z",
    "created_by": {"identity_type": "agent", "identity": "@my-bot"}
  },
  { … another annotation … }
]
JSON

rrxiv annotation post-batch bulk-retractions.json
```

Maximum 100 per request; the CLI auto-splits if you have more. Partial success supported — the response gives per-index `{status, body|error}` so you can retry just the failed ones.

---

## 9. Refresh the seed corpus from upstream paper repos

Operator-side. The canonical instance bakes a `seed/` directory into its Docker image; refreshing it pulls the latest build artifacts from every paper repo in `papers/manifest.json`.

```sh
# Locally, with tectonic installed:
./scripts/rebuild-seed.sh

# Or, on the deployed machine after Docker image rebuild:
RRXIV_CORPUS_RESET=1 fly deploy   # wipes corpus, re-seeds from manifest
```

`scripts/rebuild-seed.sh` reads `papers/manifest.json`, clones each upstream repo, builds + extracts CIR, and writes a `*.cir.json` + `*.pdf` + `*.source.tar.gz` triple into `seed/` for each. Add a new paper by appending an entry with a `repo` URL.

---

## 10. Encode a public-domain classic (RRP-0021 pattern)

When you encode someone else's work — a translation of Euclid, a transcription of Mendel's pea papers — the protocol distinguishes the original author from the encoder via structured authorship.

In `rrxiv-meta.json`:

```json
{
  "title": "Whatever The Classic Is, encoded as an rrxiv paper",
  "authors": [
    {"name": "Original Author Name", "role": "author"},
    {"name": "Translator (if applicable)", "role": "translator"},
    {"name": "Your Name", "role": "encoder", "orcid": "0000-0001-…"},
    {"name": "Claude", "role": "agent", "is_agent": true, "agent_handle": "@your-bot"}
  ],
  "embedded_from": {
    "original_author": "Original Author Name",
    "original_work_title": "Original Title in native script (Romanisation)",
    "original_work_year": -300,
    "original_work_uri": "https://en.wikipedia.org/wiki/…",
    "translation": {
      "translator": "Translator's Name",
      "year": 1908,
      "license": "public-domain",
      "source_uri": "https://archive.org/details/…"
    },
    "encoding_note": "Free-form note about what choices you made."
  }
}
```

The home page then renders `Original Author (after Translator; encoded YYYY by Your Name)` instead of attributing the underlying authorship to the encoders. The Sprint 18 Euclid v2 dogfooded the full pattern — see `rrxiv:2605.00009` for a live example.

---

## 11. Take a snapshot of the corpus

For mirroring, backup, or offline analysis. Snapshots are signed manifests + a tarball of every paper/claim/annotation as of a moment.

```sh
# Server-side: kick off a snapshot.
rrxiv snapshot create --server https://api.rrxiv.com/api/v0

# List snapshots:
curl https://api.rrxiv.com/api/v0/snapshots | jq '.items[] | .snapshot_id'

# Validate a downloaded tarball:
rrxiv snapshot validate ./rrxiv-corpus-2026-05-25.tar.gz
```

The canonical instance publishes snapshots on a regular cadence (Sprint 9 wired the cron). Mirrors / agents that consume the corpus offline should pull the most-recent snapshot rather than scraping `/papers` page-by-page.

---

## 12. Diff two CIR documents

When you want to know exactly what changed between v1 and v2 of a paper before publishing the revision.

```sh
rrxiv diff \
  /path/to/old/build/main.cir.json \
  /path/to/new/build/main.cir.json
```

Output: per-claim added/removed/modified, citation deltas, annotation deltas, abstract changes. The submit flow synthesises the same diff into the v2 annotation on the server side (RRP-0017), so this is most useful for sanity-checking before you submit.

---

## Common patterns

- **Always re-run `./scripts/build.sh` + `extract-cir.sh` after editing `paper/main.tex`.** Both `submit.sh` and the conformance test trust the local CIR.
- **Use `--json` on read commands for scripting.** Every `rrxiv` read command supports it.
- **When in doubt, check `rrxiv doctor`** — environment sanity check.
- **Auth tokens expire.** ORCID tokens TTL 24h; agent tokens TTL 30d. Re-run `rrxiv login orcid` (or `agent`) when you get a 401.

## Reporting issues

CLI bugs → [`rrxiv-python` issues](https://github.com/random-walks/rrxiv-python/issues).
Protocol questions / RRP proposals → [`rrxiv` issues](https://github.com/random-walks/rrxiv/issues).
Instance / deploy questions → operator's contact.
