---- MODULE AttestRevokeApalache ----
\* ATTESTATION TRACK — Apalache (SMT) cross-check of tla/AttestRevoke.tla: §4.3's REVOCATION
\* recursion, the one `AttestLive` left as a per-node flag. This is the third and last
\* attestation module to get a second engine, and finishing it is what lets this track be
\* described as corroborated without a footnote.
\*
\* TRACK: `attestation` (TRACKS.toml). A bare §N.M means a section of EXTENSION-ATTESTATION.md
\* at this track's pin.
\*
\* IT ALSO SETTLES F5 AND SHARPENS IT INTO SOMETHING LARGER. See "F5" below; the short form is
\* that §4.3's liveness predicate can fail to have a value on a configuration where BOTH of its
\* graphs are acyclic, which is not what F5 said and is worse.
\*
\* WHAT A SECOND ENGINE BUYS HERE. `AttestRevoke` is an enumeration model, not a concurrency
\* one: `Next` is `UNCHANGED vars` and the state space IS the space of (supersedes, revocation,
\* attester, expiry) configurations on N nodes. TLC enumerates it; Apalache answers one SMT
\* query over it. Independent METHOD, same transcription — so a defect in either engine's search
\* is visible to the other, and a shared MISREADING of §4.3 survives both. That is the 5th wall
\* (../docs/ASSURANCE-MAP.md) and no engine moves it.
\*
\* THE TWO F4 FINDINGS ARE REPRODUCED, NOT RE-DERIVED. `SelfRevReadingsAgree` and
\* `LiveReadingsAgree` are checked in configs that expect a COUNTEREXAMPLE, exactly as
\* `AttestRevokeReading.cfg` / `AttestRevokeVerdict.cfg` do under TLC, on constants where
\* nothing is weakened. Same retirement condition: a green here means the section was amended
\* upstream and the row is RETIRED, not repaired.
\*
\* ═══ THE ENCODING: A CONSTRUCTED LADDER PLUS ITS OWN FIXED-POINT OBLIGATION ═══════════════
\* Apalache does not support `RECURSIVE`, and `AttestRevoke` has FOUR mutually recursive
\* operators (`Live`, `SelfRevFull`, `IsSelfRevoked`, `HasLiveDesc`) with — deliberately — no
\* fuel parameter: their termination is by construction, because `Init` there restricts both
\* pointers to lower-numbered nodes so every recursive call moves to a strictly higher index.
\*
\* THE OBVIOUS PORT IS AN UNROLLED LADDER OF OPERATORS AND IT DOES NOT FIT. `Lv_k(x)` written
\* as nested operator definitions was typechecked and OOM-KILLED THE 2 GB CAP on every invariant
\* that used the recursive reading. The reason is worth recording because it is not the usual
\* one: `~HasLiveDesc` and `~SelfRevFull` are NEGATED existentials, so they become universals,
\* and Apalache expands a universal over a fixed range into a conjunction — branching factor
\* |Nodes|^2 per level, |Nodes|^(2k) leaf copies at depth k. Four levels at N = 4 is 65536
\* copies of the base. (The structural reading, where the descendant path does not recurse at
\* all, ran in 22 seconds. Same file, same depth: the cost is in the recursion, not the ladder.)
\*
\* SO THE LADDER IS BUILT AS STATE VARIABLES INSTEAD OF AS NESTED OPERATORS. `lT1..lT3` and
\* `lF1..lF3` are each constrained by `Init` to ONE application of §4.3's equation to the level
\* below. Linear, not exponential: the whole module now checks in three seconds. Every recursive
\* call moves to a strictly higher index under `ConstInitOK`, so `lT3` is exact at N = 4 —
\* and THAT SENTENCE IS THE KIND OF CLAIM THIS REPO HAS LEARNED NOT TO LEAVE IN A COMMENT.
\* It is checked, by the row below.
\*
\* `LadderIsFixedPoint{Rec,Struct}` — `IsFP(lT3, TRUE)` — asserts that the top of the ladder
\* SATISFIES §4.3's equation. That single row discharges two obligations at once: the ladder is
\* deep enough (a short ladder is not a fixed point), and a solution EXISTS at all. Its
\* companion `FixedPointUnique{Rec,Struct}` asserts there is only one, so the ladder's answer is
\* THE answer rather than an answer. Together they are what makes `lT3[x]` a faithful
\* transcription of `AttestRevoke.tla`'s `Live(x, TRUE)`, and both are in the green table.
\*
\* Why that pair is not bookkeeping: a recursive definition IS its fixed point, so porting a
\* recursion to a constraint moves the burden from "is the depth right" to "does the equation
\* have exactly one solution" — and NEITHER FAILURE PRODUCES AN ERROR MESSAGE. A ladder one
\* level short computes a wrong Boolean and reports nothing; an equation with two solutions lets
\* the solver pick either and reports nothing.
\*
\* ═══ F5, MACHINE-CHECKED — AND THE READING-STAGE VERSION WAS TOO KIND ═════════════════════
\* F5 (docs/outbox/ROUTING-2026-09-07-ATTESTATION-CHAIN-WALKS.md) is filed as a READING:
\* §4.3's `has_live_transitive_descendant` is explicitly cycle-safe and says so ("cycle-safe via
\* a visited-set on content_hash"), while the revocation recursion four lines above it —
\* `is_attestation_live(rev, ctx, as_of=now)` — carries no visited set and no depth bound. Its
\* stated conclusion was that §4.3's termination therefore rests on the REVOCATION GRAPH being
\* acyclic, unstated, as the supersedes graph's acyclicity is unstated (docs/LEAN-SEAM.md O6).
\* AttestRevoke.tla could not check any of it: its `Init` restricts BOTH pointers to lower
\* indices, and its header says so.
\*
\* This module lifts the two restrictions SEPARATELY — and the first row run refuted the
\* hypothesis this paragraph was drafted to confirm. **PER-RELATION ACYCLICITY IS NOT ENOUGH.**
\* `ConstInitSupUnordered` leaves the supersedes pointer unordered and keeps the revocation
\* pointer ordered, and `FixedPointUniqueRec` is VIOLATED on a state where BOTH GRAPHS ARE
\* ACYCLIC:
\*
\*     supersedes (forward):  2 -> 3 -> 4 -> 1        a path. no cycle.
\*     revocations:           3 revokes 1, 4 revokes 1    no cycle.
\*     nothing expired; all four by the same attester except node 2
\*
\*     f[4] = ~expired[4] /\ ~HasLiveDesc(4) /\ ~SelfRevoked(4)
\*          = ...  and 4's only supersedes-descendant is 1, whose revokers are 3 and 4,
\*          so this reduces to  f[4] = f[3] \/ f[4],  which BOTH values satisfy.
\*
\* The dependency is `4 --supersedes-reach--> 1 --revoked-by--> 4`: a cycle in the COMPOSITION
\* of the two relations, with neither relation cyclic. §4.3's `visited` set is scoped to the
\* supersedes walk and the recursion ALTERNATES — `is_attestation_live` ->
\* `has_live_transitive_descendant` -> `is_self_revoked` -> `is_attestation_live` — so the one
\* stated defence does not span the hop that closes the loop.
\*
\* What actually makes §4.3 well defined is a COMMON ORDER over both relations, which is what
\* AttestRevoke.tla's index restriction imposes and what content addressing supplies in a
\* deployed system (both pointers name an entity that must already exist, so both point backward
\* in creation order). That is a strictly stronger assumption than "each graph is acyclic", it
\* is the assumption O6 records in its weaker form, and the document states neither.
\*
\* `ConstInitRevUnordered` is the other half and both readings break there
\* (`FixedPointUniqueRec` and `FixedPointUniqueStruct`), self-revocation being the smallest
\* witness. Rows are in tla/Makefile's `APALACHE_ENUM_FINDING`.
\*
\* WHAT THIS DOES NOT SAY. Nothing here claims such a configuration is REACHABLE in a deployed
\* system — content addressing is exactly the argument that it is not, and this module does not
\* verify that argument any more than O6 does. The finding is that the document defends one
\* recursion, the recursion alternates between two relations, and the property it actually needs
\* is a joint order that appears in no sentence of the spec.
\*
\* ═══ ENCODER NOTES, inherited from AttestLiveApalache's header ════════════════════════════
\* No `RECURSIVE`; `InlinePass` expands the whole module before pruning, so one expensive
\* operator kills EVERY invariant in the file including ones already measured green; `CHOOSE`
\* compiles to an oracle per occurrence; a set built by comprehension and then quantified over
\* (`\E d \in {d \in Nodes : R(x,d)} : P(d)`) is a value the encoder must construct, where
\* `\E d \in Nodes : R(x,d) /\ P(d)` is free; and `\E f \in [S -> BOOLEAN]` inside an invariant
\* is rejected outright ("Trying to expand a set of functions"), while the UNIVERSAL form is
\* accepted because Apalache skolemizes the negation — which is why existence is established by
\* construction here and uniqueness by quantification.
\*
\* THIS MODULE IS WRITTEN IN THE PREDICATE FORM THROUGHOUT — `AttestRevoke.tla`'s `Revs`,
\* `RevSet` and `Desc` are SETS there and membership predicates here. Each rewrite is a place a
\* transcription can drift, so the correspondence is spelled out rather than left to be
\* re-derived: `InRevSet(r, x)` is exactly `r \in RevSet(x)`, and `Reach(x, d)` is exactly
\* `d \in Desc(x)`.
\*
\* Fidelity (5th wall): AttestRevoke.tla's abstraction boundary, unchanged — signatures and
\* their verification, content hashing (a node's number stands in for its content hash), the
\* clock (one `expired` flag per node; the as_of parameter and not_before with it), the
\* properties map beyond whether an entity is a revocation, and every index. A revocation is an
\* edge, not an entity carrying `properties.kind`. Those sentences carry no § sigil deliberately
\* (../docs/COVERAGE-MATRIX.md section 3b).
EXTENDS Naturals

CONSTANTS
  \* @type: Int;
  N,
  \* @type: Set(Int);
  Peers,
  \* @type: Bool;
  AuthorityRevoke,
  \* @type: Bool;
  RecursiveMainRev,
  \* NOTE THE NAMES. These are INDEX-ORDER restrictions, not acyclicity: `sup[x] < x` forbids
  \* far more than a cycle, and the difference is the whole of the F5 result above. Calling
  \* them SupAcyclic/RevAcyclic — the first draft did — would have made the counterexample read
  \* as "a cycle was allowed and things broke", which is the opposite of what happened.
  \* @type: Bool;
  SupOrdered,
  \* @type: Bool;
  RevOrdered

VARIABLES
  \* @type: Int -> Int;
  sup,
  \* @type: Int -> Int;
  revt,
  \* @type: Int -> Int;
  attester,
  \* @type: Int -> Bool;
  expired,
  \* §4.3's liveness under the RECURSIVE reading of the undefined `is_self_revoked`, built as a
  \* three-level ladder over the base `Base` because Apalache has no `RECURSIVE` and the nested-
  \* operator form OOMs. `lT3` is the value; `lT1`/`lT2` exist so that each level is one
  \* application of the equation rather than a nested expansion of it.
  \* @type: Int -> Bool;
  lT1,
  \* @type: Int -> Bool;
  lT2,
  \* @type: Int -> Bool;
  lT3,
  \* ...and under the STRUCTURAL reading.
  \* @type: Int -> Bool;
  lF1,
  \* @type: Int -> Bool;
  lF2,
  \* @type: Int -> Bool;
  lF3

vars == << sup, revt, attester, expired, lT1, lT2, lT3, lF1, lF2, lF3 >>

\* AttestRevoke's own bound, and it is four rather than three because the divergence needs a
\* superseded attestation, its successor, a revocation of the successor, and a revocation of
\* that revocation. The ladder depth (3) is N - 1 and is checked by LadderIsFixedPoint*.
MaxN  == 4
Nodes == 1..N
NULL  == 0

\* ---------------------------------------------------------------------------------------
\* The two graphs, as RELATIONS. See the encoder note for why these are predicates here and
\* sets in AttestRevoke.tla.
\* ---------------------------------------------------------------------------------------

\* §3.1 supersedes points BACKWARD, so the forward edge a walk follows is the inverse.
\* find_attestations_with_supersedes carries no sigil: this model assumes that lookup's
\* contract and verifies nothing about it, exactly as AttestRevoke.tla does.
R1(a, b) == sup[b] = a
R2(a, b) == R1(a, b) \/ \E m \in Nodes : R1(a, m) /\ R1(m, b)
R3(a, b) == R1(a, b) \/ \E m \in Nodes : R2(a, m) /\ R1(m, b)
R4(a, b) == R1(a, b) \/ \E m \in Nodes : R3(a, m) /\ R1(m, b)

\* `Reach(x, d)` IS `d \in Desc(x)`. Three levels suffice at N = 4 — reachability in an N-node
\* graph saturates within N-1 edges WHETHER OR NOT THE GRAPH IS CYCLIC, which is why this module
\* can drop the supersedes ordering without touching the ladder. R4 is the comparison level
\* `UnrollDeep` measures against.
Reach(x, d) == R3(x, d)

\* The lookup find_revocations_for performs, with §4.3's `rev.attesting == att.attesting` filter
\* and §4.4's line that anything else is the consumer's business. `InRevSet(r, x)` IS
\* `r \in RevSet(x)`; under the AuthorityRevoke control the filter is dropped.
IsRevOf(r, x)  == revt[r] = x
InRevSet(r, x) == IsRevOf(r, x) /\ (AuthorityRevoke \/ attester[r] = attester[x])
HasRev(x)      == \E r \in Nodes : InRevSet(r, x)

\* ---------------------------------------------------------------------------------------
\* §4.3 AS A DEFINING EQUATION, with the undefined helper supplied BOTH WAYS.
\*
\* `rec = TRUE`  — `is_self_revoked` read as the main path's predicate: a matching revocation
\*                 that is itself live.
\* `rec = FALSE` — read structurally: a matching revocation exists.
\*
\* Each operator takes the liveness function as a PARAMETER rather than reading a global, so
\* that the ladder can apply it level by level and `FixedPointUnique*` can quantify over
\* candidate solutions.
\* ---------------------------------------------------------------------------------------

\* §4.3 MAIN path: a matching revocation that is itself live. `RecursiveMainRev` is the control
\* that flattens it.
\* @type: (Int -> Bool, Int) => Bool;
SrfOf(f, x) == \E r \in Nodes : InRevSet(r, x) /\ (RecursiveMainRev => f[r])

\* §4.3 DESCENDANT path: the undefined helper, both readings.
\* @type: (Int -> Bool, Int, Bool) => Bool;
IsrOf(f, x, rec) == IF rec THEN SrfOf(f, x) ELSE HasRev(x)

\* §4.3 has_live_transitive_descendant: the WEAK check — "not_expired AND not is_self_revoked",
\* deliberately not recursive through supersession, per §4.3's own anti-bistability comment.
\* @type: (Int -> Bool, Int, Bool) => Bool;
HldOf(f, x, rec) == \E d \in Nodes : Reach(x, d) /\ ~expired[d] /\ ~IsrOf(f, d, rec)

\* §4.3's composite, as the right-hand side of the equation.
\* @type: (Int -> Bool, Int, Bool) => Bool;
RhsOf(f, x, rec) == ~expired[x] /\ ~HldOf(f, x, rec) /\ ~SrfOf(f, x)

\* "f is a solution of §4.3's equations under this reading."
\* @type: (Int -> Bool, Bool) => Bool;
IsFP(f, rec) == \A x \in Nodes : f[x] = RhsOf(f, x, rec)

\* The ladder's base: the expiry check alone. EXACT at x = N — under an index order no node can
\* point back at the highest index, so both recursions are empty there — and wrong below it,
\* which is what the three levels above it exist to correct.
\* @type: Int -> Bool;
Base == [x \in Nodes |-> ~expired[x]]

\* One application of §4.3's equation to a level. `Init` chains these.
\*
\* Written as a FUNCTION CONSTRUCTOR rather than as the pointwise constraint
\* `\A x \in Nodes : next[x] = RhsOf(prev, x, rec)`, which is the same proposition and which
\* Apalache rejects in `Init` with "lT1' is used before it is assigned": its assignment solver
\* recognises `v = <expr>` and `v \in <set>` as assignments and a universally quantified
\* equation as an ordinary constraint, so the pointwise form leaves the variable unassigned.
\* @type: (Int -> Bool, Bool) => Int -> Bool;
StepFrom(prev, rec) == [x \in Nodes |-> RhsOf(prev, x, rec)]

\* ---------------------------------------------------------------------------------------
\* The operators the properties use, named as in AttestRevoke.tla so the two files read side
\* by side. `lT3` / `lF3` are the top of the ladder; LadderIsFixedPoint* is what entitles this
\* module to call them the liveness predicate.
\* ---------------------------------------------------------------------------------------
\* @type: (Bool) => Int -> Bool;
LiveFn(rec)           == IF rec THEN lT3 ELSE lF3
Live(x, rec)          == LiveFn(rec)[x]
SelfRevFull(x, rec)   == SrfOf(LiveFn(rec), x)
IsSelfRevoked(x, rec) == IsrOf(LiveFn(rec), x, rec)
HasLiveDesc(x, rec)   == HldOf(LiveFn(rec), x, rec)

\* THE THIRD READING — what one of the three sibling implementations does instead of the weak
\* check: ask whether any descendant is FULLY live, and compensate by descending past dead
\* links. `DescReadingsCoincide` is the check that this is not a divergence.
HasFullyLiveDesc(x) == \E d \in Nodes : Reach(x, d) /\ lT3[d]

\* ---------------------------------------------------------------------------------------
\* THE ENCODING'S OWN OBLIGATIONS — green rows, and the premise of every other green here.
\* ---------------------------------------------------------------------------------------

\* THE LADDER'S TOP SATISFIES §4.3's EQUATION. Discharges two things in one query: a solution
\* EXISTS (this is it, constructively), and three levels are ENOUGH (a short ladder does not
\* satisfy the equation it was built from). Fails at N = 5 — `ConstInitLadderShort`.
LadderIsFixedPointRec    == IsFP(lT3, TRUE)
LadderIsFixedPointStruct == IsFP(lF3, FALSE)

\* ...and it is the ONLY solution, so `lT3` is §4.3's predicate rather than one of several
\* things the equation permits. Written universally on purpose: the existential form over a
\* function set is rejected by the encoder (see the header).
FixedPointUniqueRec ==
  \A f, g \in [Nodes -> BOOLEAN] : (IsFP(f, TRUE) /\ IsFP(g, TRUE)) => f = g

FixedPointUniqueStruct ==
  \A f, g \in [Nodes -> BOOLEAN] : (IsFP(f, FALSE) /\ IsFP(g, FALSE)) => f = g

\* The reachability ladder has saturated. Written as an equality of the two DERIVED SETS rather
\* than pointwise with `<=>`, which desugars into two implications and duplicates both chains
\* (AttestLiveApalache OOM-killed the 2 GB cap on exactly that form).
UnrollDeep == \A x \in Nodes : {d \in Nodes : R3(x, d)} = {d \in Nodes : R4(x, d)}

\* ---------------------------------------------------------------------------------------
\* THE PROPERTIES — transcribed from AttestRevoke.tla, same names, same readings.
\* ---------------------------------------------------------------------------------------

\* FINDING (F4). The two readings of the undefined `is_self_revoked` are not the same predicate.
\* Checked on the green sweep's own constants; nothing is weakened.
SelfRevReadingsAgree == \A x \in Nodes : IsSelfRevoked(x, TRUE) = IsSelfRevoked(x, FALSE)

\* FINDING (F4's consequence), and the one that matters: the choice changes
\* `is_attestation_live`'s ANSWER, which is the predicate every consumer's authorization
\* decision runs through.
LiveReadingsAgree == \A x \in Nodes : Live(x, TRUE) = Live(x, FALSE)

\* §4.3 + §4.4 GREEN: the primitive's liveness check is self-revocation ONLY. `AuthorityRevoke`
\* is its control.
OnlySelfRevocationKills ==
  \A x \in Nodes :
    ( /\ ~expired[x]
      /\ ~HasLiveDesc(x, TRUE)
      /\ \A r \in Nodes : IsRevOf(r, x) => attester[r] # attester[x] ) => Live(x, TRUE)

\* §4.3 GREEN: a revocation that has itself been revoked does not kill its target — the
\* revocation-side twin of the predecessor-revival semantics §4.3 documents for supersession,
\* and unlike that one documented nowhere. `RecursiveMainRev` is its control.
DeadRevocationSpares ==
  \A x \in Nodes :
    ( /\ ~expired[x]
      /\ ~HasLiveDesc(x, TRUE)
      /\ HasRev(x)
      /\ \A r \in Nodes : InRevSet(r, x) => ~Live(r, TRUE) ) => Live(x, TRUE)

\* §4.3 GREEN, and a COHORT result rather than a spec result: the weak descendant check and the
\* fully-live one compute the same predicate on every acyclic graph.
DescReadingsCoincide == \A x \in Nodes : HasLiveDesc(x, TRUE) = HasFullyLiveDesc(x)

\* §4.3 GREEN, carried over from AttestLive: a live attestation never has a live descendant.
NoLiveAncestorOfLive ==
  \A x \in Nodes : Live(x, TRUE) => \A d \in Nodes : Reach(x, d) => ~Live(d, TRUE)

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Each asserted in order to be VIOLATED; the violation is the pass.
\* They carry a second job here that they did not carry in AttestRevoke.tla: `Init` constrains
\* six variables by equations, and an over-constrained `Init` admits NO state, in which case
\* every invariant above holds vacuously and Apalache reports OK. A violated witness is the
\* proof that `Init` is satisfiable at all.
\* ---------------------------------------------------------------------------------------

\* A revocation that is itself revoked, matching attesters both times, IS REACHED.
WitnessRevokedRevocation ==
  ~( \E x \in Nodes : \E r \in Nodes :
       InRevSet(r, x) /\ (\E s \in Nodes : InRevSet(s, r)) /\ ~Live(r, TRUE) )

\* Something is actually DEAD BY REVOCATION — otherwise every liveness green above is a
\* statement about a model in which revocation never fires.
WitnessRevocationKills ==
  ~( \E x \in Nodes : ~expired[x] /\ ~HasLiveDesc(x, TRUE) /\ ~Live(x, TRUE) )

\* Supersession actually FIRES. Without it `DescReadingsCoincide` is `FALSE = FALSE` everywhere
\* and `NoLiveAncestorOfLive` is vacuous.
WitnessSupersededByLive == ~(\E x \in Nodes : HasLiveDesc(x, TRUE))

\* ---------------------------------------------------------------------------------------
\* The configuration space. `Init` IS the model; `Next` stutters, because there is no
\* transition system here and pretending there is one would be the wrong model of a pure
\* function. Every check runs at --length=0: the claim is over graphs, not over runs.
\* ---------------------------------------------------------------------------------------
TypeOK == /\ sup      \in [Nodes -> Nodes \cup {NULL}]
          /\ revt     \in [Nodes -> Nodes \cup {NULL}]
          /\ attester \in [Nodes -> Peers]
          /\ expired  \in [Nodes -> BOOLEAN]

\* Both pointers restricted to lower indices is AttestRevoke.tla's hard-coded domain, and the
\* restriction is not a convenience: it is what makes §4.3's recursion well founded. Here each
\* half is a separate constant, because the recursion alternates between the two relations and
\* the cost of the missing assumption is only visible if they can be lifted independently.
Init == /\ sup \in [Nodes -> Nodes \cup {NULL}]
        /\ SupOrdered => \A x \in Nodes : sup[x] = NULL \/ sup[x] < x
        /\ revt \in [Nodes -> Nodes \cup {NULL}]
        /\ RevOrdered => \A x \in Nodes : revt[x] = NULL \/ revt[x] < x
        /\ attester \in [Nodes -> Peers]
        /\ expired \in [Nodes -> BOOLEAN]
        \* §4.3's equation, applied one level at a time. See the header for why this is a
        \* chain of state variables rather than a chain of operator definitions.
        /\ lT1 = StepFrom(Base, TRUE)  /\ lT2 = StepFrom(lT1, TRUE)  /\ lT3 = StepFrom(lT2, TRUE)
        /\ lF1 = StepFrom(Base, FALSE) /\ lF2 = StepFrom(lF1, FALSE) /\ lF3 = StepFrom(lF2, FALSE)

Next == UNCHANGED vars

\* ----- constant inits -----
\* Parity with the TLC green sweep: AttestRevoke.cfg's constants, plus the two order switches
\* set to what AttestRevoke.tla hard-codes.
ConstInitOK ==
  /\ N = 4 /\ Peers = {1, 2}
  /\ AuthorityRevoke = FALSE /\ RecursiveMainRev = TRUE
  /\ SupOrdered = TRUE /\ RevOrdered = TRUE

\* THE F4 FINDINGS, as rows: constants are the green sweep's — nothing is weakened.
ConstInitFinding == ConstInitOK

\* F5, HALF ONE — FINDING, and the one that refuted its own hypothesis. The supersedes pointer
\* is unordered; the revocation pointer is still ordered. The counterexample has NO CYCLE IN
\* EITHER GRAPH (header). Expected: counterexample on FixedPointUniqueRec.
ConstInitSupUnordered ==
  /\ N = 4 /\ Peers = {1, 2}
  /\ AuthorityRevoke = FALSE /\ RecursiveMainRev = TRUE
  /\ SupOrdered = FALSE /\ RevOrdered = TRUE

\* F5, HALF TWO — FINDING. The revocation pointer is unordered; self-revocation is the smallest
\* witness. Expected: counterexample on FixedPointUniqueRec AND FixedPointUniqueStruct — the
\* structural reading breaks here and not under half one, which is the asymmetry F5 is about.
ConstInitRevUnordered ==
  /\ N = 4 /\ Peers = {1, 2}
  /\ AuthorityRevoke = FALSE /\ RecursiveMainRev = TRUE
  /\ SupOrdered = TRUE /\ RevOrdered = FALSE

\* NEG CONTROL — the primitive drops §4.3's matching-attester filter and takes over the
\* consumer's authority rule. Expected: counterexample on OnlySelfRevocationKills.
ConstInitBugAuthority ==
  /\ N = 4 /\ Peers = {1, 2}
  /\ AuthorityRevoke = TRUE /\ RecursiveMainRev = TRUE
  /\ SupOrdered = TRUE /\ RevOrdered = TRUE

\* NEG CONTROL — the main path stops asking whether the revocation is itself live, so a dead
\* revocation goes on killing. Expected: counterexample on DeadRevocationSpares.
ConstInitBugFlat ==
  /\ N = 4 /\ Peers = {1, 2}
  /\ AuthorityRevoke = FALSE /\ RecursiveMainRev = FALSE
  /\ SupOrdered = TRUE /\ RevOrdered = TRUE

\* GUARD CONTROL — BOTH ladders have TEETH at N = 5, where each is one level short. `UnrollDeep`
\* must fail (reachability truncated) and `LadderIsFixedPointRec` must fail (the liveness ladder
\* no longer satisfies the equation it was built from). Without these rows MaxN = 4 is a promise
\* in a comment, and the failure mode they guard is the worst available to this module: every
\* other invariant green over a silently truncated graph or a silently wrong predicate. Run them
\* first if anyone raises N.
ConstInitLadderShort ==
  /\ N = 5 /\ Peers = {1, 2}
  /\ AuthorityRevoke = FALSE /\ RecursiveMainRev = TRUE
  /\ SupOrdered = TRUE /\ RevOrdered = TRUE
====
