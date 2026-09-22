---- MODULE StoreApalache ----
\* Apalache (SMT) cross-check of the Store module (tla/Store.tla), cross-check #A per
\* docs/HANDOFF-CROSSCHECK.md Track A. A typed HAND-PORT of Store's data layer — the
\* per-request lifecycle (rstate), the in-flight accounting (pending), the shared content
\* store (store) and, new at 0.8.2, the §4.8 content-store LIFETIME REFCOUNT (rc/holders).
\*
\* 0.8.2 RE-TARGET (spec-data/v0.8.2/). Two changes, mirroring tla/Store.tla:
\*   (1) §4.8 gained the refcount sentence (0.8.1, RT-13a): "an unsynchronized refcount
\*       decrement from concurrent dispatch is a use-after-free, i.e. the §4.9 no-crash
\*       class". Modeled here as `rc` (the implementation's counter — the only racy object)
\*       against `holders` (ground truth), with the read-modify-write SPLIT when SyncRefs is
\*       FALSE. NoUseAfterFree is the new property; RefcountSound is what makes it inductive.
\*   (2) Multi-key store (3 keys against MaxStore = 2). At v0.8.0 this module declared
\*       `store \in SUBSET {"k"}` — cardinality <= 1 by construction — while asserting
\*       `Cardinality(store) <= MaxStore = 2`. That conjunct COULD NOT FAIL; it was a vacuous
\*       proof obligation disclosed in PROPERTIES.md §C.4 at Phase 1 and never fixed. It is
\*       fixed here: with 3 reachable keys the bound is falsifiable, and what discharges it
\*       is refcount correctness (a key is live exactly while some request holds a reference).
\*
\* The PlusCal pc/control is abstracted to the underlying data transitions. The single-writer
\* discipline (§4.8) is the gate on entering the write critical section; the §4.9(b) admission
\* bound is the `pending < MaxPending` gate. The invariants are state predicates over the data,
\* so this is faithful — same abstraction the TLA+ model makes.
\*
\* What this buys over TLC (the point of the cross-check): TLC ENUMERATES states at the bound;
\* Apalache proves the invariants INDUCTIVE via Z3 —
\*   base:  Init        => Inv
\*   step:  Inv /\ Next  => Inv'
\* both NoError ⇒ the invariant holds for EVERY reachable state symbolically (unbounded in
\* steps), not just the enumerated ones. The negative-control ConstInits (Serialize=FALSE /
\* Admit=FALSE / SyncRefs=FALSE) make Apalache report a counterexample exactly where TLC's
\* StoreRaceBug / StoreAdmitBug / StoreRefcountBug do — the two tools agree on the secure
\* design AND on the defects.
EXTENDS Integers, FiniteSets

CONSTANTS
  \* @type: Int;
  MaxPending,   \* §4.9(b)/§4.10: admission bound on admitted-not-yet-responded requests
  \* @type: Int;
  MaxStore,     \* §4.8/§4.9(b): live-key bound on the content store
  \* @type: Bool;
  Serialize,    \* TRUE = §4.8 single-writer store-safety gate; FALSE = neg control (data race)
  \* @type: Bool;
  Admit,        \* TRUE = §4.9(b)/§4.10 admission bound enforced; FALSE = neg control (unbounded pending)
  \* @type: Bool;
  SyncRefs      \* TRUE = §4.8 refcount RMW atomic; FALSE = neg control (split RMW -> use-after-free)

\* Four concurrent per-request dispatch activities over three store keys — fixed + small,
\* matching the TLC bound (NReq = 4). The inductive argument is unbounded in STEPS over this
\* request set, exactly as RevokeApalache fixes Peers = {"A","B"}.
Reqs == {1, 2, 3, 4}
StoreKeys == {"k1", "k2", "k3"}

\* Requests 1 and 2 SHARE "k1" — the refcount contention point (two concurrent referrers to
\* one entity is the minimum shape that can free an entity under a live referrer).
\* @type: Int => Str;
Key(r) == IF r <= 2 THEN "k1" ELSE IF r = 3 THEN "k2" ELSE "k3"

VARIABLES
  \* @type: Int -> Str;
  rstate,       \* per-request lifecycle (see States)
  \* @type: Int;
  pending,      \* §4.9(c): admitted requests not yet responded
  \* @type: Set(Str);
  store,        \* §4.8 content store — the set of LIVE keys
  \* @type: Str -> Int;
  rc,           \* §4.8 (RT-13a) lifetime refcount — the implementation's counter (racy)
  \* @type: Str -> Set(Int);
  holders,      \* ground truth: which requests still reference each key
  \* @type: Int -> Int;
  tmp           \* per-request local: the value read from rc during a SPLIT (unsynchronized) RMW

vars == << rstate, pending, store, rc, holders, tmp >>

\* "acq" and "rel" are the half-completed states of a SPLIT read-modify-write: the truth
\* (holders/store) has moved but the counter write-back has not landed yet. They are
\* reachable only when SyncRefs = FALSE.
States == {"new", "rej413", "rej400", "ref503", "acq", "admitted", "writing", "rel", "responded"}

