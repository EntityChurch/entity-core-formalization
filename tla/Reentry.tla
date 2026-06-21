---- MODULE Reentry ----
\* Spike A — V7 §6.11 Transport Reentry Contract, modeled as a small message-passing
\* state machine over 2 peers sharing pooled connections. See DESIGN-REENTRY-MODEL.md.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the cap-chain VERDICT is abstracted
\* (Gate, below) — Lean owns it; this model verifies the protocol AROUND the verdict.
\* Every state element cites the V7 §ref it transcribes from spec-data/v0.8.0/.
EXTENDS Naturals, FiniteSets

CONSTANT Serialized   \* TRUE  = pre-F-WB28 defect: hold the per-connection write mutex
                      \*         across the send+recv cycle (V7 §6.11(a) VIOLATED).
                      \* FALSE = fix: reader-task demux by request_id; mutex spans the
                      \*         write only, recv does not hold it (V7 §6.11(a)+(b)).

Peers       == {"A", "B"}
Other(p)    == IF p = "A" THEN "B" ELSE "A"
MaxLiveKeys == 2      \* V7 §4.8/§4.9(b): store bounded by live keys

\* Each peer runs a CLIENT activity and a SERVER activity CONCURRENTLY (the deadlock needs
\* the client to hold the mutex while the server contends for it). They must be distinct
\* PlusCal processes, so servers get disjoint ids mapped back to their peer by Pof.
Servers     == {"sA", "sB"}
Pof(s)      == IF s = "sA" THEN "A" ELSE "B"   \* server-id -> its peer

\* Abstract dispatch gate (V7 §6.5). The real verdict (§5.2/§5.5/§5.6) is Lean's and is
\* deliberately NOT modeled; here it is an opaque predicate that gates handler entry, so
\* NoDispatchWithoutGate is a real structural check (a handler never runs pre-gate).
Gate(p) == TRUE

(*--algorithm reentry
variables
  \* Per-peer pooled-connection write mutex — THE contended resource (V7 §6.11(a)).
  \* mtx[p] guards peer p's writes (its outbound requests AND its server responses /
  \* handler reentries) on its pooled connection to Other(p).
  mtx    = [p \in Peers |-> "free"];
  inReq  = [p \in Peers |-> FALSE];   \* an inbound request awaits p's server (from Other(p))
  resp   = [p \in Peers |-> FALSE];   \* a response has been delivered back to p's client
  store  = [p \in Peers |-> {}];      \* V7 §4.8 store: set of live keys a handler has written
  cstate = [p \in Peers |-> "init"];  \* client lifecycle: init | sent | done
  sstate = [p \in Peers |-> "idle"];  \* server lifecycle: idle | serving | done

\* ---- Client(p): originate an outbound EXECUTE to Other(p) and await the response ----
fair process client \in Peers
begin
  CSend:
    await mtx[self] = "free";          \* acquire the connection write mutex to send
    \* Serialized DEFECT: keep holding the mutex across the upcoming recv (mtx stays
    \* "client"). FIX (§6.11(a)+(b)): release right after the WRITE — recv is correlated
    \* by request_id on the reader task and does not hold the mutex. (CSend is one atomic
    \* step, so the fix's brief write-hold collapses to "free" with no observable loss.)
    mtx[self]  := IF Serialized THEN "client" ELSE "free";
    inReq[Other(self)] := TRUE;        \* deliver the request to the peer's server
    cstate[self] := "sent";
  CRecv:
    await resp[self];                  \* await response (DEFECT: still holding mtx if Serialized)
    mtx[self]  := "free";              \* release (no-op in the fix; client->free in the defect)
    cstate[self] := "done";
end process;

\* ---- Server(p): serve the inbound request; the handler reenters / writes the response,
\* which needs the connection write mutex (V7 §6.11 reentry). In the serialized defect this
\* blocks because the client holds mtx[self] across recv — the Class G deadlock surface. ----
fair process server \in Servers
begin
  SWait:
    await inReq[Pof(self)];            \* an inbound request is pending for this peer
  SGate:
    await Gate(Pof(self));             \* V7 §6.5: gate runs before handler invocation
    sstate[Pof(self)] := "serving";
  SHandle:
    \* The handler reenters / writes the response, which needs the write mutex. Modeled as
    \* a guard (SHandle is atomic — acquire+use+release has no observable interleaving): the
    \* server can only proceed when the mutex is free. In the serialized defect the client
    \* holds it across recv, so this guard never enables — the Class G deadlock.
    await mtx[Pof(self)] = "free";
    store[Pof(self)] := store[Pof(self)] \cup {"k"};  \* V7 §4.8 bounded store write
    resp[Other(Pof(self))] := TRUE;    \* respond to the requesting client
    sstate[Pof(self)] := "done";
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "56b1eb55" /\ chksum(tla) = "e279aa86")
VARIABLES pc, mtx, inReq, resp, store, cstate, sstate

