---- MODULE AttestLive ----
\* ATTESTATION TRACK, second model. The supersedes graph and the three operations defined
\* over it: the composite liveness check (§4.3), the backward chain walk (§5.2), the forward
\* live-head walk (§5.3), and the head-resolution step §5.1's `default_find_authorizing`
\* performs with the last of these.
\*
\* TRACK: `attestation` (TRACKS.toml). A bare §N.M in this file means a section of
\* EXTENSION-ATTESTATION.md at the snapshot named by this track's pin, NOT of the core
\* protocol.
\*
\* WHY THIS MODULE IS SHAPED DIFFERENTLY FROM EVERY OTHER TLC MODULE HERE.
\* The rest of this repo models CONCURRENCY: processes interleave and the invariant is about
\* reachable interleavings. Nothing in §4.3/§5.2/§5.3 is concurrent — they are pure functions
\* of one graph. The question is not "can an interleaving break this" but "does this algorithm
\* compute what its own contract says, on every graph." So the state space here is the space of
\* GRAPHS: `Init` picks the supersedes edges and the per-node expiry/self-revocation flags
\* nondeterministically and `Next` stutters, which makes TLC an exhaustive checker over every
\* attestation graph on N nodes. That is a deliberate departure from the house shape and is
\* stated here rather than left for a reader to notice.
\*
\* WHAT THE SPEC SAYS, in the three places this module puts side by side:
\*
\*   §4.3  is_attestation_live(att) = not expired, not before its window, NOT SUPERSEDED
\*         TRANSITIVELY, and not self-revoked. The transitive half is delegated to
\*         has_live_transitive_descendant, which walks the WHOLE forward DAG with a
\*         visited-set and asks of each descendant a WEAKER question: not expired and not
\*         self-revoked, explicitly "NOT recursive supersession to avoid the bistable bug".
\*         So there are two liveness predicates in play, and the weaker one is the one used
\*         on descendants.
\*
\*   §5.2  walk_supersedes_chain follows the `supersedes` back-pointer with
\*         `while current.supersedes is not null`. No depth bound. No visited set.
\*
\*   §5.3  find_live_head walks FORWARD: it takes the direct successors, keeps those that are
\*         live BY THE FULL §4.3 PREDICATE, and steps to one of them; when none is live it
\*         returns the current node if that is live and null otherwise. `while True`. No depth
\*         bound. No visited set.
\*
\* THE INTERACTION THIS MODULE EXISTS FOR. §5.3 filters successors by the full predicate, and
\* the full predicate is false for any node that HAS a live descendant. So a successor that
\* leads to the head is itself never "live", and the walk cannot pass through it. On the chain
\* a1 <- a2 <- a3 (each superseding the one before, none expired, none revoked) the head is a3;
\* §5.3 started at a1 finds no live successor, finds a1 itself not live, and returns NULL.
\* `SpecHeadFindsLiveHead` states the contract §5.3's own comment writes -- "returns the most
\* recent live attestation in the chain" -- and is checked in a config that expects it to be
\* VIOLATED, because it is. `HeadResolutionIsIdentity` is the other half, stated positively
\* and green: on any input for which §5.3 returns non-null it returns the input unchanged, so
\* the head-resolution loop in §5.1 step 4 maps every live candidate to itself.
\*
\* This is not a hypothesis about the text. All three sibling implementations diverge from
\* §5.3's pseudocode in the same direction and enumerate the forward DAG instead; one carries
\* a code comment naming this exact cause; and the Rust tree's spec-ambiguity log raised the
\* neighbouring half of it against v1.0. `DagHead` below is that convergent algorithm, and
\* `DagHeadFindsLiveHead` is the check that it does satisfy the contract §5.3 states.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): ABSTRACTED AWAY -- signatures and their
\* verification, content hashing (a node's number stands in for its content hash, and the
\* numeric order for hash order, which is what the tie-breaks are stated over), the
\* not_before/expires_at clock (both collapse into one per-node `expired` flag, so the as_of
\* time-travel parameter is out of scope and the tie-break's primary key with it), revocation
\* as an attestation entity (a per-node `selfrev` flag, the same abstraction AttestIndex makes
\* and for the same reason: what is under test is what the walks do with the verdict, not how
\* the verdict is expressed), and the properties map entirely. Those sentences carry no §
\* sigil deliberately -- a scope disclaimer that cites a section was being counted as
\* coverage of it (../docs/COVERAGE-MATRIX.md section 3b).
EXTENDS Naturals, FiniteSets

CONSTANTS N,              \* nodes are 1..N. The chain that separates the two head algorithms
                          \* needs three, so N = 3 is the smallest interesting bound.
          AllowCycles,    \* TRUE  = `sup` ranges over EVERY function into Nodes \cup {NULL},
                          \*         cyclic configurations included. This is the honest domain:
                          \*         nothing in the spec text forbids a supersedes cycle, and
                          \*         BackWalkBoundedAlways is the measurement of what that costs.
                          \* FALSE = restricted to `sup[x] < x`, i.e. an attestation may only
                          \*         supersede an older one. Acyclic by construction; this is
                          \*         the structural form of the content-hash argument that a
                          \*         predecessor must already exist to be pointed at.
          LiveTransitive, \* TRUE  = §4.3 as ratified: a node is dead if ANY node in its forward
                          \*         DAG is weakly live (has_live_transitive_descendant).
                          \* FALSE = negative control: the pre-ratification reading, in which
                          \*         only DIRECT successors count and the recursion is through
                          \*         the full predicate. Restricted to acyclic configs.
          DagFiltersLive  \* TRUE  = the convergent implementation algorithm: enumerate the
                          \*         forward DAG, keep the live nodes, tie-break among them.
                          \* FALSE = negative control: enumerate the forward DAG and tie-break
                          \*         WITHOUT the liveness filter, so the returned head is
                          \*         merely the furthest node rather than a live one.

Nodes == 1..N
NULL  == 0                \* §3.1 makes `supersedes` optional; 0 is its absent value here

VARIABLES sup,            \* §3.1 supersedes: the back-pointer, NULL when absent
          expired,        \* §4.3 the expiration and not_before checks, collapsed
          selfrev         \* §4.3 the self-revocation check, collapsed

vars == << sup, expired, selfrev >>

\* ---------------------------------------------------------------------------------------
\* The graph. `supersedes` points BACKWARD (a newer attestation names the one it replaces),
\* so the forward edges §4.3 and §5.3 walk are the inverse relation.
\* ---------------------------------------------------------------------------------------
\* Succ is the lookup find_attestations_with_supersedes performs. NO SIGIL ON THAT SECTION
\* NUMBER, deliberately: this model ASSUMES that lookup's contract and verifies nothing about
\* it, so citing it would claim coverage this module does not have. Naming it in prose is the
\* disposition the citation convention gives a reference.
Succ(p)   == {c \in Nodes : sup[c] = p}
PredOf(p) == IF sup[p] = NULL THEN {} ELSE {sup[p]}

\* Transitive closure by iteration to a fixed point. Written with fuel rather than as a
\* least-fixed-point so that it is total on CYCLIC graphs too -- the closure is well defined
\* there, it is the WALKS that are not, and keeping the two separate is the whole point.
RECURSIVE GrowF(_, _)
GrowF(S, k) == IF k = 0 THEN S
               ELSE LET S2 == S \cup UNION {Succ(p) : p \in S}
                    IN IF S2 = S THEN S ELSE GrowF(S2, k - 1)

RECURSIVE GrowB(_, _)
GrowB(S, k) == IF k = 0 THEN S
               ELSE LET S2 == S \cup UNION {PredOf(p) : p \in S}
                    IN IF S2 = S THEN S ELSE GrowB(S2, k - 1)

Desc(x) == GrowF(Succ(x), N)         \* everything forward-reachable, x excluded
Cone(x) == {x} \cup Desc(x)          \* the chain §5.3's comment means by "the chain"
Anc(x)  == GrowB(PredOf(x), N)       \* everything §5.2 would visit

\* The supersedes relation has no cycle anywhere. Stated as an operator because it is the
\* assumption §5.2's termination rests on, and the spec states it in no section.
SupAcyclic == \A a \in Nodes : a \notin Anc(a)

\* ---------------------------------------------------------------------------------------
\* §4.3 -- the two liveness predicates, and they are not the same predicate.
\* ---------------------------------------------------------------------------------------

\* The WEAK check §4.3 applies to descendants inside has_live_transitive_descendant:
\* "not_expired(next, as_of) and not is_self_revoked(next, ctx, as_of)". Deliberately not
\* recursive -- §4.3 says so in its own comment, to avoid the bistable bug.
Weak(x) == ~expired[x] /\ ~selfrev[x]

\* The FULL check, ratified form: dead if any node in the forward DAG is weakly live.
LiveT(x) == Weak(x) /\ \A d \in Desc(x) : ~Weak(d)

\* The FULL check, pre-ratification form (control only): dead if any DIRECT successor is
\* fully live. Bounded by N because on an acyclic graph no chain is longer than that; this
\* operator is meaningful only under AllowCycles = FALSE and its config sets that.
RECURSIVE LiveDF(_, _)
LiveDF(x, k) == /\ Weak(x)
                /\ \/ k = 0
                   \/ \A s \in Succ(x) : ~LiveDF(s, k - 1)

Live(x) == IF LiveTransitive THEN LiveT(x) ELSE LiveDF(x, N)

\* §5.1 / §5.3 tie-break. The spec's key is (not_before, content_hash); not_before is
\* abstracted away, so this is the content-hash half alone, modeled as the node order.
MaxOf(S) == CHOOSE m \in S : \A o \in S : o <= m

\* ---------------------------------------------------------------------------------------
\* §5.3 -- find_live_head, transcribed. `while True` becomes fuel, and the fuel running out
\* is a REPORTABLE OUTCOME rather than an error, because "how far can this loop actually go"
\* is one of the questions being asked. N + 1 steps is one more than any acyclic chain can
\* need, so status = "fuel" means the walk revisited a node.
\* ---------------------------------------------------------------------------------------
RECURSIVE SpecWalk(_, _)
SpecWalk(cur, fuel) ==
  IF fuel = 0 THEN [status |-> "fuel", node |-> cur]
  ELSE LET LS == {s \in Succ(cur) : Live(s)}          \* live_successors
       IN IF LS = {}
            THEN IF Live(cur) THEN [status |-> "found", node |-> cur]
                              ELSE [status |-> "null",  node |-> cur]
            ELSE SpecWalk(MaxOf(LS), fuel - 1)

SpecHead(x) == SpecWalk(x, N + 1)

\* ---------------------------------------------------------------------------------------
\* The algorithm all three sibling implementations converged on instead: enumerate the whole
\* forward DAG with a visited set, then apply the liveness filter and the tie-break once.
\* ---------------------------------------------------------------------------------------
DagCandidates(x) == IF DagFiltersLive THEN {c \in Cone(x) : Live(c)} ELSE Cone(x)
DagHead(x) == IF DagCandidates(x) = {}
                THEN [status |-> "null",  node |-> x]
                ELSE [status |-> "found", node |-> MaxOf(DagCandidates(x))]

\* ---------------------------------------------------------------------------------------
\* §5.2 -- walk_supersedes_chain, transcribed. Same fuel treatment, same reason.
\* ---------------------------------------------------------------------------------------
RECURSIVE BackWalk(_, _)
BackWalk(cur, fuel) == IF fuel = 0            THEN "fuel"
                       ELSE IF sup[cur] = NULL THEN "done"
                       ELSE BackWalk(sup[cur], fuel - 1)

BackWalkStatus(x) == BackWalk(x, N + 1)

\* ---------------------------------------------------------------------------------------
\* THE PROPERTIES
\* ---------------------------------------------------------------------------------------

\* §5.3's own contract, quoted from its comment: "Walks supersedes chain forward to find
\* current live head. Returns the most recent live attestation in the chain." If any node in
\* the chain forward of x is live, the walk must return one. ASSERTED IN A CONFIG THAT
\* EXPECTS IT TO BE VIOLATED -- this is a finding about the specified algorithm, not a
\* negative control over a deliberately broken model. Nothing in this module is broken:
\* AttestLiveSpecHead.cfg runs the same constants as the green sweep.
\*
\* WHAT THIS DOES NOT ASSERT: that the returned head is the MOST RECENT one. "Most recent" is
\* ordered by not_before, and the clock is abstracted away here, so the checked contract is
\* the weaker "returns a live node of the chain whenever one exists". The finding survives the
\* weakening -- §5.3 returns nothing at all, not the wrong thing -- and stating it this way
\* keeps the claim inside what the model can see.
SpecHeadFindsLiveHead ==
  \A x \in Nodes : (\E c \in Cone(x) : Live(c)) => SpecHead(x).status = "found"

\* The same contract, asked of the algorithm the implementations actually run. GREEN.
DagHeadFindsLiveHead ==
  \A x \in Nodes : (\E c \in Cone(x) : Live(c)) => DagHead(x).status = "found"

\* ...and what it returns is live, not merely reachable. GREEN; controlled by DagFiltersLive.
DagHeadIsLive == \A x \in Nodes : DagHead(x).status = "found" => Live(DagHead(x).node)

\* §5.1 step 4 -- "select the most recent live head of any supersedes chain (via
\* find_live_head)". The step runs over candidates that step 2 has ALREADY filtered to live.
\* This says that for every such candidate the resolution returns the candidate itself, so the
\* loop maps `live` onto itself and the tie-break that follows it is a tie-break over the
\* unresolved candidate set. GREEN, and the green is the finding: the step is an identity map.
HeadResolutionIsIdentity ==
  \A x \in Nodes : Live(x) => (SpecHead(x).status = "found" /\ SpecHead(x).node = x)

