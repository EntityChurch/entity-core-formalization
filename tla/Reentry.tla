---- MODULE Reentry ----
\* Spike A — V7 §6.11 Transport Reentry Contract, modeled as a small message-passing
\* state machine over 2 peers sharing pooled connections. See DESIGN-REENTRY-MODEL.md.
\*
\* 0.8.2 RE-TARGET (spec-data/v0.8.2/). §6.11 gained sub-clause (a′) FRAME-WRITE ATOMICITY
\* (0.8.1, RT-13b) — the one structural addition in the whole 0.8.0 -> 0.8.2 delta:
\*
\*   "While outbound dispatch on a shared/pooled connection proceeds concurrently (a), each
\*    wire frame (§3.3) MUST be written to the connection atomically with respect to other
\*    frames — the bytes of two distinct frames MUST NOT interleave on the connection.
\*    Concurrency lives at the dispatch/await layer; the byte-level write of a single frame
\*    is serialized... This does not reintroduce the (a) prohibition on holding serialization
\*    across the send+recv cycle — the write serialization is held only for the duration of
\*    one frame's bytes, never across the await."
\*
\* THE THEOREM THIS MODEL EXISTS TO CHECK is that last sentence. (a) and (a′) pull in
\* opposite directions — (a) forbids holding the connection lock, (a′) requires holding it —
\* and the spec asserts they are jointly satisfiable by a lock whose HOLD DURATION is exactly
\* one frame. So the model has ONE lock (`wlock`) and the two constants below select its hold
\* discipline; the green config must satisfy BOTH properties at once, and each negative
\* control must break exactly one of them:
\*
\*   AtomicFrame=TRUE,  Serialized=FALSE  (green)  -> no deadlock AND no interleaving
\*   AtomicFrame=TRUE,  Serialized=TRUE   (ReentryBug)      -> Class-G DEADLOCK (a violated)
\*   AtomicFrame=FALSE, Serialized=FALSE  (ReentryFrameBug) -> INTERLEAVED frames (a′ violated)
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the cap-chain VERDICT is abstracted
\* (Gate, below) — Lean owns it; this model verifies the protocol AROUND the verdict.
\*
\* ABSTRACTION BOUNDARY for (a′) (D11 — state what is NOT in the model): a wire frame is
\* modeled as exactly TWO chunks, which is the minimum granularity at which "these two
\* frames' bytes interleaved" is expressible. Real frames are many bytes; the property is
\* not byte-count-sensitive, so two chunks is the faithful abstraction and not a weakening.
\* What is NOT modeled: the receiver's decode. §6.11(a′) says an interleaved write "corrupts
\* the receiver's decode" — this model proves the writes do not interleave; it does not
\* model the decoder that would then fail.
\*
\* Every state element cites the V7 §ref it transcribes from spec-data/v0.8.2/.
EXTENDS Naturals, FiniteSets

CONSTANT Serialized   \* TRUE  = pre-F-WB28 defect: hold the per-connection write lock
                      \*         across the send+recv cycle (V7 §6.11(a) VIOLATED).
                      \* FALSE = fix: reader-task demux by request_id; the lock spans the
                      \*         write only, recv does not hold it (V7 §6.11(a)+(b)).

CONSTANT AtomicFrame  \* TRUE  = V7 §6.11(a′): the per-connection write lock is held for the
                      \*         duration of ONE FRAME's bytes, so frames serialize against
                      \*         each other at the byte level.
                      \* FALSE = negative control: a yielding write primitive with no
                      \*         per-frame serialization — another writer can begin a frame
                      \*         between this frame's chunks (§6.11(a′) VIOLATED).

CONSTANT N  \* NUMBER OF PEERS. Was hard-wired to 2 until 2026-08-30; see THE PEER BOUND below.

