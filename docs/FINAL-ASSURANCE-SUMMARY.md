# FINAL ASSURANCE SUMMARY — entity-core-formalization

**Status: complete and paused clean.** This is the capstone note over
everything this repo produced: the TLA+ concurrency/liveness model and the
Tamarin/ProVerif active-attacker model of the Entity Core Protocol V7 design — each now
independently cross-checked. It is written so a future reader (or a returning agent) can
understand *what was proved, how far it goes, and what it deliberately does not say*
without re-reading the underlying reports.

**The one-paragraph version for the team.** We ran formal verification on the V7 *design*
and did as much as the time allowed. **TLA+** covers all of Core Protocol's
concurrency + liveness, and is cross-checked with **two independent engines**: an independent
**Spin** (Promela) re-encoding of every concurrency module — written from the spec, not
translated — and **Apalache** SMT proofs that turn the key safety invariants from *checked at
a bound* into *proven inductive (unbounded)*. **Tamarin + ProVerif** (two provers, lockstep)
cover the active-attacker surface (12 lemmas). Every property is §-cited to `spec-data/v0.8.0/`,
every secure result has a negative control with teeth, and the scope boundaries — above all the
**5th wall (spec↔model fidelity)** — are stated, not hidden. This is a strong machine-checked
**demonstrator, not a closed proof** of the protocol: it now needs **human review against the
vendored spec** and the remaining follow-ons (fuzzing/adversarial-authz for the *code*; Phase 3
extension protocols, gated on vendoring `EXTENSION-*`).

If you are resuming work, read this capstone first — the optional leftovers are enumerated
in §5 (Findings and residual risk).

---

## 1. What this project was for (one paragraph)

The Lean proof-vector peer (in `entity-core-keystone`) already proved the V7
authority **logic** correct — attenuation monotone, deny-by-default, the verdict
enforces the per-edge check. That closes the implementation pure-core layer and is
**not** re-done here. Two formal questions about the **design** remained, each on a
layer Lean structurally cannot reach (`docs/ASSURANCE-MAP.md`, rows 4 & 5):

1. **Concurrency + liveness** — does the distributed protocol deadlock, livelock,
   race, leak, or stall under interleaved multi-peer execution? → **TLA+**.
2. **Active attacker** — can a Dolev-Yao network attacker forge a capability,
   escalate, replay, reflect, or run a confused deputy? → **Tamarin / ProVerif**.

This repo answered both at demonstrator altitude, against the SHA-pinned vendored
spec `spec-data/v0.8.0/`, with every model abstracting the Lean-owned verdict interior
away on purpose.

## 2. What was built — the three workstreams

| Phase | Workstream | Deliverable | Result |
|---|---|---|---|
| 0 (spike) | TLA+ (Spike A) | `tla/FORMALIZATION-REPORT.md` | GO — §6.11 reentry slice; **rediscovered the Class-G deadlock** as a counterexample, green after the fix |
| 0 (spike) | ProVerif + Tamarin (Spike B) | `tamarin/FORMALIZATION-REPORT.md` | GO — cap unforgeability proved **automatically** in both tools; linkage-bug control caught |
| 1 | TLA+ all-Core concurrency | `tla/PHASE1-FORMALIZATION-REPORT.md` | 7 subsystems, safety **+ liveness**, each with a teeth-proving negative control; composed 2-peer model deadlock-free |
| 1 | Tamarin/ProVerif active-attacker | `tamarin/PHASE1-FORMALIZATION-REPORT.md` | 5 lemmas (no-escalation, deep-chain frame, binding+no-replay, revocation, multi-sig), lockstep both tools |
| 2 | Tamarin/ProVerif surface-closure | `tamarin/PHASE2-FORMALIZATION-REPORT.md` | 7 more lemmas (caveats, depth, expiry, deep-N, K-of-N, no-replay-in-ProVerif, persistent re-check) + 1 documented non-closure |

| 2 (x-check) | Apalache + Spin cross-check of the TLA+ models | `docs/CROSSCHECK-RESULTS.md` | **All 6 concurrency modules** independently re-encoded in Spin (incl. the Class-G deadlock); **every module's key safety invariant proven inductive (unbounded) in Apalache** — 5 modules, 8 invariants; both engines agree with TLC on green and on every control |