\* §4.3 as ratified, stated as the property that makes "live" mean "current authoritative
\* version": a live attestation never has a live descendant. GREEN under the transitive
\* reading; the whole content of the transitive amendment. Controlled by LiveTransitive.
NoLiveAncestorOfLive == \A x \in Nodes : Live(x) => \A d \in Desc(x) : ~Live(d)

\* §5.3 has no depth bound, and does not need one: the walk cannot take two steps, because
\* stepping to a live successor proves the successor has no live successor of its own. So the
\* unbounded `while True` is masked rather than safe -- it is bounded by a property of the
\* liveness predicate it filters on, which is not a property anyone stated and not one the
\* loop is written to rely on. GREEN over the full domain, cyclic configs included.
SpecWalkNeverExhausts == \A x \in Nodes : SpecHead(x).status # "fuel"

\* §5.2 has no depth bound and no visited set, and DOES need one. GREEN: it terminates when
\* the supersedes relation is acyclic. This is the assumption isolated -- named, and shown to
\* be exactly what the walk rests on.
BackWalkBoundedWhenAcyclic ==
  SupAcyclic => \A x \in Nodes : BackWalkStatus(x) # "fuel"

\* The same claim without the assumption. ASSERTED IN A CONFIG THAT EXPECTS IT TO BE
\* VIOLATED: the violation is the exhibition of a graph on which §5.2 as written does not
\* terminate. Whether such a graph is CONSTRUCTIBLE is a question about content-addressing
\* and not about this model -- see ../docs/LEAN-SEAM.md row O6.
BackWalkBoundedAlways == \A x \in Nodes : BackWalkStatus(x) # "fuel"

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES (PROPERTIES.md §C.4). Each is asserted in order to be VIOLATED; the
\* violation is the pass and a clean run is a build failure.
\* ---------------------------------------------------------------------------------------