Peers       == 1..N
\* The dispatch topology: a directed RING. Peer p's client dispatches to Succ(p), so peer p's
\* server is serving a request that arrived from Pred(p) and must respond THERE.
Succ(p)     == IF p = N THEN 1 ELSE p + 1
Pred(p)     == IF p = 1 THEN N ELSE p - 1
MaxLiveKeys == 2      \* V7 §4.8/§4.9(b): store bounded by live keys

\* ===================================================================================
\* THE PEER BOUND (docs/status/SCOPING-2026-08-30-PEERS-BOUND.md)
\* ===================================================================================
\* This module read `Peers == {"A","B"}` and `Other(p) == IF p = "A" THEN "B" ELSE "A"`
\* through 0.8.2. `Other` is not a bound that was set low — it is the ASSERTION that every
\* peer has exactly one counterparty and it is the other one. Under it the wait-for graph has
\* two nodes, so the ONLY deadlock the model can express is the mutual 2-cycle, which is the
\* Class-G shape §6.11(a) already names. A 3-cycle — A's handler waiting on B's, B's on C's,
\* C's on A's — is a distinct deadlock class that two peers are structurally incapable of
\* exhibiting, and no amount of state-space exploration at N=2 reaches it.
\*
\* WHAT `Other` WAS HIDING, precisely. The response target was `resp[Other(Pof(self))]`: a
\* server answered "the other peer." That conflates two DIFFERENT peers — the one this peer
\* DISPATCHES TO (Succ) and the one whose request it is ANSWERING (Pred) — which are the same
\* peer if and only if N = 2. The binary assumption was not localized in the peer set; it was
\* load-bearing in the response routing, where it read as an obvious truth.
\*
\* THE RESULT (2026-08-30, N=3). The green config — §6.11(a)+(b)+(a′) all honored — holds at
\* three peers: 1229 states, 488 distinct, NoDispatchWithoutGate + FramesNotInterleaved +
\* the EventuallyResolved liveness property, no error (Reentry3.cfg). It is NOT vacuous:
\* ReentryBug3.cfg (the Serialized defect at N=3) reaches
\*     wlock = <<"client","client","client">>  /\  cstate = <<"sent","sent","sent">>
\*     pc    = <<"CRecv","CRecv","CRecv","SFrame1","SFrame1","SFrame1">>
\* — all three clients blocked awaiting a response while each holds its own write lock, and
\* all three servers blocked awaiting that lock. That is a THREE-node wait-for cycle, and it
\* is a state the pre-2026-08-30 model could not represent at all. So the state space does
\* reach cyclic waits of length 3, and the fix forbids them.
\*
\* What this does and does not add. The defect ReentryBug3 exhibits is the SAME defect as
\* ReentryBug — holding the lock across recv — not a new one; N=3 found no new bug. What is
\* new is the claim: §6.11's contract is deadlock-free against a 3-cycle, which is a shape
\* two peers cannot form. Before this the honest position was "we did not look."
\*
\* TOPOLOGY BOUNDARY (D11 — what is NOT here). The topology is a fixed directed ring, not an
\* arbitrary graph: each peer dispatches to exactly one successor and serves exactly one
\* predecessor. The ring is the MINIMAL shape that exhibits an N-cycle, which is the property
\* this generalization exists to reach. Arbitrary dispatch graphs (a peer with several
\* counterparties, or several concurrent outbound requests per peer) are a strictly larger
\* question and are NOT modeled here. At N=2 the ring IS the complete 2-peer topology, so
\* nothing is lost relative to the previous model — Succ = Pred = Other, and the N=2 results
\* are unchanged (same verdicts, same distinct-state counts; the renaming A,B -> 1,2 is an
\* isomorphism). That equivalence is the regression test for this restructuring.
\*
\* Each peer runs a CLIENT activity and a SERVER activity CONCURRENTLY (the deadlock needs
\* the client to hold the lock while the server contends for it). They must be distinct
\* PlusCal processes, so servers get disjoint ids mapped back to their peer by Pof.
\* Both write on the SAME pooled connection — peer p's connection — which is what makes them
\* two concurrent writers and puts §6.11(a′) in scope.
\* Server ids are integers in a range DISJOINT from Peers, not tuples: the PlusCal translation
\* emits `CASE self \in Peers -> ... [] self \in Servers -> ...` over the combined ProcSet, and
\* TLC refuses to evaluate `<<"s",1>> \in 1..N` (tuple tested against an integer interval).
Servers     == (N+1)..(2*N)
Pof(s)      == s - N                           \* server-id -> its peer

