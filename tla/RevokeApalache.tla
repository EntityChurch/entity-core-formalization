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
  banned,
  \* @type: Str -> Int;
  \* §5.10 (0.8.1, W7 Knob 3): each peer's DECLARED skew tolerance — a Layer-1 input
  \* alongside `t`, per the clause's own words ("it introduces no concealed state").
  delta

vars == << markerWritten, revObserved, t, banned, delta >>

\* ----- §5.10 verdict (transcribed verbatim from Revoke.tla) -----
ChainValid == TRUE
\* §5.10 cross-clock temporal model (0.8.1, W7 Knob 3), the two DENY rules negated:
\*   `expires_at + delta < t -> DENY` and `t + delta < not_before -> DENY`,
\* window [not_before - delta, expires_at + delta]. NotBefore = ExpiresAt = 1 keeps the
\* pre-0.8.3 boundary; at delta = 0 this is `t[p] = 1` exactly, which is what the scalar
\* TLC row RevokeDeltaZero runs as the clause's own equivalence check.
NotBefore  == 1
ExpiresAt  == 1
TTLok(p)   == /\ NotBefore <= t[p] + delta[p]
              /\ t[p] <= ExpiresAt + delta[p]
Verdict1(p) == /\ ChainValid
               /\ TTLok(p)
               /\ (IF HonorRevocation THEN ~revObserved[p] ELSE TRUE)
               /\ (IF LeakLayer1      THEN ~banned[p]      ELSE TRUE)

\* §5.1/§6.8: once observed, the cap fails every subsequent check.
RevokedNeverPasses == \A p \in Peers : revObserved[p] => ~Verdict1(p)

\* §5.10 cross-peer determinism MUST: same t and same observed-revocation => identical verdict.
\* `delta` is in the antecedent because §5.10 puts it there: "two peers with different
\* declared `delta` may permissibly differ at the boundary, the same way different `t` does."
VerdictFnOfLayer1 ==
  (t["A"] = t["B"] /\ delta["A"] = delta["B"] /\ revObserved["A"] = revObserved["B"])
    => (Verdict1("A") = Verdict1("B"))

\* ----- type/domain invariant (the inductive strengthening) -----
TypeOK ==
  /\ markerWritten \in BOOLEAN
  /\ revObserved \in [Peers -> BOOLEAN]
  /\ t \in [Peers -> {1, 2}]      \* reachable t domain (Init=1, Sample in {1,2}) — §5.10 boundary
  /\ banned \in [Peers -> BOOLEAN]
  /\ delta \in [Peers -> {0, 1}]  \* reachable delta domain (Init=0, Sample in {0,1}) — W7 Knob 3

\* The invariants we prove inductive (TypeOK strengthens each to be inductive).
InvDet  == TypeOK /\ VerdictFnOfLayer1
InvRev  == TypeOK /\ RevokedNeverPasses

\* ----- transitions (data layer of Revoke.tla's PSample / PSync / RWrite) -----
Init ==
  /\ markerWritten = FALSE
  /\ revObserved = [p \in Peers |-> FALSE]
  /\ t = [p \in Peers |-> 1]
  /\ banned = [p \in Peers |-> FALSE]
  /\ delta = [p \in Peers |-> 0]

Sample(p) ==
  \E tv \in {1, 2} : \E bv \in BOOLEAN : \E dv \in {0, 1} :
    /\ t' = [t EXCEPT ![p] = tv]
    /\ banned' = [banned EXCEPT ![p] = bv]
    /\ delta' = [delta EXCEPT ![p] = dv]
    /\ UNCHANGED << markerWritten, revObserved >>

Observe(p) ==
  /\ markerWritten
  /\ revObserved' = [revObserved EXCEPT ![p] = TRUE]
  /\ UNCHANGED << markerWritten, t, banned, delta >>

Write ==
  /\ markerWritten' = TRUE
  /\ UNCHANGED << revObserved, t, banned, delta >>

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
