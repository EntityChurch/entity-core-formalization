---- MODULE Core ----
\* Phase 1 — increment 6: Composed multi-peer model (V7 § all concurrency surface), per
\* PHASE1-SCOPE.md subsystem G. Two peers run the core concurrency substrate CONCURRENTLY and
\* bidirectionally: connection lifecycle (A, §4.1-4.7), reentrant cross-peer dispatch (B,
\* §6.5/6.11), bounded store writes from handlers (C, §4.8/4.9), and a revocation/verdict gate
\* (F, §5.10/§6.5). This is where the cross-subsystem interleavings live — revoke during
\* reentry, dispatch before establishment, symmetric bidirectional reentry — that no standalone
\* module can exhibit. The model checks the CONJUNCTION of the subsystem invariants plus global
\* liveness, and re-checks that the canonical Class-G reentry deadlock is still caught under
\* full composition.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): each subsystem is represented by its minimal
\* composed essence — the handshake is the established-precondition (A); the verdict is the
\* opaque Honored gate (F, abstracting Lean's chain verdict + revocation observation, whose
\* standalone teeth are increments 1 and 5); the store write is a bounded key-set mutation (C,
\* whose race-freedom teeth are increment 2). The composed NEGATIVE CONTROL is the §6.11
\* serialization defect (Serialized=TRUE) — the cross-subsystem deadlock; per-subsystem teeth
\* live in the standalone increments. Every element cites its V7 §ref.
\*
\* 0.8.2 RE-TARGET (spec-data/v0.8.2/). Every §-citation in this module resolves unchanged
\* against the 0.8.2 snapshot (no section was added, removed or renumbered — see
\* docs/SPEC-DRIFT-ASSESSMENT.md), so the composition itself is unaffected by the version move.
\*
\* §6.11(a′) FRAME-WRITE ATOMICITY IS CARRIED HERE TOO, under composition. An earlier revision
\* of this header argued it should not be — that carrying it would "duplicate Reentry without
\* producing an interleaving Reentry cannot already exhibit." That was an EMPIRICAL claim
\* asserted rather than checked, and it does not survive: Reentry has no revocation and no
\* connection lifecycle, so it structurally cannot exhibit a frame-write window that overlaps
\* a revocation or a pre-establishment dispatch. Whether those overlaps matter is a question
\* for the model, not for a scoping paragraph. It is now modeled and the answer is recorded in
\* docs/COVERAGE-MATRIX.md rather than assumed here.
\*
\* What the composition adds over Reentry for §6.11(a′): the response frame's two chunks
\* straddle a step boundary at which the revoker and the peer's own client can both move, so
\* the (a′) property is checked against interleavings involving §5.1 revocation and §4.2
\* establishment. The verdict check and the store write stay in ONE atomic step (SFrame1) —
\* that is deliberate and load-bearing, see the note at SFrame1.
\*
\* THE RESULT, stated as measured rather than as predicted. Carrying (a′) here produced NO NEW
\* VIOLATION PATH: every invariant keeps the same verdict it has standalone, and the
\* CoreFrameBug counterexample, inspected, is the same client-vs-own-server frame race
\* Reentry exhibits. A revocation appears in that trace only because TLC scheduled the revoker
\* first; it is not causally required. So the composed (a′) result is a CORROBORATION, not a
\* new defect class.
\*
\* That is a weaker outcome than "this found something" and a stronger one than the scoping
\* paragraph it replaced. The paragraph asserted this conclusion in advance as a reason not to
\* do the work; the difference is that the conclusion is now a measurement. It also closes a
\* real structural gap: without it, the composed whole-protocol model was not a faithful
\* composition of §6.11 as it stands at 0.8.2, and "the composed model omits a sub-clause of
\* the very section it composes" is not a defensible thing for this module to have been.
\*
\* Still owned elsewhere and deliberately NOT re-modeled here: §4.8's refcount use-after-free
\* (tla/Store.tla — it is a property of the store's lifetime bookkeeping, and this module
\* abstracts the store to a bounded key set) and §5.2's three-valued dispatch authority
\* (tla/Authority.tla — this module's `Honored` gate is the opaque composed verdict, which is
\* what lets the revocation interleaving be the subject). Both exclusions are structural, not
\* discretionary: neither property is expressible against this module's abstractions.
\*
\* T4 — THE COMPOSITION IS NOW CHECKED, AND THE ANSWER IS MOSTLY NO. See the §T4 block at the
\* end of this file, and tla/RefMap.tla. Until 2026-09-06 this module and the component
\* modules were checked independently with nothing relating them, which is what ledger row T4
\* recorded. They are now related by an explicit mapping, and the measured result is that
\* `Core` carries ONE of the six component invariants of Conn and Store; the other five are
\* manufactured by any mapping that types them, because Core has no state for them to be
\* about. Read §T4 before reading "the composed model is checked" as "the composition is
\* verified" — blocking exactly that inference is why T4 was recorded, and it is now a
\* measurement instead of a flag.
EXTENDS Naturals, FiniteSets, RefMap