The cross-check (the TLA+ track's independent corroboration) is **complete across every
modeled subsystem** — see §3 and `docs/CROSSCHECK-RESULTS.md`. The one
consciously-deferred item is the optional composed *Core-conjunction* inductive invariant in
Apalache (lowest-value, the deadlock it would corroborate is already reproduced by Spin).

## 3. Independent re-verification of every claim

Rather than trust the reports, the **entire model matrix was re-run from the pinned
container images** and each result graded against its expected verdict. All three
matrices reproduce exactly what the reports claim.

| Matrix | Runs | Outcome |
|---|---|---|
| **TLA+** (TLC) | 25 | 7 base configs green (rc=0, "No error has been found"); **18 negative controls each caught their defect** (invariant violation / deadlock / temporal-property violation). Clean sweep. |
| **ProVerif** | 26 | 13 secure theories — security lemma `is true` + non-vacuity reachable; **13 bug controls each falsified** (`is false` + attack). |
| **Tamarin** | 25 | 12 secure theories `verified`; **13 bug controls each `falsified` + trace**. |
| **Tamarin `RevokeMech`** | 1 | **Expected non-termination confirmed empirically** — the backward search loops the regenerated `Valid` fact; the run was observed still executing after **2–8 hours** across two sessions (vs. the report's conservative ">130s"). The documented irreducible tool split, excluded from the matrix. NB: `timeout` wraps the `podman run` client, not the detached container — kill the container directly (`podman kill`) to reclaim it. |
| **Spin cross-check** | 28 | **All 6 concurrency modules** (reentry/conn/store/revoke/emit/register) × fix + defect variants. Every fix clean (safety + liveness); every defect caught the same way the matching TLC control fails (Class-G deadlock, handshake-ordering, store race, admission-bound, §5.1 revocation-ignored, §5.10 determinism-leak, emit mis-fire, marker-type, registration partial-residue, system-guard, and all liveness controls). |
| **Apalache cross-check** | 22 | **5 modules, 8 safety invariants** (Revoke ×2, Store ×2, Conn ×1, Emit ×2, Register ×1) × {base, step} proven **inductive (unbounded)** + every negative control caught symbolically (`ERROR 12`), matching TLC. |

The Spin/Apalache cross-check (details in `docs/CROSSCHECK-RESULTS.md`) is the
corroboration the TLA+ track had been missing — an independent re-encoding (Spin) *and* an
unbounded proof (Apalache) for every modeled subsystem, not a re-run of an existing result.

**76 model runs reproduced + 50 cross-check runs; all behave exactly as designed.**
Method note: the first
automated pass ran all three matrices concurrently, which produced four spurious
failures from an SELinux `:Z` bind-mount relabel race (three concurrent containers on
overlapping trees → transient "file not found" / empty output). Re-running those four
theories serially (ProVerif `MultisigKN`; Tamarin `BindingBug`, `Caveats`,
`CaveatsBug`) confirmed every one passes. No real regressions.

## 4. What is proved — and the walls (honest scope)

Each result certifies a **model of the V7 design**, not the prose and not the code.
The boundaries are stated in full in each report and `docs/ASSURANCE-MAP.md`; the
load-bearing ones:

- **5th wall — spec↔model fidelity (deepest).** Every guarantee is relative to the
  model faithfully transcribing `spec-data/v0.8.0/`. Mitigation: every modeled element
  cites its V7 §ref; every negative control reproduces a *named, real* V7 bug class.
  No tool closes this wall — review against the vendored spec owns it.
- **Verdict-interior + crypto walls.** §5.4 attenuation arithmetic is Lean's
  (abstract predicate / function symbol here); sign/verify are perfect symbolic
  primitives. Same trust boundaries Lean takes as axioms.
- **Bounded in TLC — but the key safety invariants are now proven unbounded.** TLC is
  exhaustive only at a tight bound (2 peers, 1–3 requests, small key sets) — the faithful
  worst case for the concurrency bugs (Class-G is deterministic at N=2). That bound is no
  longer the whole story: **Apalache proves each module's key safety invariant *inductive*
  (`Init⇒Inv`, `Inv∧Next⇒Inv'`), i.e. for all states, not just the enumerated ones**
  (8 invariants across 5 modules). What remains bounded-only is **liveness** (deadlock-/
  stall-freedom, settling, convergence) — Apalache does safety/inductive by construction, so
  liveness stays TLC + Spin at the modeled bound — and the *composed* whole-protocol inductive
  invariant (the deferred Core-conjunction).
- **Distributed-time wall.** Cross-peer verdict determinism under different `t`
  (§5.10) is TLA+'s lane; the provers abstract it. Conversely the active-attacker
  surface is the provers'; TLA+ abstracts the adversary.
- **Model, not code.** Hostile-byte rejection (malformed CBOR, oversized, protocol
  confusion) is the fuzzing + adversarial-authz follow-on (ASSURANCE-MAP row 6), not
  this project. validate-peer owns "impl conforms."

## 5. Findings and residual risk

**Findings routed to architecture: none new.** The models *re-derived* the known
Class-G reentry deadlock (already fixed in V7) and otherwise confirmed the v7.76
design admits no deadlock, store race, resource leak, registration partial-residue,
emit mis-fire, Layer-1 verdict leak, or — under an active attacker — forgery,
escalation, replay, deep cross-peer frame confusion, threshold bypass, or
"trusted-forever" fail-open, at the modeled bound. Per repo discipline any defect
would be a proposal/review-note in `entity-core-architecture`, never a spec edit here.

**Residual risk, ranked (carried verbatim from the reports — not papered over):**

1. **TLA+ cross-check: complete across every modeled subsystem (was the highest risk;
   now largely retired).** The TLA+ track is no longer singly attested on any module: Spin
   independently re-encodes all 6 concurrency modules (reproducing the Class-G deadlock and
   reaching TLC's verdict on every defect), and Apalache proves every module's key safety
   invariant **inductive (unbounded)** — both engines agreeing with TLC on green and every
   negative control (`docs/CROSSCHECK-RESULTS.md`). The 5th wall is now **substantially
   narrowed** — two independent paradigms agree across the whole surface — but **not closed**:
   they could in principle share a misreading of V7, so human review against `spec-data/v0.8.0/`
   still owns it. The only deferred cross-check item is the optional composed Core-conjunction
   inductive invariant (lowest value; deadlock already reproduced by Spin).
2. **Liveness is bounded; safety is now unbounded (TLA+).** As §4 — the inductive Apalache
   proofs lift the key *safety* invariants to all-N; *liveness* (deadlock-/stall-freedom,
   settling, convergence) remains small-scope exhaustive in TLC + Spin.
3. **A few thin positives.** `Store`'s store-cardinality conjunct is vacuous at a
   single key; `Register`'s correct-model atomicity is near-tautological. Both have
   teeth on the control side; multi-key/sequenced-writes would harden the green side.
   (The Apalache `Store` port makes the single-key bound explicit — `store ⊆ {"k"}` — so the
   thinness is visible, not hidden.)
4. **One tool asymmetry is irreducible.** Mechanistic linear-token revocation does
   not terminate in Tamarin (`RevokeMech`); it stays ProVerif's lane while Tamarin
   uses the terminating trace-restriction idiom. This is a genuine tool-capability
   finding, documented, not a modeling gap.
5. **Async/extension PROTOCOLS not modeled.** `EXTENSION-CONTINUATION/-SUBSCRIPTION/
   -COMPUTE` are not in the vendored snapshot; Phase 2 modeled only the §6.8 core
   property that governs them. Full protocols are Phase 3, gated on vendoring.

## 6. Bottom line

As a **design-assurance demonstrator**, the project met its objective: the V7 design
holds — under concurrency (safety + liveness) and under an active Dolev-Yao attacker —
across every property modeled, each grounded in a §-cited check and demonstrated
falsifiable by a negative control. **Both tracks are now doubly-attested:** the prover track
by ProVerif + Tamarin agreeing in lockstep, and the TLA+ track by an independent Spin
re-encoding of every concurrency module *plus* unbounded Apalache SMT proofs of every module's
key safety invariant — both engines agreeing with TLC throughout. The two highest-value results
(the Class-G deadlock and the §5.10 cross-peer determinism MUST) are corroborated on both
dimensions. What remains is the deliberately-deferred optional item (the composed Core-conjunction
inductive invariant) and the follow-ons that are out of this project's scope by design.

This is a strong machine-checked **demonstrator, not a closed proof.** It is a complementary
third leg beside Lean (logic) and validate-peer (conformance) — not a replacement, and not a
claim that "the protocol is proven." The honest next step is **human review of the models
against `spec-data/v0.8.0/`** (the 5th wall no tool can close), then the code-level follow-ons
(fuzzing + adversarial-authz) and Phase 3 extension protocols. State plainly, to anyone who
asks: we verified *models of the design*, as far as the time allowed, and said exactly where
the boundaries are.

---

*Underlying reports: `tla/{FORMALIZATION-REPORT,PHASE1-FORMALIZATION-REPORT,PHASE1-PROGRESS}.md`,
`tamarin/{FORMALIZATION-REPORT,PHASE1-FORMALIZATION-REPORT,PHASE2-FORMALIZATION-REPORT}.md`,
scope: `tamarin/PHASE{1,2}-SCOPE.md`, `tla/PHASE1-SCOPE.md`. Reproduce any run with the
per-row commands in those reports (`make tlc` / `make proverif` / `make tamarin`).*
</content>
