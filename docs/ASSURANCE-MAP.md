# The complete formal-assurance map

The point of this map: **nothing double-owned, nothing assumed without a named
owner.** Each formal question about the Entity Core Protocol is answered by exactly
one tool, on the layer it can actually reach.

## The six questions

| # | Question | Tool | Layer | Status |
|---|---|---|---|---|
| 1 | Is the authority **logic** correct? (attenuation monotone, deny-by-default, verdict enforces the per-edge check) | **Lean** | implementation (pure core) | **DONE** (keystone Track B) |
| 2 | Do **implementations conform** to the spec? | **validate-peer** | implementation (live, per-peer) | **DONE / ongoing** (keystone) |
| 3 | Is the **crypto** sound? | audited library + FIPS KATs (EverCrypt-class) | primitive | **trusted boundary** (out of scope — we consume, don't design crypto) |
| 4 | Does the **distributed protocol** behave under concurrency — safety **+ liveness**? | **TLA+** | **protocol design** | **THIS PROJECT — Spike A** |
| 5 | Does the protocol resist an **active attacker** — unforgeability / no-escalation? | **Tamarin / ProVerif** | **protocol design** | **THIS PROJECT — Spike B** |
| 6 | Does the impl **reject hostile inputs**? (malformed CBOR, oversized, protocol confusion) | coverage-guided **fuzzing** + adversarial-authz tests | implementation (boundary) | **gap, flagged** (separate security-suite follow-on, not this project) |

Rows 4 and 5 are this project. The tell that they belong to architecture (not to
per-language peer generation): **both sit at the "protocol design" layer.** They
validate V7 itself.

## Complementarity (why there's no overlap or redo)

- **Lean** owns the authority-logic interior (row 1, DONE). TLA+ and Tamarin
  *abstract that away* — they treat cap-chain-verify as an abstract predicate /
  function symbol — precisely so they can focus on concurrency and the adversary.
  No re-modeling of the Lean-proven algorithm.
- **validate-peer** owns "implementations match the spec" (row 2).
- **Fuzzing + adversarial-authz** own hostile-input rejection in the real code (row
  6). Tamarin proves the *design* resists an attacker; fuzzing checks the *code*
  does. Different objects.

## The walls — where each tool stops and another takes over

Carried and extended from the Lean limits map. A proof/model is only as strong as
its honest boundary.

1. **Crypto wall (`@[extern]` / symbolic).** Ed25519 / SHA / Ed448 are trusted
   primitives. Lean treats them as opaque axioms; Tamarin treats them as perfect
   symbolic functions. **Same trust boundary — the assumptions line up.** Owned by
   the audited library + FIPS KATs + the FFI-vs-native byte-equality cross-check.
   Not us.
2. **IO-shell wall (transport / store / concurrency).** Effects + interleavings.
   Core Lean can't reason about them. **This is exactly TLA+'s wall (row 4)** —
   TLA+ is built to model the interleavings and prove safety + liveness over them.
3. **Adversarial-input wall (the parser).** The hostile byte space. Neither Lean
   nor TLA+ explores it; Tamarin reasons about *protocol-level* attacker messages
   but not malformed-byte rejection. Owned by **fuzzing** (row 6).
4. **Resolve-layer / shell↔model seam.** Models assume the shell feeds correct
   inputs (resolved the right granter frame, verified the sig, collected the full
   chain). If the shell resolves *wrong*, the model's guarantee is vacuous for that
   input. Owned by **live adversarial-authz tests** + the Tamarin attacker model
   (which asks whether the attacker can *cause* a wrong resolution).
5. **The 5th wall — spec↔model fidelity (the deepest assumption).** Every model
   here certifies a *model of V7*, not V7's prose and not the code. The whole effort
   is relative to the model being a faithful transcription of `spec-data/v0.8.0/`.
   There is no tool that closes this — it is owned by **careful modeling + review
   against the vendored spec**, and by keeping models at spec altitude. State it in
   every report; never let it hide. Chain of trust:
   `V7 prose ─(faithful modeling)─ formal model ─(TLC/Tamarin)─ proved property`.

## What a "done" looks like for this project (demonstrator scope)

Not "the protocol is proven." Honestly: **two headline machine-checked properties,
each with its scope boundary stated** —

- TLA+: one safety invariant + one liveness property on the §6.11 reentry slice,
  TLC-checked at a small bound (ideally rediscovering the known runaway/deadlock
  class as a counterexample first, then green after the fix is modeled).
- Tamarin/ProVerif: one capability-unforgeability lemma on a minimal cap-chain
  fragment, machine-closed (auto or with documented guidance).

Comprehensive design assurance (full async/extension flows; full attacker model
with replay/reflection/escalation lemmas) is **Phase 1 — months, post-release, a
separate explicit GO.** See `SCOPING-AND-SPIKE-PLAN.md`.
