# PROPERTIES — what is PROVEN vs only MODELED (the honest scorecard)

**entity-core-formalization · v0.8.0**

This is the load-bearing honesty document for the release. A formal-methods repo
that overclaims is the worst kind of overclaim, so this states — per property,
exactly — the *strength* of each result and where it stops.

> **Frame, once, plainly:** this project is **design assurance, off the release
> critical path.** It machine-checks **models of the V7 design**, not the prose
> and not the code. It is **not** a claim that "the Entity Core Protocol is proven
> correct." It is a strong **demonstrator** — a complementary third leg beside
> Lean (authority logic) and validate-peer (impl conformance) — whose deepest
> assumption (spec↔model fidelity, the *5th wall*) **no tool here closes**.

## The three strengths of result, defined

| Tier | Meaning | Tools |
|---|---|---|
| **PROVEN (unbounded)** | Holds for **all** states / all N — a machine-checked **inductive proof** (`Init ⇒ Inv` and `Inv ∧ Next ⇒ Inv'`). Not "no counterexample found up to a bound" — *no counterexample can exist*. | Apalache (SMT/Z3) |
| **MODELED — bounded-exhaustive** | **Every** behaviour enumerated, but only at a **tight finite bound** (2 peers, 1–3 requests, small key sets). Sound within the bound; says nothing beyond it. | TLC, Spin |
| **MODELED — symbolic (Dolev-Yao)** | Holds against an **unbounded** active network attacker, but over **perfect symbolic crypto** (sign/verify are ideal primitives; no bit-level cryptanalysis). | Tamarin, ProVerif |

Every result below is additionally relative to the **5th wall**: it is a property
of the *model*, true only insofar as the model faithfully transcribes
`spec-data/v0.8.0/`. Each modeled element carries a V7 §-citation and each secure
result has a negative control that reproduces a *named, real* V7 bug class — that
is the mitigation, not a closure. Human review against the vendored spec owns it.

---

## A. Concurrency / distributed correctness (TLA+ track)

### A1 — PROVEN unbounded (Apalache inductive, all N): 8 safety invariants / 5 modules

These are the key **safety** invariants of each concurrency module, proven
inductive — they hold in every reachable state, for any number of peers/requests,
not just the enumerated ones.

| Module | Invariant (operator) | V7 basis | What it proves |
|---|---|---|---|
| Revoke | `InvDet` (`VerdictFnOfLayer1`) | §5.10 | verdict is a function of Layer-1 only — no cross-peer/time leak |
| Revoke | `InvRev` (`RevokedNeverPasses`) | §5.1 | a revoked capability never produces a pass |
| Store | `InvRace` (`StoreRaceFree`) | §4.8 | concurrent admits cannot race the store past its gate |
| Store | `InvBound` (`ResourceBounded`) | §4.9(b) | the store stays within its admission bound |
| Conn | `Inv` (`HelloImpliesNonce ∧ NoEstablishWithoutNonce`) | §4.6 | no connection established without the issued-nonce handshake |
| Emit | `InvIff` (`EventIffRealWork`) | §6.10 | an event fires **iff** real work happened (no phantom/no-op events) |
| Emit | `InvType` (`EventTypeCorrect`) | v7.74 B2 | the emitted event type matches the work done |
| Register | `Inv` (`SafeSys ∧ NoUserAtSystem`) | §6.2 | system-namespace guard holds; no user registers at a system path |

Reproduce: `make -C tla apalache-green` (each: base case length 0 + inductive step length 1).

### A2 — MODELED, bounded-exhaustive (TLC + Spin): everything, incl. ALL liveness

At the tight bound (2 peers — the faithful worst case; the Class-G reentry deadlock
is deterministic at N=2), TLC enumerates every interleaving and Spin **independently
re-encodes** the same 6 modules from the spec (a different formalism — explicit-state
Promela — agreeing corroborates the transcription).

- **Safety** at the bound: all of A1 **plus** the composed 2-peer `Core` model
  (deadlock-free establish→request→revoke).
- **Liveness — bounded only, by nature** (Apalache does safety/induction by
  construction, so liveness stays TLC+Spin at the bound): deadlock-freedom,
  stall-freedom, eventual settling, revocation convergence, emit progress. *These
  are MODELED, not PROVEN-unbounded.*
- **Negative controls with teeth:** 18 TLC + 28 Spin defect variants, each of which
  **must** be caught (and is) — Class-G deadlock, handshake-ordering, store race,
  admission-bound breach, §5.1 revocation-ignored, §5.10 determinism-leak, emit
  mis-fire, marker-type, registration partial-residue, system-guard removal, and the
  liveness controls.

