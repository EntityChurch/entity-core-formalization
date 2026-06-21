# Reentry.tla — model design (Spike A)

**Status:** design fixed; toolchain proven; model authoring next.
**Modeling ground truth:** `../spec-data/v0.8.0/ENTITY-CORE-PROTOCOL.md` (pinned).
**Discipline:** every model element cites the spec clause it transcribes (5th-wall
fidelity, `../docs/ASSURANCE-MAP.md`). The verdict algorithm is **abstracted**, never
re-modeled — Lean owns it.

---

## 1. What we are modeling (and what we are not)

The smallest faithful slice of the **§6.11 Transport Reentry Contract** that can
exhibit the **Class G** deadlock and the **§4.8 / §4.9** store-safety / resilience
properties — no more.

**In scope (transcribed from spec):**

| Spec clause | What it says | Model element |
|---|---|---|
| §6.11 intro | Receive handlers MAY initiate cross-peer EXECUTE back to the peer they're serving (reentry) | A handler action that emits an outbound EXECUTE to the requester |
| §6.11(a) | A pooled connection MUST NOT hold per-connection serialization across the send+recv cycle; concurrent outbound EXECUTEs MUST proceed | The contended resource + the two variants (§4 below) |
| §6.11(b) | Responses routed by `request_id`, tolerating out-of-order replies | `reqId`-keyed pending map; responses match by id, not arrival order |
| §6.11(c) | Per-request deadlines at the request layer, not connection-wide | Per-request `timeout` action that resolves one request without touching others |
| §6.11 teardown (informative) | On teardown, in-flight requests resolved with connection-broken error | `connBroken` action drains pending → clean failure |
| §4.8 | Store + tree index MUST be safe under concurrent dispatch; a data race is a crash | Store as an abstract map; writes serialized by construction; `StoreBounded` invariant |
| §4.9(a) | Stay responsive — no deadlock/livelock, always make progress | `EventuallyResolved` liveness |
| §4.9(b) | Bound resource use — no unbounded growth under load/churn | `StoreBounded` (+ bounded pending/inbox by construction) |
| §4.9(c) | Deliver or signal — never silently drop an admitted request | `NoSilentDrop`: every admitted request ends in `Responded` or `Failed` |
| §6.5 | Dispatch gate runs before a handler is invoked | `Gate(req)` abstract predicate; `NoDispatchWithoutGate` invariant |

**Out of scope (abstracted — stated so the 5th wall never hides):**

- **Cap-chain verdict (§5.2/§5.4/§5.5/§5.6).** An opaque operator `Gate(req) ∈ BOOLEAN`.
  Lean proved the verdict; TLA+ asks only "does the protocol *around* the verdict
  behave." We do **not** model attenuation, signatures, or chain walking.
- **Crypto, bytes, CBOR.** No content hashes, no wire encoding. Identities are atomic
  model values (`{A, B}`).
- **Negotiation, handshake legs (§4.1–§4.6).** Assume an established connection.
- **Extensions** (subscription/continuation/compute). The reentry handler stands in
  for "any handler that originates outbound dispatch" (§6.13(b)).

---

## 2. The Class G deadlock — the bug we want TLC to rediscover

Grounded in the reference-impl fix (entity-core-go `connection.go` "Class G / F-WB28"
comment; `connection_multiplex_test.go::TestConnection_ReentrantCrossPeerDoesNotDeadlock`;
arch `BUG-CLASSES.md` Class G). The deterministic N=2 cycle:

1. A → B: `Execute(reentry)`. A holds the **A↔B pooled connection's send+recv hold**,
   waiting for B's response.
2. B's handler receives it and reenters: calls `Execute` back toward A on the **same
   pooled connection**, in the reverse direction.
3. Symmetrically, B → A and A's handler reenters toward B.
4. Each side blocks on the hold the other side's outbound dispatch is waiting behind
   → **deadlock**. (N≥3 meshes sidestep it via timing skew — a probability mask, not
   a fix; we model N=2 where it is deterministic.)

The fix (§6.11(a)+(b)): a single **reader task** per connection demultiplexes inbound
frames to per-request channels keyed by `request_id`; the write hold spans the *write
only*, never the recv. We model **both** the broken serialized discipline and the
fixed multiplexed discipline, and let the liveness property tell them apart.

---

## 3. State (PlusCal `variables`)

Atomic-value abstraction; small finite bounds for TLC.

