---- MODULE QuorumSignerSetApalache ----
\* QUORUM TRACK — Apalache (SMT) cross-check of tla/QuorumSignerSet.tla: §4.2
\* `current_signer_set`, the resolver that decides WHO IS ALLOWED TO SIGN for every consumer of
\* this extension. **This is the module that carries Q1**, so it is the one where a second
\* engine is worth the most on this track.
\*
\* TRACK: `quorum` (TRACKS.toml). A bare §N.M means a section of EXTENSION-QUORUM.md at this
\* track's pin. A cross-track reference writes the sigil first: §ATTEST:5.3 is a section of
\* EXTENSION-ATTESTATION.md and is EXCLUDED from both tracks' coverage sets.
\*
\* ═══ WHY THIS MODULE EXISTS: IT IS O20, AND O20 IS A RULE'S FIRST HARVEST ══════════════════
\* `docs/LEAN-SEAM.md` O20 is not a row a model produced. It is a row a RULE went looking for:
\* docs/DISCIPLINE-CHARTER.md D15's tenth shape — *a model's domain restriction is a claim; make it a constant
\* with a control row or book what it excludes* — was written after `AttestRevoke.tla`'s
\* unconditional `Init` restriction turned out to hide a requirement STRONGER than the prose
\* drawn from it (F5/O10). Enumerating that class across all nine extension models found exactly
\* one unbooked site, and it is the line below in `QuorumSignerSet.tla`:
\*
\*     /\ \A x \in Nodes : sup[x] = NULL \/ sup[x] < x
\*
\* Unconditional, no constant, no control — on the module carrying this repo's most-quoted
\* quorum finding. `SupOrdered` is that line turned into a constant, and this file is the
\* experiment O20 asks for.
\*
\* ═══ THE ANSWER, AND IT IS NOT THE ONE ATTESTREVOKE GAVE ══════════════════════════════════
\* On `AttestRevoke` the lifted restriction exposed a requirement the prose had understated:
\* per-relation acyclicity was NOT enough, because §ATTEST:4.3's recursion alternates between
\* two relations and the cycle lives in their composition. **Here it is enough, and saying so
\* precisely is the point of the two rows below.** §4.2's resolver runs over ONE relation, and
\* with the index order lifted:
\*
\*   - `CohortNeverSilentlyRevertsWhenAcyclic` is GREEN — acyclicity alone carries it.
\*   - `CohortNeverSilentlyReverts` unguarded is VIOLATED, on a supersedes CYCLE.
\*
\* THE COUNTEREXAMPLE, and the first one was not the one to route. Run as written, the row
\* returns `sup = <<1, 1, 2>>`: node 1 supersedes ITSELF. True, minimal, and the wrong thing to
\* publish — "an attestation whose `supersedes` names itself" invites the answer "no
\* implementation would build that" and the claim does not need it. Hence
\* `CohortNeverSilentlyRevertsNoSelfLoop`, which forbids the self-loop and is VIOLATED TOO:
\*
\*     sup = <<3, 3, 1>>        1 supersedes 3, 3 supersedes 1 — a two-node cycle; 2 is off it
\*     xp  = <<1, 2, NULL>>     at as_of = 2, nodes 1 and 2 have expired
\*     nb  = <<2, NULL, 1>>     node 3 took effect at instant 1 and is inside its window
\*
\*   §4.2 is asked for the signer set at `as_of = 2`. `quorum-update` 3 is live by the plain
\*   reading of the section's own normative sentence. Every probe returns null — node 3 is its
\*   own transitive descendant, so §ATTEST:4.3 finds it a live descendant and calls it dead —
\*   and §4.2 falls through to `quorum.data.signers`, THE ROSTER FROZEN AT `:create`.
\*
\* So the index order was a strictly stronger assumption than this module needs, and what it was
\* standing in for is acyclicity — which §6.2 does not validate (it validates
\* `new_threshold`, and `supersedes` is an optional caller-supplied hash: O13's observation, one
\* shape over), which §3.2 describes only in prose, and which content addressing supplies in a
\* deployed system for the same unstated reason it does in §ATTEST:4.3. **Naming the gap that
\* precisely is what the O20 experiment buys; asserting "the order was harmless" without running
\* it is what F5 did.**
\*
\* WHY THAT VIOLATION IS A SEPARATE FINDING FROM Q2 AND NOT A RESTATEMENT OF IT. Q2 (the silent
\* revert) is about §4.2's fall-through being reached because §ATTEST:5.3's forward walk returns
\* null from the oldest element of a CHAIN. The route here is different in every step: every
\* probe returns null because no node on a cycle can ever be live (a cycle makes each node its
\* own descendant, and §ATTEST:4.3 kills any attestation with a live descendant), so the
\* fall-through is reached with no walk defect involved at all. Same consequence — the roster
\* frozen at `:create` is served while membership changes are in force — through an input shape
\* nothing in either document rejects.
\*
\* ═══ WHAT A SECOND ENGINE BUYS, AND WHAT IT DOES NOT ══════════════════════════════════════
\* `QuorumSignerSet` is not a concurrency model: `Next` is `UNCHANGED vars` and the state space
\* IS the space of (supersedes, not_before, expires_at) configurations on N nodes. TLC
\* enumerates it; Apalache answers one SMT query over it. Independent METHOD, same
\* transcription — a defect in either engine's search is visible to the other, and a shared
\* MISREADING of §4.2 survives both. That is the 5th wall (../docs/ASSURANCE-MAP.md) and no
\* engine moves it. Q1–Q4 are REPRODUCED here, not re-derived: each is a row that must be
\* violated on the green sweep's own constants, with the same retirement condition as its TLC
\* twin.
\*
\* SCOPE: N = 3, T = 2, PARITY WITH TLC AND NOTHING MORE. The ladders below are cut to what
\* N = 3 needs; `ConstInitLadderShort` is the control that makes that bound fail LOUDLY at N = 4
\* rather than truncating the graph silently.
\*
\* ═══ ENCODER NOTES, inherited from AttestLiveApalache and AttestRevokeApalache ════════════
\* No `RECURSIVE`, so both of this module's recursions are unrolled: the reachability closure
\* (`GrowF` there, `R1..R4` here) and the §ATTEST:5.3 walk (`HeadFrom` there, `SW1/SW2` here).
\* `InlinePass` expands the whole module before the "leaving only relevant operators" pruning
\* takes effect on term size, so one expensive operator kills EVERY invariant in the file
\* including ones already measured green. `CHOOSE` compiles to an oracle per occurrence — both
\* of `QuorumSignerSet.tla`'s selectors are CHOOSE and both are folds here (see `MostRecent`).
\* A set built by comprehension and then quantified over is a value the encoder must construct,
\* where the flattened existential is free — hence `HasLiveDesc` is a predicate here and a set
\* membership there.
\*
\* EVERY ONE OF THOSE REWRITES IS A PLACE A TRANSCRIPTION CAN DRIFT, so each carries its own
\* obligation rather than a comment: `UnrollDeep` (the closure saturated), `MostRecentExact` and
\* `LeastExact` (the folds really are §ATTEST:5.3's tie-break and §4.2's cross-probe pick), and
\* `SpecWalkNeverExhausts` (the walk ladder is deep enough that its depth is not a promise).
\*
\* ═══ THE DERIVED LAYERS ARE STATE VARIABLES, AND THAT IS NOT COSMETIC ═════════════════════
\* `Live`, the walk and the probe image are each computed ONCE into a variable (`lvT`/`lvF`,
\* `wkT`/`wkF`, `hs`) and read as lookups everywhere else. Written the natural way — as
\* operators — `LeastExact` alone mentions the probe image three times, each mention re-expands
\* the walk over every start node, each walk re-expands `Live`, and each `Live` re-expands the
\* reachability closure: OOM-KILLED AT THE 2 GB CAP, measured, not predicted. With the layers
\* materialized the whole file checks comfortably inside it.
\*
\* HOW THIS DIFFERS FROM AttestRevokeApalache's LADDER, because the two look identical and carry
\* DIFFERENT obligations. There, the levels encode a mutual RECURSION, so the encoding owes
\* `LadderIsFixedPoint*` (deep enough, and a solution exists) and `FixedPointUnique*` (only one).
\* Here each layer is a function CONSTRUCTOR over the layer below — a definition, evaluated once,
\* with exactly one value and no depth to justify. What this file still owes is that its
\* `Init` admits any state at all: an over-constrained `Init` makes every invariant hold
\* vacuously while Apalache reports OK, and the violated witnesses are the proof that it does.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): QuorumSignerSet.tla's abstraction boundary,
\* unchanged -- signatures and K-of-N validation entirely (that is `QuorumKofN`), the cache and
\* the arrival-time trust model (that is `QuorumTrust`), revocation of a quorum-update, the
\* resolver hook and every resolution mode, content hashing (a node's number stands in for its
\* content hash, and both orderings below are taken over that number), and the roster VALUES
\* themselves -- what is under test is WHICH update supplies the roster. Those sentences carry
\* no § sigil deliberately (../docs/COVERAGE-MATRIX.md section 3b).
\* `Integers` rather than `Naturals` because the walk's exhaustion sentinel is negative; SANY
\* rejects `-1` under Naturals with a bare semantic-analysis failure that names no line.
EXTENDS Integers, FiniteSets, Apalache