Reproduce: `make -C tla tlc-green`, `make -C spin green`; controls per the reports.

---

## B. Active-attacker protocol security (Tamarin / ProVerif track)

### B1 — MODELED, symbolic Dolev-Yao (unbounded sessions, perfect crypto): 12 lemmas

Two independent provers in lockstep (ProVerif proves all 13 incl. `BindingReplay`;
Tamarin proves 12). Unbounded in sessions/attacker behaviour; crypto is ideal.

| Lemma | Property | V7 basis |
|---|---|---|
| Unforge | capability unforgeability | §5.4/§5.6 |
| NoEscalation | no privilege escalation via attenuation | §5.4 |
| Binding / BindingReplay | request-binding; no replay/reflection | §5.6 |
| Caveats | caveat enforcement under an attacker | §5.5 |
| DepthBound / DeepChain / DeepChainN | delegation-depth bound; deep cross-peer frame integrity | §5.4 |
| Expiry | expiry honored against an attacker | §5.5 |
| Multisig / MultisigKN | K-of-N threshold cannot be bypassed | §5.7 |
| Revoke | revocation under an active attacker | §5.1 |
| PersistentRecheck | no "trusted-forever" fail-open; re-check persists | §6.8 |

Reproduce: `make -C tamarin green`; 13 ProVerif + 13 Tamarin bug controls each falsified.

---

## C. What is NOT proven here (the walls — stated, not hidden)

1. **Spec↔model fidelity — the 5th wall (deepest).** Every result above is a
   property of a *model*. No tool closes this; the two-paradigm agreement (Spin
   independent encoding + Apalache unbounded, both matching TLC; ProVerif+Tamarin
   lockstep) **narrows** it substantially but they could share a misreading of V7.
   **Human review against `spec-data/v0.8.0/` owns this.**
2. **Verdict interior + crypto.** §5.4 attenuation arithmetic is **Lean's** (abstract
   predicate / function symbol here); sign/verify are perfect symbolic primitives.
   Same trust boundaries Lean takes as axioms — not re-proven here.
3. **Liveness is bounded-only** (see A2). Safety is lifted to unbounded by Apalache;
   liveness is not.
4. **Two thin positives** (disclosed): `Store`'s store-cardinality conjunct is vacuous
   at a single key (the Apalache port makes the `store ⊆ {"k"}` bound explicit);
   `Register`'s correct-model atomicity is near-tautological. Both have teeth on the
   control side.
5. **One irreducible tool asymmetry:** mechanistic linear-token revocation
   (`RevokeMech`) does **not terminate** in Tamarin — it stays ProVerif's lane; Tamarin
   uses the terminating trace-restriction idiom. Documented tool-capability finding,
   not a modeling gap. (`RevokeMech` is excluded from `make check`; run by hand with a
   kill switch.)
6. **Code, not modeled.** Hostile-byte rejection (malformed/oversized CBOR, protocol
   confusion) is the **fuzzing + adversarial-authz follow-on**, not this project.
   validate-peer (keystone) owns "impl conforms."
7. **Extension protocols not modeled.** `EXTENSION-CONTINUATION/-SUBSCRIPTION/-COMPUTE`
   are not in the vendored snapshot; only the §6.8 core property governing them is
   modeled. Full protocols are **Phase 3, gated on vendoring**.
8. **Deferred (optional):** the composed whole-protocol *Core-conjunction* inductive
   invariant in Apalache (lowest value — the deadlock it would corroborate is already
   reproduced by Spin).

---

## D. Findings routed to architecture

**None new.** The models *re-derived* the known Class-G reentry deadlock (already
fixed in V7) and otherwise found the v7.76 design admits no deadlock, store race,
resource leak, registration partial-residue, emit mis-fire, Layer-1 verdict leak, or
— under an active attacker — forgery, escalation, replay, deep frame confusion,
threshold bypass, or trusted-forever fail-open, at the modeled bound. Per repo
discipline any defect is a proposal/review-note in `entity-core-architecture`, never a
spec edit here.

*Full narrative + the 76-run re-verification matrix: `docs/FINAL-ASSURANCE-SUMMARY.md`.
Cross-check detail: `docs/CROSSCHECK-RESULTS.md`. Per-property commands: the
`tla/` and `tamarin/` FORMALIZATION-REPORTs.*
