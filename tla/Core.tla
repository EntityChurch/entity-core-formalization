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
EXTENDS Naturals, FiniteSets

CONSTANTS Serialized,     \* FALSE = §6.11 fix (reader-demux: mutex spans the write only);
                          \* TRUE  = negative control: hold the per-connection mutex across send+recv
                          \*         (the Class-G deadlock surface) — must deadlock even when composed.
          GateEstablished,\* TRUE = A §4.2: client + server gate on established; FALSE = negative
                          \*        control: dispatch before establishment -> *NeedsEstablished fail.
          GateRevocation  \* TRUE = F §5.1/§6.5: handler write gated on the verdict (not revoked);
                          \*        FALSE = negative control: serve a revoked cap -> NoServeWhenRevoked fails.

Peers    == {"A", "B"}
Other(p) == IF p = "A" THEN "B" ELSE "A"
Servers  == {"sA", "sB"}
Pof(s)   == IF s = "sA" THEN "A" ELSE "B"   \* server-id -> the peer it serves
Links    == {"lA", "lB"}                     \* distinct ids for the establishment activities
Lof(l)   == IF l = "lA" THEN "A" ELSE "B"   \* link-id -> the peer it establishes
MaxKeys  == 1                                \* §4.8/4.9(b): bounded store

(*--algorithm core
variables
  conn    = [p \in Peers |-> "new"],     \* A §4: per-connection phase (new -> established)
  mtx     = [p \in Peers |-> "free"],    \* B §6.11(a): per-connection write mutex (the contended resource)
  inReq   = [p \in Peers |-> FALSE],     \* B: an inbound request awaits p's server
  resp    = [p \in Peers |-> FALSE],     \* B §6.11(b): a response routed back to p's client
  store   = [p \in Peers |-> {}],        \* C §4.8: bounded content store written by handlers
  cstate  = [p \in Peers |-> "init"],    \* B client lifecycle: init | sent | done
  sstate  = [p \in Peers |-> "idle"],    \* B server lifecycle: idle | serving | done
  revoked = FALSE,                       \* F §5.1: a revocation marker (consulted by the gate)
  servedRevoked = {};                    \* F ghost: peers whose handler wrote under a revoked cap

define
  \* §6.5/§5.10 verdict gate (abstracted): a request is honored iff the cap is not revoked. The
  \* structural verdict is Lean's; revocation observation/convergence is increment 5's — here it
  \* is one global flag the dispatch gate consults, exposing the revoke-during-reentry interleaving.
  Honored(p) == ~revoked

  \* C §4.8/4.9(b): every peer's store stays within its live-key bound under concurrent dispatch.
  StoreBounded == \A p \in Peers : Cardinality(store[p]) <= MaxKeys

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
end define;

\* A §4: the connection handshake completes (abstracted) — the precondition for any dispatch.
fair process link \in Links
begin
  Estab:
    conn[Lof(self)] := "established";
end process;

\* B client: once established, originate a reentrant cross-peer EXECUTE to Other(self) and await
\* the response. The §6.11 fix releases the write mutex after the WRITE (recv is demuxed by
\* request_id); the Serialized defect holds it across recv — the deadlock surface.
fair process client \in Peers
begin
  CEst:
    if GateEstablished then
      await conn[self] = "established";     \* A §4.2: no dispatch pre-establishment
    end if;
  CSend:
    await mtx[self] = "free";
    mtx[self] := IF Serialized THEN "client" ELSE "free";   \* B §6.11(a)
    inReq[Other(self)] := TRUE;
    cstate[self] := "sent";
  CRecv:
    await resp[self];                       \* B §6.11(b): demuxed response
    mtx[self] := "free";
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
  SHandle:
    await mtx[Pof(self)] = "free";           \* B §6.11 reentry write mutex (deadlock point if Serialized)
    if Honored(Pof(self)) \/ ~GateRevocation then   \* F §6.5/§5.10 verdict gate; correct writes only when honored
      store[Pof(self)] := store[Pof(self)] \cup {"k"};   \* C §4.8 bounded store write
      if revoked then
        \* only reachable when GateRevocation=FALSE: wrote under a revoked cap (§5.1 violation)
        servedRevoked := servedRevoked \cup {Pof(self)};
      end if;
    end if;
    resp[Other(Pof(self))] := TRUE;          \* §4.9(c) deliver-or-signal: respond either way
    sstate[Pof(self)] := "done";
end process;

\* F §5.1: a revocation may (or may not) occur concurrently with in-flight dispatch.
fair process revoker = "rev"
begin
  RWrite:
    either revoked := TRUE; or skip; end either;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "531862a4" /\ chksum(tla) = "76021510")
VARIABLES pc, conn, mtx, inReq, resp, store, cstate, sstate, revoked, 
          servedRevoked

(* define statement *)
Honored(p) == ~revoked


