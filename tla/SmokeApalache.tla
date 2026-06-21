---- MODULE SmokeApalache ----
\* Apalache toolchain smoke — proves the SMT engine genuinely verifies, end-to-end, and
\* demonstrates the capability that motivates the cross-check: an INDUCTIVE invariant proven
\* for ALL reachable states (unbounded), not just enumerated at a finite bound like TLC.
\* This is a throwaway sanity spec, NOT a Core Protocol model.
EXTENDS Integers

VARIABLE
  \* @type: Int;
  x

Init == x = 0
Next == x' = x + 1

\* Safety: x is never negative. This invariant is already inductive:
\*   Init => Inv      (0 >= 0)
\*   Inv /\ Next => Inv'   (x >= 0  /\  x' = x+1  =>  x' >= 1 >= 0)
\* Apalache proves both one-step obligations via Z3 -> holds for ALL x, no bound.
Inv == x >= 0

\* Inductive-step init: assign x to an ARBITRARY integer satisfying Inv (the idiom for proving
\* inductiveness — the inv used as a predicate must also assign the variable, here via x \in Int).
\* Running  check --init=IndInit --next=Next --inv=Inv --length=1  proves Inv /\ Next => Inv'
\* for every x at once (symbolic, not enumerated) — the unbounded half of the inductive proof.
IndInit == x \in Int /\ Inv
====
