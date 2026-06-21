---- MODULE StoreApalache ----
\* Apalache (SMT) cross-check of the Store module (tla/Store.tla), cross-check #A per
\* docs/HANDOFF-CROSSCHECK.md Track A. A typed HAND-PORT of Store's data layer — the
\* per-request lifecycle (rstate), the in-flight accounting (pending), and the shared
\* content store (store) — plus the two §4.8 / §4.9(b) / §4.10 safety invariants.
\*
\* The PlusCal pc/control is abstracted to the underlying data transitions (Admit / WBegin /
\* WCommit). The single-writer discipline (§4.8) is the await-empty gate on entering the write
\* critical section, here `Serialize => no request is currently writing`; the §4.9(b) admission
\* bound is the `pending < MaxPending` gate. The invariants are state predicates over the data,
\* so this is faithful — same abstraction the TLA+ model makes.
\*
\* What this buys over TLC (the point of the cross-check): TLC ENUMERATES states at the bound;
\* Apalache proves the invariants INDUCTIVE via Z3 —
\*   base:  Init        => Inv
\*   step:  Inv /\ Next  => Inv'
\* both NoError ⇒ the invariant holds for EVERY reachable state symbolically (unbounded in
\* steps), not just the enumerated ones. The negative-control ConstInits (Serialize=FALSE /
\* Admit=FALSE) make Apalache report a counterexample exactly where TLC's StoreRaceBug /
\* StoreAdmitBug do — the two tools agree on the secure design AND on the defects.
EXTENDS Integers, FiniteSets

CONSTANTS
  \* @type: Int;
  MaxPending,   \* §4.9(b)/§4.10: admission bound on admitted-not-yet-responded requests
  \* @type: Int;
  MaxStore,     \* §4.8/§4.9(b): live-key bound on the content store
  \* @type: Bool;
  Serialize,    \* TRUE = §4.8 single-writer store-safety gate; FALSE = neg control (data race)
  \* @type: Bool;
  Admit         \* TRUE = §4.9(b)/§4.10 admission bound enforced; FALSE = neg control (unbounded pending)

\* Three concurrent per-request dispatch activities — fixed + small, matching the TLC bound
\* (NReq = 3). The inductive argument is unbounded in STEPS over this request set, exactly as
\* RevokeApalache fixes Peers = {"A","B"}.
Reqs == {1, 2, 3}
StoreKey == "k"   \* §4.8 single shared key — strongest concurrent-mutation contention point

VARIABLES
  \* @type: Int -> Str;
  rstate,       \* per-request lifecycle: new | rej413 | rej400 | ref503 | admitted | writing | responded
  \* @type: Int;
  pending,      \* §4.9(c): admitted requests not yet responded
  \* @type: Set(Str);
  store         \* §4.8 content store (set of live keys; only ever {} or {"k"})

vars == << rstate, pending, store >>

States == {"new", "rej413", "rej400", "ref503", "admitted", "writing", "responded"}

\* §4.8 store-safety: at most one request inside the write critical section. The set of
\* writers is derived from rstate (a request is "writing" iff it holds the section).
Writing == {r \in Reqs : rstate[r] = "writing"}

\* §4.9(c): requests that have been admitted and not yet responded — pending is exactly its size.
InFlight == {r \in Reqs : rstate[r] \in {"admitted", "writing"}}

