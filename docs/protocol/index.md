---
title: Protocol overview
---

# Protocol

The rrvix protocol is described in three layers:

1. **The whitepaper** — the design document that motivates the protocol and explains the high-level architecture.
2. **The spec documents** — Markdown documents that formalize each component (CIR, claim graph, LaTeX class, submission flow, annotations, API, governance).
3. **The schemas** — machine-readable JSON Schema and OpenAPI files that any conforming implementation must satisfy.

Together these are the canonical definition of rrvix v0.

| Layer       | Source                                                                                | Status                              |
| ----------- | ------------------------------------------------------------------------------------- | ----------------------------------- |
| Whitepaper  | [`whitepaper/rrvix-whitepaper.tex`](https://github.com/random-walks/rrvix/blob/main/whitepaper/rrvix-whitepaper.tex) | v0.1 — first draft landed           |
| Spec docs   | [`spec/`](https://github.com/random-walks/rrvix/tree/main/spec)                       | M0.4 — being written                |
| CIR schema  | [`schema/cir.schema.json`](https://github.com/random-walks/rrvix/blob/main/schema/cir.schema.json) | v0.1.0 — first draft landed         |
| Sub-schemas | [`schema/`](https://github.com/random-walks/rrvix/tree/main/schema)                   | M0.2 — paper/claim/annotation pending |
| LaTeX class | [`template/rrvix.cls`](https://github.com/random-walks/rrvix/blob/main/template/rrvix.cls) | v0.1 — used by the whitepaper       |
| OpenAPI     | `schema/api.openapi.yaml`                                                             | not yet — Phase 1                   |

See [Bootstrap](bootstrap.md) for the full milestone list.
