# Publishing an rrxiv paper

The conventions every rrxiv paper repo follows, and the artifacts a canonical instance expects.

> If you just want to start a new paper, use the [`rrxiv-paper-template`](https://github.com/random-walks/rrxiv-paper-template) GitHub template — it ships the scripts + CI described below.

---

## One paper = one repo

A rrxiv paper is a **standalone GitHub repository**, not a folder inside a multi-paper monorepo. Each repo carries:

```
paper/
├── main.tex              # the paper itself
├── refs.bib              # bibliography (optional)
├── figures/              # figure assets (PDF, PNG, SVG, TikZ)
└── rrxiv.cls             # vendored from random-walks/rrxiv@HEAD

scripts/
├── build.sh              # tectonic main.tex → build/main.pdf
├── extract-cir.sh        # rrxiv parse → build/main.cir.json
└── verify.sh             # jsonschema validate build/main.cir.json

build/                    # outputs (gitignored)
├── main.pdf
├── main.cir.json
└── main.source.tar.gz    # source bundle uploaded alongside CIR

.github/workflows/
└── build.yml             # CI: build PDF + extract + validate + release artifacts

rrxiv-meta.json           # standalone metadata (slug, license, topics)
CITATION.cff              # GitHub-native citation file
README.md                 # human-readable summary
LICENSE-CONTENT           # CC-BY-4.0 by default — applies to paper text + figures
LICENSE-CODE              # MIT by default — applies to .cls, scripts, CI
```

Why one repo per paper:

- **Provenance.** Every revision is a git commit; the full edit history is public, citable, and bisectable.
- **Reproducibility.** Any reader can `git clone` and rebuild the PDF + CIR locally from the exact source the canonical instance ingested.
- **Independence.** A retraction or correction never touches another paper's history. Versions chain via `previous_version` in `rrxiv-meta.json`, not via shared directories.

---

## The three artifacts

Every published paper ships three files alongside its `rrxiv-meta.json`:

| Artifact | What it is | Lives at |
| -------- | ---------- | -------- |
| `build/main.cir.json` | Canonical Intermediate Representation — paper metadata + claims + claim-graph edges + annotations. Validated against [`cir.schema.json`](schema/cir.schema.json). | The structured representation a rrxiv instance ingests. |
| `build/main.pdf` | Tectonic-compiled rendering of `paper/main.tex`. Human-readable. | `GET /api/v0/papers/{id}/pdf` once ingested. |
| `build/main.source.tar.gz` | tarball of `paper/main.tex` + `figures/` + `rrxiv.cls` + `refs.bib`. Source-of-truth that lets readers rebuild the PDF and verify the CIR. | `GET /api/v0/papers/{id}/source` once ingested. |

**All three are mandatory.** A CIR-only paper can be ingested, but the source viewer and PDF download will both be disabled on the web client — that's a degraded UX. Run `./scripts/build.sh && ./scripts/extract-cir.sh` once locally to make sure all three artifacts come out of a clean build, and commit them via the per-paper CI workflow described below.

The standard `.gitignore` excludes `build/` from the repo. CI produces the artifacts on every push to `main`; canonical-instance ingestion pulls them from the latest release.

---

## The build pipeline

```bash
# 1. Compile the PDF
./scripts/build.sh
# → build/main.pdf

# 2. Extract the CIR (parses the LaTeX class macros)
./scripts/extract-cir.sh
# → build/main.cir.json

# 3. Validate against the JSON Schema
./scripts/verify.sh
# → exit 0 on conformance

# 4. Bundle the source for reproducibility
tar czf build/main.source.tar.gz \
  --exclude='*.aux' --exclude='*.log' --exclude='*.out' \
  paper/ scripts/ rrxiv-meta.json
```

The template ships all four steps; you should not need to write them.

`scripts/build.sh` uses [Tectonic](https://tectonic-typesetting.github.io/) — single binary, fetches packages on demand, deterministic builds. It's the canonical compiler for rrxiv papers; if your paper needs a feature Tectonic doesn't yet support, file an issue in `rrxiv-paper-template` instead of switching to a different TeX engine.

`scripts/extract-cir.sh` calls `rrxiv parse paper/main.tex --output build/main.cir.json` and depends on `rrxiv-python` being installed (`pip install rrxiv @ git+https://github.com/random-walks/rrxiv-python.git@main`).

---

## CI: automate the build + release

The template's `.github/workflows/build.yml` runs the four steps above on every push to `main` and uploads the three artifacts to a GitHub release tagged with the commit SHA. Canonical-instance operators can then ingest the release tarball without needing tectonic in their deploy pipeline.

A passing CI run is the contract: if the workflow is green on the SHA you submit to a canonical instance, the instance can ingest it.

---

## Dependency edge format

Inside `paper/main.tex` (or any `\input{}`ed file), claims are written like:

```latex
\begin{claim}[Proposition I.47: Pythagoras]
\label{prop:I.47}
In right-angled triangles the square on the side subtending the right angle
is equal to the squares on the sides containing the right angle.
\end{claim}

\begin{evidence}[Proof of I.47]
\label{ev:I.47}
…
\dependson{I.47}{I.4}
\dependson{I.47}{I.14}
\dependson{I.47}{I.31}
\dependson{I.47}{I.41}
\dependson{I.47}{I.46}
\end{evidence}
```

- `\dependson{X.Y}{target}` declares that claim `X.Y` requires `target` to be already established.
- `target` uses short forms: `I.47`, `def:V.5`, `post:3`, `cn:1`. Cross-paper edges use the full canonical form: `rrxiv:2605.00001:prop:main`. The merge-sidecar pass resolves short forms to canonical claim IDs at build time.
- Other edge kinds: `\supports`, `\contradicts`, `\extends`. Same syntax.

`rrxiv.cls` defines these macros; they're CIR-extraction-only (no-op in the PDF rendering).

---

## Submitting to a canonical instance

`rrxiv.com` (the canonical instance run by random-walks) is currently invite-only for submissions; the v0.1 corpus is curated by hand. Once `/submit` lands (v0.2, ETA TBD):

1. Push your paper to a public GitHub repo following the template structure.
2. Open the `/submit` flow on `rrxiv.com`, sign in via ORCID, paste the repo URL.
3. The server fetches the latest release's artifacts, validates the CIR, mints an `id_slug` (e.g. `rrxiv:2605.00012`), and indexes the paper.

Until then, third parties run their own instances by following the [`rrxiv-python`](https://github.com/random-walks/rrxiv-python) reference server quickstart.

---

## Versions

Papers are immutable; new versions are new papers that point at the previous one via `previous_version` in `rrxiv-meta.json`:

```json
{
  "id": "01923f8e-...-7c4d-...",
  "id_slug": "rrxiv:2605.00012",
  "version": "v2",
  "previous_version": "01923f8e-...-6a3b-..."
}
```

The web client renders the version chain on the paper page so readers can see the lineage.

---

## Writing meaty claims

A bare claim ("Proposition X: statement.") is the bare minimum. To make the claim view useful — the web client renders an entire detail page per claim — populate the optional fields the schema reserves for *what's actually known about the claim*: the proof, the figures it relies on, where it lives in the source. The parser pulls this content out of the .tex automatically when you follow a small set of conventions; the same conventions are how `rrxiv-web` renders a proof inline on the claim page.

The encoding contract is two LaTeX environments + one pairing rule:

```latex
\begin{claim}[Proposition I.10: To bisect a given finite straight line]
\label{prop:I.10}
To bisect a given finite straight line.
\end{claim}

\begin{evidence}[Proof of I.10]
\label{ev:I.10}
\input{figures/fig-i-10}
Let $AB$ be the given finite straight line. With centre $A$ and distance
$AB$ describe the circle $BCD$ (Postulate 3). \dots
\dependson{I.10}{I.1}
\dependson{I.10}{I.9}
\end{evidence}
```

- **Pair the proof to its claim via the label suffix.** A `\label{prop:X.Y}` on the claim pairs to a `\label{ev:X.Y}` on the evidence block by the `X.Y` tail. The parser walks claim → evidence by this rule and writes the cleaned evidence body into `Claim.proof`. Math (`$...$`, `\[...\]`) is preserved verbatim so the web client (KaTeX) can render formulas; `\dependson{}{}` lines are stripped because that information already rides on `Claim.depends_on`.
- **Reference figures inside the evidence block.** Any `\input{figures/foo}` inside `\begin{evidence}...\end{evidence}` becomes a `Claim.figures[]` entry — the path is preserved relative to the source-archive root, and any `\caption{...}` inside the figure file is captured. The web client renders the diagrams alongside the proof; readers don't have to open the source tarball to see the construction.
- **Source provenance is computed automatically.** The parser writes `Claim.source_location.file`, `line_start`, and `line_end` so deep links into the source viewer work. For multi-file papers (Euclid puts each book in its own .tex), use `\input` from `main.tex` and run `flatten-tex.py` before parsing — the parser maps the flattened lines back to the original file via the `% [flatten-tex.py] inlined: <path>` markers.

Why each field exists:

| Field | Why |
|-------|-----|
| `proof` | The reader of a claim page is asking "why is this claim true?" If the proof lives only in the PDF, the claim page is dead text. The proof is the first-class content of a `Claim`, not a sidecar. |
| `figures` | A geometric proof without its diagram is harder to read than it needs to be. Figures referenced inside the evidence block are *part of the proof* — surfacing them inline on the claim page closes the loop. |
| `source_location` | Provenance. A reader who wants to verify the encoding (translate this from the original .tex?) needs a deep link, not a "go read the tarball" instruction. |
| `pdf_anchor` | A `#page=N` (or `#nameddest=...`) URL fragment so the "open in PDF" affordance jumps to the right page. The parser leaves this unset — computing page numbers requires the rendered PDF — but the schema reserves a place for a downstream tool to write it. |

Claims that aren't propositions (definitions, postulates, conventions) usually have no paired evidence block — that's fine. The fields are optional; the parser writes them when they're available and omits them when they're not. The schema (claim.schema.json v0.2.0) and the protocol guidance for this encoding are in [RRP-0015](proposals/0015-meaty-claims.md).

---

## See also

- [`rrxiv-paper-template`](https://github.com/random-walks/rrxiv-paper-template) — the canonical GitHub template
- [`rrxiv-whitepaper`](https://github.com/random-walks/rrxiv-whitepaper) — the genesis paper, a working reference
- [`rrxiv-paper-euclid-elements`](https://github.com/random-walks/rrxiv-paper-euclid-elements) — a more substantial reference with 200+ claims and a deep dependency DAG
- [`schema/`](schema/) — the JSON Schemas the CIR validates against
- [`proposals/`](proposals/) — RRPs governing changes to the above