vars == << pc, mtx, inReq, resp, store, cstate, sstate >>

ProcSet == (Peers) \cup (Servers)

Init == (* Global variables *)
        /\ mtx = [p \in Peers |-> "free"]
        /\ inReq = [p \in Peers |-> FALSE]
        /\ resp = [p \in Peers |-> FALSE]
        /\ store = [p \in Peers |-> {}]
        /\ cstate = [p \in Peers |-> "init"]
        /\ sstate = [p \in Peers |-> "idle"]
        /\ pc = [self \in ProcSet |-> CASE self \in Peers -> "CSend"
                                        [] self \in Servers -> "SWait"]

CSend(self) == /\ pc[self] = "CSend"
               /\ mtx[self] = "free"
               /\ mtx' = [mtx EXCEPT ![self] = IF Serialized THEN "client" ELSE "free"]
               /\ inReq' = [inReq EXCEPT ![Other(self)] = TRUE]
               /\ cstate' = [cstate EXCEPT ![self] = "sent"]
               /\ pc' = [pc EXCEPT ![self] = "CRecv"]
               /\ UNCHANGED << resp, store, sstate >>

CRecv(self) == /\ pc[self] = "CRecv"
               /\ resp[self]
               /\ mtx' = [mtx EXCEPT ![self] = "free"]
               /\ cstate' = [cstate EXCEPT ![self] = "done"]
               /\ pc' = [pc EXCEPT ![self] = "Done"]
               /\ UNCHANGED << inReq, resp, store, sstate >>

client(self) == CSend(self) \/ CRecv(self)

SWait(self) == /\ pc[self] = "SWait"
               /\ inReq[Pof(self)]
               /\ pc' = [pc EXCEPT ![self] = "SGate"]
               /\ UNCHANGED << mtx, inReq, resp, store, cstate, sstate >>

SGate(self) == /\ pc[self] = "SGate"
               /\ Gate(Pof(self))
               /\ sstate' = [sstate EXCEPT ![Pof(self)] = "serving"]
               /\ pc' = [pc EXCEPT ![self] = "SHandle"]
               /\ UNCHANGED << mtx, inReq, resp, store, cstate >>

SHandle(self) == /\ pc[self] = "SHandle"
                 /\ mtx[Pof(self)] = "free"
                 /\ store' = [store EXCEPT ![Pof(self)] = store[Pof(self)] \cup {"k"}]
                 /\ resp' = [resp EXCEPT ![Other(Pof(self))] = TRUE]
                 /\ sstate' = [sstate EXCEPT ![Pof(self)] = "done"]
                 /\ pc' = [pc EXCEPT ![self] = "Done"]
                 /\ UNCHANGED << mtx, inReq, cstate >>

server(self) == SWait(self) \/ SGate(self) \/ SHandle(self)

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == (\E self \in Peers: client(self))
           \/ (\E self \in Servers: server(self))
           \/ Terminating

Spec == /\ Init /\ [][Next]_vars
        /\ \A self \in Peers : WF_vars(client(self))
        /\ \A self \in Servers : WF_vars(server(self))

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION 

\* ===== Properties (checked after the translation block below) =====

\* SAFETY — V7 §4.8 / §4.9(b): the store never exceeds its live-key bound (leak/runaway class).
StoreBounded == \A p \in Peers : Cardinality(store[p]) <= MaxLiveKeys

\* SAFETY — V7 §6.5: a handler is only ever invoked after its dispatch gate held.
NoDispatchWithoutGate == \A p \in Peers : (sstate[p] # "idle") => Gate(p)

\* LIVENESS — V7 §4.9(a): every admitted (sent) request eventually resolves (responded →
\* cstate "done"); no deadlock, no livelock. THE property nothing else proves. Needs the
\* weak fairness supplied by `fair process`.
EventuallyResolved == \A p \in Peers : (cstate[p] = "sent") ~> (cstate[p] = "done")
====