CONSTANTS
  \* @type: Int;
  N,
  \* @type: Int;
  T,
  \* @type: Bool;
  ProbeAllUpdates,
  \* @type: Bool;
  DescTemporal,
  \* NOTE THE NAME, for the reason AttestRevokeApalache's header gives: this is an INDEX-ORDER
  \* restriction, not acyclicity. `sup[x] < x` forbids far more than a cycle, and the whole
  \* result below is the size of that difference.
  \* @type: Bool;
  SupOrdered

VARIABLES
  \* @type: Int -> Int;
  sup,
  \* @type: Int -> Int;
  nb,
  \* @type: Int -> Int;
  xp,
  \* ── THE MATERIALIZED LAYERS, and they are the difference between this file checking and
  \* this file OOM-killing the cap. See "THE DERIVED LAYERS ARE STATE VARIABLES" in the header.
  \* §ATTEST:4.3 is_attestation_live per (instant, node), under the cohort reading of the
  \* undefined `not_expired` and under the literal one.
  \* @type: Int -> (Int -> Bool);
  lvT,
  \* @type: Int -> (Int -> Bool);
  lvF,
  \* §ATTEST:5.3 find_live_head per (instant, start node), same two readings. FUEL is a value
  \* here rather than an error, because "how far can this loop go" is one of the questions.
  \* @type: Int -> (Int -> Int);
  wkT,
  \* @type: Int -> (Int -> Int);
  wkF,
  \* §4.2's probe image: the set of heads any probe element yields, per instant.
  \* @type: Int -> Set(Int);
  hs

