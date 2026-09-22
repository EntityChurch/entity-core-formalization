# PROPERTIES — what is PROVEN vs only MODELED (the honest scorecard)

**entity-core-formalization · v0.8.2**

This is the load-bearing honesty document for the release. A formal-methods repo
that overclaims is the worst kind of overclaim, so this states — per property,
exactly — the *strength* of each result and where it stops.

> **Which spec version this scorecard is about.** Everything below is machine-checked
> against the SHA-pinned snapshot named by `spec-data/MODELING-PIN`, currently
> `spec-data/v0.8.2/` — the Entity Core Protocol at spec version **0.8.2**, which is the
> current published line. The models were re-validated against that text and extended to
> cover the normative surface it added; the pin moved as the last step of that work, not
> the first. `make specdrift` reports the distance from the pin to the live spec and is the
> check that keeps this sentence true.

> **Frame, once, plainly:** this project is **design assurance, off the release
> critical path.** It machine-checks **models of the V8 design**, not the prose
> and not the code. It is **not** a claim that "the Entity Core Protocol is proven
> correct." It is a strong **demonstrator** — a complementary third leg beside
> Lean (authority logic) and validate-peer (impl conformance) — whose deepest
> assumption (spec↔model fidelity, the *5th wall*) **no tool here closes**.

## The three strengths of result, defined

| Tier | Meaning | Tools |
|---|---|---|
| **PROVEN (unbounded)** | Holds for **all** states / all N — a machine-checked **inductive proof** (`Init ⇒ Inv` and `Inv ∧ Next ⇒ Inv'`). Not "no counterexample found up to a bound" — *no counterexample can exist*. | Apalache (SMT/Z3) |
| **MODELED — bounded-exhaustive** | **Every** behaviour enumerated, but only at a **tight finite bound** (2 peers, 3–4 requests, small key sets). Sound within the bound; says nothing beyond it. | TLC, Spin |
| **MODELED — symbolic (Dolev-Yao)** | Holds against an **unbounded** active network attacker, but over **perfect symbolic crypto** (sign/verify are ideal primitives; no bit-level cryptanalysis). | Tamarin, ProVerif |

Every result below is additionally relative to the **5th wall**: it is a property
of the *model*, true only insofar as the model faithfully transcribes
`spec-data/v0.8.2/`. Each modeled element carries a V8 §-citation, each secure
result has a negative control that reproduces a *named, real* bug class, and each
module has a **non-vacuity witness** proving it reaches an interesting state at all —
that is the mitigation, not a closure. Human review against the vendored spec owns it.

---

## A. Concurrency / distributed correctness (TLA+ track)

### A1 — PROVEN unbounded (Apalache inductive, all N): 9 safety invariants / 5 modules

These are the key **safety** invariants of each concurrency module, proven
inductive — they hold in every reachable state, for any number of peers/requests,
not just the enumerated ones.

| Module | Invariant (operator) | V8 basis | What it proves |
|---|---|---|---|
| Revoke | `InvDet` (`VerdictFnOfLayer1`) | §5.10 | verdict is a function of Layer-1 only — no cross-peer/time leak |
| Revoke | `InvRev` (`RevokedNeverPasses`) | §5.1 | a revoked capability never produces a pass |
| Store | `InvRace` (`StoreRaceFree`) | §4.8 | concurrent admits cannot race the store past its gate |
| Store | `InvBound` (`ResourceBounded`) | §4.9(b) | the store stays within its admission bound |
| **Store** | **`InvUAF` (`NoUseAfterFree`)** | **§4.8 (0.8.1 RT-13a)** | **the content-store lifetime refcount never frees an entity under a live referrer** |
| Conn | `Inv` (`HelloImpliesNonce ∧ NoEstablishWithoutNonce`) | §4.6 | no connection established without the issued-nonce handshake |
| Emit | `InvIff` (`EventIffRealWork`) | §6.10 | an event fires **iff** real work happened (no phantom/no-op events) |
| Emit | `InvType` (`EventTypeCorrect`) | v7.74 B2 | the emitted event type matches the work done |
| Register | `Inv` (`SafeSys ∧ NoUserAtSystem`) | §6.2 | system-namespace guard holds; no user registers at a system path |

The inductive strengthening for the three `Store` invariants is `RefcountSound` —
the counter equals the live-referrer set and a key is in the store exactly while it
has one. `NoUseAfterFree` is an immediate corollary, which is precisely why the
synchronized discipline is safe and the split read-modify-write is not.

Reproduce: `make -C tla apalache-green` (each: base case length 0 + inductive step length 1).

### A2 — MODELED, bounded-exhaustive (TLC + Spin): everything, incl. ALL liveness

At the tight bound (2 peers — the faithful worst case; the Class-G reentry deadlock
is deterministic at N=2), TLC enumerates every interleaving over **9 modules** and Spin
**independently re-encodes** 6 of them from the spec (a different formalism — explicit-state
Promela — agreeing corroborates the transcription).