```
Peers      == {"A", "B"}                 \* §1.5 identities, atomic
ReqId      == 1..MaxReq                  \* §6.11(b) per-connection id space (bounded)

variables
  \* The pooled connection per ordered pair, and (serialized variant only) its hold.
  hold       = [p \in Pairs |-> NULL],   \* who holds the send+recv lock; NULL = free
  \* §6.11(b) pending-response map: reqId -> awaiting caller state.
  pending    = [p \in Peers |-> {}],     \* outstanding outbound requests per peer
  \* Inbound frame queues (the reader task's input).
  inbox      = [p \in Peers |-> << >>],
  \* Handler activation: is a peer currently inside a reentering handler body?
  handler    = [p \in Peers |-> "idle"], \* idle | serving | reentering
  \* §4.8 store: abstract map; writes bounded by live keys.
  store      = [p \in Peers |-> {}],     \* set of live keys written
  \* Per-request lifecycle for the liveness / no-drop properties.
  reqState   = [r \in AllRequests |-> "new"]  \* new|admitted|responded|failed
```

`Pairs` is the set of ordered peer pairs sharing a pooled connection. `AllRequests`
is a bounded set of (origin, target, reqId) triples.

## 4. The two variants (one model, a CONSTANT switch `Serialized`)

- **`Serialized = TRUE` (the bug, §6.11(a) *violated*).** The `Send` action acquires
  `hold[pair]` and does **not** release it until the matching response is received
  (`recv`). A reentering handler that needs the same pair's hold blocks. This is the
  pre-F-WB28 discipline.
- **`Serialized = FALSE` (the fix, §6.11(a)+(b) honored).** `Send` takes the hold for
  the enqueue step only and releases immediately; a reader action delivers responses
  by `reqId` from `pending`. Reentry never blocks on an outbound in flight.

Running the *same* properties against both variants is the demonstrator: liveness
**fails with a counterexample trace** under `Serialized = TRUE` (TLC rediscovers Class
G) and **holds** under `Serialized = FALSE` (the fix is modeled correct).

## 5. Actions (high level)

`Admit(r)` (gate per §6.5) · `Send(r)` (outbound EXECUTE) · `Deliver` (reader task,
§6.11(b)) · `Serve(r)` (handler runs; MAY `Reenter`) · `Reenter(r)` (handler-initiated
outbound, §6.11 intro) · `Respond(r)` · `Timeout(r)` (§6.11(c), → clean `failed`) ·
`ConnBroken(pair)` (teardown, → drain pending to `failed`).

## 6. Properties

**Safety (invariants):**
- `StoreBounded == \A p : Cardinality(store[p]) <= MaxLiveKeys`
  — surfaces the §4.8/§4.9(b) leak/runaway class.
- `NoDispatchWithoutGate == \A r : handler enters serving(r) => Gate(r)`
  — §6.5: no handler invocation without the gate having held.

**Liveness (temporal, needs fairness):**
- `EventuallyResolved == \A r : reqState[r] = "admitted" ~> reqState[r] \in {"responded","failed"}`
  — §4.9(a): every admitted request reaches a response or a *clean* failure; no
  deadlock, no livelock. **This is the property nothing else proves.**
- `NoSilentDrop` (safety form of §4.9(c)): the model has **no** transition that moves
  a request out of `admitted` to anything but `responded`/`failed` — checked
  structurally + as the `[]` companion to the liveness above.

**Fairness:** weak fairness on `Deliver`, `Serve`, `Respond`, `Timeout` (the reader
task and the request-layer deadline are always-eventually-enabled). Without it,
`EventuallyResolved` is vacuously violable by stuttering; with it, a *real* deadlock
(no enabled successor) still violates it — which is exactly the Class G signature.

## 7. TLC bounds (Reentry.cfg)

`MaxReq = 2`, `MaxLiveKeys = 2`, `Peers = {A,B}`, both reentry directions enabled.
Start small enough to be push-button; raise only if green and we want confidence.
`-deadlock` checking ON for the serialized variant (a true deadlock = no successor
state is the cleanest possible Class-G witness; TLC reports it directly).

## 8. Success criteria (maps to the §-gate in README §"Go/no-go gate")

1. `Serialized = FALSE`: all invariants green + `EventuallyResolved` holds at the 2-peer
   bound. ✔ = the fixed design is modeled correct.
2. `Serialized = TRUE`: TLC produces a **counterexample / deadlock trace** matching the
   Class G cycle (§2). ✔ = "the model finds the bug we found by hand" — the killer result.
3. Honest report of modeling pain (hours/days) and the model–code gap at this altitude.

## 9. Open design questions (resolve while authoring)

- Model the hold as a genuine blocking lock (TLC `-deadlock` catches it as a stuck
  state) **or** as a liveness violation only? Plan: do both — blocking lock first
  (sharpest witness), then confirm the liveness property also flags it.
- Is `MaxReq = 2` enough to force the symmetric cycle, or do we need a distinct id per
  direction? Expect 2 suffices (one outbound + one reentry per peer); confirm in TLC.
- Does `NoSilentDrop` need to be a state-action constraint (`[Next]_vars` refinement)
  rather than a plain invariant? Likely yes for the "never drops" phrasing.
