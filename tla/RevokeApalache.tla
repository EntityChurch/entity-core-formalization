---- MODULE RevokeApalache ----
\* Apalache (SMT) cross-check of the Revoke module (tla/Revoke.tla), cross-check #A per
\* docs/HANDOFF-CROSSCHECK.md Track A. A typed HAND-PORT of Revoke's data layer (markerWritten,
\* revObserved, t, banned) + the §5.10 Verdict1 definition + the two safety invariants. The
\* pc/control structure is abstracted to the underlying data transitions (Sample / Observe /
\* Write) — the invariants are state predicates over the data, so this is faithful.
\*
\* What this buys over TLC (the whole point of the cross-check): TLC ENUMERATES states at the
\* bound; Apalache proves the invariants are INDUCTIVE via Z3 —
\*   base:  Init        => Inv
\*   step:  Inv /\ Next  => Inv'
\* both NoError ⇒ the invariant holds for EVERY state symbolically (a second independent engine,
\* and an unbounded argument), not just the enumerated ones. The negative-control ConstInits make
\* Apalache report a counterexample, exactly where TLC's RevokeIgnoreBug / RevokeLeakBug do — so
\* the two tools agree on the secure design AND on the defects.
EXTENDS Integers

CONSTANTS
  \* @type: Bool;
  HonorRevocation,   \* §5.1: an observed revocation makes the cap fail every check
  \* @type: Bool;
  LeakLayer1         \* §5.10: FALSE = Layer-1 verdict ignores local policy (correct)

Peers == {"A", "B"}

VARIABLES
  \* @type: Bool;
  markerWritten,
  \* @type: Str -> Bool;
  revObserved,
  \* @type: Str -> Int;
  t,
  \* @type: Str -> Bool;
  banned

vars == << markerWritten, revObserved, t, banned >>

\* ----- §5.10 verdict (transcribed verbatim from Revoke.tla) -----
ChainValid == TRUE
TTLok(p)   == t[p] = 1
Verdict1(p) == /\ ChainValid
               /\ TTLok(p)
               /\ (IF HonorRevocation THEN ~revObserved[p] ELSE TRUE)
               /\ (IF LeakLayer1      THEN ~banned[p]      ELSE TRUE)

\* §5.1/§6.8: once observed, the cap fails every subsequent check.
RevokedNeverPasses == \A p \in Peers : revObserved[p] => ~Verdict1(p)

\* §5.10 cross-peer determinism MUST: same t and same observed-revocation => identical verdict.
VerdictFnOfLayer1 ==
  (t["A"] = t["B"] /\ revObserved["A"] = revObserved["B"]) => (Verdict1("A") = Verdict1("B"))

\* ----- type/domain invariant (the inductive strengthening) -----
TypeOK ==
  /\ markerWritten \in BOOLEAN
  /\ revObserved \in [Peers -> BOOLEAN]
  /\ t \in [Peers -> {1, 2}]      \* reachable t domain (Init=1, Sample in {1,2}) — §5.10 boundary
  /\ banned \in [Peers -> BOOLEAN]

\* The invariants we prove inductive (TypeOK strengthens each to be inductive).
InvDet  == TypeOK /\ VerdictFnOfLayer1
InvRev  == TypeOK /\ RevokedNeverPasses

\* ----- transitions (data layer of Revoke.tla's PSample / PSync / RWrite) -----
Init ==
  /\ markerWritten = FALSE
  /\ revObserved = [p \in Peers |-> FALSE]
  /\ t = [p \in Peers |-> 1]
  /\ banned = [p \in Peers |-> FALSE]

Sample(p) ==
  \E tv \in {1, 2} : \E bv \in BOOLEAN :
    /\ t' = [t EXCEPT ![p] = tv]
    /\ banned' = [banned EXCEPT ![p] = bv]
    /\ UNCHANGED << markerWritten, revObserved >>

Observe(p) ==
  /\ markerWritten
  /\ revObserved' = [revObserved EXCEPT ![p] = TRUE]
  /\ UNCHANGED << markerWritten, t, banned >>

Write ==
  /\ markerWritten' = TRUE
  /\ UNCHANGED << revObserved, t, banned >>

Next ==
  \/ Write
  \/ \E p \in Peers : (Sample(p) \/ Observe(p))
  \/ UNCHANGED vars

\* ----- inductive-step inits: arbitrary typed state satisfying the invariant -----
IndInitDet == TypeOK /\ VerdictFnOfLayer1
IndInitRev == TypeOK /\ RevokedNeverPasses

\* ----- constant inits (correct model + the two negative controls) -----
ConstInitOK      == HonorRevocation = TRUE  /\ LeakLayer1 = FALSE  \* §5.1 + §5.10 honored
ConstInitBugRev  == HonorRevocation = FALSE /\ LeakLayer1 = FALSE  \* neg ctrl: revocation ignored
ConstInitBugLeak == HonorRevocation = TRUE  /\ LeakLayer1 = TRUE   \* neg ctrl: Layer-2 leaks into verdict
====
