# Claude Science — harness knowledge base

**Last verified: 2026-07-10** (product at v0.1.18, released 2026-07-09; public
launch 2026-06-30 as v0.1.14). Claude Science is in beta and shipping
near-daily; re-verify against the
[changelog](https://claude.com/docs/claude-science/changelog.md) before relying
on details here.

Confidence labels: **[C]** confirmed on an official Anthropic/claude.com page we
fetched · **[R]** reported by reputable secondary sources · **[I]** our
inference, labeled. Facts were independently re-verified by a second
fact-checking pass on 2026-07-10; corrections from that pass are incorporated.

## What it is

- **[C]** "An AI workbench for scientists" — a **local desktop application**
  (macOS 13+, Linux x64, Windows via WSL) that pairs existing Claude models
  with a sandboxed on-device analysis environment. It is *not* a new model;
  Anthropic positions it as doing for science what Claude Code does for
  software engineering.
  ([overview](https://claude.com/docs/claude-science/overview.md),
  [announcement](https://www.anthropic.com/news/claude-science-ai-workbench))
- **[C]** Launched publicly 2026-06-30 (build 0.1.14), in beta for **Pro, Max,
  Team, and Enterprise** plans (Team/Enterprise Owners must enable it
  org-wide); no separate pricing; discounted academic/nonprofit Team seats.
  ([overview](https://claude.com/docs/claude-science/overview.md))
- **[C]** Runs via `claude-science serve` — a local background process serving
  a web UI on `127.0.0.1` with a one-time nonce login link. Sign-in is the
  user's claude.ai account (OAuth); no API key.
  ([CLI docs](https://claude.com/docs/claude-science/command-line-settings.md))
- **[R]** Press reports the underlying model inconsistently (MIT Technology
  Review: Opus 4.5; other launch coverage: Opus 4.8); the official docs say
  only that it "uses the standard model API" with the org's model picker.

## Architecture

- **[C]** A generalist **coordinating agent** writes and runs Python/R/shell in
  an OS-level sandbox; "Delegation" splits work into parallel tracks;
  customizable "Specialists" exist, including a built-in **Reviewer** that
  re-reads responses, plan, artifacts, and the execution record, flagging
  results never computed, values contradicting sources, citations that don't
  support claims, and **DOIs resolving to different articles**. It does not
  re-run analyses.
  ([core concepts](https://claude.com/docs/claude-science/core-concepts.md),
  [the reviewer](https://claude.com/docs/claude-science/the-reviewer.md))
- **[C]** Sandbox: code can read/write only the workspace + granted folders;
  network is deny-by-default through a local proxy (package managers, featured
  databases, and user-approved hosts only). Permission cards gate folders,
  network hosts, connector tools, and remote jobs, with scopes Once / This
  conversation / This project / Global.
  ([core concepts](https://claude.com/docs/claude-science/core-concepts.md))
- **[C]** Local-first data: files, history, and artifacts stay on the user's
  device; Anthropic hosts no session store; locally added connectors talk to
  their service **directly, not via Anthropic**.
  ([data handling](https://claude.com/docs/claude-science/how-claude-science-works-with-your-data.md))
- **[C]** No scheduler / unattended runs: sessions are user-initiated; durable
  compute exists only as user-approved Modal jobs (≤23 h) or SSH/SLURM jobs
  that survive disconnect.
  ([compute](https://claude.com/docs/claude-science/compute-providers.md),
  [remote clusters](https://claude.com/docs/claude-science/remote-compute-clusters.md))
- **[C]** No public API for the app itself; integration is connectors in,
  artifact export out.

## Connectors (the integration surface)

- **[C]** **Custom connectors are MCP servers** — added under Settings >
  Connectors as *Remote* (HTTPS; SSE or Streamable HTTP; OAuth client settings;
  a "Headers helper command") or *Local command* (stdio inside the sandbox,
  per-connector writable dir; env vars stored unencrypted — no high-value
  secrets). ([custom connectors](https://claude.com/docs/claude-science/custom-connectors.md))
- **[C]** **Write/mutation tools are supported**, gated per tool: every custom
  tool starts at "Ask each time" and can be set Always allow / Block; a
  connector-wide "Skip approvals" exists (warned as trust-sensitive). No
  read-only restriction applies to custom connectors — the read-only guarantee
  in the docs covers only the built-in Featured set. Anthropic's general
  connector docs explicitly list "creating, modifying, or deleting data" as
  custom-connector capabilities.
  ([custom connectors](https://claude.com/docs/claude-science/custom-connectors.md),
  [support article](https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp))
  **[I]** No official page demonstrates a write tool end-to-end inside Claude
  Science specifically — smoke-test against staging before shipping.
- **[C]** Connector tiers: ~20 read-only **Featured** connectors (on by
  default, toggleable, no account) collectively covering 60+ public
  life-sciences databases — the "Literature Graph" featured connector is
  OpenAlex + arXiv; four **Directory** connectors surfaced in Claude Science:
  **PubMed, Clinical Trials, ChEMBL, bioRxiv** (admin-added on Team/Enterprise);
  plus user-added **Custom** connectors.
  ([connectors & skills](https://claude.com/docs/claude-science/connectors-and-skills.md))
- **[C]** **bioRxiv's connector is "Made by Anthropic"** — first-party, not
  self-submitted ([claude.com/connectors/biorxiv](https://claude.com/connectors/biorxiv)).
  Directory listing for third parties is self-serve but requires a **Team or
  Enterprise org** to submit, HTTPS remote MCP, OAuth 2.0 for authenticated
  services, read/write split into separate tools with
  `readOnlyHint`/`destructiveHint`, no catch-all tools, tool names ≤64 chars,
  privacy policy, public docs, and test credentials; auto-scan → "Community"
  tier, with automatic escalation to functional "Verified" review.
  ([submission](https://claude.com/docs/connectors/building/submission),
  [review criteria](https://claude.com/docs/connectors/building/review-criteria))
- **[C]** Org admins cannot yet restrict member-added custom connectors
  (roadmap) — good for grassroots adoption, unmanaged for enterprises.
  ([admin controls](https://claude.com/docs/claude-science/admin-controls.md))

## Skills

- **[C]** Skills are written instructions loaded when relevant; created via
  chat, from scratch, upload, or **Import from GitHub** (public and private
  repos); any pipeline can be distilled into a skill. Featured science skills
  include literature review and model-specific skills (AlphaFold2, Boltz-2,
  ESM-2, Evo 2, etc.).
  ([connectors & skills](https://claude.com/docs/claude-science/connectors-and-skills.md))

## Artifacts, provenance, and the export gap

- **[C]** Artifacts (figures, datasets, reports, notebooks, manuscripts) are
  stored locally and versioned; each version carries an in-app **Provenance**
  pane with five tabs — Messages, Code (downloadable as script/notebook),
  Execution Log ("the authoritative record of what ran"), Environment
  (packages + versions), Review.
  ([artifacts](https://claude.com/docs/claude-science/artifacts.md))
- **[C]** Manuscript authoring renders Markdown and LaTeX; LaTeX
  cross-reference resolution (`\ref`, `\eqref`, section numbering) landed in
  v0.1.16. ([product page](https://claude.com/product/claude-science),
  [changelog](https://claude.com/docs/claude-science/changelog.md))
- **[C]** **Provenance does not travel.** Every export path — per-artifact
  Download (any surface, as of v0.1.18), copying from `~/.claude-science`, or
  cloud export to S3/GCS/Azure — moves only the artifact's bare bytes. Only the
  Code tab has a component export; Execution Log, Environment, Messages, and
  Review have none. The local database schema is undocumented and the docs warn
  against touching it. The Compliance API cannot export Claude Science data.
  ([artifacts](https://claude.com/docs/claude-science/artifacts.md),
  [cloud storage](https://claude.com/docs/claude-science/cloud-storage.md),
  [not available yet](https://claude.com/docs/claude-science/whats-not-available-yet.md))
- **[I]** Consequence: a "Claude Science → rrxiv" submission bundle must be
  **self-assembled** (artifact + code download + hand-carried
  environment/log/review) — the vendor cannot produce one today. This is the
  design premise of the provenance-bundle profile in
  [`../connectors.md`](../connectors.md).

## Literature access (why DOIs matter to rrxiv)

- **[C]** Given a DOI or title, Claude fetches in order: open-access copy
  (**Unpaywall, Semantic Scholar, PubMed Central**), publisher routes with
  user keys, library EZproxy, publisher page.
  ([literature access](https://claude.com/docs/claude-science/literature-access.md))
- **[I]** rrxiv papers without DOIs and open-access indexing are invisible to
  this pipeline, and the Reviewer flags citations whose DOIs don't resolve —
  registering DOIs + getting indexed is rrxiv's biggest discoverability lever
  for harness-era readers.

## Reception & context (2026-07)

- **[C]** Anthropic pairs the launch with internal drug-discovery programs and
  an "AI for Science" cohort: up to 50 projects, up to $30k credits (+$2k
  Modal), applications through 2026-07-15, projects 2026-09-01 → 2026-12-01.
  ([announcement](https://www.anthropic.com/news/claude-science-ai-workbench))
- **[R]** Researchers report ~10x speedups on the "boring 80%" (literature,
  variant workups, pipelines) while calling it "a co-pilot that requires a
  skilled pilot"; skeptics warn it accelerates *plausible* scientific work and
  paper volume rather than validated truth.
  ([Northeastern](https://news.northeastern.edu/2026/06/30/anthropic-claude-science-launch/),
  [HN](https://news.ycombinator.com/item?id=48735770))
- **[C]** Anthropic ships **no publishing venue** for its outputs; meanwhile
  arXiv restricts AI-generated content (CS review/position papers stopped
  2025-10-31; one-year bans for unverified LLM output since 2026-05) and
  publishers prohibit AI authors. Agent-native venues are prototypes (aiXiv —
  API+MCP submission, AI authorship, DOIs; AgentRxiv). This is the venue gap
  rrxiv targets; see [`../connectors.md`](../connectors.md).
  ([404 Media](https://www.404media.co/arxiv-changes-rules-after-getting-spammed-with-ai-generated-research-papers/),
  [aiXiv](https://arxiv.org/abs/2508.15126))

## Open questions (as of 2026-07-10)

1. OAuth 2.0 grant types supported by Remote custom-connector settings
   (Dynamic Client Registration vs. manual credentials) — undocumented.
2. Whether portable artifact provenance export ships later — watch the
   changelog; it would replace the self-assembled bundle.
3. Underlying model version (Opus 4.5 vs 4.8 in press) — officially unstated.
4. Real-world write-tool invocation inside Claude Science — needs a staging
   smoke test.
5. Whether any Claude Science output has yet been published to a named venue —
   none found as of 10 days post-launch; re-check.
