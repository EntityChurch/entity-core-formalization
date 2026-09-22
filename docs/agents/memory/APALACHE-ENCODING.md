# Apalache encoding — what the SMT backend will and will not take

**Symptom that brings you here:** Apalache dies at the 2 GB cap, prints
*"v' is used before it is assigned"*, *"Trying to expand a set of functions"*, or a
`RECURSIVE` operator is rejected — or you are about to port a TLC module to Apalache and
want the shape that works before you spend a sweep finding it.

Every fact below was learned by OOM-killing the cap, not by reading documentation.

**A FOURTH ENCODER FACT, AND IT REPLACES THE FIRST ONE'S REMEDY.** Unrolling into a ladder of
nested operator definitions is the obvious port and it does not survive a *mutual* recursion:
`~HasLiveDesc` and `~SelfRevFull` are negated existentials, so they become universals, and
Apalache expands a universal over a fixed range into a conjunction — branching |Nodes|^2 per
level, |Nodes|^(2k) leaves at depth k. Four levels at N = 4 is 65536 copies of the base and the
cap dies. **Build the ladder as a chain of STATE VARIABLES instead**, one application of the
equation each (`lT1 = StepFrom(Base, TRUE)`, `lT2 = StepFrom(lT1, TRUE)`, …): linear, and the
whole module then checks in three seconds. Three sharp edges come with it — write the level as
a *function constructor* (`v = [x \in Nodes |-> …]`), because Apalache's assignment solver does
not recognise the equivalent pointwise `\A x : v[x] = …` and fails with *"v' is used before it
is assigned"*; `\E f \in [S -> BOOLEAN]` inside an invariant is rejected outright (*"Trying to
expand a set of functions"*) while the universal form is accepted, because the negation is
skolemized; and **the obligation changes shape**. A ladder must justify its DEPTH; a fixed point
must justify its EXISTENCE AND UNIQUENESS, and neither failure prints anything — a short ladder
computes a wrong Boolean silently and a second solution is chosen silently. Hence
`LadderIsFixedPoint*` (deep enough *and* a solution exists, in one query) and `FixedPointUnique*`
(so the ladder's answer is *the* answer), both in the green table.

Three encoder facts worth having before writing the next one, all learned by OOM-killing the
2 GB cap rather than by reading documentation. **Apalache does not support `RECURSIVE`**, so
fuel-bounded recursion has to be unrolled into a ladder — and *every ladder depth is then a
claim*, so `UnrollDeep`, `MaxOfExact` and `SpecWalkNeverExhausts` exist to check the depths
rather than assert them in a comment. **`InlinePass` expands the whole module before the
"leaving only relevant operators" pruning takes effect on term size**, so one expensive operator
kills *every* invariant in the file, including ones already measured green — which is exactly
how the `IF`-ladder `MaxOf` was found. And **the natural TLA+ is often the wrong encoding**:
`CHOOSE` compiles to an oracle per occurrence, `S \cup UNION {f(p) : p \in S}` nested is a
combinatorial blow-up, `<=>` duplicates both sides, and `SUBSET S` over a symbolically-sized `S`
is unbounded. Each has a cheap equivalent; each rewrite is a place a transcription can drift, so
each one is commented at its site with what it replaced and why.
