---- MODULE ReentryApalache ----
\* NEW at 0.8.2 — Apalache (SMT) cross-check of the Reentry module (tla/Reentry.tla).
\*
\* WHY THIS EXISTS. `Reentry` carries the marquee result of this repo (the Class-G deadlock)
\* and, since 0.8.2, §6.11(a′) frame-write atomicity — and until now it had **no unbounded
\* proof**. It was TLC + Spin only. That is a coverage hole the audit surfaced rather than a
\* deliberate scope call: five of the other modules have an Apalache port and this one did
\* not, for no stated reason.
\*
\* WHAT IT BUYS. TLC enumerates every interleaving at the 2-peer bound. Apalache proves
\* `FramesNotInterleaved` **inductive**:
\*     base:  Init       => Inv
\*     step:  Inv /\ Next => Inv'
\* Both NoError ⇒ no execution of any length can interleave two frames' bytes — not "none was
\* found at the bound". For a byte-level integrity property that distinction is the whole
\* point: an interleaving that needs a long run to set up is exactly what a bounded check
\* misses.
\*
\* LIVENESS IS NOT HERE, and cannot be. `EventuallyResolved` — the Class-G deadlock property
\* — is a temporal/liveness claim; Apalache does safety and induction by construction. The
\* deadlock result stays TLC + Spin at the bound. That is a tool limit, stated, not a gap.
\*
\* THE ABSTRACTION (D11). This is a typed HAND-PORT of Reentry's data layer. The PlusCal
\* pc/control is abstracted into explicit `cphase` / `sphase` lifecycle fields, which is the
\* same shape the other *Apalache ports take. A wire frame is two chunks, as in Reentry —
\* the minimum granularity at which "two frames' bytes interleaved" is expressible.
\* The dispatch gate is TRUE, as in Reentry (see that module's declared limit; denial is
\* modeled in Authority).
EXTENDS Integers, FiniteSets

CONSTANTS
  \* @type: Bool;
  Serialized,   \* TRUE = §6.11(a) defect: hold the write lock across the send+recv cycle
  \* @type: Bool;
  AtomicFrame,  \* TRUE = §6.11(a′): the write lock is held for one frame's bytes
  \* @type: Int;
  N             \* NUMBER OF PEERS — was hard-wired to 2. See Reentry.tla §THE PEER BOUND.

\* Peers are INTEGERS, matching Reentry.tla: the dispatch topology is a directed ring, and
\* `Other(p) == IF p = "A" THEN "B" ELSE "A"` was not a low bound but the assertion that every
\* peer has exactly one counterparty. It also CONFLATED two peers — the one a peer dispatches
\* to (Succ) and the one whose request it answers (Pred) — which coincide iff N = 2.
Peers == 1..N
\* @type: Int => Int;
Succ(p) == IF p = N THEN 1 ELSE p + 1
\* @type: Int => Int;
Pred(p) == IF p = 1 THEN N ELSE p - 1

VARIABLES
  \* @type: Int -> Str;
  wlock,        \* §6.11(a)/(a′) per-connection write lock: "free" | "client" | "server"
  \* @type: Int -> Set(Str);
  midframe,     \* §6.11(a′) who holds a partially-written frame on peer p's connection
  \* @type: Bool;
  interleaved,  \* §6.11(a′) latched violation flag
  \* @type: Int -> Str;
  cphase,       \* client lifecycle: "init" | "midframe" | "sent" | "done"
  \* @type: Int -> Str;
  sphase,       \* server lifecycle: "idle" | "serving" | "midframe" | "done"
  \* @type: Int -> Bool;
  inReq,        \* an inbound request awaits peer p's server
  \* @type: Int -> Bool;
  resp          \* a response has been routed back to peer p's client

vars == << wlock, midframe, interleaved, cphase, sphase, inReq, resp >>

CPhases == {"init", "midframe", "sent", "done"}
SPhases == {"idle", "serving", "midframe", "done"}
Locks   == {"free", "client", "server"}

\* ----- the property (transcribed from Reentry.tla) -----
\* §6.11(a′): the bytes of two distinct frames never interleave on a pooled connection.
FramesNotInterleaved == ~interleaved

\* ----- the inductive strengthening -----
\* This is the load-bearing part, and it is exactly the argument §6.11(a′) makes in prose:
\* per-frame write serialization means the lock is HELD FOR THE FRAME, so at most one writer
\* can be mid-frame and the lock names which one. Those three facts together make
\* ~interleaved inductive; without them the step case fails, because from an arbitrary state
\* with two writers mid-frame a chunk-write sets the flag.
FrameSound ==
  /\ \A p \in Peers : Cardinality(midframe[p]) <= 1
  /\ \A p \in Peers : (cphase[p] = "midframe") <=> ("client" \in midframe[p])
  /\ \A p \in Peers : (sphase[p] = "midframe") <=> ("server" \in midframe[p])
  /\ \A p \in Peers : \A w \in midframe[p] : wlock[p] = w

TypeOK ==
  /\ interleaved \in BOOLEAN   \* assignment form for the flag (Apalache needs it in IndInit)
  /\ wlock    \in [Peers -> Locks]
  /\ midframe \in [Peers -> SUBSET {"client", "server"}]
  /\ cphase   \in [Peers -> CPhases]
  /\ sphase   \in [Peers -> SPhases]
  /\ inReq    \in [Peers -> BOOLEAN]
  /\ resp     \in [Peers -> BOOLEAN]

InvFrame == TypeOK /\ FrameSound /\ FramesNotInterleaved

