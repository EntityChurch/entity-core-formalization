# FORMALIZATION-REPORT — Phase 1 (TLA+ / all-Core-Protocol concurrency surface)

**Status:** Phase 1 TLA+ modeling complete. **Recommendation: GO** — the staged
comprehensive model landed; every increment is green with a negative control TLC catches.
**Artifact type:** design-assurance formalization note (sibling to keystone's Lean
`FORMALIZATION-REPORT.md` and the conformance scorecard). Models the **V7 design**, not the
code — see *Scope boundaries*. Companion to the Spike-A report (`FORMALIZATION-REPORT.md`),
which this extends from one slice (§6.11) to the whole concurrent/distributed surface.

---

## TL;DR — the headline result

The plan (`PHASE1-SCOPE.md`) decomposed "all of Core Protocol" into the **seven concurrent/
distributed subsystems** TLA+ can faithfully reach, and staged them as one model family. **All
seven are built and machine-checked green at their fidelity bar, each with a negative control
TLC catches** (the Spike-A discipline: prove the model has teeth). The composed multi-peer
model holds the conjoined invariants **and** stays deadlock-free under full interleaving —
while still catching the canonical Class-G deadlock when the §6.11 fix is removed.

| # | Subsystem (V7 §) | Module | Correct | Negative control(s) → caught (safety / **liveness**) |
|---|---|---|---|---|
| 0 | Dispatch + reentry (§6.5/6.11) | `Reentry` | ✔ green | `Serialized=TRUE` → **Deadlock** (`EventuallyResolved`) |
| 1 | Connection lifecycle (§4.1–4.7) | `Conn` | ✔ green | `Enforce=FALSE` → `NoEstablishWithoutNonce`; **`DropFrame=TRUE` → `AllAnswered`** |
| 2 | Store / resilience / admission (§4.8/4.9/4.10) | `Store` | ✔ green | `Serialize=FALSE` → `StoreRaceFree`; `Admit=FALSE` → `ResourceBounded`; **`SilentDrop=TRUE` → `Responsive`+`Recovers`** |
| 3 | Registration + index↔tree (§6.1/6.2/6.6) | `Register` | ✔ green | `Atomic=FALSE` → `NoPartialResidue`; `GuardSystem=FALSE` → `NoUserAtSystem`; **`WedgeReg=TRUE` → `RegisterSettles`** |
| 4 | Emit pathway (§6.10) | `Emit` | ✔ green | `Fire=FALSE` → `EventIffRealWork`; `MarkerDeletes=TRUE` → `EventTypeCorrect`; **`StallEmit=TRUE` → `EmitTerminates`** |
| 5 | Revocation + verdict determinism (§5.1/5.10) | `Revoke` | ✔ green | `HonorRevocation=FALSE` → `RevokedNeverPasses`; `LeakLayer1=TRUE` → `VerdictFnOfLayer1`; **`NoConverge=TRUE` → `RevocationConverges`** |
| 6 | Composed multi-peer (§ all) | `Core` | ✔ green | `Serialized=TRUE` → **Deadlock** (Class-G survives composition); `GateEstablished=FALSE` → `DispatchNeedsEstablished`; `GateRevocation=FALSE` → `NoServeWhenRevoked` |

**25 model runs, all behaving exactly as designed: 7 correct models green (safety + liveness),
18 negative controls each catching their intended defect.** After a critical self-review +
confidence-hardening pass, **every property checked — safety AND liveness — is now demonstrated
falsifiable** (a negative control where it fails), and the composed model's A (establishment)
and F (revocation) layers are checked by controls with teeth rather than guarded-by-construction.
Reproduce the whole matrix from `tla/` with the commands in each row's note (`PHASE1-PROGRESS.md`).

## What the model proves — per subsystem

Each increment proves **safety + (where it applies) liveness** at tight bounds, exhaustively
model-checked. Highlights (full property catalog: `PHASE1-SCOPE.md` §2; per-increment notes:
`PHASE1-PROGRESS.md`):

- **A — Connection (`Conn`).** Handshake ordering, no token reissue on reconnect, the 403
  pre-auth gate (safety); the handshake settles (liveness). The §4.6 hello-before-auth ordering
  is the modeled check; crypto is abstracted.
- **C — Store/resilience/admission (`Store`).** Store-safety as a single-writer critical section
  (`StoreRaceFree`), bounded resources under load (`ResourceBounded`), clean coded rejection of
  over-limit input (`CleanReject`) — safety; stays responsive and recovers to idle when load
  subsides (`Responsive`, `Recovers`) — liveness. This is the §4.9 "stays up under load"
  outcome contract checked as temporal properties.
