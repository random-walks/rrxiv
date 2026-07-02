# Maintainers

This file lists the active maintainers of the rrxiv protocol. It is the canonical source for the "maintainer group" referenced in [`spec/0008-governance.md`](spec/0008-governance.md) and [`proposals/README.md`](proposals/README.md).

## Active maintainers

| Identity | GitHub | Conflict-of-interest disclosures |
| -------- | ------ | -------------------------------- |
| Blaise Albis-Burdige — <albisburdige@protonmail.com> | [@random-walks](https://github.com/random-walks) | TBD |

The first maintainer set is the founding contributors at v0.1; additional maintainers join via the RRP process described in `spec/0008-governance.md` §"Stewardship structure".

## What maintainers do

- **Review and merge PRs** to the canonical `rrxiv` repo.
- **Accept RRPs** that have reached their discussion threshold. (A maintainer may not unilaterally accept an RRP they themselves authored; co-acceptance by another maintainer is required.)
- **Moderate RRP discussions.** Keep them on substance, surface unstated assumptions.
- **Make decision-of-last-resort calls** when an RRP discussion deadlocks; see `spec/0008-governance.md` §"Dispute resolution".

Maintainers do **not**:

- Operate the canonical rrxiv.com instance. That role belongs to a separate operating entity (cooperative / nonprofit) per `spec/0008-governance.md` §"Operator vs. protocol".
- Have unilateral authority to amend locked governance principles. Those changes require a higher-bar governance RRP.

## Onboarding

To propose a new maintainer, file an RRP with `Affects: governance` that:

- Names the candidate (with their GitHub handle and ideally ORCID).
- Summarises the candidate's contribution history to rrxiv or adjacent open-source protocols.
- Includes the candidate's conflict-of-interest disclosures.
- Articulates what gap or growth this maintainer addresses.

The RRP follows the standard lifecycle (Draft → Discussion → Accepted/Rejected). Maintainer additions require co-acceptance by ≥2 existing maintainers.

## Removal

Maintainer removal is itself an RRP, except for the automatic sunset cases in `spec/0008-governance.md` §"Sunset clauses" (60-day unreachable rule, etc.).

## Conflict-of-interest disclosures

Each maintainer's disclosures appear in the table above. Updating disclosures is a regular PR (not an RRP); the maintainer themselves is expected to keep their entry current.

Examples of disclosures that should be listed:

- Employment by a company whose product or service depends on rrxiv's design.
- Equity or other financial interest in such a company.
- Service on the boards of organisations whose interests intersect with rrxiv.

Disclosures are not bars to maintainership; they're context for evaluating individual decisions.

## Contact

Operational issues with the canonical instance: <albisburdige@protonmail.com> (interim operator contact until a separate operating entity is established per `spec/0008-governance.md`).

Protocol questions, RRP discussions, contribution: GitHub issues and PRs on this repository.

Code-of-conduct reports: see [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) — <albisburdige@protonmail.com>.