\* ----- transitions (data layer of Reentry.tla) -----
Init ==
  /\ wlock       = [p \in Peers |-> "free"]
  /\ midframe    = [p \in Peers |-> {}]
  /\ interleaved = FALSE
  /\ cphase      = [p \in Peers |-> "init"]
  /\ sphase      = [p \in Peers |-> "idle"]
  /\ inReq       = [p \in Peers |-> FALSE]
  /\ resp        = [p \in Peers |-> FALSE]

\* §6.11(a′) first chunk of the client's request frame. Under (a′) this takes the write lock.
CFrame1(p) ==
  /\ cphase[p] = "init"
  /\ (AtomicFrame => wlock[p] = "free")
  /\ interleaved' = (interleaved \/ midframe[p] # {})
  /\ midframe' = [midframe EXCEPT ![p] = @ \cup {"client"}]
  /\ wlock' = [wlock EXCEPT ![p] = IF AtomicFrame THEN "client" ELSE "free"]
  /\ cphase' = [cphase EXCEPT ![p] = "midframe"]
  /\ UNCHANGED << sphase, inReq, resp >>

\* Last chunk of the same frame; deliver; release at END OF FRAME (or hold it across the
\* recv, which is the §6.11(a) Serialized defect).
CFrame2(p) ==
  /\ cphase[p] = "midframe"
  /\ interleaved' = (interleaved \/ midframe[p] # {"client"})
  /\ midframe' = [midframe EXCEPT ![p] = @ \ {"client"}]
  /\ inReq' = [inReq EXCEPT ![Succ(p)] = TRUE]
  /\ cphase' = [cphase EXCEPT ![p] = "sent"]
  /\ wlock' = [wlock EXCEPT ![p] = IF Serialized THEN "client" ELSE "free"]
  /\ UNCHANGED << sphase, resp >>

\* A writer releases only a lock IT holds. Under the §6.11 fix the client already released
\* at end-of-frame (CFrame2), so by the time the response arrives the lock may belong to this
\* peer's OWN SERVER, mid-frame. Freeing it here would be releasing a lock we do not hold —
\* see the note in Reentry.tla; this guard is what that finding fixed.
CRecv(p) ==
  /\ cphase[p] = "sent"
  /\ resp[p]
  /\ wlock' = [wlock EXCEPT ![p] = IF wlock[p] = "client" THEN "free" ELSE wlock[p]]
  /\ cphase' = [cphase EXCEPT ![p] = "done"]
  /\ UNCHANGED << midframe, interleaved, sphase, inReq, resp >>

\* §6.5 gate then handler entry (gate abstracted TRUE, as in Reentry).
SGate(p) ==
  /\ sphase[p] = "idle"
  /\ inReq[p]
  /\ sphase' = [sphase EXCEPT ![p] = "serving"]
  /\ UNCHANGED << wlock, midframe, interleaved, cphase, inReq, resp >>

\* The handler reenters and writes the response frame on the SAME pooled connection.
SFrame1(p) ==
  /\ sphase[p] = "serving"
  /\ (AtomicFrame => wlock[p] = "free")
  /\ interleaved' = (interleaved \/ midframe[p] # {})
  /\ midframe' = [midframe EXCEPT ![p] = @ \cup {"server"}]
  /\ wlock' = [wlock EXCEPT ![p] = IF AtomicFrame THEN "server" ELSE "free"]
  /\ sphase' = [sphase EXCEPT ![p] = "midframe"]
  /\ UNCHANGED << cphase, inReq, resp >>

SFrame2(p) ==
  /\ sphase[p] = "midframe"
  /\ interleaved' = (interleaved \/ midframe[p] # {"server"})
  /\ midframe' = [midframe EXCEPT ![p] = @ \ {"server"}]
  /\ resp' = [resp EXCEPT ![Pred(p)] = TRUE]
  /\ sphase' = [sphase EXCEPT ![p] = "done"]
  /\ wlock' = [wlock EXCEPT ![p] = "free"]
  /\ UNCHANGED << cphase, inReq >>

Next ==
  \/ \E p \in Peers : (CFrame1(p) \/ CFrame2(p) \/ CRecv(p)
                       \/ SGate(p) \/ SFrame1(p) \/ SFrame2(p))
  \/ UNCHANGED vars

\* ----- inductive-step init -----
IndInitFrame == TypeOK /\ FrameSound /\ FramesNotInterleaved

\* ----- constant inits -----
\* The §6.11 fix: concurrent dispatch (a) AND per-frame write serialization (a′).
ConstInitOK        == Serialized = FALSE /\ AtomicFrame = TRUE /\ N = 2
\* NEG CONTROL: (a′) dropped — a yielding write primitive. Frames interleave.
ConstInitBugFrame  == Serialized = FALSE /\ AtomicFrame = FALSE /\ N = 2

\* The same two at THREE peers. This is what makes the N=3 result in Reentry.tla more than a
\* bounded check: TLC enumerates every 3-peer interleaving, Apalache proves FramesNotInterleaved
\* INDUCTIVE at N=3 — no execution of any length interleaves two frames' bytes on a 3-ring.
ConstInitOK3       == Serialized = FALSE /\ AtomicFrame = TRUE  /\ N = 3
ConstInitBugFrame3 == Serialized = FALSE /\ AtomicFrame = FALSE /\ N = 3
\* The (a) defect holds the lock across recv. SAFETY still holds here — over-holding the lock
\* is byte-safe — which is why this control belongs to the LIVENESS side (TLC/Spin) and is
\* listed here only to make that split explicit rather than silent.
ConstInitSerialized == Serialized = TRUE /\ AtomicFrame = TRUE /\ N = 2
====
