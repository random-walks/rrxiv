# Spec documents

The rrvix protocol is described in this directory. Each document focuses on a single concern and has a stable filename prefix (`0001-`, `0002-`, …) so it can be referenced from RRPs and code by ID.

| ID | Title | Status |
| --- | --- | --- |
| [0001](0001-overview.md) | Overview | v0.1 draft |
| [0002](0002-cir.md) | Canonical Intermediate Representation | v0.1 draft |
| [0003](0003-claim-graph.md) | Claim graph | v0.1 draft |
| [0004](0004-tex-template.md) | `rrvix.cls` LaTeX template | v0.1 draft |
| [0005](0005-submission.md) | Submission flow | v0.1 draft |
| [0006](0006-annotations.md) | Annotation model | v0.1 draft |
| [0007](0007-api.md) | HTTP API | v0.1 sketch |
| [0008](0008-governance.md) | Governance | v0.1 draft |

## Reading order

Read [0001-overview.md](0001-overview.md) first if you're new to rrvix. From there:

- For the **data model**: [0002-cir.md](0002-cir.md) → [0003-claim-graph.md](0003-claim-graph.md).
- For **authoring rrvix papers**: [0004-tex-template.md](0004-tex-template.md).
- For **understanding the protocol's posture**: [0008-governance.md](0008-governance.md) (when it lands).

## Conventions

- Each document leads with rationale before mechanics. Future contributors need to understand *why* before *how*.
- Documents reference the schemas under [`../schema/`](../schema/) and the whitepaper at [`../whitepaper/`](../whitepaper/) rather than restating their content.
- Mermaid diagrams are used for graph-shaped explanations; mkdocs-material renders them in the docs site.
- Open questions are called out explicitly at the end of each document and tracked as candidate RRPs in [`../proposals/`](../proposals/).

## Versioning

Spec documents version with the protocol. A breaking schema change requires an RRP that updates the relevant spec document(s) at the same time. Patch and minor changes can amend spec documents without a full RRP.