- **E — Registration (`Register`).** The §6.2 five-write `register`/`unregister` as an
  all-or-nothing atomic transition (`NoPartialResidue`, `RegisterAllOrNothing`), the §6.6
  dispatch-index↔tree cache-coherence invariant (`IndexMatchesTree`), and no-user-at-system
  (`NoUserAtSystem`) — safety; registration settles (liveness).
- **D — Emit (`Emit`).** The §6.10 event-iff-real-work firing contract and the
  created/modified/deleted derivation including the v7.74 B2 deletion-marker carve-out
  (`EventTypeCorrect`).
- **F — Revocation/determinism (`Revoke`).** Revoked-never-passes (§5.1) and the §5.10
  cross-peer determinism MUST — the Layer-1 verdict is a function of (chain, `t`, observed
  revocations) only, with local Layer-2 policy provably unable to modulate it
  (`VerdictFnOfLayer1`); revocation converges (liveness).
- **G — Composition (`Core`).** The conjunction of the above survives 2-peer bidirectional
  interleaving, and **global liveness** (`EventuallyResolved`) holds — the whole substrate is
  deadlock/livelock-free. The negative control proves this result has teeth: the Class-G
  deadlock re-forms under full composition when the fix is removed.

## Scope boundaries — the walls (the 5th-wall, stated per subsystem)

A model certifies a *model*. The deepest wall is **spec↔model fidelity** — the result is only
as good as each module faithfully transcribing V7 from `spec-data/v0.8.0/`. Mitigation: **every
modeled state element cites its V7 §ref** (grep the modules), and the abstractions are named,
never hidden:

