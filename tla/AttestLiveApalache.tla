---- MODULE AttestLiveApalache ----
\* ATTESTATION TRACK — Apalache (SMT) cross-check of tla/AttestLive.tla: §4.3 composite
\* liveness, §5.2 the backward chain walk, §5.3 `find_live_head`, and §5.1's head-resolution
\* step. **This is the module that carries F1**, so it is the one where a second engine is
\* worth the most.
\*
\* TRACK: `attestation` (TRACKS.toml). A bare §N.M means a section of EXTENSION-ATTESTATION.md
\* at this track's pin.
\*
\* WHAT A SECOND ENGINE BUYS HERE, precisely. AttestLive is not a concurrency model: `Next` is
\* `UNCHANGED vars` and the state space is the space of supersedes GRAPHS, so TLC is an
\* exhaustive ENUMERATOR over every graph on N nodes. Apalache checks the same claims
\* SYMBOLICALLY — one SMT query over the graph space rather than 4^3 * 8 * 8 enumerated states.
\* It is a genuinely independent METHOD, not a second run of the same one: a defect in either
\* engine's search is visible to the other. What it does NOT buy is independence from the
\* transcription — this file and AttestLive.tla are two readings by the same author of the same
\* spec text, so a shared misreading survives both. That is the 5th wall and no engine moves it.
\*
\* SCOPE: N = 3, PARITY WITH TLC AND NOTHING MORE. An earlier draft of this header claimed the
\* greens were "re-proved at N = 4 and N = 5". They were not, and the claim is struck rather
\* than quietly deleted: the ladders below are cut to exactly what N = 3 needs, because the
\* deeper ones OOM-killed the 2 GB cap. Raising N is real future work — it needs R3/R4 extended,
\* the walk ladder re-justified at the new bound, and MaxN raised — and it is the one thing this
\* module could give that TLC cannot, so it is worth doing and is not done here.
\*
\* WHY THIS FILE UNROLLS ITS WALKS. Apalache does not support `RECURSIVE` operators. AttestLive
\* uses recursion in five places — the forward and backward closures, `LiveDF`, `SpecWalk` and
\* `BackWalk` — each already FUEL-BOUNDED in the TLC model for its own reasons, and fuel-bounded
\* recursion unrolls to a fixed composition. **The unrolling depth is the transcription risk in
\* this module**, so no depth here is asserted by comment: `UnrollDeep` checks that the
\* reachability ladder has reached its fixed point, `MaxOfExact` checks that the tie-break really
\* is the maximum, and the walk ladder's depth is justified by `SpecWalkNeverExhausts` rather
\* than by claim (see SpecHead).
\*
\* THE FINDING IS REPRODUCED, NOT RE-DERIVED. `SpecHeadFindsLiveHead` is checked in a config
\* that expects it to be VIOLATED, exactly as `AttestLiveSpecHead.cfg` does under TLC. Nothing
\* here is weakened to produce that violation: the constants are the green sweep's constants.
\* This is a `TLC_FINDING`-shaped row in Apalache's table, and the same retirement condition
\* applies — if it ever goes green, the defect was fixed upstream and the row is RETIRED, not
\* repaired.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): AttestLive.tla's abstraction boundary,
\* unchanged — signatures and their verification, content hashing (a node's number stands in
\* for its content hash and the numeric order for hash order), the not_before/expires_at clock
\* (collapsed into one per-node flag, so the `as_of` parameter is out of scope), revocation as
\* an attestation entity (a per-node flag), and the properties map entirely.
\* `Apalache` is extended for ApaFoldSet; see MaxOf for why the natural TLA+ form is not used.
EXTENDS Naturals, FiniteSets, Apalache

CONSTANTS
  \* @type: Int;
  N,
  \* @type: Bool;
  AllowCycles,
  \* @type: Bool;
  LiveTransitive,
  \* @type: Bool;
  DagFiltersLive

VARIABLES
  \* @type: Int -> Int;
  sup,
  \* @type: Int -> Bool;
  expired,
  \* @type: Int -> Bool;
  selfrev

vars == << sup, expired, selfrev >>