- **Safety** at the bound: all of A1 **plus** the composed 2-peer `Core` model
  (deadlock-free establish→request→revoke), plus the two modules added at 0.8.2:
  - **`Authority`** (§5.2) — the three-valued dispatch authority, the resource-check
    binding, and the no-resource-inheritance rule.
  - **`Bounds`** (§5.9/§4.10) — TTL versus continuation `chain_depth` as distinct
    magnitudes, single-decrement TTL accounting, and distinct reason strings.
- **Liveness — bounded only, by nature** (Apalache does safety/induction by
  construction, so liveness stays TLC+Spin at the bound): deadlock-freedom,
  stall-freedom, eventual settling, revocation convergence, emit progress. *These
  are MODELED, not PROVEN-unbounded.*
- **Negative controls with teeth:** **29 TLC** + 3 Apalache + **17 Spin** defect variants, each of
  which **must** be caught (and is) — Class-G deadlock, **frame interleaving**,
  handshake-ordering, store race, **refcount use-after-free**, admission-bound breach,
  §5.1 revocation-ignored, **unbounded revocation propagation**, §5.10 determinism-leak,
  emit mis-fire, marker-type, registration partial-residue, system-guard removal,
  **both Option-collapse defaults for the dispatch authority**, **sub-dispatch gate skip**,
  **resource inheritance**, **equal TTL/depth magnitudes**, **TTL double-count**,
  **shared reason string**, and the liveness controls.
- **Non-vacuity witnesses (new at 0.8.2): 9, one per module.** Each is an invariant
  asserted *in order to be violated*; the violation exhibits the interesting state. See
  §C.4 — this closes a gap that stood open from Phase 1.

Reproduce: `make -C tla tlc-green`, `make -C spin green`; full gate `make matrix`.

---

## B. Active-attacker protocol security (Tamarin / ProVerif track)

### B1 — MODELED, symbolic Dolev-Yao (unbounded sessions, perfect crypto): 14 lemmas

Two independent provers in lockstep (ProVerif proves all 15 incl. `BindingReplay`;
Tamarin proves 14). Unbounded in sessions/attacker behaviour; crypto is ideal.

| Lemma | Property | V8 basis |
|---|---|---|
| Unforge | capability unforgeability | §5.4/§5.6 |
| NoEscalation | no privilege escalation via attenuation | §5.4 |
| Binding / BindingReplay | request-binding; no replay/reflection | §5.6 |
| Caveats | caveat enforcement under an attacker | §5.5 |
| DepthBound / DeepChain / DeepChainN | delegation-depth bound; deep cross-peer frame integrity | §5.4 |
| Expiry | expiry honored against an attacker | §5.5 |
| **Malformed** | **an unrepresentable temporal field is refused, never read as absent** | **§5.6 (0.8.1 CAP-6a)** |
| **ChainTopology** | **cross-peer provenance holds at a NON-ISSUING third-party verifier** | **§5.8** |
| Multisig / MultisigKN | K-of-N threshold cannot be bypassed | §5.7 |
| Revoke | revocation under an active attacker | §5.1 |
| PersistentRecheck | no "trusted-forever" fail-open; re-check persists | §6.8 |

**On `ChainTopology` and what it says about `DeepChain`.** `DeepChain`/`DeepChainN`
prove the §5.5a granter-frame property with the verifier seated as the **root issuer**.
Those results are sound for the property they claim, but in that topology the root frame
and the verifier frame are the same peer, so a defect that canonicalizes against the root
is indistinguishable from correct behaviour — the local identity-collapse §5.8 names.
`ChainTopology` separates root / granter / grantee / verifier into four distinct peers and
adds the lemma `DeepChain` structurally cannot state. Its negative control confirms the
asymmetry: canonicalizing against the root frame leaves the verifier-namespace lemma
**still true** while falsifying the root-namespace one. `DeepChain` is not retracted; it is
**not sufficient on its own**, and that is now recorded rather than assumed.

Reproduce: `make -C tamarin green`; 15 ProVerif + 14 Tamarin bug controls each falsified.

---

## C. What is NOT proven here (the walls — stated, not hidden)

1. **Spec↔model fidelity — the 5th wall (deepest).** Every result above is a
   property of a *model*. No tool closes this; the two-paradigm agreement (Spin
   independent encoding + Apalache unbounded, both matching TLC; ProVerif+Tamarin
   lockstep) **narrows** it substantially but they could share a misreading of the spec.
   **Human review against `spec-data/v0.8.2/` owns this.**
   *This is not hypothetical:* during the 0.8.2 work the ProVerif/Tamarin lockstep caught
   a real defect in a hand-written Tamarin lemma (a `pkW` variable never bound to the
   verifier, so the lemma said far less than it appeared to). The cross-check earned its
   keep on the modeller, which is the failure mode it exists for.
2. **Verdict interior + crypto.** §5.4 attenuation arithmetic is **Lean's** (abstract
   predicate / function symbol here); sign/verify are perfect symbolic primitives.
   Same trust boundaries Lean takes as axioms — not re-proven here.