\* §4.8 store-safety: at most one request inside the write critical section.
Writing == {r \in Reqs : rstate[r] = "writing"}

\* §4.9(c): admitted and not yet responded — pending is exactly its size.
InFlight == {r \in Reqs : rstate[r] \in {"acq", "admitted", "writing"}}

\* ----- the safety invariants (transcribed from Store.tla's define block) -----
StoreRaceFree   == Cardinality(Writing) <= 1                                  \* §4.8
ResourceBounded == pending <= MaxPending /\ Cardinality(store) <= MaxStore    \* §4.9(b)/§4.10
NoUseAfterFree  == \A k \in StoreKeys : (k \notin store) => (holders[k] = {})  \* §4.8 RT-13a

\* ----- type/domain invariant (the inductive strengthening) -----
\* The linking invariants are the real strengthening:
\*   pending = |InFlight|          ties the counter to the lifecycle (no underflow from an
\*                                 arbitrary step-state; makes the §4.9(b) gate load-bearing)
\*   holders[k] \subseteq keys of  a request only ever holds ITS OWN key, which is what lets
\*     requests mapped to k        |holders[k]| be bounded and `store` be bounded by MaxPending
\*   r \in holders[Key(r)] <=>     a request holds its reference exactly across its admitted
\*     rstate[r] \in Live          lifetime (acquire-on-admit / release-on-respond)
TypeOK ==
  /\ rstate \in [Reqs -> States]
  /\ store \in SUBSET StoreKeys
  /\ rc \in [StoreKeys -> 0..4]
  /\ holders \in [StoreKeys -> SUBSET Reqs]
  /\ tmp \in [Reqs -> 0..4]
  /\ pending = Cardinality(InFlight)
  \* a request appears only in ITS OWN key's holder set, and exactly while it is live
  /\ \A r \in Reqs : \A k \in StoreKeys :
        (r \in holders[k]) <=> (k = Key(r) /\ rstate[r] \in {"acq", "admitted", "writing"})

\* The SYNCHRONIZED discipline's characteristic property: the counter never diverges from the
\* truth, and a key is in the store exactly while it has a live referrer. NoUseAfterFree is an
\* immediate corollary — which is precisely why the synchronized design is safe and the split
\* one is not. Under SyncRefs the half-completed split states are unreachable.
RefcountSound ==
  /\ \A r \in Reqs : rstate[r] \notin {"acq", "rel"}
  /\ \A k \in StoreKeys : rc[k] = Cardinality(holders[k])
  /\ \A k \in StoreKeys : (k \in store) <=> (holders[k] # {})

\* Inv == TypeOK /\ <property>; TypeOK (+ RefcountSound for the refcount property) is the
\* strengthening that makes each property inductive.
InvRace  == TypeOK /\ RefcountSound /\ StoreRaceFree
InvBound == TypeOK /\ RefcountSound /\ ResourceBounded
InvUAF   == TypeOK /\ RefcountSound /\ NoUseAfterFree

\* UNSTRENGTHENED form, for the SyncRefs = FALSE negative control ONLY. RefcountSound asserts
\* the split states are unreachable, so under ConstInitBugRefs it is FALSE and any inductive
\* obligation carrying it would be vacuously satisfied — a green that means nothing. The
\* refcount negative control is therefore a BOUNDED reachability run from Init against this
\* predicate (see the Makefile's APALACHE_NEG row), not an inductive one.
InvUAFPlain == TypeOK /\ NoUseAfterFree

\* ----- transitions (data layer of Store.tla's AdmitStep / WBegin / WCommit / RefRelCommit) -----
Init ==
  /\ rstate = [r \in Reqs |-> "new"]
  /\ pending = 0
  /\ store = {}
  /\ rc = [k \in StoreKeys |-> 0]
  /\ holders = [k \in StoreKeys |-> {}]
  /\ tmp = [r \in Reqs |-> 0]

\* §4.10 admission, in order: over-size -> 413; else over-depth -> 400; else §4.9(b)
\* back-pressure when the in-flight bound is reached -> 503; else admit. On ADMIT the request
\* also ACQUIRES its content-store reference (§4.8) — acquire-on-admit is what ties the
\* reference lifetime to the admitted lifetime and makes the live-key bound follow from the
\* admission bound. The caller (possibly adversarial) chooses payload size + chain depth.
\* DNF (one disjunct per outcome) so Apalache's assignment finder sees every variable assigned
\* on every branch — IF/THEN/ELSE + UNCHANGED defeats it (assignment-before-use).
Admit_(r) ==
  /\ rstate[r] = "new"
  /\ \E payOver \in BOOLEAN : \E depOver \in BOOLEAN :
       \/ /\ payOver                                              \* §4.10(a) 413 payload_too_large
          /\ rstate' = [rstate EXCEPT ![r] = "rej413"]
          /\ pending' = pending /\ store' = store /\ rc' = rc
          /\ holders' = holders /\ tmp' = tmp
       \/ /\ ~payOver /\ depOver                                  \* §4.10(b) 400 chain_depth_exceeded
          /\ rstate' = [rstate EXCEPT ![r] = "rej400"]
          /\ pending' = pending /\ store' = store /\ rc' = rc
          /\ holders' = holders /\ tmp' = tmp
       \/ /\ ~payOver /\ ~depOver /\ Admit /\ pending >= MaxPending  \* §4.9(b) clean 503 refusal
          /\ rstate' = [rstate EXCEPT ![r] = "ref503"]
          /\ pending' = pending /\ store' = store /\ rc' = rc
          /\ holders' = holders /\ tmp' = tmp
       \/ /\ ~payOver /\ ~depOver /\ ~(Admit /\ pending >= MaxPending)  \* admitted -> owes a response
          \* truth + liveness move atomically; the COUNTER is what may lag
          /\ rstate' = [rstate EXCEPT ![r] = IF SyncRefs THEN "admitted" ELSE "acq"]
          /\ pending' = pending + 1
          /\ holders' = [holders EXCEPT ![Key(r)] = @ \cup {r}]
          /\ store' = store \cup {Key(r)}
          /\ rc' = IF SyncRefs THEN [rc EXCEPT ![Key(r)] = @ + 1] ELSE rc
          /\ tmp' = [tmp EXCEPT ![r] = rc[Key(r)]]

\* Write-back half of the SPLIT acquire (unreachable when synchronized). If a second request
\* read the same value before this write lands, that increment is LOST.
AcqCommit(r) ==
  /\ rstate[r] = "acq"
  /\ rstate' = [rstate EXCEPT ![r] = "admitted"]
  /\ rc' = [rc EXCEPT ![Key(r)] = tmp[r] + 1]
  /\ UNCHANGED << pending, store, holders, tmp >>

\* §4.8 write critical section entry under the single-writer discipline: Serialize gates entry
\* on an empty section (no current writer); the neg control drops the gate so two can enter.
WBegin(r) ==
  /\ rstate[r] = "admitted"
  /\ (Serialize => Cardinality(Writing) = 0)
  /\ rstate' = [rstate EXCEPT ![r] = "writing"]
  /\ UNCHANGED << pending, store, rc, holders, tmp >>

\* §4.9(c): respond, leave the critical section, and RELEASE the §4.8 reference. Under SyncRefs
\* the decrement and free-decision are in this same atomic step as the truth update, so `rc = 0`
\* and `holders = {}` cannot disagree.
WCommit(r) ==
  /\ rstate[r] = "writing"
  /\ rstate' = [rstate EXCEPT ![r] = IF SyncRefs THEN "responded" ELSE "rel"]
  /\ pending' = pending - 1
  /\ holders' = [holders EXCEPT ![Key(r)] = @ \ {r}]
  /\ rc' = IF SyncRefs THEN [rc EXCEPT ![Key(r)] = @ - 1] ELSE rc
  /\ store' = IF SyncRefs /\ rc[Key(r)] - 1 = 0 THEN store \ {Key(r)} ELSE store
  /\ tmp' = [tmp EXCEPT ![r] = rc[Key(r)]]

\* Write-back half of the SPLIT release, and FREE when the COUNTER says zero — the exact
\* sentence §4.8 adds at 0.8.1. Once the counter has lost an update (or is applying a stale
\* read) it reads zero while a referrer is still live, and the entity is freed under it.
RelCommit(r) ==
  /\ rstate[r] = "rel"
  /\ rstate' = [rstate EXCEPT ![r] = "responded"]
  /\ rc' = [rc EXCEPT ![Key(r)] = IF tmp[r] > 0 THEN tmp[r] - 1 ELSE 0]
  /\ store' = IF tmp[r] - 1 <= 0 THEN store \ {Key(r)} ELSE store
  /\ UNCHANGED << pending, holders, tmp >>

Next ==
  \/ \E r \in Reqs : (Admit_(r) \/ AcqCommit(r) \/ WBegin(r) \/ WCommit(r) \/ RelCommit(r))
  \/ UNCHANGED vars

\* ----- inductive-step inits: arbitrary typed state satisfying the invariant -----
IndInitRace  == TypeOK /\ RefcountSound /\ StoreRaceFree
IndInitBound == TypeOK /\ RefcountSound /\ ResourceBounded
IndInitUAF   == TypeOK /\ RefcountSound /\ NoUseAfterFree

\* ----- constant inits (correct model + the three negative controls) -----
ConstInitOK       == MaxPending = 2 /\ MaxStore = 2 /\ Serialize = TRUE  /\ Admit = TRUE  /\ SyncRefs = TRUE
ConstInitBugRace  == MaxPending = 2 /\ MaxStore = 2 /\ Serialize = FALSE /\ Admit = TRUE  /\ SyncRefs = TRUE   \* §4.8 gate dropped
ConstInitBugAdmit == MaxPending = 2 /\ MaxStore = 2 /\ Serialize = TRUE  /\ Admit = FALSE /\ SyncRefs = TRUE   \* §4.9(b) bound dropped
ConstInitBugRefs  == MaxPending = 2 /\ MaxStore = 2 /\ Serialize = TRUE  /\ Admit = TRUE  /\ SyncRefs = FALSE  \* §4.8 RT-13a refcount RMW split
====
