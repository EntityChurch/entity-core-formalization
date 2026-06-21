# Phase 1 — TLA+ progress

Running log of the staged comprehensive Core Protocol model (scope + property catalog:
`PHASE1-SCOPE.md`). One row per increment; each lands green + a negative control that TLC
catches (the Spike-A discipline: prove the model has teeth). Newest at bottom.

**Full matrix (after the confidence-hardening pass): 7 correct models green, 18
negative controls all firing — every safety AND every liveness property is demonstrated
falsifiable.** See "Confidence-hardening pass" below for what changed and why.

| # | Subsystem | Module | §refs | Status | Result |
|---|---|---|---|---|---|
| 0 | Dispatch + reentry | `Reentry.tla` | §6.5/6.11 | **DONE** (Spike A) | fixed green incl. liveness; defect → "Deadlock reached" |
| 1 | Connection lifecycle | `Conn.tla` | §4.1–4.7 | **DONE** | green (3 safety + liveness `AllAnswered`, 266 states); negs: `Enforce=FALSE`→`NoEstablishWithoutNonce`; `DropFrame=TRUE`→`AllAnswered` (liveness) |
| 2 | Store-safety / resilience / admission | `Store.tla` | §4.8/4.9/4.10 | **DONE** | green (3 safety + 2 liveness, 4932 states); negs: `Serialize=FALSE`→`StoreRaceFree`; `Admit=FALSE`→`ResourceBounded`; `SilentDrop=TRUE`→`Responsive`+`Recovers` (liveness) |
| 3 | Registration + index↔tree coherence | `Register.tla` | §6.1/6.2/6.6 | **DONE** | green (4 safety + liveness, 25 states); negs: `Atomic=FALSE`→`NoPartialResidue`; `GuardSystem=FALSE`→`NoUserAtSystem`; `WedgeReg=TRUE`→`RegisterSettles` (liveness) |
| 4 | Emit pathway | `Emit.tla` | §6.10 | **DONE** | green (3 safety + liveness, 244 states); negs: `Fire=FALSE`→`EventIffRealWork`; `MarkerDeletes=TRUE`→`EventTypeCorrect`; `StallEmit=TRUE`→`EmitTerminates` (liveness) |
| 5 | Revocation + verdict determinism | `Revoke.tla` | §5.1/5.10 | **DONE** | green (2 safety + liveness, 106 states); negs: `HonorRevocation=FALSE`→`RevokedNeverPasses`; `LeakLayer1=TRUE`→`VerdictFnOfLayer1`; `NoConverge=TRUE`→`RevocationConverges` (liveness) |
| 6 | Composed multi-peer | `Core.tla` | § all | **DONE** | green (4 conjoined safety + global liveness, ~206 states; no explosion, Apalache NOT needed); negs: `Serialized=TRUE`→Deadlock (`EventuallyResolved`); `GateEstablished=FALSE`→`DispatchNeedsEstablished`; `GateRevocation=FALSE`→`NoServeWhenRevoked` |

## Increment 1 — Connection lifecycle (DONE)

