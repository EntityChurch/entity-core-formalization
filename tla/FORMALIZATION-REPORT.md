# FORMALIZATION-REPORT — Spike A (TLA+ / §6.11 reentry concurrency)

**Status:** Spike A complete. **Recommendation: GO** to a scoped Phase 1.
**Artifact type:** design-assurance formalization note (sibling to keystone's Lean
`FORMALIZATION-REPORT.md` and the conformance scorecard). Models the **V7 design**,
not the code — see *Scope boundaries* below.

---

## TL;DR — the headline result

A small TLA+/PlusCal model of the **§6.11 Transport Reentry Contract** (2 peers, pooled
connections, reverse-direction reentry) **rediscovered the known Class G deadlock as a
machine-checked counterexample**, and verified that the §6.11(a)+(b) fix removes it:

| Variant | §6.11(a) | Safety invariants | Liveness `EventuallyResolved` | TLC verdict |
|---|---|---|---|---|
| **Fixed** (`Serialized = FALSE`) | honored | ✔ green | ✔ holds | **No error** (36 states) |
| **Defect** (`Serialized = TRUE`) | violated | ✔ green | ✗ **violated** | **Deadlock reached** + temporal counter-example |

The defect variant fails **two independent ways** — TLC's deadlock check reports a stuck
state with no successor, and (with deadlock-checking disabled) the liveness property
`EventuallyResolved` is violated by a stuttering counterexample. This is exactly the
outcome architecture asked for: *"the model finds the bug we found by hand."*

## Status as of Spike A

- **Toolchain:** containerized (make + podman), zero host installs. `entity-tla` image
  = JRE + pinned `tla2tools v1.8.0`. Proven end-to-end (`make image/smoke/translate/
  tlc`) before any modeling.
- **Model:** `Reentry.tla` (PlusCal) + `Reentry.cfg` (fixed) + `ReentryBug.cfg` (defect).
  Design + fidelity mapping in `DESIGN-REENTRY-MODEL.md`.
- **Result:** the table above. Modeling effort: **~hours**, not days (see *On-ramp*).

## What the model proves — and what it does NOT yet say

**Proved (at the 2-peer bound, exhaustively model-checked):**
- *Safety* `StoreBounded` (V7 §4.8/§4.9(b)) and `NoDispatchWithoutGate` (V7 §6.5) hold in
  both variants.
- *Liveness* `EventuallyResolved` (V7 §4.9(a): every admitted request eventually responds
  or fails — no deadlock/livelock) **holds for the fixed design** under weak fairness.
- The **defect** design (per-connection mutex held across send+recv) **necessarily
  deadlocks** at the symmetric N=2 shape: both clients hold their connection mutex across
  recv, both servers block acquiring it to reenter/respond → circular wait, no successor
  state. This matches the entity-core-go `Class G / F-WB28` mechanism byte-for-byte at the
  abstraction level modeled.

**Does NOT say (honest boundary):**
- *Nothing about N≥3 meshes.* The model is bounded at 2 peers — which is correct, because
  Class G is *deterministic* at N=2 and only *probabilistically masked* at N≥3 (per
  BUG-CLASSES Class G). The 2-peer bound is the faithful worst case, not a coverage gap to
  apologize for — but it is a bound.
- *Nothing about the real verdict algorithm.* `Gate(p)` is an abstract always-true
  predicate. `NoDispatchWithoutGate` is therefore a *structural* guarantee (a handler never
  runs pre-gate), not a statement about §5.x correctness — **Lean owns that, and it is
  done.** A Phase-1 refinement could model gate *denials* to exercise the deny path.
- *Nothing quantitative.* No latency, no throughput — §4.9 is an outcome contract and the
  model checks the outcomes (progress, no silent drop), not numbers.
- `StoreBounded` is presently a structural guard (the modeled handler writes one key); it
  becomes load-bearing only when Phase 1 models repeated/unbounded writes to exercise the
  §4.9(b) leak/runaway class directly.

## Why the N=2 deadlock is the faithful target (not a toy)

Grounded against the reference impl, not invented: entity-core-go's
`connection.go` carries the `Class G / F-WB28` fix comment and
`connection_multiplex_test.go::TestConnection_ReentrantCrossPeerDoesNotDeadlock` pins the
exact 2-peer bidirectional shape; arch `BUG-CLASSES.md` Class G and keystone's §7b gate
(probe T1.2 `reentry-under-load`) catalogue it. The model's `Serialized` switch is the
pre-fix vs post-fix discipline; the deadlock trace is the pre-fix transport.

## Scope boundaries — the walls (carried from the Lean limits map)

A model certifies a *model*. The result is relative to:
1. **5th wall — spec↔model fidelity (deepest).** The guarantee is only as good as
   `Reentry.tla` faithfully transcribing V7 §6.11/§4.8/§4.9/§6.5 from `spec-data/v0.8.0/`.
   Mitigation: every state element cites its §ref; the deadlock shape was cross-checked
   against the Go impl. There is no tool that closes this wall — it is owned by review.
2. **Verdict wall.** Cap-chain correctness is abstracted to `Gate` — **Lean's**, done.
3. **Crypto wall.** Not in scope for this spike (it is Spike B / Tamarin's symbolic wall).
4. **Model-not-code.** TLA+ certifies the *design*. That the *code* matches is owned by
   the §7b concurrency gate + validate-peer; this model and that gate are complementary
   (the gate spot-checks behavior; the model proves the design admits no deadlock at all).

## On-ramp pain (for the Phase-1 estimate)

- **Low.** The whole spike — toolchain, model, both variants, this report — was ~hours.
- Two PlusCal gotchas cost minutes each, both caught immediately by the translator:
  (a) two assignments to one variable in a single atomic step are illegal (fold into one);
  (b) two process families cannot share the same id set — client and server of a peer need
  disjoint ids to run concurrently (the bug that, uncaught, would have silently prevented
  the deadlock by collapsing 4 processes to 2). Both are in the research log.
- **TLC is push-button** at this bound (sub-second, 36/70 states). No Apalache needed.

## Recommendation — GO, with a scoped Phase 1

The spike cleared its gate decisively: TLC checked the fixed design green **and**
rediscovered the Class G deadlock as a counterexample. Liveness — the property nothing
else in the assurance stack proves — is now machine-checked for the core reentry slice.

**Phase 1 scope (estimate: ~1–2 weeks for the high-value increments):**
1. Add per-request deadlines (§6.11(c)) and show they convert the deadlock-hang into a
   *clean* `recv_timeout`/503 failure — i.e. model *why* §6.11(c) is the backstop that
   keeps Class G a liveness bug, not a crash. (~days)
2. Model gate *denials* (verdict abstracted but not always-true) to exercise the deny path
   and make `NoDispatchWithoutGate` load-bearing. (~days)
3. Unbounded/repeated store writes + connection churn to exercise §4.9(b)/(e) (leak +
   recovery) directly, mirroring §7b probes T2.1/T2.2 as temporal properties. (~days)
4. Raise to 3 peers to confirm the model agrees with the "N≥3 probabilistically masks"
   claim (expect: fixed stays green; defect still has a reachable deadlock). (~days)

Phase 1 remains **post-06-21, off the critical path**, a separate explicit GO.
