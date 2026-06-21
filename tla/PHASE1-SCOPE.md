# Phase 1 — TLA+ comprehensive Core Protocol scope

**Status:** scoping (post-Spike-A GO). **Goal stated by user:** "aim to get
all Core Protocol done" in TLA+ if reasonable. This doc says what "all Core Protocol"
honestly means *for TLA+*, decomposes it, and stages it.

> **The honest headline:** "all of Core Protocol" is the wrong unit for TLA+. Half of V7
> §1–§9 is data shapes, crypto, and verdict arithmetic that TLA+ cannot or should not
> model (other tools own them). The right unit is **the entire concurrent/distributed
> behavioral surface of Core Protocol** — connection lifecycle, dispatch+reentry, store
> safety/resilience, emit, registration, revocation-as-shared-state — at multi-peer
> concurrency, with safety **and** liveness. That IS reasonable as the Phase-1 goal, but
> it is a **staged, multi-increment** model (~3–4 weeks at this project's fidelity bar),
> not one monolith and not one session. Spike A (§6.11) is increment 0, done.

---

## 1. The TLA+ reach line — what's in, what's out, who owns the rest

TLA+'s wall is the **IO-shell: transport / store / concurrency** (ASSURANCE-MAP wall #2):
interleavings, ordering, progress, shared mutable state. Everything else in Core Protocol
is owned by another tool and is **abstracted** in the model (named, never hidden — 5th wall).

| V7 area | TLA+? | Disposition |
|---|---|---|
| §4.1–4.7 connection handshake (ordering, nonce-echo, 409, error codes) | **IN** | concurrent state machine — subsystem **A** |
| §4.8 store-safety, §4.9 resilience, §4.10 admission/bounds | **IN** | subsystem **C** |
| §6.5 dispatch chain, §6.6 path dispatch, §6.11 reentry | **IN** | subsystem **B** (B core = Spike A) |
| §6.10 emit pathway (Store+Bind, event derivation, bind-atomicity) | **IN** | subsystem **D** |
| §6.1/§6.2 handler registration (5 writes), §6.6 index↔tree coherence | **IN** | subsystem **E** |
| §5.1 revocation as tree state, §5.10 verdict determinism / time-as-input | **IN** | subsystem **F** |
| multi-peer concurrent sessions | **IN** | subsystem **G** (composition) |
| §5.2/§5.4/§5.5/§5.6 verdict + attenuation arithmetic | OUT | **Lean** — abstract as `Gate`/`Attenuated` predicates |
| §7.3/§7.4, §4.6 PoP signatures/nonce crypto | OUT | **Tamarin/Lean** — abstract; Spike B owns the attacker |
| §1 identity, §2 type system, §3/CBOR encoding | OUT | type-system + conformance; pure data |
| §8 constants, §9 conformance | OUT | n/a |

**Rule for every OUT item:** it appears in the model only as an opaque predicate or an
atomic value, with a comment citing the § and the owning tool. No re-modeling of Lean's
verdict (the project's non-negotiable #4).

## 2. Subsystem decomposition (the property catalog)

Each subsystem is an increment: its own module(s), its own safety + liveness properties,
its own mini-report. Citations are to `spec-data/v0.8.0/`.

### A — Connection lifecycle (§4.1–4.7)
- **State:** per-connection phase (`new → hello → authed → established → closed`), the
  pre-auth allowlist (only `system/protocol/connect`), issued-nonce, established flag.
- **Safety:** `HelloBeforeAuth` (§4.2 ordering); `NoPreAuthDispatch` (§4.2 — non-connect
  path pre-establish → 403); `NoReissueOnReconnect` (§4.2 — established+connect → 409, no
  new token); `PhaseMonotone` (phase never regresses); `NonceEchoChecked` (§4.6 step 1 —
  authenticate only accepted when nonce matches the issued one — crypto abstracted, the
  *check* modeled).
- **Liveness:** `HandshakeSettles` (every started handshake reaches `established` or a
  coded failure §4.7 — never hangs).

### B — Dispatch + reentry (§6.5, §6.6, §6.11)  ← Spike A is the core
- **Safety:** `NoDispatchWithoutGate` (§6.5); `RespToRightAwaiter` (§6.11(b) reqId demux —
  a response resolves exactly its originating request); `LongestPrefixResolve` (§6.6).
- **Liveness:** `EventuallyResolved` (§6.11/§4.9a — done at N=2; extend to N=3).
- **Reuse:** the Spike-A `Serialized` idiom and the per-request correlation map.

### C — Store-safety / resilience / admission (§4.8, §4.9, §4.10)
- **Safety:** `StoreRaceFree` (§4.8 — no unserialized concurrent mutation of a key; model
  the single-writer/lock/actor discipline); `ResourceBounded` (§4.9b/§4.10 — store, pending
  map, connections all bounded under churn); `AdmittedNeverDropped` (§4.9c deliver-or-
  signal — every admitted request ends responded/failed, never vanishes);
  `OverLimitCleanReject` (§4.10 — payload>max → 413, chain-depth>max → 400, peer keeps
  serving in-flight).
- **Liveness:** `Responsive` (§4.9a — always-eventually progress); `Recovers` (§4.9e —
  load subsides ⇒ pending queue drains ⇒ normal state, modeled as `<>[]` return-to-idle).

### D — Emit pathway (§6.10)
- **Safety:** `BindAtomic` (§6.10 — a reader sees pre- or post-bind, never partial);
  `EventIffRealWork` (§6.10 — content-store event iff hash new; tree-change event iff
  binding changed; `event_type` created/modified/deleted derivation correct);
  `NoEventOnNoop` (re-put / re-bind to current ⇒ no event).
- **Liveness:** `ConsumersEventuallyRun` (if a consumer is modeled — optional; core-only
  peers have no consumers, §6.10).

### E — Handler registration (§6.1, §6.2, §6.6 cache)
- **Safety:** `RegisterAllOrNothing` (§6.2 five writes — dispatch never observes a handler
  manifest without its grant+signature, or vice versa; the atomicity boundary);
  `IndexMatchesTree` (§6.6 — the dispatch index is observably equivalent to the tree walk
  at all times; the cache-coherence invariant); `NoUserAtSystem` (§6.2 — user register at
  `system/*` rejected); `UnregisterReverses` (§6.2 — unregister removes exactly the five).
- **Liveness:** `RegisterCompletes`; concurrent register-vs-dispatch makes progress.

### F — Revocation + verdict determinism (§5.1, §5.10)
- **Safety:** `RevokedNeverPasses` (§5.1/§6.8 — once a revocation marker is observed, the
  cap fails every subsequent check, even mid-operation); `VerdictFnOfLayer1` (§5.10 — the
  verdict is a function of (chain, observed-revocations, `t`) only; two peers with the same
  Layer-1 state + same `t` agree — `t` and revocation as *enumerated* inputs, §5.10 v7.76).
- **Liveness:** `RevocationConverges` (§5.10 — a written marker is eventually observed by a
  verifier in the same revocation tier).
- **Abstract:** the chain *validity* verdict itself = `Gate` (Lean's); F models the
  *temporal/observation* layer around it (when a valid cap flips to invalid).

### G — Multi-peer composition (§ all)
- 2–3 peers running A–F concurrently with cross-peer dispatch. The composed model where the
  cross-subsystem interleavings live (e.g., revoke during reentry; register during dispatch;
  handshake under load). Properties: the conjunction of A–F invariants + global liveness.

## 3. State-space strategy (keeping TLC tractable)

The composed model (G) will blow up under naïve BFS. Plan:
- **Build A–F as standalone modules first**, each green at tight bounds (2 peers, 1–2
  requests, MaxKeys=2). Each is small (Spike A was 36 states).
- **Symmetry reduction** on the `Peers` set (TLC `SYMMETRY`) — peers are interchangeable.
- **Tight constants + state constraints** (`CONSTRAINT` to cap queue lengths / request
  counts) so the composed model stays finite and small.
- **Apalache fallback** (SCOPING decision #3): if BFS blows up on G, switch that model to
  Apalache (symbolic/SMT, bounded) — it handles larger state with inductive invariants.
  Keep A–F on TLC (push-button).
- **Liveness cost:** liveness checking is more expensive than safety; run safety-only first
  at higher bounds, then liveness at minimal bounds with explicit fairness.

## 4. Staging / build order (each ≈ days; total ≈ 3–4 weeks at fidelity bar)

0. **§6.11 reentry — DONE** (Spike A).
1. **A — Connection lifecycle** (natural next; foundational; no store coupling). ~2–3 days.
2. **C — Store-safety/resilience/admission** (extends Spike A's store + reentry). ~3–4 days.
3. **E — Registration + index↔tree coherence** (a sharp, high-value cache invariant). ~3 days.
4. **D — Emit pathway** (small, self-contained). ~2 days.
5. **F — Revocation + verdict determinism** (the cross-peer determinism MUST is high-value). ~3–4 days.
6. **G — Composed multi-peer model** + TLC/Apalache scaling. ~1 week.
7. **Composed FORMALIZATION-REPORT** + Phase-1 close. ~1–2 days.

Highest security/assurance value if forced to prioritize: **A, C, F** (liveness of the
substrate + the cross-peer determinism contract). D and E are correctness-hardening.

## 5. Deliverables

- One module (or small module family) per increment, each with `.cfg`(s) and a short
  result note appended to a running `tla/PHASE1-PROGRESS.md`.
- A composed `FORMALIZATION-REPORT` (Lean-report shape) at close: properties proved /
  counterexamples / scope boundaries (5th wall per subsystem) / TLC-vs-Apalache notes /
  Phase-2 (extensions: async/INSTALL/continuations/subscriptions) recommendation.
- Negative controls throughout (mirror Spike A): for each safety invariant, a "remove the
  check" variant that TLC must catch — proof the model has teeth.

## 6. Is "all Core Protocol, this session" reasonable? — No; here's the honest call

A faithful comprehensive model — 6 subsystems × (safety + liveness) × multi-peer, each
with per-clause citations and negative controls, plus making TLC/Apalache scale on the
composed model — is **multiple sessions / ~3–4 weeks**, not one session. Forcing it into
one session would mean dropping the fidelity discipline (the per-§ transcription review and
the 5th-wall honesty) that is the entire point of the project. **Recommendation:** treat
"all Core Protocol concurrency" as the Phase-1 *goal*, build it in the staged order above,
land each increment with its own checked result, and keep a running progress note. Start
next session with increment 1 (Connection lifecycle) per the handoff.

## 7. Risks / open questions

- **[Q] Composed-model state explosion** — the main risk. Mitigation: modular-first +
  symmetry + Apalache fallback (above). Decide TLC-vs-Apalache per-increment empirically.
- **[Q] Liveness under realistic fairness** — weak vs strong fairness on which actions?
  Spike A needed WF on the reader/serve steps; the handshake and revocation-observation
  steps will need their own fairness; over-strong fairness can mask real livelocks.
- **[Q] How much of emit/registration is "core" vs extension-coupled?** §6.10 consumers are
  extensions; core-only emit is trivial. Keep D minimal (the Store+Bind primitive), defer
  consumer cascades to Phase 2.
- **[Q] Revocation tiers (§5.10)** — `supports_revocation` on/off changes the determinism
  statement. Model both tiers or pin one? Plan: model the `true` tier, note the `false` tier.