`Conn.tla`: a responder's per-connection handshake state machine (`new → hello_done →
established`) reacting to a nondeterministic frame stream — the environment / a possibly-
adversarial initiator chooses frame order and nonces. Crypto (signatures/PoP, §4.6 steps
2–3) abstracted; the nonce-echo *check* (§4.6 step 1) modeled as state. `Enforce` CONSTANT
switches the §4-correct responder vs the ordering-bug negative control.

- **Safety (all green, `Enforce=TRUE`):** `TokenBounded` (§4.2 — ≤1 token, no reissue on
  reconnect), `NoEstablishWithoutNonce` (§4.1/4.6 — established ⇒ a nonce was issued, i.e.
  hello ran first), `DispatchedImpliesEstablished` (§4.2 — no non-connect EXECUTE dispatched
  pre-establishment; the 403 pre-auth gate).
- **Liveness (green):** `AllAnswered` (§4.1 — every submitted frame eventually answered;
  the handshake settles / "every EXECUTE receives an EXECUTE_RESPONSE") under weak fairness.
- **Negative control (`Enforce=FALSE`, `ConnBug.cfg`):** drop the §4.6 hello-before-auth
  ordering + issued-nonce bind → TLC reports `NoEstablishWithoutNonce` violated with a trace
  establishing straight from `new` on an authenticate, no hello. The model catches the bug.
- Effort: ~1 hour. TLC: 266 distinct states, sub-second. Run:
  `make tlc SPEC=Conn` (correct) / `make tlc SPEC=Conn CFG=ConnBug` (neg control).

## Increment 2 — Store-safety / resilience / admission (DONE)

`Store.tla`: one peer serving `NReq` concurrent per-request dispatch activities against a
shared content store with an admission gate. Each request (a possibly-adversarial caller)
picks a payload size + chain depth (`ok`/`over` — §4.10 bounds are symbolic; the contract is
"finite declared bound + clean reject," not the 16 MiB/64 numbers), is run through §4.10
admission (413/400/503), then through a single-writer store critical section (§4.8). The
store data-race is modeled as concurrent occupancy of that section (`writers > 1`); the
single-writer discipline is the `await writers = 0` entry guard. Two CONSTANT switches drive
the two negative controls: `Serialize` (§4.8 discipline on/off) and `Admit` (§4.10/4.9b
admission on/off).

- **Safety (all green, correct cfg):** `StoreRaceFree` (§4.8 — ≤1 writer in the store
  critical section; a race is a crash is a §4.9d violation), `ResourceBounded` (§4.9b/§4.10 —
  `pending` ≤ admission bound, store ≤ live-key bound), `CleanReject` (§4.10 — over-limit
  requests get the right coded outcome (413 before 400) and never mutate the store).
- **Liveness (green, weak fairness):** `Responsive` (§4.9a/c — every admitted request
  eventually responds; no deadlock/livelock/silent-drop), `Recovers` (§4.9e — `<>[]`
  `pending=0`: when offered load subsides the in-flight count drains back to idle).
- **Negative control #1 (`Serialize=FALSE`, `StoreRaceBug.cfg`):** drop the single-writer
  guard → TLC reports `StoreRaceFree` violated with a trace driving `writers` to 2 (two
  activities mutating the store at once — the §4.8 data race).
- **Negative control #2 (`Admit=FALSE`, `StoreAdmitBug.cfg`):** drop the admission bound →
  TLC reports `ResourceBounded` violated with `pending` reaching 3 > `MaxPending`=2 (the
  §4.9b unbounded-growth / per-request-leak class). `MaxPending`(2) < `NReq`(3) makes the
  bound load-bearing.
- Effort: ~1 hour. TLC: 4932 distinct states, ~1s. Run:
  `make tlc SPEC=Store` (correct) / `make tlc SPEC=Store CFG=StoreRaceBug` /
  `make tlc SPEC=Store CFG=StoreAdmitBug` (neg controls).

**Scope boundary (5th wall):** single-peer; cross-peer store contention is increment 6 (G).
Store growth is bounded via a single shared key (Spike-A idiom) — live-key *eviction/GC* is
not modeled (the §4.9b leak class is exercised via `pending`, the admission resource). Verdict
and crypto abstracted as in Spike A. Payload/depth limits are symbolic over/under, not bytes.

## Increment 3 — Registration + index↔tree coherence (DONE)

`Register.tla`: two user-installed handlers (one at a domain path, one at a system path) run
the §6.2 `register`→`unregister` lifecycle concurrently while the §6.6 dispatch index (a cache,
`disp`) must stay coherent with the tree (source of truth) at every state. The five normative
§6.2 writes are modeled as five opaque tree facets (manifest/types/grant/sig/iface) — their
content, grant attenuation (Lean), and grant-signature crypto (Tamarin) abstracted; their
*presence/atomicity w.r.t. dispatch* is what's modeled. Two CONSTANT switches: `Atomic` (five
writes atomic vs incremental) and `GuardSystem` (system-path guard on/off).

- **Safety (all green, correct cfg):** `NoPartialResidue` (§6.2 — a handler path is always
  fully present or fully absent; the five-write atomicity), `RegisterAllOrNothing` (§6.2 —
  nothing dispatch-visible is missing its grant+sig; the "manifest without grant → no
  capability ceiling" hazard), `IndexMatchesTree` (§6.6 — `disp` equals the tree-walk result
  at all times: no stale-positive/negative cache), `NoUserAtSystem` (§6.2 — no user handler
  ever present at a system path).
- **Liveness (green, weak fairness):** `RegisterSettles` (§6.2 — every registrar reaches a
  terminal outcome: torn down or guard-rejected; concurrent register-vs-dispatch progresses).
- **Negative control #1 (`Atomic=FALSE`, `RegisterAtomicBug.cfg`):** publish to the dispatch
  index with only manifest+iface written (grant/sig/types land later) → TLC reports
  `NoPartialResidue` (and `RegisterAllOrNothing`/`IndexMatchesTree`) violated: a half-built
  handler is dispatch-visible.
- **Negative control #2 (`GuardSystem=FALSE`, `RegisterSysGuardBug.cfg`):** drop the guard →
  TLC reports `NoUserAtSystem` violated: the user handler installs at a system path.
- Effort: ~1 hour. TLC: 25 distinct states, sub-second. Run: `make tlc SPEC=Register`
  (correct) / `... CFG=RegisterAtomicBug` / `... CFG=RegisterSysGuardBug` (neg controls).

**Scope boundary (5th wall):** single-peer; longest-prefix tree-walk dispatch (§6.6) is
abstracted to the Live/dispatchable predicate (the resolution *algorithm* is not re-walked —
the coherence *invariant* between cache and tree is what's checked). Grant content/attenuation
= Lean; grant-sig crypto = Tamarin. Bootstrap handlers (§6.9) not modeled.

## Increment 4 — Emit pathway (DONE)

`Emit.tla`: the §6.10 emit primitive — an emitter applies a bounded nondeterministic sequence
of `content_store.put` (Store step), `tree_put` (Store+Bind), and `tree:delete` (Bind→null)
operations against a content store + single-path tree binding, recording the event-firing
*decision* each step makes. Entity content/hashing/CBOR abstracted to opaque hash tokens; the
modeled object is the state transition and the event-iff-real-work decision it drives. Two
CONSTANT switches: `Fire` (fire iff real work vs unconditionally) and `MarkerDeletes` (the
v7.74 B2 deletion-marker carve-out on/off).

- **Safety (all green, correct cfg):** `EventIffRealWork` (§6.10 — content-store event iff
  hash new; tree-change event iff binding changed), `NoEventOnNoop` (§6.10 — re-put of an
  existing hash / re-bind to current fires no event), `EventTypeCorrect` (§6.10 + v7.74 B2 —
  event_type = created/modified/deleted derivation, and bind-to-deletion-marker is "modified"
  not "deleted").
- **Liveness (green, trivial):** `EmitTerminates` — emit always completes. Core-only emit has
  NO consumers (§6.10 final para), so there is no cascade/convergence obligation; consumer
  delivery/ordering (SYSTEM-COMPOSITION) is Phase 2.
- **Negative control #1 (`Fire=FALSE`, `EmitFireBug.cfg`):** fire unconditionally → TLC
  reports `EventIffRealWork` (and `NoEventOnNoop`) violated: an event on a no-op re-put/re-bind.
- **Negative control #2 (`MarkerDeletes=TRUE`, `EmitMarkerBug.cfg`):** marker-bind fires
  "deleted" → TLC reports `EventTypeCorrect` violated (the §6.10 v7.74 B2 carve-out has teeth).
- Effort: ~1 hour. TLC: 244 distinct states, sub-second. Run: `make tlc SPEC=Emit` (correct) /
  `... CFG=EmitFireBug` / `... CFG=EmitMarkerBug` (neg controls).

**Scope boundary (5th wall):** core-only (no consumers); single path (multi-path is a trivial
replication of the per-path semantics); bind/store-write *atomicity* is the §4.8 single-writer
property already checked in increment 2 (not re-modeled). Hashing/content = type-system + conformance.

## Increment 5 — Revocation + verdict determinism (DONE)

`Revoke.tla`: two conformant peers evaluate the same capability chain. The chain's structural
validity (§5.5/5.6 — Lean's) is abstracted as the opaque `ChainValid`; what's modeled is the
§5.10 temporal/observation layer around it — `t` as a declared per-verdict input, revocation
as a convergent (async-observed) Layer-1 input, and the Layer-1/Layer-2 separation. Both peers
pinned to the full revocation tier (`supports_revocation=true`). Two CONSTANT switches:
`HonorRevocation` and `LeakLayer1`.

- **Safety (all green, correct cfg):** `RevokedNeverPasses` (§5.1/§6.8 — once a peer observes
  the revocation marker, the cap never produces a passing verdict again), `VerdictFnOfLayer1`
  (§5.10 — the cross-peer determinism MUST: same `t` + same observed-revocation state ⇒
  identical verdict; async divergence on *different* observed state or *different* `t` is
  guarded out as permitted).
- **Liveness (green, weak fairness):** `RevocationConverges` (§5.10 — a written marker is
  eventually observed by every verifier in the tier; revocation is a convergent input).
- **Negative control #1 (`HonorRevocation=FALSE`, `RevokeIgnoreBug.cfg`):** ignore observed
  revocation → TLC reports `RevokedNeverPasses` violated (a revoked cap still passes).
- **Negative control #2 (`LeakLayer1=TRUE`, `RevokeLeakBug.cfg`):** a local banlist (Layer 2)
  modulates the Layer-1 verdict → TLC reports `VerdictFnOfLayer1` violated: two peers with the
  same `t` and same observed revocations disagree (local policy masquerading as protocol — the
  §5.10 leak the proposal forbids).
- Effort: ~1 hour. TLC: 106 distinct states, sub-second. Run: `make tlc SPEC=Revoke` (correct)
  / `... CFG=RevokeIgnoreBug` / `... CFG=RevokeLeakBug` (neg controls).

**Scope boundary (5th wall):** structural chain validity = Lean (`ChainValid` opaque); crypto
= Tamarin. Full revocation tier modeled; the core tier (treats observed set as empty, §5.1) is
noted not modeled (PHASE1-SCOPE §7). Single chain; `t` boundary is two-valued (valid/expired).

## Increment 6 — Composed multi-peer model (DONE)

`Core.tla`: two peers run the core concurrency substrate concurrently and bidirectionally —
connection lifecycle (A), reentrant cross-peer dispatch (B, the Spike-A topology), bounded
store writes (C), and a revocation/verdict gate (F) — so the cross-subsystem interleavings
(revoke-during-reentry, dispatch-before-establishment, symmetric bidirectional reentry) become
reachable. Each subsystem is represented by its minimal composed essence; per-subsystem teeth
live in the standalone increments. One CONSTANT switch: `Serialized` (the §6.11 fix vs defect).

- **Safety (all green, conjoined, correct cfg):** `StoreBounded` (C §4.8/4.9b), `DispatchNeeds
  Established` (A∧B §4.2 — no client dispatch pre-establishment), `ServeNeedsEstablished` (A∧B
  §6.5 — no server dispatch pre-establishment/gate).
- **Liveness (green — the star result):** `EventuallyResolved` (§4.9a/§6.11 — every client's
  reentrant dispatch resolves; the whole composed substrate is deadlock/livelock-free).
- **Negative control (`Serialized=TRUE`, `CoreBug.cfg`):** hold the per-connection mutex across
  send+recv → TLC reports **"Deadlock reached"**: the Class-G bidirectional reentry deadlock
  forms *even under full composition* — the handshake/store/revocation layers did NOT mask it.
- **State explosion (the scope's main risk) did NOT materialize:** 206 distinct states, sub-
  second on TLC. The mitigation (minimal composed essence per subsystem + tight 2-peer bounds)
  kept it small; **Apalache was not needed.** SYMMETRY on `Peers` was available as a further
  lever but unnecessary at this size.
- Effort: ~1 hour. Run: `make tlc SPEC=Core` (correct) / `make tlc SPEC=Core CFG=CoreBug` (neg).

**Scope boundary (5th wall):** the composed model checks the *conjunction* of invariants and
the *cross-subsystem deadlock-freedom*; the standalone per-subsystem teeth (store race, register
atomicity, emit derivation, verdict determinism) are NOT re-proven here — they are increments
2–5. Registration (E) and emit (D) compose by conjunction (local invariants, verified
standalone) and are represented implicitly; the composed model deliberately concentrates on the
A/B/C/F concurrency interleavings where genuine composition risk lives. 2 peers, 1 request each.

**Phase-1 modeling complete (increments 0–6).** Composed `FORMALIZATION-REPORT`:
`PHASE1-FORMALIZATION-REPORT.md`.

## Confidence-hardening pass — closing the "green-but-untoothed" gaps

A critical self-review found that, while every *safety* invariant had a negative control, most
*liveness* properties did not — they were green but never shown falsifiable (a property that
can't fail might be vacuously true). And the composed model's A (establishment) and F
(revocation) layers were *guarded by construction* with no control that made them fail. This
pass closed both, so the method's discipline ("every checked property is demonstrated
falsifiable") now applies uniformly. **18 negative controls total (was 11).**

- **Every liveness property now has a negative control** (each routes to a wrong terminal /
  early halt so the property provably fails, while safety still holds — proving the liveness is
  load-bearing, not vacuous):
  - `Conn` `DropFrame=TRUE` → `AllAnswered` violated (responder stops with frames unanswered).
  - `Store` `SilentDrop=TRUE` → `Responsive` + `Recovers` violated (§4.9c: admit then drop, pending leaked).
  - `Register` `WedgeReg=TRUE` → `RegisterSettles` violated (a live handler never settles).
  - `Emit` `StallEmit=TRUE` → `EmitTerminates` violated (emit halts early).
  - `Revoke` `NoConverge=TRUE` → `RevocationConverges` violated (a peer never observes the marker).
- **`Core`'s A and F layers are now honest** — two new switches + a new invariant give them teeth:
  - `GateEstablished=FALSE` → `DispatchNeedsEstablished` violated (dispatch on a `new` connection).
  - `GateRevocation=FALSE` → new invariant `NoServeWhenRevoked` violated (a handler writes the
    store under a revoked cap — §5.1 revoked-never-passes, mid-operation, now actually checked
    in the composed model rather than decorative).

**Honest gaps that remain (NOT closed — see the report's "remaining gaps"):**
- `Store`'s `ResourceBounded` store-cardinality conjunct is still vacuous (single key `"k"`);
  the *pending* conjunct carries the teeth. Multi-key + eviction is a Phase-2 item.
- `Register`'s positive result is still near-tautological (the five writes are one atomic step
  in the correct model; the control models the non-atomic case). It has teeth but the green
  result largely restates its premise.
- **No independent cross-check** (single encoding, single tool, my transcription) and **no
  conformance-vector tie** beyond the Class-G grounding. These are the #4/#5 items — the only
  ones that meaningfully attack the 5th wall — and are deferred.
- Bounds remain tiny (2 peers, 1–3 requests): bounded checks, not unbounded proofs.