\* Abstract dispatch gate (V7 §6.5). The real verdict (§5.2/§5.5/§5.6) is Lean's and is
\* deliberately NOT modeled; here it is an opaque predicate that gates handler entry, so
\* NoDispatchWithoutGate is a real structural check (a handler never runs pre-gate).
\*
\* DECLARED LIMIT: Gate is the CONSTANT TRUE, so the DENIAL case is inexpressible in this
\* module and NoDispatchWithoutGate cannot fail here. That is a known thin positive, and the
\* §5.2 three-valued dispatch-authority rule new at 0.8.2 (SELF / GRANT / ABSENT-must-deny)
\* is modeled where it can be load-bearing instead: tla/Authority.tla, which makes denial a
\* reachable outcome and proves the grantless sub-dispatch is refused.
Gate(p) == TRUE

(*--algorithm reentry
variables
  \* Per-peer pooled-connection WRITE LOCK — THE contended resource (V7 §6.11(a)/(a′)).
  \* wlock[p] guards writes on peer p's pooled connection: p's outbound requests to Succ(p)
  \* AND p's server responses / handler reentries. Its HOLD DURATION is the whole design
  \* question — see the header.
  wlock  = [p \in Peers |-> "free"];
  \* V7 §6.11(a′): who currently has a PARTIALLY WRITTEN frame on peer p's connection.
  \* A frame is two chunks; a writer is in this set between its first and last chunk.
  midframe = [p \in Peers |-> {}];
  \* V7 §6.11(a′) violation flag: set when one writer's frame chunks are separated by
  \* another writer's chunk on the same connection ("the bytes of two distinct frames
  \* interleaved"). Latched, because the corruption is not undone by finishing the frame.
  interleaved = FALSE;
  inReq  = [p \in Peers |-> FALSE];   \* an inbound request awaits p's server (from Pred(p))
  resp   = [p \in Peers |-> FALSE];   \* a response has been delivered back to p's client
  store  = [p \in Peers |-> {}];      \* V7 §4.8 store: set of live keys a handler has written
  cstate = [p \in Peers |-> "init"];  \* client lifecycle: init | sent | done
  sstate = [p \in Peers |-> "idle"];  \* server lifecycle: idle | serving | done

\* ---- Client(p): originate an outbound EXECUTE to Succ(p) and await the response ----
fair process client \in Peers
begin
  CFrame1:
    \* V7 §6.11(a′): write the FIRST chunk of the request frame. Under (a′) this takes the
    \* per-connection write lock, which is what stops another writer's bytes getting in
    \* between. The negative control has no lock — a yielding write primitive.
    if AtomicFrame then
      await wlock[self] = "free";
    end if;
    \* beginning a frame while another writer is mid-frame IS an interleave
    if midframe[self] # {} then
      interleaved := TRUE;
    end if;
    midframe[self] := midframe[self] \cup {"client"} ||
    wlock[self]    := IF AtomicFrame THEN "client" ELSE "free";
  CFrame2:
    \* Write the LAST chunk of the same frame. If another writer began a frame since our
    \* first chunk, our two chunks are no longer contiguous on the wire — §6.11(a′) violated.
    if midframe[self] # {"client"} then
      interleaved := TRUE;
    end if;
    midframe[self] := midframe[self] \ {"client"} ||
    inReq[Succ(self)] := TRUE ||         \* the complete frame is delivered to Succ(p)'s server
    cstate[self] := "sent" ||
    \* END OF FRAME — release the write lock HERE. This is the (a′)-conformant hold duration:
    \* "held only for the duration of one frame's bytes, never across the await."
    \* Serialized DEFECT (§6.11(a) violated): keep holding it across the upcoming recv.
    wlock[self] := IF Serialized THEN "client" ELSE "free";
  CRecv:
    await resp[self];                  \* await response (DEFECT: still holding wlock if Serialized)
    \* RELEASE ONLY A LOCK WE HOLD. Under the §6.11(a)+(a′) fix the client released at
    \* end-of-frame (CFrame2), so by the time the response arrives the write lock may belong
    \* to this peer's OWN SERVER, mid-frame. An unconditional release here would free a lock
    \* held by another writer — a modeling defect with no observable consequence at the
    \* 2-peer TLC bound (no third writer exists to exploit the stolen lock), which is exactly
    \* why TLC did not surface it. tla/ReentryApalache.tla's INDUCTIVE step did, immediately,
    \* because it starts from arbitrary states rather than reachable ones.
    if wlock[self] = "client" then
      wlock[self] := "free";           \* the Serialized defect's hold ends here
    end if;
    cstate[self] := "done";
end process;

\* ---- Server(p): serve the inbound request; the handler reenters / writes the response,
\* which needs the connection write lock (V7 §6.11 reentry). In the serialized defect this
\* blocks because the client holds wlock[self] across recv — the Class G deadlock surface. ----
fair process server \in Servers
begin
  SWait:
    await inReq[Pof(self)];            \* an inbound request is pending for this peer
  SGate:
    await Gate(Pof(self));             \* V7 §6.5: gate runs before handler invocation
    sstate[Pof(self)] := "serving";
  SFrame1:
    \* The handler reenters and writes the FIRST chunk of the response frame on the SAME
    \* pooled connection. Under (a′) it must take the write lock; in the serialized defect
    \* the client holds that lock across its recv, so this guard never enables — Class G.
    if AtomicFrame then
      await wlock[Pof(self)] = "free";
    end if;
    if midframe[Pof(self)] # {} then
      interleaved := TRUE;
    end if;
    midframe[Pof(self)] := midframe[Pof(self)] \cup {"server"} ||
    wlock[Pof(self)]    := IF AtomicFrame THEN "server" ELSE "free" ||
    store[Pof(self)]    := store[Pof(self)] \cup {"k"};  \* V7 §4.8 bounded store write
  SFrame2:
    \* Last chunk of the response frame; then release the lock (end of frame) and deliver.
    if midframe[Pof(self)] # {"server"} then
      interleaved := TRUE;
    end if;
    midframe[Pof(self)] := midframe[Pof(self)] \ {"server"} ||
    resp[Pred(Pof(self))] := TRUE ||    \* respond to the REQUESTER (Pred), not to our own target
    sstate[Pof(self)] := "done" ||
    wlock[Pof(self)] := "free";
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "63336e5b" /\ chksum(tla) = "b5a172f4")
VARIABLES pc, wlock, midframe, interleaved, inReq, resp, store, cstate, 
          sstate