\* The configuration the whole module turns on is REACHED: an acyclic three-link chain whose
\* deepest link is live and whose two ancestors are not. Without this, SpecHeadFindsLiveHead's
\* violation could be coming from somewhere less interesting, and BackWalkBoundedWhenAcyclic's
\* green could be holding over a domain in which SupAcyclic is only ever satisfied by graphs
\* with no edges at all.
WitnessThreeChain ==
  ~( /\ SupAcyclic
     /\ \E x \in Nodes : \E y \in Succ(x) : \E z \in Succ(y) :
          /\ x # y /\ y # z /\ x # z
          /\ Live(z) /\ ~Live(y) /\ ~Live(x) )

\* The §5.3 walk ADVANCES somewhere in the state space. This is what SpecWalkNeverExhausts
\* needs to not be vacuous: "the walk never runs out of fuel" is satisfied completely by a
\* walk that never takes a single step, and that reading would make the bound look safe for
\* the wrong reason. The violation exhibits a start whose returned head is a different node.
WitnessSpecWalkSteps ==
  ~(\E x \in Nodes : SpecHead(x).status = "found" /\ SpecHead(x).node # x)

\* The forward enumeration returns something other than its own start, i.e. DagHead's greens
\* are not the greens of an algorithm that trivially answers `x` to every question.
WitnessDagHeadMoves ==
  ~(\E x \in Nodes : DagHead(x).status = "found" /\ DagHead(x).node # x)

\* ---------------------------------------------------------------------------------------
\* The graph space. `Init` is the model: every supersedes configuration and every
\* expiry/self-revocation assignment over N nodes. `Next` stutters -- there is no transition
\* system here, and pretending there is one would be the wrong model of a pure function.
\* ---------------------------------------------------------------------------------------
Init == /\ sup \in [Nodes -> Nodes \cup {NULL}]
        /\ IF AllowCycles THEN TRUE ELSE \A x \in Nodes : sup[x] = NULL \/ sup[x] < x
        /\ expired \in [Nodes -> BOOLEAN]
        /\ selfrev \in [Nodes -> BOOLEAN]

Next == UNCHANGED vars

Spec == Init /\ [][Next]_vars

\* Type correctness, so that a config that silently enumerates nothing is visible as such.
TypeOK == /\ sup \in [Nodes -> Nodes \cup {NULL}]
          /\ expired \in [Nodes -> BOOLEAN]
          /\ selfrev \in [Nodes -> BOOLEAN]
====