StoreBounded == \A p \in Peers : Cardinality(store[p]) <= MaxKeys



DispatchNeedsEstablished ==
  \A p \in Peers : (cstate[p] \in {"sent", "done"}) => (conn[p] = "established")


ServeNeedsEstablished ==
  \A s \in Servers : (sstate[Pof(s)] # "idle") => (conn[Pof(s)] = "established")



NoServeWhenRevoked == servedRevoked = {}


vars == << pc, conn, mtx, inReq, resp, store, cstate, sstate, revoked, 
           servedRevoked >>

ProcSet == (Links) \cup (Peers) \cup (Servers) \cup {"rev"}

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
        /\ pc = [self \in ProcSet |-> CASE self \in Links -> "Estab"
                                        [] self \in Peers -> "CEst"
                                        [] self \in Servers -> "SWait"
                                        [] self = "rev" -> "RWrite"]

Estab(self) == /\ pc[self] = "Estab"
               /\ conn' = [conn EXCEPT ![Lof(self)] = "established"]
               /\ pc' = [pc EXCEPT ![self] = "Done"]
               /\ UNCHANGED << mtx, inReq, resp, store, cstate, sstate, 
                               revoked, servedRevoked >>

link(self) == Estab(self)

CEst(self) == /\ pc[self] = "CEst"
              /\ IF GateEstablished
                    THEN /\ conn[self] = "established"
                    ELSE /\ TRUE
              /\ pc' = [pc EXCEPT ![self] = "CSend"]
              /\ UNCHANGED << conn, mtx, inReq, resp, store, cstate, sstate, 
                              revoked, servedRevoked >>

CSend(self) == /\ pc[self] = "CSend"
               /\ mtx[self] = "free"
               /\ mtx' = [mtx EXCEPT ![self] = IF Serialized THEN "client" ELSE "free"]
               /\ inReq' = [inReq EXCEPT ![Other(self)] = TRUE]
               /\ cstate' = [cstate EXCEPT ![self] = "sent"]
               /\ pc' = [pc EXCEPT ![self] = "CRecv"]
               /\ UNCHANGED << conn, resp, store, sstate, revoked, 
                               servedRevoked >>

CRecv(self) == /\ pc[self] = "CRecv"
               /\ resp[self]
               /\ mtx' = [mtx EXCEPT ![self] = "free"]
               /\ cstate' = [cstate EXCEPT ![self] = "done"]
               /\ pc' = [pc EXCEPT ![self] = "Done"]
               /\ UNCHANGED << conn, inReq, resp, store, sstate, revoked, 
                               servedRevoked >>

client(self) == CEst(self) \/ CSend(self) \/ CRecv(self)

SWait(self) == /\ pc[self] = "SWait"
               /\ inReq[Pof(self)]
               /\ pc' = [pc EXCEPT ![self] = "SGate"]
               /\ UNCHANGED << conn, mtx, inReq, resp, store, cstate, sstate, 
                               revoked, servedRevoked >>

SGate(self) == /\ pc[self] = "SGate"
               /\ IF GateEstablished
                     THEN /\ conn[Pof(self)] = "established"
                     ELSE /\ TRUE
               /\ sstate' = [sstate EXCEPT ![Pof(self)] = "serving"]
               /\ pc' = [pc EXCEPT ![self] = "SHandle"]
               /\ UNCHANGED << conn, mtx, inReq, resp, store, cstate, revoked, 
                               servedRevoked >>

SHandle(self) == /\ pc[self] = "SHandle"
                 /\ mtx[Pof(self)] = "free"
                 /\ IF Honored(Pof(self)) \/ ~GateRevocation
                       THEN /\ store' = [store EXCEPT ![Pof(self)] = store[Pof(self)] \cup {"k"}]
                            /\ IF revoked
                                  THEN /\ servedRevoked' = (servedRevoked \cup {Pof(self)})
                                  ELSE /\ TRUE
                                       /\ UNCHANGED servedRevoked
                       ELSE /\ TRUE
                            /\ UNCHANGED << store, servedRevoked >>
                 /\ resp' = [resp EXCEPT ![Other(Pof(self))] = TRUE]
                 /\ sstate' = [sstate EXCEPT ![Pof(self)] = "done"]
                 /\ pc' = [pc EXCEPT ![self] = "Done"]
                 /\ UNCHANGED << conn, mtx, inReq, cstate, revoked >>

server(self) == SWait(self) \/ SGate(self) \/ SHandle(self)

RWrite == /\ pc["rev"] = "RWrite"
          /\ \/ /\ revoked' = TRUE
             \/ /\ TRUE
                /\ UNCHANGED revoked
          /\ pc' = [pc EXCEPT !["rev"] = "Done"]
          /\ UNCHANGED << conn, mtx, inReq, resp, store, cstate, sstate, 
                          servedRevoked >>

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
====