\* @type: <<Int -> Int, Int -> Int, Int -> Int, Int -> (Int -> Bool), Int -> (Int -> Bool), Int -> (Int -> Int), Int -> (Int -> Int), Int -> Set(Int)>>;
vars == << sup, nb, xp, lvT, lvF, wkT, wkF, hs >>

\* The ladders are cut to what N = 3 needs. MaxN is the bound they are valid for and it is
\* CHECKED, not asserted: `UnrollDeep` fails at N = 4 (ConstInitLadderShort).
MaxN    == 3
Nodes   == 1..N
Times   == 1..T
NULL    == 0
\* GENESIS and NULL are deliberately the same value: §4.2 has no third outcome. See
\* QuorumSignerSet.tla's header.
GENESIS == 0

\* ---------------------------------------------------------------------------------------
\* The supersedes graph. §3.2's pointer runs BACKWARD, so the forward edge a walk follows is
\* its inverse. §ATTEST:5.6a find_attestations_with_supersedes carries NO SIGIL: this model
\* assumes that lookup's contract and verifies nothing about it.
\*
\* `Rk(a,b)` = "b is reachable from a by a forward path of length 1..k", the same closure
\* QuorumSignerSet.tla builds by growing a set (`GrowF`) — as a pure boolean relation, because
\* the set-growing form nested per level is a combinatorial blow-up in the encoder.
\* WITH CYCLES ADMITTED, saturation needs N levels rather than N-1: a node's reachability to
\* ITSELF costs a full cycle. That is exactly why R3/R4 is right at N = 3 here and why
\* ConstInitLadderShort at N = 4 must fail.
\* ---------------------------------------------------------------------------------------
R1(a, b) == sup[b] = a
R2(a, b) == R1(a, b) \/ \E m \in Nodes : R1(a, m) /\ R1(m, b)
R3(a, b) == R1(a, b) \/ \E m \in Nodes : R2(a, m) /\ R1(m, b)
R4(a, b) == R1(a, b) \/ \E m \in Nodes : R3(a, m) /\ R1(m, b)

\* `Reach(x, d)` IS `d \in Desc(x)` in QuorumSignerSet.tla.
Reach(x, d) == R3(x, d)

Succ(p) == {c \in Nodes : sup[c] = p}
Roots   == {x \in Nodes : sup[x] = NULL}

\* THE UNROLLING IS ASSERTED, NOT ASSUMED. Three levels short of the fixed point and every
\* operator below silently under-approximates the descendant set, which would make every green
\* here a green about a TRUNCATED graph. Written as an equality of the two DERIVED SETS rather
\* than pointwise with `<=>`, which desugars into two implications and duplicates both chains.
UnrollDeep == \A x \in Nodes : {d \in Nodes : R3(x, d)} = {d \in Nodes : R4(x, d)}