vars == << pc, wlock, midframe, interleaved, inReq, resp, store, cstate, 
           sstate >>

ProcSet == (Peers) \cup (Servers)

Init == (* Global variables *)
        /\ wlock = [p \in Peers |-> "free"]
        /\ midframe = [p \in Peers |-> {}]
        /\ interleaved = FALSE
        /\ inReq = [p \in Peers |-> FALSE]
        /\ resp = [p \in Peers |-> FALSE]
        /\ store = [p \in Peers |-> {}]
        /\ cstate = [p \in Peers |-> "init"]
        /\ sstate = [p \in Peers |-> "idle"]
        /\ pc = [self \in ProcSet |-> CASE self \in Peers -> "CFrame1"
                                        [] self \in Servers -> "SWait"]

CFrame1(self) == /\ pc[self] = "CFrame1"
                 /\ IF AtomicFrame
                       THEN /\ wlock[self] = "free"
                       ELSE /\ TRUE
                 /\ IF midframe[self] # {}
                       THEN /\ interleaved' = TRUE
                       ELSE /\ TRUE
                            /\ UNCHANGED interleaved
                 /\ /\ midframe' = [midframe EXCEPT ![self] = midframe[self] \cup {"client"}]
                    /\ wlock' = [wlock EXCEPT ![self] = IF AtomicFrame THEN "client" ELSE "free"]
                 /\ pc' = [pc EXCEPT ![self] = "CFrame2"]
                 /\ UNCHANGED << inReq, resp, store, cstate, sstate >>