3. **Liveness is bounded-only** (see A2). Safety is lifted to unbounded by Apalache;
   liveness is not.
4. **Vacuity — one thin positive retired, one remaining, and the gap now instrumented.**
   - *Retired at 0.8.2:* `Store`'s store-cardinality conjunct was **vacuous** — the model
     held a single key while asserting a bound of 2, so `Cardinality(store) ≤ MaxStore`
     could not fail, and the Apalache port made it explicit as `store ⊆ {"k"}`. The store
     is now multi-key (3 keys against a bound of 2) and the bound is discharged by
     refcount correctness, so it is a real obligation with a control that breaks it.
   - *Still standing:* `Register`'s correct-model atomicity is **near-tautological**. It
     has teeth on the control side only. Sequenced-write `Register` remains open.
   - *The general gap, now closed:* the TLA+ track had **no non-vacuity assertions at
     all**, unlike ProVerif's reachability queries — a trivially-inert model would have
     reported the same green as a working one. Every TLC module now carries a **witness
     config** asserting an invariant that MUST be violated; `make -C tla tlc-witness`
     fails loudly if any witnessed state becomes unreachable.
5. **One irreducible tool asymmetry:** mechanistic linear-token revocation
   (`RevokeMech`) does **not terminate** in Tamarin — it stays ProVerif's lane; Tamarin
   uses the terminating trace-restriction idiom. Documented tool-capability finding,
   not a modeling gap. (`RevokeMech` is excluded from `make check`; run by hand with a
   kill switch.)
6. **Code, not modeled.** Hostile-byte rejection (malformed/oversized CBOR, protocol
   confusion) is the **fuzzing + adversarial-authz follow-on**, not this project.
   validate-peer (keystone) owns "impl conforms." Note the boundary carefully for
   §5.6 CAP-6a: `Malformed` proves the *verifier's disposition* of an unrepresentable
   temporal field; the CBOR decode that produces it is not modeled.
7. **Extension protocols not modeled.** `EXTENSION-CONTINUATION/-SUBSCRIPTION/-COMPUTE`
   are not in the vendored snapshot; only the core properties governing them are modeled
   (§6.8 re-check, and now §5.8's conformance topology and §5.9's continuation depth
   brake). Full protocols are **Phase 3, gated on vendoring**.
8. **§6.11(a′) is proved per-connection, not composed.** Frame-write atomicity is
   modeled in `Reentry` (TLC) and `reentry.pml` (Spin). The composed `Core` model
   deliberately does **not** carry it — it would duplicate `Reentry` without producing a
   cross-subsystem interleaving `Reentry` cannot already exhibit. Declared in `Core.tla`'s
   header rather than left silent.
9. **Deferred (optional):** the composed whole-protocol *Core-conjunction* inductive
   invariant in Apalache (lowest value — the deadlock it would corroborate is already
   reproduced by Spin).

---

## D. Findings routed to `entity-core-protocol`

Per repo discipline any defect is a proposal/review-note in the sibling protocol repo,
**never a spec edit here.**

1. **§5.9 recommended TTL/`chain_depth` ratio has zero margin at worst-case fan-out.**
   §5.9 requires the ratio be "chosen so the deterministic depth brake engages before the
   TTL backstop **under the peer's worst-case sub-dispatch fan-out**", and recommends 8×
   (seed 512 at ceiling 64). `Bounds` shows the property needs
   `ceiling × worst_case_fanout` **strictly less than** the seed: at exact equality the
   final causal level spends the last of the TTL and the backstop fires on the step the
   brake would have. A deployment that takes the recommended 8× seed *and* has a
   worst-case fan-out of 8 therefore has no margin. This is **not** a claim the default
   is wrong — §5.9 explicitly puts the choice on the deployment — but the boundary is
   worth stating where operators will read it. Reproduce: `BoundsRatioBug.cfg`.
2. **§5.8's topology rule is load-bearing for this repo's own prior results.** See §B1:
   the pre-0.8.2 `DeepChain` models sit in exactly the same-peer topology §5.8 says cannot
   witness a cross-peer seam. Recorded as a note on modeling practice for anyone building
   cross-peer chain-construction tests, not as a spec defect.

Otherwise **none new**: the models re-derived the known Class-G reentry deadlock (already
fixed) and otherwise found the 0.8.2 design admits no deadlock, frame interleaving, store
race, refcount use-after-free, resource leak, registration partial-residue, emit mis-fire,
Layer-1 verdict leak, grantless-sub-dispatch authorization, or — under an active attacker —
forgery, escalation, replay, deep frame confusion, threshold bypass, temporal fail-open, or
trusted-forever fail-open, at the modeled bound.

*Full narrative + the re-verification matrix: `docs/FINAL-ASSURANCE-SUMMARY.md`.
Cross-check detail: `docs/CROSSCHECK-RESULTS.md`. Per-property commands: the
`tla/` and `tamarin/` FORMALIZATION-REPORTs.*