\* The property `SupOrdered` was standing in for, stated on its own so the two can be told
\* apart. This is the O20 question in one line.
SupAcyclic == \A a \in Nodes : ~Reach(a, a)

\* The shape §3.2 describes and §6.2 does not enforce: a single per-quorum chain.
WellFormedChain == /\ Cardinality(Roots) = 1
                   /\ \A x \in Nodes : Cardinality(Succ(x)) <= 1

\* ---------------------------------------------------------------------------------------
\* §ATTEST:4.3's two temporal checks, kept apart on purpose — the document writes them as two
\* consecutive `if` statements and then names only one of them in the descendant filter.
\* ---------------------------------------------------------------------------------------
NotExpiredOnly(x, t) == xp[x] = NULL \/ t < xp[x]
Effective(x, t)      == /\ NotExpiredOnly(x, t)
                        /\ nb[x] = NULL \/ nb[x] <= t

\* The undefined helper, both ways. `rd` TRUE is the cohort's reading (Go `shallowEffective`,
\* Rust `is_self_valid_basic`, Python `_is_temporally_invalid`); FALSE is the literal one.
NotExpired(x, t, rd) == IF rd THEN Effective(x, t) ELSE NotExpiredOnly(x, t)

\* §ATTEST:4.3 has_live_transitive_descendant, minus self-revocation (declared above). Flattened
\* to an existential over `Nodes` — `\E d \in {d \in Nodes : Reach(x,d)} : P(d)` builds a set the
\* encoder must construct where this form is free.
HasLiveDesc(x, t, rd) == \E d \in Nodes : Reach(x, d) /\ NotExpired(d, t, rd)

\* §ATTEST:4.3 is_attestation_live, restricted to the dimensions this module models. `LiveRaw`
\* is the definition; `Live` is the materialized lookup that everything else uses. `Init` is what
\* ties them together, once per (instant, node).
LiveRaw(x, t, rd) == Effective(x, t) /\ ~HasLiveDesc(x, t, rd)
Live(x, t, rd)    == IF rd THEN lvT[t][x] ELSE lvF[t][x]