CFrame2(self) == /\ pc[self] = "CFrame2"
                 /\ IF midframe[self] # {"client"}
                       THEN /\ interleaved' = TRUE
                       ELSE /\ TRUE
                            /\ UNCHANGED interleaved
                 /\ /\ cstate' = [cstate EXCEPT ![self] = "sent"]
                    /\ inReq' = [inReq EXCEPT ![Succ(self)] = TRUE]
                    /\ midframe' = [midframe EXCEPT ![self] = midframe[self] \ {"client"}]
                    /\ wlock' = [wlock EXCEPT ![self] = IF Serialized THEN "client" ELSE "free"]
                 /\ pc' = [pc EXCEPT ![self] = "CRecv"]
                 /\ UNCHANGED << resp, store, sstate >>

CRecv(self) == /\ pc[self] = "CRecv"
               /\ resp[self]
               /\ IF wlock[self] = "client"
                     THEN /\ wlock' = [wlock EXCEPT ![self] = "free"]
                     ELSE /\ TRUE
                          /\ wlock' = wlock
               /\ cstate' = [cstate EXCEPT ![self] = "done"]
               /\ pc' = [pc EXCEPT ![self] = "Done"]
               /\ UNCHANGED << midframe, interleaved, inReq, resp, store, 
                               sstate >>

client(self) == CFrame1(self) \/ CFrame2(self) \/ CRecv(self)

SWait(self) == /\ pc[self] = "SWait"
               /\ inReq[Pof(self)]
               /\ pc' = [pc EXCEPT ![self] = "SGate"]
               /\ UNCHANGED << wlock, midframe, interleaved, inReq, resp, 
                               store, cstate, sstate >>

SGate(self) == /\ pc[self] = "SGate"
               /\ Gate(Pof(self))
               /\ sstate' = [sstate EXCEPT ![Pof(self)] = "serving"]
               /\ pc' = [pc EXCEPT ![self] = "SFrame1"]
               /\ UNCHANGED << wlock, midframe, interleaved, inReq, resp, 
                               store, cstate >>

SFrame1(self) == /\ pc[self] = "SFrame1"
                 /\ IF AtomicFrame
                       THEN /\ wlock[Pof(self)] = "free"
                       ELSE /\ TRUE
                 /\ IF midframe[Pof(self)] # {}
                       THEN /\ interleaved' = TRUE
                       ELSE /\ TRUE
                            /\ UNCHANGED interleaved
                 /\ /\ midframe' = [midframe EXCEPT ![Pof(self)] = midframe[Pof(self)] \cup {"server"}]
                    /\ store' = [store EXCEPT ![Pof(self)] = store[Pof(self)] \cup {"k"}]
                    /\ wlock' = [wlock EXCEPT ![Pof(self)] = IF AtomicFrame THEN "server" ELSE "free"]
                 /\ pc' = [pc EXCEPT ![self] = "SFrame2"]
                 /\ UNCHANGED << inReq, resp, cstate, sstate >>