CONSTANTS Serialized,     \* FALSE = §6.11 fix (reader-demux: mutex spans the write only);
                          \* TRUE  = negative control: hold the per-connection mutex across send+recv
                          \*         (the Class-G deadlock surface) — must deadlock even when composed.
          AtomicFrame,    \* TRUE  = §6.11(a′): the per-connection write lock is held for the
                          \*         duration of ONE FRAME's bytes, so frames serialize at the
                          \*         byte level while dispatch stays concurrent.
                          \* FALSE = negative control: a yielding write primitive — another
                          \*         writer can begin a frame between this frame's chunks.
          GateEstablished,\* TRUE = A §4.2: client + server gate on established; FALSE = negative
                          \*        control: dispatch before establishment -> *NeedsEstablished fail.
          GateRevocation  \* TRUE = F §5.1/§6.5: handler write gated on the verdict (not revoked);
                          \*        FALSE = negative control: serve a revoked cap -> NoServeWhenRevoked fails.

CONSTANT N  \* NUMBER OF PEERS — was hard-wired to 2. See Reentry.tla §THE PEER BOUND for
            \* what `Other(p)` was actually asserting, and why it was not merely a low bound.

Peers    == 1..N
\* Directed-ring dispatch topology, identical to Reentry.tla: p's client dispatches to Succ(p),
\* so p's server answers Pred(p). The old `Other` collapsed those two roles into one peer,
\* which is sound iff N = 2.
Succ(p)  == IF p = N THEN 1 ELSE p + 1
Pred(p)  == IF p = 1 THEN N ELSE p - 1
\* Server ids are integers disjoint from Peers, not strings: the PlusCal translation emits
\* `CASE self \in Peers -> ... [] self \in Servers -> ...` over the combined ProcSet, and TLC
\* will not evaluate a non-integer against the interval 1..N.
Servers  == (N+1)..(2*N)
Pof(s)   == s - N                           \* server-id -> the peer it serves
\* Link ids: a third integer band, disjoint from Peers (1..N) and Servers (N+1..2N), for the
\* same reason Servers is — ProcSet mixes all three and TLC will not test a string against
\* the interval 1..N.
Links    == (2*N+1)..(3*N)                  \* distinct ids for the establishment activities
Lof(l)   == l - 2*N                         \* link-id -> the peer it establishes
Revoker  == 3*N+1                           \* the single §5.1 revocation-writer activity