\* The ladders below are cut to what N = 3 needs. MaxN is the bound they are valid for, and it
\* is checked, not asserted: `UnrollDeep` fails if the reachability ladder is short.
MaxN  == 3
Nodes == 1..N
NULL  == 0

\* §3.1 supersedes points BACKWARD, so the forward edges §4.3/§5.3 walk are the inverse.
\* No sigil on find_attestations_with_supersedes deliberately: this model ASSUMES that
\* lookup's contract and verifies nothing about it (AttestLive.tla makes the same disposition).
Succ(p)   == {c \in Nodes : sup[c] = p}
PredOf(p) == IF sup[p] = NULL THEN {} ELSE {sup[p]}

\* ----- forward reachability, as a RELATION rather than an iterated set construction -----
\* AttestLive.tla computes the closure by growing a SET to a fixed point (`GrowF`). Transcribed
\* literally that becomes `S \cup UNION {Succ(p) : p \in S}` nested once per unrolling level,
\* and Apalache's inliner OOM-killed the 2 GB cap on it — a set-of-sets comprehension nested
\* six deep is a combinatorial blow-up in the encoder even though the value is tiny.
\*
\* `Rk(a,b)` = "b is reachable from a by a forward path of length 1..k" is the same closure as
\* a pure BOOLEAN predicate with one existential per level, which the SMT backend handles
\* directly. Within N nodes every reachable node is reachable in at most N-1 steps, so R3
\* saturates for N = 3 and R4 is the extra level `UnrollDeep` compares against to prove it. The
\* sets are derived from the relation and are never themselves built by iteration.
R1(a, b) == sup[b] = a
R2(a, b) == R1(a, b) \/ \E m \in Nodes : R1(a, m) /\ R1(m, b)
R3(a, b) == R1(a, b) \/ \E m \in Nodes : R2(a, m) /\ R1(m, b)
R4(a, b) == R1(a, b) \/ \E m \in Nodes : R3(a, m) /\ R1(m, b)

Desc(x) == {d \in Nodes : R3(x, d)}   \* everything forward-reachable, x excluded unless cyclic
Cone(x) == {x} \cup Desc(x)
Anc(x)  == {a \in Nodes : R3(a, x)}   \* everything §5.2 would visit

\* THE UNROLLING IS ASSERTED, NOT ASSUMED. If three levels did not reach the fixed point, every
\* operator above would silently under-approximate and every green below would be a green about
\* a TRUNCATED graph. R3 = R4 is exactly that saturation claim, checked as an invariant in its
\* own right rather than argued in this comment.
\*
\* Written as an equality of the two DERIVED SETS rather than pointwise as `R3(a,b) <=> R4(a,b)`.
\* Same proposition; the pointwise form OOM-killed the 2 GB cap in InlinePass, because `<=>`
\* desugars to two implications and duplicates both chains.
UnrollDeep == \A x \in Nodes : {d \in Nodes : R3(x, d)} = {d \in Nodes : R4(x, d)}

\* The assumption §5.2's termination rests on, and the spec states it in no section.
SupAcyclic == \A a \in Nodes : a \notin Anc(a)

\* ----- §4.3, the two liveness predicates -----
\* The WEAK check §4.3 applies to descendants inside has_live_transitive_descendant:
\* "not_expired(next, as_of) and not is_self_revoked(next, ctx, as_of)" — deliberately not
\* recursive, per §4.3's own comment, to avoid the bistable bug.
Weak(x) == ~expired[x] /\ ~selfrev[x]

\* The FULL check, ratified (v1.1 SI-2) form: dead if any node in the forward DAG is weakly live.
LiveT(x) == Weak(x) /\ \A d \in Desc(x) : ~Weak(d)

\* The FULL check, pre-ratification form (negative control only): dead if any DIRECT successor
\* is fully live, recursing through the full predicate. Unrolled; meaningful only on acyclic
\* configs, and its config sets AllowCycles = FALSE.
LDF0(x) == Weak(x)
LDF1(x) == Weak(x) /\ \A s \in Succ(x) : ~LDF0(s)
LDF2(x) == Weak(x) /\ \A s \in Succ(x) : ~LDF1(s)
LDF3(x) == Weak(x) /\ \A s \in Succ(x) : ~LDF2(s)