- **Verdict / attenuation arithmetic (§5.2/5.4/5.5/5.6) — Lean's, abstracted.** Appears only as
  the opaque `Gate`/`Honored`/`ChainValid` predicate. Not re-modeled (project non-negotiable #4).
  `Revoke` models the *temporal/observation* layer §5.10 puts **around** that verdict, not the
  verdict.
- **Crypto / PoP / signatures (§4.6, §7.3) — Tamarin/Lean's.** Abstracted; the active-attacker
  wall is Spike B's. `Conn` models the nonce-echo *check* as state, not the signature.
- **Type system / CBOR / identity (§1/2/3) — type-system + conformance.** Pure data; not in any
  TLA+ module. `Emit` abstracts entity content to opaque hash tokens.
- **Bounds are symbolic, not numeric.** `Store` models payload/chain-depth as `ok`/`over`; §4.10
  names 16 MiB / 64 as *recommended defaults*, and the normative contract is "enforce a finite
  *declared* bound and reject over-limit cleanly," which the symbolic choice captures faithfully.
- **Tight bounds.** 2 peers; 1–3 requests; small key sets. This is the faithful worst case for
  the concurrency bugs (Class-G is deterministic at N=2), not a coverage gap to apologize for —
  but it is a bound. Single-peer modules (`Conn`, `Store`, `Register`, `Emit`) check the
  per-peer property; cross-peer contention is `Core`'s job.
- **Composition is by-conjunction + cross-interleaving, not full integration.** `Core`
  concentrates on the A/B/C/F concurrency interleavings; D and E compose as local invariants
  verified standalone. The per-subsystem *teeth* live in increments 2–5, not re-proven in `Core`.
- **Model, not code.** TLA+ certifies the *design*. That the *code* matches is owned by the §7b
  concurrency gate + validate-peer — complementary, not redundant: the gate spot-checks behavior,
  the model proves the design admits no deadlock/race/leak *at all* at the modeled bound.

## TLC vs Apalache, fairness, and on-ramp notes

- **State explosion (the scope's flagged main risk) did not materialize.** Every module is
  ≤ ~5k distinct states, sub-second on TLC; the composed model is **206 states**. The mitigation
  (modular-first + minimal composed essence per subsystem + tight bounds) was sufficient; **the
  Apalache fallback was not needed**, and `SYMMETRY` on `Peers` was available but unnecessary at
  this size. If a future increment widens bounds (3 peers, unbounded churn) and BFS blows up,
  the per-`PHASE1-SCOPE.md` §3 plan (symmetry → Apalache on the composed model only) still stands.
- **Fairness.** Liveness uses the weak fairness supplied by `fair process` on the
  serve/reader/drain/observe steps (matching Spike A). No strong fairness was needed; nothing
  was over-faired (which would mask real livelocks) — the negative controls confirm the liveness
  properties still *fail* when the design is broken, so the fairness is not hiding a livelock.
- **On-ramp.** Each increment was ~1 hour. The two recurring PlusCal gotchas (both caught
  instantly by the translator): a `*)` inside an algorithm-block comment closes the block early
  (reworded `system/*` prose); and two process families must not share an id set (`Core`'s
  link/client collision — distinct `Links` ids). Both are in the research log.

## Confidence — what a critical review closed, and what it did not

This report is deliberately not self-congratulatory. A green TLC run checks the model against
*its own invariants*, not against V7, and TLC is exhaustive only inside a tiny bound. A critical
self-review drove a hardening pass; here is the honest ledger.

**Closed by the hardening pass:**
- *Every property is now demonstrated falsifiable.* Previously only 1 of 7 liveness properties
  had a negative control; now all do (the table's bold entries), plus the composed model's A/F
  layers. A property that can fail when the design is broken — and these all now do — is not
  vacuous.

**NOT closed — the real residual risk, ranked by how much it should lower your confidence:**
1. **No independent cross-check (highest).** One encoding, one tool (TLC), one transcriber. Unlike
   Spike B (Tamarin *and* ProVerif agreed), nothing here corroborates that the TLA+ faithfully
   encodes V7 — the 5th wall rests entirely on the §-citations being right. **Status: the path is
   now prepped, not yet walked.** Two independent cross-check toolchains are stood up and
   smoke-tested — **Apalache** (SMT; proves inductive invariants → *unbounded*, all-N, closing
   "checked ≠ proved") and **Spin** (Promela; an independent re-encoding → attacks fidelity, the
   true analog of the multi-language conformance peers). The per-module sequence, property
   mapping, and agreement criterion are in `docs/HANDOFF-CROSSCHECK.md`. Until those encodings are
   built and shown to *agree*, this gap is open — but it is now executable, not theoretical.
2. **Bounded, not proven.** 2 peers, 1–3 requests, single keys. These are exhaustive checks *at
   that bound*, not theorems for all N. No inductive invariants. Small-scope heuristic ≠ proof.
3. **Two thin positives remain.** `Store`'s store-cardinality conjunct is vacuous (single key);
   `Register`'s correct-model atomicity is near-tautological (one atomic step). Both have
   teeth on the *control* side but weak green sides. Multi-key/eviction + sequenced-writes are Phase-2.
4. **No conformance-vector tie** beyond Class-G. Only the reentry deadlock is grounded against a
   reference impl; the other properties are grounded only in spec prose, not in a passing test.

Bottom line: as a **design-assurance demonstrator**, this is now internally rigorous — every
check earns its place. As **"verified,"** it is not, and the four items above are exactly why.
It is a complementary third leg (beside Lean and the conformance gate), and still the
least-independently-attested one.

## Recommendation — GO; Phase 1 modeling objective met

The user's Phase-1 goal — cover **all of Core Protocol's concurrent/distributed surface** in
TLA+ — is **met as scoped**: seven subsystems, safety + liveness, each green with a teeth-proving
negative control, plus a composed model that shows the whole substrate is deadlock-free and that
composition did not mask the canonical defect. Liveness — the property nothing else in the
assurance stack proves — is now machine-checked across the entire core concurrency surface, not
just the §6.11 slice.

**Findings routed to architecture:** none new. The models *re-derived* the known Class-G
deadlock (already fixed in V7) and otherwise confirmed the v7.76 design admits no deadlock,
store race, resource leak, registration partial-visibility, emit mis-fire, or Layer-1 verdict
leak at the modeled bound. (Per the repo discipline, any defect would be a proposal/review-note
in `entity-core-architecture`, never a spec edit here.)

**Phase 2 (later, separate explicit GO) — the deferred dimensions, each named above:**
1. **Extensions surface** — async delivery / INSTALL / continuations / subscription cascades
   (SYSTEM-COMPOSITION), the emit *consumer* model `Emit` deliberately left core-only.
2. **Wider bounds** — 3 peers + unbounded/churned store writes to exercise §4.9(b)/(e) leak +
   recovery at scale; this is where `SYMMETRY` / Apalache earn their place.
3. **Deny-path depth** — model gate *denials* (verdict abstracted but not always-honored) to
   make the dispatch gate load-bearing across the composed model, and the core-tier
   (`supports_revocation=false`) revocation determinism statement.
4. **Per-request deadlines (§6.11(c))** as the time-domain backstop that converts a would-be
   hang into a clean `recv_timeout`/503 — modeling *why* Class-G stays a liveness bug, not a crash.

Phase 1 remained **post-06-21, off the release critical path**, additive design assurance.
```
Reproduce: cd tla && make tlc SPEC=<Module> [CFG=<Variant>]   # see PHASE1-PROGRESS.md per row
```
