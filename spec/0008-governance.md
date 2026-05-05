# 0008 — Governance

**Status:** v0.1 draft.
**Prereqs:** [`0001-overview.md`](0001-overview.md). The RRP process is in [`proposals/README.md`](../proposals/README.md).

This document describes how rrxiv is governed: who decides what enters the protocol, what changes require an RRP, the RRP lifecycle (cross-referenced from the proposals README), the dispute-resolution process, the relationship between the rrxiv.com canonical instance and the protocol itself, and the legal/license posture.

## Locked principles

These principles are baseline commitments. They cannot be altered by ordinary contribution — only by an explicit governance RRP that itself satisfies the constraints below. They come from the whitepaper and are not up for redebate in v0:

1. **The protocol is permissively-licensed open source.** Code is MIT; spec docs and the whitepaper are CC-BY-4.0.
2. **The corpus is CC-BY licensed.** Submitted content must be under a CC-BY-compatible license; CC-BY-4.0 is the default and recommendation.
3. **Snapshot exports are mandatory and free.** Any rrxiv instance must expose a complete, downloadable corpus archive at no cost to the requester.
4. **Forks are first-class.** If the canonical instance fails its users, the corpus and the code can be forked; the protocol must not introduce technical or legal lock-in. New mechanisms that would create such lock-in are rejected.
5. **Read access is free for both humans and agents.** Read access cannot be paywalled. Rate limits for anti-abuse are permitted but must not effectively gate research access.

A governance RRP that proposes amending one of these principles requires (i) a substantively higher acceptance bar, including a longer discussion window (≥30 days vs. ≥14 days) and (ii) explicit acknowledgement from current maintainers and from any third parties who relied on the principle when they integrated with rrxiv.

## Stewardship structure

In v0, rrxiv is stewarded by a small **maintainer group** named in [`MAINTAINERS.md`](../MAINTAINERS.md). Maintainer authority:

- **Merge rights** on the canonical repository (the `rrxiv` repo).
- **RRP acceptance authority** — a maintainer may merge an RRP that has reached its discussion threshold.
- **Operations of rrxiv.com** — separately, the canonical instance is run by an operator (a cooperative / nonprofit; see *Operator vs. protocol* below). The operator is **not** automatically a maintainer.

Maintainer additions and removals are themselves an RRP. The first maintainer set is whoever is named in `MAINTAINERS.md` at v0.1 — those people inherit authority from the project's founding act.

A maintainer cannot unilaterally accept an RRP they themselves authored or championed. Such RRPs require co-acceptance by at least one other maintainer.

## Dispute resolution

When two contributors disagree substantively on an RRP and neither side cedes, the escalation path is:

1. **Discussion phase.** Maintainers actively moderate the RRP discussion: keep it on substance, surface unstated assumptions, ask each side for the strongest version of the other's argument. Most disputes resolve here.
2. **Time-boxed extension.** If discussion has been productive but unresolved at day 14, maintainers may extend the discussion window in 14-day increments (max 60 days total).
3. **Maintainer decision.** If the discussion is complete and the dispute persists, maintainers vote. Quorum: ≥3 maintainers; majority decides. The maintainer with the closest conflict-of-interest abstains.
4. **Appeal.** A losing party may file an appeal RRP within 90 days of the decision. The appeal RRP can be merged only if a *different majority* of maintainers approves. If sustained appeals deadlock, the question is escalated to the operator's governance body (the cooperative's board) for a final binding decision; that decision is itself published as an annotation on the RRP.

The bias is toward letting the protocol be smaller and slower than ambitious. *"We disagreed and didn't change anything"* is a valid resolution.

## Conflict of interest

RRP champions and maintainers must disclose:

- **Direct financial interest** in the RRP's outcome (employment by a vendor whose product depends on the change, equity in a company whose roadmap depends on the change, etc.).
- **Indirect financial interest** of close family / cohabitants.
- **Adversarial relationship** with another active RRP champion or maintainer.

Disclosure is appended to the RRP's `Conflict-of-interest:` line and to the maintainer's [`MAINTAINERS.md`](../MAINTAINERS.md) entry. Failure to disclose, when later surfaced, is grounds for an RRP to remove the maintainer.

This is intentionally light-touch. The intent is to surface obvious conflicts before they're a problem; not to police private interests.