Live(x) == IF LiveTransitive THEN LiveT(x) ELSE LDF3(x)

\* §5.1 / §5.3 tie-break. The spec's key is (not_before, content_hash); not_before is
\* abstracted away, so this is the content-hash half alone, modeled as node order.
\* The maximum of a NON-EMPTY subset of Nodes.
\*
\* THIS OPERATOR WAS WRITTEN THREE WAYS AND THE FIRST TWO BOTH OOM-KILLED THE 2 GB CAP, IN
\* DIFFERENT PASSES. `CHOOSE m \in S : \A o \in S : o <= m` -- AttestLive.tla's own form, and
\* the natural TLA+ -- compiles to one oracle per occurrence and the walk ladder nests several,
\* which dies in InlinePass. A descending membership ladder (`IF 5 \in S THEN 5 ELSE ...`) is
\* cheap to SOLVE but is a 5-way branch that InlinePass expands once per nesting level, which
\* dies harder and, because InlinePass runs before the "leaving only relevant operators"
\* pruning takes effect on the term size, it killed EVERY invariant in the file including two
\* that had already measured green. The fold is opaque to the inliner and exact. 0 is the
\* identity because Nodes = 1..N and the ladder never folds an empty set.
MaxOf(S) == ApaFoldSet(LAMBDA a, e: IF e > a THEN e ELSE a, 0, S)

\* `MaxOfExact` states that this ladder really is the maximum. It is defined below, after the
\* two set families it quantifies over.

\* ----- §5.3 find_live_head, transcribed and unrolled -----
\* `while True` is fuel in the TLC model and an unrolled ladder here. Running out of fuel is a
\* REPORTABLE OUTCOME rather than an error, because "how far can this loop actually go" is one
\* of the questions being asked.
LiveSucc(cur) == {s \in Succ(cur) : Live(s)}

\* @type: (Int) => { status: Str, node: Int };
Settle(cur) == IF Live(cur) THEN [status |-> "found", node |-> cur]
                            ELSE [status |-> "null",  node |-> cur]

SW1(cur) == IF LiveSucc(cur) = {} THEN Settle(cur) ELSE [status |-> "fuel", node |-> cur]
SW2(cur) == IF LiveSucc(cur) = {} THEN Settle(cur) ELSE SW1(MaxOf(LiveSucc(cur)))
SW3(cur) == IF LiveSucc(cur) = {} THEN Settle(cur) ELSE SW2(MaxOf(LiveSucc(cur)))
SW4(cur) == IF LiveSucc(cur) = {} THEN Settle(cur) ELSE SW3(MaxOf(LiveSucc(cur)))

\* THE LADDER DEPTH IS JUSTIFIED, NOT ASSUMED. SW_k returns "fuel" exactly when the walk would
\* need k or more steps, so a green `SpecWalkNeverExhausts` on SW2 is the statement that the
\* walk never advances twice -- and therefore that SW2 agrees with AttestLive.tla's
\* SpecWalk(x, N+1) on every input this model can build. The deeper ladders are not merely
\* unnecessary, they are unreachable, which is §5.3's masked-bound result stated as a fact about
\* the encoding: stepping to a live successor proves that successor has no live successor of its
\* own, so a second step is impossible. Depth 4 was measured and OOM-killed the 2 GB cap; depth
\* 2 is exact for the same reason the bound is safe.
SpecHead(x) == SW2(x)

\* ----- the algorithm all three implementations converged on instead -----
DagCandidates(x) == IF DagFiltersLive THEN {c \in Cone(x) : Live(c)} ELSE Cone(x)
DagHead(x) == IF DagCandidates(x) = {}
                THEN [status |-> "null",  node |-> x]
                ELSE [status |-> "found", node |-> MaxOf(DagCandidates(x))]