\* ---------------------------------------------------------------------------------------
\* §ATTEST:5.3's tie-break: `max(live_successors, key=lambda s: (s.not_before or 0,
\* s.content_hash))` — a HIGHER not_before wins, ties broken by a HIGHER content_hash.
\*
\* QuorumSignerSet.tla writes this as `CHOOSE x \in S : \A y \in S : Better(x, y)`, which is the
\* natural TLA+ and which compiles to one ORACLE PER OCCURRENCE here; the walk ladder nests
\* several. It is a fold instead, over an integer KEY that linearizes the lexicographic order:
\* every node number is in 1..N, so multiplying not_before by N+1 makes (not_before, node) fit
\* in one integer with no carry, and `% (N + 1)` recovers the node.
\*
\* THAT IS A REWRITE OF A NORMATIVE TIE-BREAK AND SO IT IS CHECKED, NOT COMMENTED:
\* `MostRecentExact` states the CHOOSE's own defining condition — `Better` verbatim from the
\* TLC module — of whatever the fold returns, on the two set families it is applied to.
\* ---------------------------------------------------------------------------------------
NbOr0(x) == IF nb[x] = NULL THEN 0 ELSE nb[x]
KeyOf(x) == NbOr0(x) * (N + 1) + x

Better(x, y) == \/ NbOr0(x) > NbOr0(y)
                \/ (NbOr0(x) = NbOr0(y) /\ x >= y)

MaxKey(S)     == ApaFoldSet(LAMBDA a, e: IF KeyOf(e) > a THEN KeyOf(e) ELSE a, 0, S)
MostRecent(S) == MaxKey(S) % (N + 1)

\* §4.2's cross-probe pick: `Least` in the TLC module, the lowest content_hash among the heads
\* found, which is what entity-core-go and entity-core-py do. Same fold treatment, same reason.
\* N + 1 is the identity because Nodes = 1..N and this is never folded over an empty set.
MinOf(S) == ApaFoldSet(LAMBDA a, e: IF e < a THEN e ELSE a, N + 1, S)

\* ---------------------------------------------------------------------------------------
\* §ATTEST:5.3 find_live_head, unrolled. `while True` is fuel in the TLC model (`HeadFrom`,
\* fuel = N) and a ladder here. RUNNING OUT IS A REPORTABLE OUTCOME rather than an error,
\* because "how far can this loop actually go" is one of the questions being asked — and under
\* `SupOrdered = FALSE` it is a question with a cycle in it.
\*
\* Depth 2 is exact for the same reason it is in AttestLiveApalache, and the reason is checked
\* rather than claimed (`SpecWalkNeverExhausts`): stepping to a live successor PROVES that
\* successor has no live successor of its own, because a live successor would be a live
\* descendant. §ATTEST:5.3's unbounded loop is masked, not safe.
\* ---------------------------------------------------------------------------------------
\* The walk's outcome is ONE INTEGER rather than a status record: a node number is a head,
\* GENESIS (= 0) is the null the fall-through consumes, and FUEL (= -1) is exhaustion. A record
\* would be the more readable TLA+ and it costs a `Str` field the encoder carries through every
\* nesting level of the ladder; the three outcomes are disjoint as integers because `Nodes` is
\* 1..N.
FUEL == -1

LiveSucc(cur, t, rd) == {s \in Nodes : sup[s] = cur /\ Live(s, t, rd)}

Settle(cur, t, rd) == IF Live(cur, t, rd) THEN cur ELSE GENESIS

SW1(cur, t, rd) == IF LiveSucc(cur, t, rd) = {} THEN Settle(cur, t, rd) ELSE FUEL
SW2(cur, t, rd) == IF LiveSucc(cur, t, rd) = {} THEN Settle(cur, t, rd)
                                                ELSE SW1(MostRecent(LiveSucc(cur, t, rd)), t, rd)

\* `SpecHeadRaw` is the definition; `WalkRaw` is the materialized lookup. Same relationship as
\* LiveRaw/Live, and `Init` is again what ties them together.
SpecHeadRaw(x, t, rd) == SW2(x, t, rd)
WalkRaw(x, t, rd)     == IF rd THEN wkT[t][x] ELSE wkF[t][x]

\* §4.2's whole algorithm from one probe element. A null head is the SILENT FALL-THROUGH to
\* `quorum.data.signers`, not an error and not an empty set. Fuel exhaustion maps to the same
\* value because QuorumSignerSet.tla's `HeadFrom` returns NULL when its fuel runs out; the two
\* files therefore agree on every input, and `SpecWalkNeverExhausts` is what says so.
SpecResult(x, t, rd) == IF WalkRaw(x, t, rd) = FUEL THEN GENESIS ELSE WalkRaw(x, t, rd)

\* ---------------------------------------------------------------------------------------
\* WHAT §4.2's NORMATIVE SENTENCE ASKS FOR, independently of how §4.2 computes it. Both readings
\* it needs — "live at as_of" as within the validity window, "successor" as transitive — are
\* declared in QuorumSignerSet.tla's header rather than assumed, because the sentence pins
\* neither and "most recent" names no field.
\* ---------------------------------------------------------------------------------------
LiveAt(x, t) == Effective(x, t)

NormCandidates(t) == {x \in Nodes : LiveAt(x, t) /\ \A d \in Nodes : Reach(x, d) => ~LiveAt(d, t)}

NormativeResult(t) == IF NormCandidates(t) = {} THEN GENESIS
                                                ELSE MostRecent(NormCandidates(t))

\* ---------------------------------------------------------------------------------------
\* THE RESOLUTION ACTUALLY PERFORMED. Every node is a quorum-update targeting the quorum, so
\* `updates` is `Nodes`. Under the control this collapses to §4.2's literal `updates[0]`.
\* `FoundHeads` is the image of the probe set, written as a comprehension over `Nodes` with the
\* existential inside rather than as the image `{SpecResult(u, ...) : u \in Nodes} \ {GENESIS}`,
\* which builds a set and then subtracts from it.
\* ---------------------------------------------------------------------------------------
FoundHeadsRaw(t) == {h \in Nodes : \E u \in Nodes : SpecResult(u, t, DescTemporal) = h}
FoundHeads(t)    == hs[t]

Resolve(t) == IF ProbeAllUpdates
              THEN (IF FoundHeads(t) = {} THEN GENESIS ELSE MinOf(FoundHeads(t)))
              ELSE SpecResult(MinOf(Nodes), t, DescTemporal)

\* ---------------------------------------------------------------------------------------
\* THE ENCODING'S OWN OBLIGATIONS — green rows, and the premise of every other green here.
\* ---------------------------------------------------------------------------------------

\* The two folds really are the two selectors they replace. Quantified over `Nodes` and the set
\* families the folds are actually applied to, NOT over `SUBSET Nodes`: the powerset form is the
\* more obviously complete statement and it is a powerset the encoder cannot bound cheaply —
\* AttestLiveApalache OOM-killed the 2 GB cap on exactly that, losing every invariant in the
\* file rather than just the one.
MostRecentExact ==
  \A t \in Times :
    /\ \A x \in Nodes :
         LiveSucc(x, t, DescTemporal) # {} =>
           /\ MostRecent(LiveSucc(x, t, DescTemporal)) \in LiveSucc(x, t, DescTemporal)
           /\ \A o \in LiveSucc(x, t, DescTemporal) :
                Better(MostRecent(LiveSucc(x, t, DescTemporal)), o)
    /\ NormCandidates(t) # {} =>
         /\ MostRecent(NormCandidates(t)) \in NormCandidates(t)
         /\ \A o \in NormCandidates(t) : Better(MostRecent(NormCandidates(t)), o)

LeastExact ==
  \A t \in Times :
    FoundHeads(t) # {} =>
      /\ MinOf(FoundHeads(t)) \in FoundHeads(t)
      /\ \A o \in FoundHeads(t) : MinOf(FoundHeads(t)) <= o

\* §ATTEST:5.3's unbounded `while True` is MASKED rather than safe, and the ladder depth is
\* justified by this row rather than by a comment. GREEN over the full domain — INCLUDING the
\* cyclic configurations `SupOrdered = FALSE` admits, which is a result in its own right: the
\* walk cannot loop, because nothing on a cycle is ever live to step to.
SpecWalkNeverExhausts ==
  \A t \in Times : \A x \in Nodes : WalkRaw(x, t, DescTemporal) # FUEL

\* ---------------------------------------------------------------------------------------
\* THE PROPERTIES — transcribed from QuorumSignerSet.tla, same names, same readings.
\* ---------------------------------------------------------------------------------------

\* FINDING (Q3). §4.2 walks forward from `updates[0]` and §ATTEST:5.4 defines no order on
\* `updates`. Guarded by `WellFormedChain` so the exhibited state IS the chain of three rather
\* than a smaller true-but-different instance; see QuorumSignerSet.tla's header.
ResultIndependentOfProbe ==
  \A t \in Times :
    WellFormedChain =>
      \A u, v \in Nodes :
        SpecResult(u, t, DescTemporal) = SpecResult(v, t, DescTemporal)

\* FINDING (Q2), the one with teeth: §4.2 returns the CREATION-TIME roster while a
\* quorum-update is live and in force.
SpecNeverSilentlyReverts ==
  \A t \in Times :
    (WellFormedChain /\ \E x \in Nodes : LiveAt(x, t)) =>
      \A u \in Nodes : SpecResult(u, t, DescTemporal) # GENESIS

\* FINDING (Q4). The two readings of §ATTEST:4.3's undefined `not_expired` do not agree on
\* §4.2's answer. Named explicitly rather than taken from the constant, so the row does not
\* depend on which reading the sweep is configured for.
NotExpiredReadingsAgree ==
  \A t \in Times : \A u \in Nodes :
    SpecResult(u, t, TRUE) = SpecResult(u, t, FALSE)

\* FINDING (Q1). §4.2's algorithm against §4.2's own normative sentence, directly.
SpecMatchesNormative ==
  \A t \in Times : \A u \in Nodes :
    SpecResult(u, t, DescTemporal) = NormativeResult(t)

\* FINDING. The cohort's repairs match the normative sentence on the chain shape §3.2 describes
\* and NOT off it — and off it they do not match each other either.
CohortMatchesNormative == \A t \in Times : Resolve(t) = NormativeResult(t)

\* §4.2 GREEN, and a COHORT result rather than a spec result: on the single-chain shape §3.2
\* describes, the repair all three implementations independently wrote computes what §4.2's
\* normative sentence asks for. The spec's own algorithm does not (SpecMatchesNormative).
\* Control: ProbeAllUpdates = FALSE.
CohortMatchesNormativeOnChain ==
  WellFormedChain => \A t \in Times : Resolve(t) = NormativeResult(t)

\* §4.2 GREEN, and THE ROW O20 EXISTS FOR. The safety property the whole section provides: the
\* resolver does not hand back the creation-time roster while a membership change is in force.
\* Control: DescTemporal = FALSE.
\*
\* GREEN under `ConstInitOK` (the index order, which is what QuorumSignerSet.tla hard-codes) and
\* VIOLATED under `ConstInitSupUnordered` (the order lifted). The counterexample is a supersedes
\* CYCLE — see this file's header and `CohortNeverSilentlyRevertsWhenAcyclic` immediately below,
\* which is what makes the two rows a measurement rather than a pair of opposite claims.
CohortNeverSilentlyReverts ==
  \A t \in Times :
    (\E x \in Nodes : LiveAt(x, t)) => Resolve(t) # GENESIS

\* THE SAME CLAIM WITH THE CHEAPEST COUNTEREXAMPLE RULED OUT, and it is here because the first
\* run of the row above returned one: `sup = <<1, 1, 2>>` — node 1 SUPERSEDES ITSELF. That is a
\* true instance and it is not the mechanism worth routing, because "an attestation whose
\* `supersedes` names itself" invites the answer "no implementation would build that" and the
\* interesting claim survives without it. This row forbids the self-loop and asks whether a
\* two-node cycle still does it. Same guard discipline as `SpecNeverSilentlyReverts`'s
\* `WellFormedChain`: a finding whose stated mechanism is not the one its counterexample
\* exhibits is docs/PROPERTIES.md §D.1 happening again.
CohortNeverSilentlyRevertsNoSelfLoop ==
  (\A x \in Nodes : sup[x] # x) =>
    \A t \in Times :
      (\E x \in Nodes : LiveAt(x, t)) => Resolve(t) # GENESIS

\* THE SAME CLAIM WITH THE ASSUMPTION ISOLATED, and the reason this module can say what
\* `SupOrdered` was standing in for instead of merely that removing it broke something.
\* GREEN under BOTH `ConstInitOK` and `ConstInitSupUnordered`: acyclicity — not the index
\* order — is exactly what §4.2's resolver needs, and it is weaker than what the TLC model
\* assumes and stronger than anything §3.2/§6.2 validate.
CohortNeverSilentlyRevertsWhenAcyclic ==
  SupAcyclic =>
    \A t \in Times :
      (\E x \in Nodes : LiveAt(x, t)) => Resolve(t) # GENESIS

\* §4.2 GREEN. Whatever head is returned is itself within its validity window at `as_of` and has
\* no live successor. Weaker than CohortMatchesNormativeOnChain (it does not say WHICH
\* candidate) and stated separately because it holds unguarded — on forked graphs, and on the
\* cyclic ones too.
ResolvedHeadIsCurrent ==
  \A t \in Times :
    Resolve(t) # GENESIS =>
      /\ LiveAt(Resolve(t), t)
      /\ \A d \in Nodes : Reach(Resolve(t), d) => ~LiveAt(d, t)

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Each asserted in order to be VIOLATED; the violation is the pass.
\* ---------------------------------------------------------------------------------------

\* A well-formed chain of THREE, all three within their validity windows at some instant — the
\* configuration the probe and revert findings are about.
WitnessThreeChain ==
  ~(/\ WellFormedChain
     /\ \E t \in Times : \A y \in Nodes : Effective(y, t)
     /\ \E x \in Nodes : Cardinality({d \in Nodes : Reach(x, d)}) = 2)

\* A SCHEDULED update: not yet effective at `t`, with an effective predecessor.
WitnessPendingUpdate ==
  ~(\E t \in Times : \E x \in Nodes :
      /\ nb[x] # NULL /\ nb[x] > t
      /\ sup[x] # NULL /\ Effective(sup[x], t))

\* The fall-through is REACHED: §4.2 returns the genesis roster at an instant when some update
\* is live.
WitnessSilentRevert ==
  ~(\E t \in Times :
      /\ \E x \in Nodes : LiveAt(x, t)
      /\ \E u \in Nodes : SpecResult(u, t, DescTemporal) = GENESIS)

\* A SUPERSEDES CYCLE IS REACHABLE at all under `SupOrdered = FALSE`, so the O20 finding row is
\* about a state this model can build rather than about an antecedent that never holds. Under
\* `ConstInitOK` this witness HOLDS (no cycle exists), which is why it is a row only on the
\* unordered cinit — the same shape as AttestRevokeApalache's `Init`-satisfiability witnesses.
WitnessSupCycle == ~(\E x \in Nodes : Reach(x, x))

\* ---------------------------------------------------------------------------------------
\* The configuration space. `Init` IS the model; `Next` stutters, because there is no transition
\* system here and pretending there is one would be the wrong model of a pure function. Every
\* check runs at --length=0: the claim is over graphs, not over runs.
\* ---------------------------------------------------------------------------------------
TypeOK == /\ sup \in [Nodes -> Nodes \cup {NULL}]
          /\ nb  \in [Nodes -> Times \cup {NULL}]
          /\ xp  \in [Nodes -> Times \cup {NULL}]

\* The supersedes pointer restricted to lower indices is QuorumSignerSet.tla's hard-coded
\* domain — unconditional there, a constant here. That is the whole of O20.
\*
\* The five conjuncts after it are the materialized layers, each a FUNCTION CONSTRUCTOR applied
\* to the layer above it. Order is load-bearing: `wkT` reads `lvT`, `hs` reads both. Written as
\* constructors rather than as the equivalent pointwise `\A t, x : lvT[t][x] = ...`, which
\* Apalache's assignment solver does not recognise as an assignment ("lvT' is used before it is
\* assigned").
Init == /\ sup \in [Nodes -> Nodes \cup {NULL}]
        /\ SupOrdered => \A x \in Nodes : sup[x] = NULL \/ sup[x] < x
        /\ nb \in [Nodes -> Times \cup {NULL}]
        /\ xp \in [Nodes -> Times \cup {NULL}]
        /\ lvT = [t \in Times |-> [x \in Nodes |-> LiveRaw(x, t, TRUE)]]
        /\ lvF = [t \in Times |-> [x \in Nodes |-> LiveRaw(x, t, FALSE)]]
        /\ wkT = [t \in Times |-> [x \in Nodes |-> SpecHeadRaw(x, t, TRUE)]]
        /\ wkF = [t \in Times |-> [x \in Nodes |-> SpecHeadRaw(x, t, FALSE)]]
        /\ hs  = [t \in Times |-> FoundHeadsRaw(t)]

Next == UNCHANGED vars

\* ----- constant inits -----
\* Parity with the TLC green sweep: QuorumSignerSet.cfg's constants, plus the order switch set
\* to what QuorumSignerSet.tla hard-codes.
ConstInitOK ==
  /\ N = 3 /\ T = 2
  /\ ProbeAllUpdates = TRUE /\ DescTemporal = TRUE /\ SupOrdered = TRUE

\* THE Q1–Q4 FINDINGS, as rows: constants are the green sweep's — nothing is weakened.
ConstInitFinding == ConstInitOK

\* O20 — THE EXPERIMENT. The index order is lifted; nothing else changes. FIVE GREEN rows
\* (UnrollDeep, SpecWalkNeverExhausts, ResolvedHeadIsCurrent, CohortMatchesNormativeOnChain,
\* CohortNeverSilentlyRevertsWhenAcyclic), TWO FINDING rows (CohortNeverSilentlyReverts and its
\* no-self-loop form) and ONE WITNESS (WitnessSupCycle — a cycle is constructible here, and
\* under `ConstInitOK` that same witness HOLDS, which is the pair of runs that says the two
\* cinits really do differ in the intended dimension).
\*
\* READ THE GREENS AS PART OF THE RESULT, NOT AS BACKGROUND. Four of §4.2's five checked
\* properties survive the lifted order untouched; exactly one does not. That is what makes this
\* a measurement of the assumption rather than a demonstration that removing an assumption
\* breaks things.
ConstInitSupUnordered ==
  /\ N = 3 /\ T = 2
  /\ ProbeAllUpdates = TRUE /\ DescTemporal = TRUE /\ SupOrdered = FALSE

\* NEG CONTROL — §4.2 AS WRITTEN: probe `updates[0]` only, instead of probing every candidate as
\* all three implementations do. Expected: counterexample on CohortMatchesNormativeOnChain.
ConstInitBugProbe ==
  /\ N = 3 /\ T = 2
  /\ ProbeAllUpdates = FALSE /\ DescTemporal = TRUE /\ SupOrdered = TRUE

\* NEG CONTROL — the LITERAL reading of §ATTEST:4.3's undefined `not_expired`, the expires_at
\* check alone. Expected: counterexample on CohortNeverSilentlyReverts.
ConstInitBugLiteral ==
  /\ N = 3 /\ T = 2
  /\ ProbeAllUpdates = TRUE /\ DescTemporal = FALSE /\ SupOrdered = TRUE

\* GUARD CONTROL — the reachability ladder has TEETH at N = 4, where R3 is one level short of
\* saturation once cycles are admitted (a node reaches ITSELF only via a full cycle, which costs
\* N edges, not N-1). `UnrollDeep` MUST fail here. Without this row MaxN = 3 is a promise in a
\* comment and the failure mode it guards is the worst available to this module: every other
\* invariant green over a silently truncated descendant set. Run it first if anyone raises N.
ConstInitLadderShort ==
  /\ N = 4 /\ T = 2
  /\ ProbeAllUpdates = TRUE /\ DescTemporal = TRUE /\ SupOrdered = FALSE
====