\* ----- the safety invariants (transcribed from Store.tla's define block) -----
StoreRaceFree   == Cardinality(Writing) <= 1                       \* §4.8
ResourceBounded == pending <= MaxPending /\ Cardinality(store) <= MaxStore   \* §4.9(b)/§4.10

\* ----- type/domain invariant (the inductive strengthening) -----
\* store \subseteq {"k"} bounds the live-key count to <= 1 (single shared key) so the §4.9(b)
\* store bound is inductive; the rstate domain makes `Writing` well-defined.
\* The linking invariant `pending = |InFlight|` is the real inductive strengthening: it ties the
\* pending counter to the rstate lifecycle so (a) WCommit cannot underflow it from an arbitrary
\* step-state (a writer existing => pending >= 1) and (b) the §4.9(b) gate on `pending` correctly
\* bounds the in-flight set. It also gives Apalache a finite assignment for `pending` (0..3).
TypeOK ==
  /\ rstate \in [Reqs -> States]
  /\ store \in SUBSET {StoreKey}    \* = {{}, {"k"}}; `\in` is an Apalache assignment form (`\subseteq` is not)
  /\ pending = Cardinality(InFlight)

\* Inv == TypeOK /\ <property>; TypeOK is the strengthening that makes each property inductive.
InvRace  == TypeOK /\ StoreRaceFree
InvBound == TypeOK /\ ResourceBounded

\* ----- transitions (data layer of Store.tla's AdmitStep / WBegin / WCommit) -----
Init ==
  /\ rstate = [r \in Reqs |-> "new"]
  /\ pending = 0
  /\ store = {}

\* §4.10 admission, in order: over-size -> 413; else over-depth -> 400; else §4.9(b)
\* back-pressure when the in-flight bound is reached -> 503; else admit (pending++). The
\* caller (possibly adversarial) chooses payload size + chain depth.
\* DNF (one disjunct per admission outcome) so Apalache's assignment finder sees rstate'/pending'
\* assigned on every branch — IF/THEN/ELSE + UNCHANGED defeats it (assignment-before-use).
Admit_(r) ==
  /\ rstate[r] = "new"
  /\ \E payOver \in BOOLEAN : \E depOver \in BOOLEAN :
       \/ /\ payOver                                              \* §4.10(a) 413 payload_too_large
          /\ rstate' = [rstate EXCEPT ![r] = "rej413"]
          /\ pending' = pending
       \/ /\ ~payOver /\ depOver                                  \* §4.10(b) 400 chain_depth_exceeded
          /\ rstate' = [rstate EXCEPT ![r] = "rej400"]
          /\ pending' = pending
       \/ /\ ~payOver /\ ~depOver /\ Admit /\ pending >= MaxPending  \* §4.9(b) clean 503 refusal
          /\ rstate' = [rstate EXCEPT ![r] = "ref503"]
          /\ pending' = pending
       \/ /\ ~payOver /\ ~depOver /\ ~(Admit /\ pending >= MaxPending)  \* §4.9(c): admitted -> owes a response
          /\ rstate' = [rstate EXCEPT ![r] = "admitted"]
          /\ pending' = pending + 1
  /\ store' = store

\* §4.8 write critical section entry under the single-writer discipline: Serialize gates entry
\* on an empty section (no current writer); the neg control drops the gate so two can enter.
WBegin(r) ==
  /\ rstate[r] = "admitted"
  /\ (Serialize => Cardinality(Writing) = 0)
  /\ rstate' = [rstate EXCEPT ![r] = "writing"]
  /\ UNCHANGED << pending, store >>

\* §4.9(c): mutate the bounded store, respond, leave the critical section.
WCommit(r) ==
  /\ rstate[r] = "writing"
  /\ rstate' = [rstate EXCEPT ![r] = "responded"]
  /\ pending' = pending - 1
  /\ store' = store \cup {StoreKey}

Next ==
  \/ \E r \in Reqs : (Admit_(r) \/ WBegin(r) \/ WCommit(r))
  \/ UNCHANGED vars

\* ----- inductive-step inits: arbitrary typed state satisfying the invariant -----
IndInitRace  == TypeOK /\ StoreRaceFree
IndInitBound == TypeOK /\ ResourceBounded

\* ----- constant inits (correct model + the two negative controls) -----
ConstInitOK       == MaxPending = 2 /\ MaxStore = 2 /\ Serialize = TRUE  /\ Admit = TRUE
ConstInitBugRace  == MaxPending = 2 /\ MaxStore = 2 /\ Serialize = FALSE /\ Admit = TRUE   \* §4.8 gate dropped
ConstInitBugAdmit == MaxPending = 2 /\ MaxStore = 2 /\ Serialize = TRUE  /\ Admit = FALSE  \* §4.9(b) bound dropped
====