\* MaxOf really is the maximum, on the two set families this model actually applies it to.
\* Guards the ladder against MaxN drifting past it — the failure mode would be a silently wrong
\* tie-break, which is exactly the kind of defect a green sweep does not notice.
\*
\* Quantified over `Nodes` and the sets built from them, NOT over `SUBSET Nodes`. The powerset
\* form is the more obviously complete statement and it is the reason this module OOM-killed the
\* 2 GB cap a second time: `SUBSET Nodes` over a symbolically-sized `Nodes` is a powerset the
\* encoder cannot bound cheaply, and it cost EVERY invariant in the file, not just this one —
\* including two that had already been measured green, which is how it was found. Noted because
\* the fix looks like a weakening and is not: MaxOf is only ever applied to `LiveSucc` and
\* `DagCandidates`, so these are the instances that carry the tie-break.
MaxOfExact ==
  \A x \in Nodes :
    /\ LiveSucc(x) # {} =>
         (MaxOf(LiveSucc(x)) \in LiveSucc(x) /\ \A o \in LiveSucc(x) : o <= MaxOf(LiveSucc(x)))
    /\ DagCandidates(x) # {} =>
         (MaxOf(DagCandidates(x)) \in DagCandidates(x)
          /\ \A o \in DagCandidates(x) : o <= MaxOf(DagCandidates(x)))

\* ----- §5.2 walk_supersedes_chain, transcribed and unrolled -----
BW1(cur) == IF sup[cur] = NULL THEN "done" ELSE "fuel"
BW2(cur) == IF sup[cur] = NULL THEN "done" ELSE BW1(sup[cur])
BW3(cur) == IF sup[cur] = NULL THEN "done" ELSE BW2(sup[cur])
BW4(cur) == IF sup[cur] = NULL THEN "done" ELSE BW3(sup[cur])

BackWalkStatus(x) == BW4(x)

\* ---------------------------------------------------------------------------------------
\* THE PROPERTIES — transcribed from AttestLive.tla, same names, same readings.
\* ---------------------------------------------------------------------------------------

\* §5.3's own contract, quoted from its comment: "returns the most recent live attestation in
\* the chain." ASSERTED IN A CONFIG THAT EXPECTS IT TO BE VIOLATED — this is F1, a finding about
\* the specified algorithm, not a negative control over a broken model.
\* WHAT THIS DOES NOT ASSERT: that the returned head is the MOST RECENT one. "Most recent" is
\* ordered by not_before and the clock is abstracted away, so the checked contract is the weaker
\* "returns a live node of the chain whenever one exists". The finding survives the weakening —
\* §5.3 returns nothing at all, not the wrong thing.
SpecHeadFindsLiveHead ==
  \A x \in Nodes : (\E c \in Cone(x) : Live(c)) => SpecHead(x).status = "found"

\* The same contract asked of the algorithm the implementations actually run. GREEN.
DagHeadFindsLiveHead ==
  \A x \in Nodes : (\E c \in Cone(x) : Live(c)) => DagHead(x).status = "found"

\* ...and what it returns is live, not merely reachable. GREEN; controlled by DagFiltersLive.
DagHeadIsLive == \A x \in Nodes : DagHead(x).status = "found" => Live(DagHead(x).node)

\* §5.1 step 4. GREEN, and the green is the finding: the head-resolution step is an identity map,
\* which is why the cross-impl vectors over the composite cannot see F1.
HeadResolutionIsIdentity ==
  \A x \in Nodes : Live(x) => (SpecHead(x).status = "found" /\ SpecHead(x).node = x)

\* §4.3 as ratified: a live attestation never has a live descendant. Controlled by LiveTransitive.
NoLiveAncestorOfLive == \A x \in Nodes : Live(x) => \A d \in Desc(x) : ~Live(d)

\* §5.3's unbounded `while True` is MASKED rather than safe: the walk cannot take two steps,
\* because stepping to a live successor proves the successor has no live successor of its own.
\* GREEN over the full domain, cyclic configs included.
SpecWalkNeverExhausts == \A x \in Nodes : SpecHead(x).status # "fuel"

\* §5.2 has no depth bound and no visited set, and DOES need one. GREEN when acyclic — the
\* assumption isolated and shown to be exactly what the walk rests on.
BackWalkBoundedWhenAcyclic ==
  SupAcyclic => \A x \in Nodes : BackWalkStatus(x) # "fuel"

