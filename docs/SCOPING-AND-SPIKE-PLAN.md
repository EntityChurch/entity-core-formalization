# Scoping + spike plan

**Owner:** architecture. **Posture:** spike-first; demonstrator-altitude; additive
assurance, off the release critical path.
**Origin:** a keystone formal-methods handoff (beyond-Lean: TLA+ + Tamarin, in
`entity-core-keystone`), reviewed + scoped by architecture.

## The decision

Lean shrank "is the authority *logic* right" to near-zero. That is exactly what
makes it worth pointing heavier tools at the two design-layer questions Lean can't
reach: **TLA+** (concurrency + liveness) and **Tamarin/ProVerif** (active attacker).
See `ASSURANCE-MAP.md` for the full picture.

## Arch's calls on the open questions

| # | Question | Decision | Reasoning |
|---|---|---|---|
| 1 | Project home | **This repo** (`entity-core-formalization`, top-level sibling). | Verifies the V7 *design*; deserves its own home like keystone. Co-located vendored spec (`spec-data/`) keeps the model↔spec fidelity link explicit. |
| 2 | Model altitude | **Spike = core §6.11 reentry slice.** Comprehensive (async/extension flows — origination / INSTALL / continuations) is Phase 1+. | Minimal interesting concurrency AND the known §7b sustained-load runaway. Best demonstrator = the model rediscovers a bug we found by hand. |
| 3 | TLA+ surface / checker | **PlusCal + TLC** default; Apalache only if the state space blows up. | PlusCal is the gentler on-ramp; TLC is push-button. Java is the only dependency (`tla2tools.jar`), near-zero setup. |
| 4 | Tamarin vs ProVerif | **Spike both on the same fragment; lead with ProVerif.** | ProVerif usually more automated (lower hand-holding risk on a short window); fall back to Tamarin if it over-approximates / reports false attacks. Decide by which closes our unforgeability fragment cleaner. |
| 5 | Timeline appetite | **Demonstrator-first.** Comprehensive (months) = post-release, separate GO, gated on a spike clearing. | Off the critical path; the user steer was "spike it, see how far we get." |

## Phase 0 — the two spikes (go/no-go gated, parallelizable)

Mirror the Lean S1 throwaway-spike discipline: **do not commit to a full model
before a spike tells you the shape.**

### Spike A — TLA+ (lead) → `tla/`
- **Model:** §6.11 reentry concurrency — 2 peers, a pooled connection, an outbound
  dispatch that reenters in the reverse direction (the Class-G deadlock surface /
  the sustained-load store-leak class). Cap-verify *result* = abstract predicate;
  **do NOT re-model the Lean-proven algorithm.**
- **Properties:** one **safety** invariant (store bounded by live keys / no dispatch
  without passing the gate) + one **liveness** property (every accepted request
  eventually gets a response or clean failure — no deadlock/livelock).
- **GO/NO-GO gate:** Did TLC check it, or find a *real* counterexample? How painful
  was the modeling? Is the model–code gap acceptable at spec altitude? **Killer
  result:** TLC rediscovers the §6.11 runaway/deadlock as an invariant/liveness
  violation — "the model finds the bug we found by hand."

### Spike B — Tamarin/ProVerif (de-risk) → `tamarin/`
- **Model:** cap issuance + delegation chain + verify as a minimal symbolic theory
  with the built-in Dolev-Yao adversary. Symbolic crypto = our wall-#1 trust
  boundary (assumptions line up).
- **Property:** ONE **unforgeability** lemma — an attacker cannot derive a
  verifier-accepted cap chain without having been delegated that authority.
- **GO/NO-GO gate:** Does the prover close it **automatically**, or need heavy
  hand-holding (source/reuse lemmas, interactive guidance)? Run ProVerif and Tamarin
  on the same fragment; report which is cleaner. **Honest expectation:** TLA+ clears
  first; Tamarin is the gamble the spike prices.

### Deliverable per spike (new artifact type, mirrors Lean's `FORMALIZATION-REPORT`)
A short report: properties proved / counterexamples found / scope boundaries /
on-ramp pain / go-no-go recommendation. If it graduates, this becomes a standing
arch design-assurance deliverable beside the Lean report and the conformance
scorecard.

## Phase 1 (only if a spike clears)

Scope the full model for the tool that cleared, properties prioritized by security
value. Separate, explicit, post-release GO. Months-scale. Not part of Phase 0.

## Honest caveats (carry into every report)

- Both tools verify a **model**, not the code — they certify the **design**. Keep
  the model at spec altitude.
- The **5th wall — spec↔model fidelity** (`ASSURANCE-MAP.md`): the proof is relative
  to the model faithfully transcribing `spec-data/v0.8.0/`. Owned by careful modeling
  + review, not by the tool. State it; don't let it hide.
- **Off the critical path.** Must not pull effort off the shipping work.
