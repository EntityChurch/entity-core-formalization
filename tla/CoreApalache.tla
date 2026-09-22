---- MODULE CoreApalache ----
\* NEW at 0.8.2 — Apalache (SMT) cross-check of the COMPOSED model (tla/Core.tla).
\*
\* THIS IS THE ITEM DEFERRED SINCE PHASE 1. It was carried as "the composed whole-protocol
\* inductive invariant — lowest value, consciously deferred", on the rationale that the
\* deadlock it would corroborate is already reproduced by Spin and each invariant is already
\* proven separately in its own module. The 0.8.2 audit re-examined that rationale and it does
\* not hold up:
\*
\*   1. "Each invariant is proven separately" is precisely what a COMPOSITION invariant is NOT.
\*      Proving ResourceBounded inductive in Store and DispatchNeedsEstablished inductive in Conn
\*      says nothing about whether they hold TOGETHER in a system that does both at once. The
\*      conjunction is the claim; proving the conjuncts elsewhere is not proving it.
\*   2. "The deadlock it would corroborate" was never the point — deadlock is LIVENESS, which
\*      Apalache cannot do at all. The safety conjunction is a different and unproven claim.
\*   3. Core was, until this audit, the module with the WEAKEST tool coverage in the repo
\*      (TLC only) despite being the one whose whole purpose is cross-subsystem interaction.
\*
\* So it is done. What it proves: the four composed safety invariants hold TOGETHER in every
\* reachable state of the composition, for executions of any length — not just at the bound
\* TLC enumerates.
\*
\* WHAT IT STILL DOES NOT PROVE, stated plainly: the Class-G deadlock property
\* (EventuallyResolved) is liveness and stays TLC + Spin at the bound. Apalache does safety
\* and induction by construction. That is a tool limit and it is why this port is a
\* completion of the safety story, not of the whole module.
\*
\* THE ABSTRACTION (D11): a typed hand-port of Core's data layer, same shape as the other
\* *Apalache ports — PlusCal pc/control abstracted into explicit lifecycle fields. Each
\* subsystem is its minimal composed essence, exactly as in Core.tla: the handshake is the
\* established-precondition, the verdict is the opaque not-revoked gate, the store write is a
\* bounded key set.
EXTENDS Integers, FiniteSets

CONSTANTS
  \* @type: Bool;
  Serialized,
  \* @type: Bool;
  AtomicFrame,
  \* @type: Bool;
  GateEstablished,
  \* @type: Bool;
  GateRevocation

Peers == {"A", "B"}
\* @type: Str => Str;
Other(p) == IF p = "A" THEN "B" ELSE "A"