\* The same claim without the assumption. ASSERTED IN A CONFIG THAT EXPECTS IT TO BE VIOLATED.
BackWalkBoundedAlways == \A x \in Nodes : BackWalkStatus(x) # "fuel"

\* ----- non-vacuity witnesses. Each asserted in order to be VIOLATED. -----

\* The configuration the whole module turns on IS REACHED: an acyclic three-link chain whose
\* deepest link is live and whose two ancestors are not.
WitnessThreeChain ==
  ~( /\ SupAcyclic
     /\ \E x \in Nodes : \E y \in Succ(x) : \E z \in Succ(y) :
          /\ x # y /\ y # z /\ x # z
          /\ Live(z) /\ ~Live(y) /\ ~Live(x) )

\* The forward enumeration returns something other than its own start, i.e. DagHead's greens are
\* not the greens of an algorithm that trivially answers `x` to every question.
WitnessDagHeadMoves ==
  ~(\E x \in Nodes : DagHead(x).status = "found" /\ DagHead(x).node # x)

\* ---------------------------------------------------------------------------------------
\* The graph space. `Init` IS the model; `Next` stutters, because there is no transition system
\* here and pretending there is one would be the wrong model of a pure function. Every check in
\* this module therefore runs at --length=0: the claim is over graphs, not over runs.
\* ---------------------------------------------------------------------------------------
TypeOK == /\ sup     \in [Nodes -> Nodes \cup {NULL}]
          /\ expired \in [Nodes -> BOOLEAN]
          /\ selfrev \in [Nodes -> BOOLEAN]

Init == /\ sup \in [Nodes -> Nodes \cup {NULL}]
        /\ IF AllowCycles THEN TRUE ELSE \A x \in Nodes : sup[x] = NULL \/ sup[x] < x
        /\ expired \in [Nodes -> BOOLEAN]
        /\ selfrev \in [Nodes -> BOOLEAN]

Next == UNCHANGED vars

\* The green conjunction. `UnrollDeep` is in it deliberately: the ladders' saturation is a
\* premise of every other conjunct, so it is checked in the same query rather than argued.
Inv == /\ TypeOK
       /\ UnrollDeep
       /\ DagHeadFindsLiveHead
       /\ DagHeadIsLive
       /\ HeadResolutionIsIdentity
       /\ NoLiveAncestorOfLive
       /\ SpecWalkNeverExhausts
       /\ BackWalkBoundedWhenAcyclic

\* ----- constant inits -----
\* Parity with the TLC green sweep: N = 3, the full domain including cyclic configurations.
ConstInitOK   == N = 3 /\ AllowCycles = TRUE  /\ LiveTransitive = TRUE  /\ DagFiltersLive = TRUE

\* GUARD CONTROL — the ladder bound has TEETH. At N = 4 the reachability ladder (R3, with R4 as
\* the comparison level) is one level too short, so `UnrollDeep` MUST fail here. Without this row
\* MaxN = 3 would be a promise in a comment, and the failure mode it guards against is the worst
\* kind available to this module: every other invariant would go green over a SILENTLY TRUNCATED
\* graph. This is the row to run first if anyone raises N.
ConstInitLadderShort == N = 4 /\ AllowCycles = TRUE /\ LiveTransitive = TRUE /\ DagFiltersLive = TRUE

\* THE FINDING (F1), as a row: §5.3 cannot traverse a chain of three. Constants are the green
\* sweep's — nothing is weakened. Expected: counterexample on SpecHeadFindsLiveHead.
ConstInitFinding == ConstInitOK

\* NEG CONTROL — the pre-ratification direct-only reading of §4.3, on acyclic configs.
\* Expected: counterexample on NoLiveAncestorOfLive.
ConstInitBugDirect == N = 3 /\ AllowCycles = FALSE /\ LiveTransitive = FALSE /\ DagFiltersLive = TRUE

\* NEG CONTROL — the forward enumeration WITHOUT the liveness filter, so the returned head is
\* merely the furthest node. Expected: counterexample on DagHeadIsLive.
ConstInitBugDagFilter == N = 3 /\ AllowCycles = TRUE /\ LiveTransitive = TRUE /\ DagFiltersLive = FALSE
====