(*--algorithm core
variables
  conn    = [p \in Peers |-> "new"],     \* A §4: per-connection phase (new -> established)
  mtx     = [p \in Peers |-> "free"],    \* B §6.11(a): per-connection write mutex (the contended resource)
  inReq   = [p \in Peers |-> FALSE],     \* B: an inbound request awaits p's server
  resp    = [p \in Peers |-> FALSE],     \* B §6.11(b): a response routed back to p's client
  store   = [p \in Peers |-> {}],        \* C §4.8: content store written by handlers — the
                                         \* observable the §5.1/§6.5 gate protects. The §4.9(b)
                                         \* BOUND is Store.tla's; see the note below.
  cstate  = [p \in Peers |-> "init"],    \* B client lifecycle: init | sent | done
  sstate  = [p \in Peers |-> "idle"],    \* B server lifecycle: idle | serving | done
  revoked = FALSE,                       \* F §5.1: a revocation marker (consulted by the gate)
  servedRevoked = {},                    \* F ghost: peers whose handler wrote under a revoked cap
  \* B §6.11(a′): who holds a PARTIALLY WRITTEN frame on peer p's pooled connection. A frame
  \* is two chunks; a writer is in this set between its first and last chunk.
  midframe = [p \in Peers |-> {}],
  \* B §6.11(a′) violation flag, latched — the corruption is not undone by finishing the frame.
  interleaved = FALSE;

\* §4.8/§4.9(b) STORE BOUND — DELIBERATELY NOT ASSERTED HERE. Owned by tla/Store.tla, and
\* now a THIRD structural exclusion beside the two named in the header (§4.8's refcount
\* use-after-free and §5.2's three-valued dispatch authority).
\*
\* This module used to carry `StoreBounded == \A p \in Peers : Cardinality(store[p]) <=
\* MaxKeys` with MaxKeys == 1. It was VACUOUS: each peer's server writes the single literal
\* key "k" once, so the cardinality is 0 or 1 against a bound of 1 and no behaviour of this
\* model could violate it. A conjunct that cannot fail reports the same green as one that
\* holds — and it was carried INTO `CoreApalache.ComposedSafety`, so the composed
\* whole-protocol conjunction included a term that was true by construction.
\*
\* REMOVED rather than given teeth: the bound only has content under repeated dispatch or
\* multi-key writes, and this model's servers serve once. Making it falsifiable would mean
\* importing Store.tla's multi-key/refcount machinery into the largest model in the repo —
\* duplicating an owner, not adding assurance. Store.tla's `ResourceBounded` is the real
\* §4.8/§4.9(b) obligation: multi-key, falsifiable, discharged by refcount correctness.
\*
\* The `store` variable stays — the handler's write is the observable NoServeWhenRevoked is
\* about ("no store write under a cap observed revoked"). Only the bound is gone.

define
  \* §6.5/§5.10 verdict gate (abstracted): a request is honored iff the cap is not revoked. The
  \* structural verdict is Lean's; revocation observation/convergence is increment 5's — here it
  \* is one global flag the dispatch gate consults, exposing the revoke-during-reentry interleaving.
  Honored(p) == ~revoked

  \* A∧B §4.2: a client never dispatches before its connection is established (the 403 pre-auth gate,
  \* composed with reentrant dispatch).
  DispatchNeedsEstablished ==
    \A p \in Peers : (cstate[p] \in {"sent", "done"}) => (conn[p] = "established")

  \* A∧B §6.5: a server never enters handler dispatch before establishment + gate.
  ServeNeedsEstablished ==
    \A s \in Servers : (sstate[Pof(s)] # "idle") => (conn[Pof(s)] = "established")

  \* F §5.1/§6.8: no handler ever performs a store write under a cap it has observed revoked
  \* (the revocation gate composed into dispatch; revoked-never-passes, mid-operation).
  NoServeWhenRevoked == servedRevoked = {}

  \* B §6.11(a′): the bytes of two distinct frames never interleave on a shared/pooled
  \* connection — now checked against interleavings that also involve §5.1 revocation and
  \* §4.2 establishment, which the standalone Reentry module cannot produce.
  FramesNotInterleaved == ~interleaved
end define;

\* A §4: the connection handshake completes (abstracted) — the precondition for any dispatch.
fair process link \in Links
begin
  Estab:
    conn[Lof(self)] := "established";
end process;

\* B client: once established, originate a reentrant cross-peer EXECUTE to Succ(self) and await
\* the response. The §6.11 fix releases the write mutex after the WRITE (recv is demuxed by
\* request_id); the Serialized defect holds it across recv — the deadlock surface.
fair process client \in Peers
begin
  CEst:
    if GateEstablished then
      await conn[self] = "established";     \* A §4.2: no dispatch pre-establishment
    end if;
  CFrame1:
    \* B §6.11(a′): first chunk of the request frame. Under (a′) this takes the per-connection
    \* write lock, which is what stops another writer's bytes getting in between.
    if AtomicFrame then
      await mtx[self] = "free";
    end if;
    if midframe[self] # {} then
      interleaved := TRUE;                                   \* began a frame mid-frame
    end if;
    midframe[self] := midframe[self] \cup {"client"} ||
    mtx[self]      := IF AtomicFrame THEN "client" ELSE "free";
  CFrame2:
    \* Last chunk of the same frame; then deliver. END OF FRAME is where the (a′)-conformant
    \* hold ends — "never across the await". The Serialized defect keeps holding it (§6.11(a)).
    if midframe[self] # {"client"} then
      interleaved := TRUE;                                   \* another writer's chunk landed between ours
    end if;
    midframe[self] := midframe[self] \ {"client"} ||
    inReq[Succ(self)] := TRUE ||
    cstate[self] := "sent" ||
    mtx[self] := IF Serialized THEN "client" ELSE "free";     \* B §6.11(a)
  CRecv:
    await resp[self];                       \* B §6.11(b): demuxed response
    \* RELEASE ONLY A LOCK WE HOLD — see the same note in tla/Reentry.tla. Under the fix the
    \* client released at end-of-frame, so the lock may belong to this peer's own server
    \* mid-frame; an unconditional release would free another writer's lock.
    if mtx[self] = "client" then
      mtx[self] := "free";
    end if;
    cstate[self] := "done";
end process;

\* B server: serve the inbound request — the handler reenters to write the response, which needs
\* the connection write mutex (§6.11). Composes A (established gate), F (verdict/revocation gate),
\* and C (bounded store write). In the Serialized defect this blocks on the mutex the peer's own
\* client holds across recv — the Class-G deadlock, now under full composition.
fair process server \in Servers
begin
  SWait:
    await inReq[Pof(self)];
  SGate:
    if GateEstablished then
      await conn[Pof(self)] = "established"; \* A + §6.5 gate precondition
    end if;
    sstate[Pof(self)] := "serving";
  SFrame1:
    \* B §6.11 reentry: the handler writes the response frame on the SAME pooled connection.
    \* Under the Serialized defect the peer's own client holds the lock across its recv, so
    \* this guard never enables — the Class-G deadlock, under full composition.
    await mtx[Pof(self)] = "free";           \* B §6.11 reentry write lock (deadlock point if Serialized)
    if midframe[Pof(self)] # {} then
      interleaved := TRUE;
    end if;
    \* F §6.5/§5.10 VERDICT GATE AND C §4.8 STORE WRITE STAY IN ONE ATOMIC STEP.
    \* This is load-bearing, not incidental. §5.2 completes verify_request (including the
    \* step-4 revocation check) BEFORE dispatch, and §5.10 samples the verdict once per
    \* verdict — so a revocation landing after the gate does not retroactively invalidate an
    \* in-flight handler. That permitted window is exactly what §5.10's declared
    \* `revocation_propagation_bound` bounds, and it is modeled in tla/Revoke.tla. Splitting
    \* the gate from the write here would model a peer that RE-SAMPLES the verdict
    \* mid-operation, which no clause requires and which would make NoServeWhenRevoked fail
    \* in the GREEN config for a reason the spec does not call a defect.
    if Honored(Pof(self)) \/ ~GateRevocation then   \* F §6.5/§5.10 verdict gate
      store[Pof(self)] := store[Pof(self)] \cup {"k"} ||     \* C §4.8 bounded store write
      midframe[Pof(self)] := midframe[Pof(self)] \cup {"server"} ||
      mtx[Pof(self)] := IF AtomicFrame THEN "server" ELSE "free" ||
      \* only reachable when GateRevocation=FALSE: wrote under a revoked cap (§5.1 violation)
      servedRevoked := IF revoked THEN servedRevoked \cup {Pof(self)} ELSE servedRevoked;
    else
      midframe[Pof(self)] := midframe[Pof(self)] \cup {"server"} ||
      mtx[Pof(self)] := IF AtomicFrame THEN "server" ELSE "free";
    end if;
  SFrame2:
    \* Last chunk of the response frame; then deliver and release. §4.9(c) deliver-or-signal:
    \* respond either way, honored or not.
    if midframe[Pof(self)] # {"server"} then
      interleaved := TRUE;
    end if;
    midframe[Pof(self)] := midframe[Pof(self)] \ {"server"} ||
    resp[Pred(Pof(self))] := TRUE ||
    sstate[Pof(self)] := "done" ||
    mtx[Pof(self)] := "free";
end process;

\* F §5.1: a revocation may (or may not) occur concurrently with in-flight dispatch.
fair process revoker = Revoker
begin
  RWrite:
    either revoked := TRUE; or skip; end either;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "73ec9b71" /\ chksum(tla) = "dcdc9f6d")
VARIABLES pc, conn, mtx, inReq, resp, store, cstate, sstate, revoked, 
          servedRevoked, midframe, interleaved

(* define statement *)
Honored(p) == ~revoked



DispatchNeedsEstablished ==
  \A p \in Peers : (cstate[p] \in {"sent", "done"}) => (conn[p] = "established")


ServeNeedsEstablished ==
  \A s \in Servers : (sstate[Pof(s)] # "idle") => (conn[Pof(s)] = "established")



NoServeWhenRevoked == servedRevoked = {}




FramesNotInterleaved == ~interleaved


vars == << pc, conn, mtx, inReq, resp, store, cstate, sstate, revoked, 
           servedRevoked, midframe, interleaved >>

ProcSet == (Links) \cup (Peers) \cup (Servers) \cup {Revoker}

Init == (* Global variables *)
        /\ conn = [p \in Peers |-> "new"]
        /\ mtx = [p \in Peers |-> "free"]
        /\ inReq = [p \in Peers |-> FALSE]
        /\ resp = [p \in Peers |-> FALSE]
        /\ store = [p \in Peers |-> {}]
        /\ cstate = [p \in Peers |-> "init"]
        /\ sstate = [p \in Peers |-> "idle"]
        /\ revoked = FALSE
        /\ servedRevoked = {}
        /\ midframe = [p \in Peers |-> {}]
        /\ interleaved = FALSE
        /\ pc = [self \in ProcSet |-> CASE self \in Links -> "Estab"
                                        [] self \in Peers -> "CEst"
                                        [] self \in Servers -> "SWait"
                                        [] self = Revoker -> "RWrite"]

Estab(self) == /\ pc[self] = "Estab"
               /\ conn' = [conn EXCEPT ![Lof(self)] = "established"]
               /\ pc' = [pc EXCEPT ![self] = "Done"]
               /\ UNCHANGED << mtx, inReq, resp, store, cstate, sstate, 
                               revoked, servedRevoked, midframe, interleaved >>

link(self) == Estab(self)

CEst(self) == /\ pc[self] = "CEst"
              /\ IF GateEstablished
                    THEN /\ conn[self] = "established"
                    ELSE /\ TRUE
              /\ pc' = [pc EXCEPT ![self] = "CFrame1"]
              /\ UNCHANGED << conn, mtx, inReq, resp, store, cstate, sstate, 
                              revoked, servedRevoked, midframe, interleaved >>

CFrame1(self) == /\ pc[self] = "CFrame1"
                 /\ IF AtomicFrame
                       THEN /\ mtx[self] = "free"
                       ELSE /\ TRUE
                 /\ IF midframe[self] # {}
                       THEN /\ interleaved' = TRUE
                       ELSE /\ TRUE
                            /\ UNCHANGED interleaved
                 /\ /\ midframe' = [midframe EXCEPT ![self] = midframe[self] \cup {"client"}]
                    /\ mtx' = [mtx EXCEPT ![self] = IF AtomicFrame THEN "client" ELSE "free"]
                 /\ pc' = [pc EXCEPT ![self] = "CFrame2"]
                 /\ UNCHANGED << conn, inReq, resp, store, cstate, sstate, 
                                 revoked, servedRevoked >>

CFrame2(self) == /\ pc[self] = "CFrame2"
                 /\ IF midframe[self] # {"client"}
                       THEN /\ interleaved' = TRUE
                       ELSE /\ TRUE
                            /\ UNCHANGED interleaved
                 /\ /\ cstate' = [cstate EXCEPT ![self] = "sent"]
                    /\ inReq' = [inReq EXCEPT ![Succ(self)] = TRUE]
                    /\ midframe' = [midframe EXCEPT ![self] = midframe[self] \ {"client"}]
                    /\ mtx' = [mtx EXCEPT ![self] = IF Serialized THEN "client" ELSE "free"]
                 /\ pc' = [pc EXCEPT ![self] = "CRecv"]
                 /\ UNCHANGED << conn, resp, store, sstate, revoked, 
                                 servedRevoked >>

CRecv(self) == /\ pc[self] = "CRecv"
               /\ resp[self]
               /\ IF mtx[self] = "client"
                     THEN /\ mtx' = [mtx EXCEPT ![self] = "free"]
                     ELSE /\ TRUE
                          /\ mtx' = mtx
               /\ cstate' = [cstate EXCEPT ![self] = "done"]
               /\ pc' = [pc EXCEPT ![self] = "Done"]
               /\ UNCHANGED << conn, inReq, resp, store, sstate, revoked, 
                               servedRevoked, midframe, interleaved >>

client(self) == CEst(self) \/ CFrame1(self) \/ CFrame2(self) \/ CRecv(self)

SWait(self) == /\ pc[self] = "SWait"
               /\ inReq[Pof(self)]
               /\ pc' = [pc EXCEPT ![self] = "SGate"]
               /\ UNCHANGED << conn, mtx, inReq, resp, store, cstate, sstate, 
                               revoked, servedRevoked, midframe, interleaved >>

SGate(self) == /\ pc[self] = "SGate"
               /\ IF GateEstablished
                     THEN /\ conn[Pof(self)] = "established"
                     ELSE /\ TRUE
               /\ sstate' = [sstate EXCEPT ![Pof(self)] = "serving"]
               /\ pc' = [pc EXCEPT ![self] = "SFrame1"]
               /\ UNCHANGED << conn, mtx, inReq, resp, store, cstate, revoked, 
                               servedRevoked, midframe, interleaved >>

SFrame1(self) == /\ pc[self] = "SFrame1"
                 /\ mtx[Pof(self)] = "free"
                 /\ IF midframe[Pof(self)] # {}
                       THEN /\ interleaved' = TRUE
                       ELSE /\ TRUE
                            /\ UNCHANGED interleaved
                 /\ IF Honored(Pof(self)) \/ ~GateRevocation
                       THEN /\ /\ midframe' = [midframe EXCEPT ![Pof(self)] = midframe[Pof(self)] \cup {"server"}]
                               /\ mtx' = [mtx EXCEPT ![Pof(self)] = IF AtomicFrame THEN "server" ELSE "free"]
                               /\ servedRevoked' = (IF revoked THEN servedRevoked \cup {Pof(self)} ELSE servedRevoked)
                               /\ store' = [store EXCEPT ![Pof(self)] = store[Pof(self)] \cup {"k"}]
                       ELSE /\ /\ midframe' = [midframe EXCEPT ![Pof(self)] = midframe[Pof(self)] \cup {"server"}]
                               /\ mtx' = [mtx EXCEPT ![Pof(self)] = IF AtomicFrame THEN "server" ELSE "free"]
                            /\ UNCHANGED << store, servedRevoked >>
                 /\ pc' = [pc EXCEPT ![self] = "SFrame2"]
                 /\ UNCHANGED << conn, inReq, resp, cstate, sstate, revoked >>

SFrame2(self) == /\ pc[self] = "SFrame2"
                 /\ IF midframe[Pof(self)] # {"server"}
                       THEN /\ interleaved' = TRUE
                       ELSE /\ TRUE
                            /\ UNCHANGED interleaved
                 /\ /\ midframe' = [midframe EXCEPT ![Pof(self)] = midframe[Pof(self)] \ {"server"}]
                    /\ mtx' = [mtx EXCEPT ![Pof(self)] = "free"]
                    /\ resp' = [resp EXCEPT ![Pred(Pof(self))] = TRUE]
                    /\ sstate' = [sstate EXCEPT ![Pof(self)] = "done"]
                 /\ pc' = [pc EXCEPT ![self] = "Done"]
                 /\ UNCHANGED << conn, inReq, store, cstate, revoked, 
                                 servedRevoked >>

server(self) == SWait(self) \/ SGate(self) \/ SFrame1(self)
                   \/ SFrame2(self)

RWrite == /\ pc[Revoker] = "RWrite"
          /\ \/ /\ revoked' = TRUE
             \/ /\ TRUE
                /\ UNCHANGED revoked
          /\ pc' = [pc EXCEPT ![Revoker] = "Done"]
          /\ UNCHANGED << conn, mtx, inReq, resp, store, cstate, sstate, 
                          servedRevoked, midframe, interleaved >>

revoker == RWrite

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == revoker
           \/ (\E self \in Links: link(self))
           \/ (\E self \in Peers: client(self))
           \/ (\E self \in Servers: server(self))
           \/ Terminating

Spec == /\ Init /\ [][Next]_vars
        /\ \A self \in Links : WF_vars(link(self))
        /\ \A self \in Peers : WF_vars(client(self))
        /\ \A self \in Servers : WF_vars(server(self))
        /\ WF_vars(revoker)

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION

\* ===== Global liveness (the composed-model star result; needs WF from `fair process`) =====

\* §4.9(a)/§6.11: every client's reentrant cross-peer dispatch eventually resolves — the whole
\* composed substrate (handshake + bidirectional reentry + store + revocation gate) makes
\* progress and never deadlocks/livelocks. This is the property the §6.11 fix exists to hold;
\* the Serialized negative control breaks it (the Class-G deadlock, caught even under composition).
EventuallyResolved == \A p \in Peers : <>(cstate[p] = "done")

\* NON-VACUITY WITNESS (PROPERTIES.md §C.4 / CoreWitness.cfg). TLC has no ProVerif-style
\* reachability query, so a witness is expressed as an invariant that MUST BE VIOLATED. A
\* violation is the PASS condition: it exhibits a reachable state in which
\* both peers actually COMPLETED the composed cross-peer exchange — so the whole-protocol
\* safety and liveness results are not vacuously true of a system that never exchanges.
\* Checking it GREEN would mean the interesting state is unreachable — i.e. the results above
\* hold of an inert model. Expected verdict: VIOLATION.
WitnessExchangeComplete == ~(\A p \in Peers : cstate[p] = "done")

\* ===== §T4 — the composition, related to its components rather than asserted =====
\*
\* Ledger row T4 (docs/LEAN-SEAM.md Class T) recorded the assumption that "the composed
\* verdict is the conjunction the component modules check separately", discharged by nothing.
\* This block discharges as much of it as is true, and MEASURES the rest.
\*
\* WHAT WAS TRIED FIRST AND DOES NOT WORK: a standard refinement, `Core!Spec => Conn!Spec`
\* under a mapping. It fails for a structural reason worth recording rather than working
\* around. Core collapses the §4.6 handshake into ONE step — the `link` process assigns
\* conn[p] := "established" directly — while Conn runs new -> hello_done -> established as
\* two steps driven by a frame stream. A refinement mapping lets the abstract spec STUTTER
\* while the concrete one moves; it does not let one concrete step perform two abstract ones.
\* So no mapping of Core onto Conn's phase satisfies Conn's next-state relation, and the
\* honest report is that **Core is not a refinement of Conn**. Same conclusion for Store, and
\* more sharply: Core has no counterpart for Store's refcount, referrer set, write critical
\* section or admission state at all. This is not a defect being disclosed — it is what
\* "minimal composed essence" in this module's header MEANS, stated as a checkable fact.
\*
\* WHAT IS CHECKED INSTEAD: invariant implication under an explicit mapping (tla/RefMap.tla).
\* The component modules are INSTANCEd through it, so what is asserted below is each
\* component's OWN invariant text — `CONN(p)!DispatchedImpliesEstablished`, not a
\* transcription of it into this module's vocabulary. A transcription is a place the two can
\* silently diverge, which is the failure mode this whole block exists to close.
\*
\* THESE TWO ARE NOT THE SAME CLAIM AND MUST NOT BE BLURRED. Invariant implication says the
\* composed model's reachable states satisfy the component's invariant under the mapping. It
\* does NOT say the composition preserves the component's BEHAVIOUR. Anyone citing this
\* result should cite it as the weaker one, because that is what was run.
\*
\* AND IT IS ONLY WORTH ANYTHING WITH THE CLASSIFIER. A mapping that sends a component
\* variable to a constant turns that component's invariant into a tautology, and TLC reports
\* the identical green for "Core enforces this" and "the mapping asserts it" — the
\* `StoreBounded` vacuity one level up, inside the fix for it. tla/CoreMapFree.tla runs each
\* of the seven against every type-correct valuation instead of the reachable ones. Measured
\* verdicts, 2026-09-06:
\*
\*   CARRIED      1/7  Conn!DispatchedImpliesEstablished  (== this module's own
\*                     DispatchNeedsEstablished, reached through Conn's text)
\*   MANUFACTURED 6/7  Conn!TokenBounded, Conn!NoEstablishWithoutNonce,
\*                     Store!StoreRaceFree, Store!NoUseAfterFree,
\*                     Store!ResourceBounded, Store!CleanReject
\*
\* So the composed model genuinely carries ONE component property, and the §4.2 dispatch gate
\* is the one it carries. Every other component invariant here is a statement about
\* tla/RefMap.tla. That is a narrower claim than "the composition is verified" by a wide
\* margin, and it is the claim the runs support.

\* The mapping is per-connection because Conn models ONE responder's connection while Core
\* runs N of them on a ring; quantifying over Peers checks the symmetry rather than assuming
\* it, which is the mistake `Other(p)` made in this module's own history.
CONN(p) == INSTANCE Conn WITH
  MaxFrames       <- 1,
  Enforce         <- TRUE,
  DropFrame       <- FALSE,
  pc              <- MapConnPc,
  phase           <- MapPhase(conn[p]),
  issuedNonce     <- MapIssuedNonce(conn[p]),
  tokensIssued    <- MapTokens(conn[p]),
  everEstablished <- MapEver(conn[p]),
  dispatched      <- MapDispatched(cstate[p]),
  inbox           <- MapInbox,
  submitted       <- MapSubmitted,
  answered        <- MapAnswered,
  respHalted      <- MapRespHalted

STORE(p) == INSTANCE Store WITH
  NReq            <- 1,
  MaxPending      <- 2,
  MaxStore        <- 2,
  Serialize       <- TRUE,
  Admit           <- TRUE,
  SilentDrop      <- FALSE,
  SyncRefs        <- TRUE,
  pc              <- MapStorePc,
  store           <- MapStoreSet(store[p]),
  rc              <- MapRc,
  holders         <- MapHolders,
  writers         <- MapWriters,
  pending         <- MapPending,
  rstate          <- MapRstate,
  payload         <- MapPayload,
  depth           <- MapDepth,
  wrote           <- MapWrote,
  tmp             <- 0

\* THE ONE WITH CONTENT (classifier: CARRIED). Conn's own §4.2 pre-auth invariant, holding
\* over Core's reachable states at every peer. Core states the same property for itself as
\* DispatchNeedsEstablished; that these agree is the composition claim actually landing.
RefinesConnDispatched == \A p \in Peers : CONN(p)!DispatchedImpliesEstablished

\* AND THE OTHER SIX ARE DELIBERATELY NOT CHECKED HERE. The first draft of this block put all
\* seven mapped invariants in CoreRefines.cfg. It went green — 331 distinct states, Core's
\* count unchanged — and that green was worth almost nothing: six of the seven cannot fail
\* over ANY Core behaviour, so the cfg would have added six conjuncts that could not fail to
\* the largest model in the repo. That is `StoreBounded` exactly, in the fix for the gap
\* `StoreBounded` is the cautionary tale for. Their content is the CLASSIFICATION, and the
\* classification is run where it has teeth: tla/CoreMapFree.tla, one graded cfg each.
\*
\* They are not kept as drift detectors either, which was the other tempting reason. If
\* Conn's or Store's invariant text moves, the CoreMapFree rows are the ones that notice —
\* a manufactured row flipping to VIOLATED is a graded verdict change there. Keeping a
\* second, weaker copy here would detect nothing the classifier misses.
\*
\* TLC SAW PART OF THIS BY ITSELF, AND THE PART IT MISSED IS THE INTERESTING ONE. Running
\* the seven-invariant draft, TLC warned that `RefinesStoreRaceFree` and `RefinesStoreReject`
\* are "constant-level formula[s] ... evaluate[d] to TRUE" — an independent confirmation of
\* the manufactured verdict, in a channel the classifier does not read. But it flagged only
\* **2 of the 6**. The other four (`TokenBounded`, `NoEstablishWithoutNonce`,
\* `NoUseAfterFree`, `ResourceBounded`) all mention a Core variable through the mapping and
\* are still tautologies over the whole type space — `NoUseAfterFree` reads `store` via
\* MapStoreSet yet is unfalsifiable because MapHolders is constant. **A syntactic
\* constant-level check catches vacuity that is visible in the formula; it does not catch
\* vacuity manufactured by the mapping.** So "the tool would have told us" is false here, and
\* that is the argument for CoreMapFree.tla existing at all rather than leaning on the
\* warning. (It is also why those two warnings are not merely silenced: under D13 a tool
\* warning is a build failure, and the way to clear these is to stop asserting formulas that
\* assert nothing — which is what this note records doing.)
====