## Operator vs. protocol

**rrxiv-the-protocol** is what this repository defines: schemas, spec docs, the cls, the RRP process. It is governed by the maintainer group above.

**rrxiv.com-the-service** is one instance — the canonical one, eventually — that runs the protocol. The instance is operated by an organisational entity (a cooperative or nonprofit; see below). The operator:

- **Cannot unilaterally amend the protocol.** Operator-driven changes go through the RRP process like any other.
- **Cannot privatise the corpus.** Snapshot exports remain free. Locked principle 3.
- **Can introduce instance-specific features** (e.g. its UI, its operational policies, its abuse-mitigation tooling) that are not part of the protocol — provided those features do not violate locked principles.
- **Funding is its own problem.** The operator may charge for above-and-beyond services (e.g. high-volume API use, hosted authoring tools, premium analytics) but never for the protocol-mandated minimums (read access, snapshot export).

A clean separation between operator and protocol is the structural protection against the canonical instance becoming captured. If the operator strays — adds artificial scarcity to baseline features, captures the namespace, slow-walks RRPs that threaten its business model — the community can legitimately fork. The protocol is designed to support that fork: corpus is mirrorable (snapshot exports), protocol is open, code is open.

## Cooperative / nonprofit structure

The canonical operating entity should be structured as a **cooperative** or **nonprofit** with:

- **A board** with representation from researchers (corpus contributors), implementers (other instances, integrators), and at least one independent ombudsperson.
- **A charter** that incorporates the locked principles above by reference, such that an operator's articles of incorporation cannot lawfully be amended to violate them.
- **Sunset and dissolution clauses** that, if the operator ceases or pivots away from the protocol, transfer the canonical-instance role to a successor entity selected by the community.
- **Transparent finances** — annual financial reports published openly.

v0.1 does not mandate a specific legal jurisdiction or organisational form. Different jurisdictions support different structures (US 501(c)(3), EU non-profit association, UK CIC, etc.). The mandate is on the *properties* the structure must satisfy, not the form.

The first operating entity will be chosen by the founding maintainers at the time the canonical instance launches. Once chosen, changing it requires a Phase-1 governance RRP.

## Sunset clauses

### Maintainer disappearance

If a maintainer is unreachable for 60 consecutive days, remaining maintainers may revoke their merge rights via an RRP. The disappeared maintainer can request reinstatement when they return.

If only one maintainer remains, that maintainer **must** open an RRP to recruit at least one more within 30 days. A single-maintainer state is not a stable governance configuration.

### Operator failure

If the canonical instance:

- Becomes unreachable for >30 consecutive days,
- Or violates a locked principle without an accepted RRP authorising it,
- Or formally announces dissolution,

the maintainer group can declare a **fork event**: a different instance is designated canonical; the old DNS / brand may continue but the protocol's canonical referent moves. This is the protection of last resort. It exists so the corpus is never held hostage.

Fork events are themselves RRPs; the urgency may shorten the discussion window.

### Protocol-itself sunset

If the rrxiv protocol itself is no longer being maintained — no maintainers active, no RRPs accepted in 12 months, no replacement plan — the corpus snapshot at that time becomes the canonical artifact. The protocol enters a **frozen** state; existing instances may continue to operate but new RRPs cannot be accepted.

This isn't an outcome anyone wants, but the corpus's value to readers must survive even if the protocol's governance does not.

## Open questions

- **Concrete maintainer onboarding criteria.** What does it take to become a maintainer? Track record on past RRPs? Contributor history? A v0.2 RRP should specify.
- **Operator selection criteria.** When the cooperative is being formed, what's the procedure? An open call? An invited founding board? Both have precedent in adjacent communities (Open Library Foundation, Code for Science & Society).
- **Cross-instance governance.** If federation lands, do other instances participate in protocol governance? Probably yes — but the mechanism is unspecified.
- **Funding-the-protocol-itself.** The operator funds its own operations. Who funds the protocol's maintenance (RRP review, schema work, the cls)? In adjacent communities this is often grants + sponsor donations; needs concrete sketching.
- **Trademark.** Should "rrxiv" be a registered trademark held by the operator, with a permissive licence for compatible implementations? Outside scope for spec docs but a real legal question.

These are tracked in [`proposals/`](../proposals/) once they crystallise.