VARIABLES
  \* @type: Str -> Str;
  conn,          \* §4: "new" | "established"
  \* @type: Str -> Str;
  mtx,           \* §6.11(a)/(a') per-connection write lock: "free" | "client" | "server"
  \* @type: Str -> Set(Str);
  midframe,      \* §6.11(a') partially-written-frame holders
  \* @type: Bool;
  interleaved,   \* §6.11(a') latched violation flag
  \* @type: Str -> Bool;
  inReq,
  \* @type: Str -> Bool;
  resp,
  \* @type: Str -> Set(Str);
  store,         \* §4.8 content store (no bound asserted here — see below)
  \* @type: Str -> Str;
  cstate,        \* "init" | "midframe" | "sent" | "done"
  \* @type: Str -> Str;
  sstate,        \* "idle" | "serving" | "midframe" | "done"
  \* @type: Bool;
  revoked,       \* §5.1 revocation marker
  \* @type: Set(Str);
  servedRevoked  \* ghost: peers whose handler wrote under a revoked cap

vars == << conn, mtx, midframe, interleaved, inReq, resp, store, cstate, sstate,
           revoked, servedRevoked >>

CPhases == {"init", "midframe", "sent", "done"}
SPhases == {"idle", "serving", "midframe", "done"}
Locks   == {"free", "client", "server"}

\* @type: Str => Bool;
Honored(p) == ~revoked

\* ----- the four composed safety invariants (transcribed from Core.tla) -----
\* WAS FIVE. `StoreBounded` (Cardinality(store[p]) <= MaxKeys, MaxKeys == 1) was dropped from
\* Core.tla as VACUOUS — each peer's server writes one literal key once, so the conjunct was
\* true by construction and could not fail. Carrying it here made the composed conjunction
\* look one term stronger than it was. The real §4.8/§4.9(b) bound is StoreApalache's
\* `InvBound`/`InvUAF` (multi-key, refcount-discharged). See Core.tla's note for why it is a
\* structural exclusion rather than something to give teeth here.
DispatchNeedsEstablished ==
  \A p \in Peers : (cstate[p] \in {"sent", "done"}) => (conn[p] = "established")
ServeNeedsEstablished ==
  \A p \in Peers : (sstate[p] # "idle") => (conn[p] = "established")
NoServeWhenRevoked == servedRevoked = {}
FramesNotInterleaved == ~interleaved

\* THE COMPOSITION CLAIM: all four at once. This is the conjunction that was never proved
\* until the 0.8.2 audit — and it is four real conjuncts rather than four plus a tautology.
ComposedSafety ==
  /\ DispatchNeedsEstablished
  /\ ServeNeedsEstablished
  /\ NoServeWhenRevoked
  /\ FramesNotInterleaved

\* ----- the inductive strengthening -----
\* Same frame argument as ReentryApalache (per-frame lock => at most one writer mid-frame,
\* and the lock names which), plus the composition-specific facts: a peer mid-frame on the
\* client side has already dispatched, and the store only ever holds the single modeled key.
FrameSound ==
  /\ \A p \in Peers : Cardinality(midframe[p]) <= 1
  /\ \A p \in Peers : (cstate[p] = "midframe") <=> ("client" \in midframe[p])
  /\ \A p \in Peers : (sstate[p] = "midframe") <=> ("server" \in midframe[p])
  /\ \A p \in Peers : \A w \in midframe[p] : mtx[p] = w

\* The establishment gate is monotone: conn never leaves "established", and any peer that has
\* begun a client frame or entered a handler did so after establishment.
EstabSound ==
  /\ \A p \in Peers : (cstate[p] # "init") => (GateEstablished => conn[p] = "established")
  /\ \A p \in Peers : (sstate[p] # "idle") => (GateEstablished => conn[p] = "established")

TypeOK ==
  /\ interleaved \in BOOLEAN
  /\ revoked \in BOOLEAN
  /\ conn     \in [Peers -> {"new", "established"}]
  /\ mtx      \in [Peers -> Locks]
  /\ midframe \in [Peers -> SUBSET {"client", "server"}]
  /\ inReq    \in [Peers -> BOOLEAN]
  /\ resp     \in [Peers -> BOOLEAN]
  /\ store    \in [Peers -> SUBSET {"k"}]
  /\ cstate   \in [Peers -> CPhases]
  /\ sstate   \in [Peers -> SPhases]
  /\ servedRevoked \in SUBSET Peers

InvComposed == TypeOK /\ FrameSound /\ EstabSound /\ ComposedSafety

\* ----- transitions (data layer of Core.tla) -----
Init ==
  /\ conn        = [p \in Peers |-> "new"]
  /\ mtx         = [p \in Peers |-> "free"]
  /\ midframe    = [p \in Peers |-> {}]
  /\ interleaved = FALSE
  /\ inReq       = [p \in Peers |-> FALSE]
  /\ resp        = [p \in Peers |-> FALSE]
  /\ store       = [p \in Peers |-> {}]
  /\ cstate      = [p \in Peers |-> "init"]
  /\ sstate      = [p \in Peers |-> "idle"]
  /\ revoked     = FALSE
  /\ servedRevoked = {}

\* §4: the handshake completes.
Estab(p) ==
  /\ conn[p] = "new"
  /\ conn' = [conn EXCEPT ![p] = "established"]
  /\ UNCHANGED << mtx, midframe, interleaved, inReq, resp, store, cstate, sstate,
                  revoked, servedRevoked >>

\* §5.1: a revocation may occur concurrently with in-flight dispatch.
Revoke ==
  /\ ~revoked
  /\ revoked' = TRUE
  /\ UNCHANGED << conn, mtx, midframe, interleaved, inReq, resp, store, cstate, sstate,
                  servedRevoked >>

\* B §6.11(a′) request frame, chunk 1 — gated on establishment (§4.2).
CFrame1(p) ==
  /\ cstate[p] = "init"
  /\ (GateEstablished => conn[p] = "established")
  /\ (AtomicFrame => mtx[p] = "free")
  /\ interleaved' = (interleaved \/ midframe[p] # {})
  /\ midframe' = [midframe EXCEPT ![p] = @ \cup {"client"}]
  /\ mtx' = [mtx EXCEPT ![p] = IF AtomicFrame THEN "client" ELSE "free"]
  /\ cstate' = [cstate EXCEPT ![p] = "midframe"]
  /\ UNCHANGED << conn, inReq, resp, store, sstate, revoked, servedRevoked >>

CFrame2(p) ==
  /\ cstate[p] = "midframe"
  /\ interleaved' = (interleaved \/ midframe[p] # {"client"})
  /\ midframe' = [midframe EXCEPT ![p] = @ \ {"client"}]
  /\ inReq' = [inReq EXCEPT ![Other(p)] = TRUE]
  /\ cstate' = [cstate EXCEPT ![p] = "sent"]
  /\ mtx' = [mtx EXCEPT ![p] = IF Serialized THEN "client" ELSE "free"]
  /\ UNCHANGED << conn, resp, store, sstate, revoked, servedRevoked >>

\* Release only a lock we hold (see tla/Reentry.tla — the defect this audit found).
CRecv(p) ==
  /\ cstate[p] = "sent"
  /\ resp[p]
  /\ mtx' = [mtx EXCEPT ![p] = IF mtx[p] = "client" THEN "free" ELSE mtx[p]]
  /\ cstate' = [cstate EXCEPT ![p] = "done"]
  /\ UNCHANGED << conn, midframe, interleaved, inReq, resp, store, sstate,
                  revoked, servedRevoked >>

\* §6.5 gate: handler entry after establishment.
SGate(p) ==
  /\ sstate[p] = "idle"
  /\ inReq[p]
  /\ (GateEstablished => conn[p] = "established")
  /\ sstate' = [sstate EXCEPT ![p] = "serving"]
  /\ UNCHANGED << conn, mtx, midframe, interleaved, inReq, resp, store,
                  cstate, revoked, servedRevoked >>

\* Response frame chunk 1: the §5.1/§6.5 verdict gate and the §4.8 store write are ONE atomic
\* step — see the note in Core.tla; splitting them would model a peer that re-samples the
\* verdict mid-operation, which no clause requires.
SFrame1(p) ==
  /\ sstate[p] = "serving"
  /\ (AtomicFrame => mtx[p] = "free")
  /\ interleaved' = (interleaved \/ midframe[p] # {})
  /\ midframe' = [midframe EXCEPT ![p] = @ \cup {"server"}]
  /\ mtx' = [mtx EXCEPT ![p] = IF AtomicFrame THEN "server" ELSE "free"]
  /\ sstate' = [sstate EXCEPT ![p] = "midframe"]
  /\ IF Honored(p) \/ ~GateRevocation
       THEN /\ store' = [store EXCEPT ![p] = @ \cup {"k"}]
            /\ servedRevoked' = IF revoked THEN servedRevoked \cup {p} ELSE servedRevoked
       ELSE /\ store' = store
            /\ servedRevoked' = servedRevoked
  /\ UNCHANGED << conn, inReq, resp, cstate, revoked >>

SFrame2(p) ==
  /\ sstate[p] = "midframe"
  /\ interleaved' = (interleaved \/ midframe[p] # {"server"})
  /\ midframe' = [midframe EXCEPT ![p] = @ \ {"server"}]
  /\ resp' = [resp EXCEPT ![Other(p)] = TRUE]
  /\ sstate' = [sstate EXCEPT ![p] = "done"]
  /\ mtx' = [mtx EXCEPT ![p] = "free"]
  /\ UNCHANGED << conn, inReq, store, cstate, revoked, servedRevoked >>

Next ==
  \/ Revoke
  \/ \E p \in Peers : (Estab(p) \/ CFrame1(p) \/ CFrame2(p) \/ CRecv(p)
                       \/ SGate(p) \/ SFrame1(p) \/ SFrame2(p))
  \/ UNCHANGED vars

IndInitComposed == TypeOK /\ FrameSound /\ EstabSound /\ ComposedSafety

\* ----- constant inits -----
ConstInitOK == Serialized = FALSE /\ AtomicFrame = TRUE
               /\ GateEstablished = TRUE /\ GateRevocation = TRUE
ConstInitBugFrame == Serialized = FALSE /\ AtomicFrame = FALSE
               /\ GateEstablished = TRUE /\ GateRevocation = TRUE
ConstInitBugEstab == Serialized = FALSE /\ AtomicFrame = TRUE
               /\ GateEstablished = FALSE /\ GateRevocation = TRUE
ConstInitBugRevoke == Serialized = FALSE /\ AtomicFrame = TRUE
               /\ GateEstablished = TRUE /\ GateRevocation = FALSE
====
