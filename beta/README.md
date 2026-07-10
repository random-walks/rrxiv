# `beta/` — forward-looking protocol documents

Non-normative, timestamped working documents about where the protocol is going —
integrations that don't exist yet, ecosystems that are moving faster than the
spec process, designs that need to be written down *before* they are ready for
an RRP. Nothing in this directory is part of the rrxiv protocol.

## Why this exists

The spec (`../spec/`) describes what **is**; RRPs (`../proposals/`) ratify
changes to it. Neither is a good home for "here is what we currently know about
a two-week-old product we intend to integrate with." That knowledge still needs
to live in the repo — versioned, reviewable, and honest about its shelf life —
so it lives here.

## Conventions

- **Every document carries a `Last verified:` date** near the top. A beta doc
  whose facts you are about to rely on should be re-verified if that date is
  stale; external products documented here change weekly.
- **Claims about external systems cite a source URL** and carry a confidence
  label where it matters (`confirmed` = stated on an official property we
  fetched; `reported` = reputable secondary source; `inference` = our
  conclusion, labeled as such).
- **Nothing here is normative.** If a design in `beta/` needs schema fields,
  identifiers, or API surface, it graduates: a numbered spec doc
  (`spec/00NN-*.md`) and/or an RRP per `../proposals/README.md`. The beta doc
  then points at its successor.
- Documentation-only changes here need no RRP (per the proposals README).

## Contents

- [`connectors.md`](connectors.md) — design for **rrxiv connectors**: how agent
  harnesses (Claude Science, Claude Code, and whatever comes next) read from and
  publish to rrxiv, built on the Model Context Protocol.
- [`harnesses/`](harnesses/) — one timestamped knowledge base per agent harness
  we track as an integration target:
  - [`harnesses/claude-science.md`](harnesses/claude-science.md) — Anthropic's
    Claude Science workbench (launched 2026-06-30).

New science-agent harnesses will appear; add a knowledge base per harness under
`harnesses/` following the same conventions, and extend `connectors.md` with a
harness-specific integration note rather than forking the design per harness.