SFrame2(self) == /\ pc[self] = "SFrame2"
                 /\ IF midframe[Pof(self)] # {"server"}
                       THEN /\ interleaved' = TRUE
                       ELSE /\ TRUE
                            /\ UNCHANGED interleaved
                 /\ /\ midframe' = [midframe EXCEPT ![Pof(self)] = midframe[Pof(self)] \ {"server"}]
                    /\ resp' = [resp EXCEPT ![Pred(Pof(self))] = TRUE]
                    /\ sstate' = [sstate EXCEPT ![Pof(self)] = "done"]
                    /\ wlock' = [wlock EXCEPT ![Pof(self)] = "free"]
                 /\ pc' = [pc EXCEPT ![self] = "Done"]
                 /\ UNCHANGED << inReq, store, cstate >>

server(self) == SWait(self) \/ SGate(self) \/ SFrame1(self)
                   \/ SFrame2(self)

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

\* ===== Properties =====

\* §4.8/§4.9(b) STORE BOUND — DELIBERATELY NOT ASSERTED HERE. Owned by tla/Store.tla.
\*
\* This module used to carry `StoreBounded == \A p \in Peers : Cardinality(store[p]) <=
\* MaxLiveKeys`. It was VACUOUS: each of the two servers writes the single literal key "k"
\* into its own peer's set exactly once, so the cardinality is 0 or 1 against a bound of 2 and
\* the invariant could not fail in any behaviour of this model. It reported the same green a
\* real obligation would, which is the failure mode this repo names as a first-class hazard
\* (docs/COVERAGE-MATRIX.md §6). It was disclosed as vacuous twice without being fixed.
\*
\* It is REMOVED rather than given teeth, because the property is not expressible against this
\* module's abstractions: the bound only has content under REPEATED dispatch or multi-key
\* writes, and this model's servers serve once and write one key. Making it falsifiable would
\* mean importing Store.tla's multi-key/refcount machinery — duplicating an owner rather than
\* adding assurance, at a state-space cost in the model that already carries the most.
\* The real §4.8/§4.9(b) live-key bound is Store.tla's `ResourceBounded`, which is multi-key,
\* falsifiable, and discharged by refcount correctness (StoreApalache.InvBound / InvUAF).
\*
\* The `store` variable stays: the handler's write is the observable that §6.5's dispatch gate
\* protects, which is what NoDispatchWithoutGate below is about. Only the bound is gone.

\* SAFETY — V7 §6.5: a handler is only ever invoked after its dispatch gate held.
NoDispatchWithoutGate == \A p \in Peers : (sstate[p] # "idle") => Gate(p)

\* SAFETY — V7 §6.11(a′) (NEW at 0.8.2, 0.8.1 RT-13b): the bytes of two distinct frames never
\* interleave on a shared/pooled connection. Holds in the green config SIMULTANEOUSLY with
\* EventuallyResolved below, which is the joint-satisfiability claim §6.11(a′) makes.
FramesNotInterleaved == ~interleaved

\* LIVENESS — V7 §4.9(a): every admitted (sent) request eventually resolves (responded →
\* cstate "done"); no deadlock, no livelock. THE property nothing else proves. Needs the
\* weak fairness supplied by `fair process`.
EventuallyResolved == \A p \in Peers : (cstate[p] = "sent") ~> (cstate[p] = "done")

\* NON-VACUITY WITNESS (see PROPERTIES.md §C.4 and ReentryWitness.cfg). TLC has no
\* ProVerif-style reachability query, so a witness is an invariant that MUST be violated:
\* if both peers ever actually complete the reentrant exchange, this fails and TLC produces
\* the trace. Checking it GREEN would mean the exchange never completes — i.e. the liveness
\* and frame-integrity results above were true of a system that does nothing.
\* Expected verdict: VIOLATION.
WitnessBothComplete == ~(\A p \in Peers : cstate[p] = "done" /\ sstate[p] = "done")
====
