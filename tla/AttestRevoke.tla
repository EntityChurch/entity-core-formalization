---- MODULE AttestRevoke ----
\* ATTESTATION TRACK, third model. §4.3's OTHER recursion: revocation. `AttestLive` modeled the
\* supersedes graph and left self-revocation as a per-node flag; this module closes that
\* abstraction, because the thing the flag was hiding turns out to be undefined in the spec.
\*
\* TRACK: `attestation` (TRACKS.toml). A bare §N.M means a section of EXTENSION-ATTESTATION.md
\* at this track's pin.
\*
\* WHAT §4.3 SAYS, and the hole in the middle of it.
\* `is_attestation_live` asks whether an attestation is self-revoked, in the main path:
\*
\*     revocations = find_revocations_for(att.content_hash, ctx)
\*     for rev in revocations:
\*       if rev.attesting == att.attesting and is_attestation_live(rev, ctx, as_of=now):
\*         return false
\*
\* — a matching-attester revocation that is ITSELF LIVE, recursively. And it asks the same
\* question again inside `has_live_transitive_descendant`, about each descendant:
\*
\*     if not_expired(next, as_of) and not is_self_revoked(next, ctx, as_of):
\*       return true
\*
\* **`is_self_revoked` IS NEVER DEFINED.** One occurrence in the document, and it is that use.
\* So is `not_expired`. Both are load-bearing: they decide which descendants count as live, and
\* that decides supersession, and that decides liveness.
\*
\* This is a KNOWN CLASS in this document. The v1.0 Amendment 1 history entry reads: *"Added
\* section 5.6a `find_attestations_with_supersedes` and 5.6b `find_attestations_with_kind`
\* definitions — both were referenced from §4.3 (`is_attestation_live`), §5.3 (`find_live_head`),
\* and TV-I5 but never specified."* Two undefined helpers were found and fixed **in this
\* function**; two more in the same function were not.
\*
\* WHY IT IS NOT PEDANTRY: THE TWO NATURAL READINGS ARE NOT EQUIVALENT.
\*   RECURSIVE  — `is_self_revoked(x)` means what the main path means: a matching-attester
\*                revocation exists that is itself live.
\*   STRUCTURAL — it means a matching-attester revocation exists, full stop.
\* They diverge exactly when a revocation has itself been revoked. Under RECURSIVE a revoked
\* revocation does not kill, so its target stays live; under STRUCTURAL it does. Both readings
\* are computed here side by side and compared: `SelfRevReadingsAgree` and `LiveReadingsAgree`
\* are asserted in configs that expect them to be VIOLATED, on a model where nothing is
\* weakened. The choice is observable in `is_attestation_live`'s answer, which is the substrate
\* predicate every consumer's authorization decision runs through.
\*
\* A THIRD OBSERVATION, RECORDED BUT NOT CHECKED HERE. `has_live_transitive_descendant` is
\* explicitly cycle-safe — it carries `visited` and says so. The revocation recursion has **no
\* visited set and no depth bound**, and the one place the spec defends against cycles defends
\* one of its two recursions. This module cannot check what that costs, and says so rather than
\* implying otherwise: `Init` restricts BOTH relations to point at lower-numbered nodes, which
\* is acyclic by construction, and every recursion below terminates because of that restriction
\* rather than because of anything in the algorithm. `AttestLive`'s `BackWalkBoundedAlways` is
\* the same question measured on the supersedes side; docs/LEAN-SEAM.md O6 owns it.
\*
\* !! THE CONCLUSION THIS PARAGRAPH ORIGINALLY DREW WAS WRONG, AND IT WAS WRONG *BECAUSE* IT
\* !! WAS DRAWN HERE. It read: "so §4.3's termination rests on the revocation graph being
\* !! acyclic as well as the supersedes graph" — struck 2026-09-08, kept rather than deleted.
\* !! Per-relation acyclicity is NOT the assumption. `tla/AttestRevokeApalache.tla` splits the
\* !! `Init` restriction into two constants and lifts them one at a time, and §4.3's equation
\* !! has NO UNIQUE SOLUTION on a configuration where BOTH graphs are acyclic: the recursion
\* !! alternates between the two relations and `visited` is scoped to one hop, so
\* !! `4 --supersedes-reach--> 1 --revoked-by--> 4` closes a loop across the COMPOSITION. What
\* !! §4.3 needs is a COMMON ORDER OVER BOTH, which content addressing supplies and no sentence
\* !! states. This is D18: the model that hard-codes an assumption in `Init` is the one model
\* !! that cannot measure it, and a disclosure reads as a conclusion. Point the second engine
\* !! at the first one's `Init`, not at its invariants.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): ABSTRACTED AWAY -- signatures and their
\* verification, content hashing (a node's number stands in for its content hash, and the
\* strict-decrease restriction on both pointers is the structural form of "a predecessor must
\* already exist to be pointed at"), the clock (one `expired` flag per node; the as_of parameter
\* and not_before with it), the properties map beyond whether an entity is a revocation, and
\* every index. A revocation is modeled as an edge rather than as an entity carrying
\* `properties.kind = "revocation"`, because what is under test is what the liveness check does
\* with the revocation relation, not how the relation is spelled. Those sentences carry no §
\* sigil deliberately -- a scope disclaimer that cites a section was being counted as coverage
\* of it (../docs/COVERAGE-MATRIX.md section 3b).
EXTENDS Naturals, FiniteSets

CONSTANTS N,               \* nodes are 1..N. The divergence needs FOUR: a superseded
                           \* attestation, its successor, a revocation of the successor, and a
                           \* revocation of that revocation.
          Peers,           \* the `attesting` parties. Two is enough to separate a
                           \* self-revocation from someone else's revocation.
          AuthorityRevoke, \* FALSE = §4.3/§4.4 as written: only a revocation whose `attesting`
                           \*         MATCHES the target's counts. Authority-revocation is
                           \*         consumer-supplied and the primitive does not do it.
                           \* TRUE  = negative control: any revocation kills, so the primitive
                           \*         has silently taken over the consumer's authority rule.
          RecursiveMainRev \* TRUE  = §4.3's main path as written: the revocation must itself
                           \*         be live (`is_attestation_live(rev, ...)`).
                           \* FALSE = negative control: any matching revocation kills whether or
                           \*         not it has itself been revoked.

Nodes == 1..N
NULL  == 0

VARIABLES sup,       \* §3.1 supersedes: the back-pointer, NULL when absent
          revt,      \* §3.3 this entity is a revocation targeting revt[x] (its `attested`)
          attester,  \* §3.1 attesting: who signed it
          expired    \* §4.3's expiration and not_before checks, collapsed

vars == << sup, revt, attester, expired >>

\* ---------------------------------------------------------------------------------------
\* The two graphs.
\* ---------------------------------------------------------------------------------------
Succ(p) == {c \in Nodes : sup[c] = p}        \* find_attestations_with_supersedes

RECURSIVE GrowF(_, _)
GrowF(S, k) == IF k = 0 THEN S
               ELSE LET S2 == S \cup UNION {Succ(p) : p \in S}
                    IN IF S2 = S THEN S ELSE GrowF(S2, k - 1)

Desc(x) == GrowF(Succ(x), N)

\* The lookup find_revocations_for performs. NO SIGIL on that section number: this model
\* assumes its contract and verifies nothing about it, so citing it would claim coverage this
\* module does not have.
Revs(x) == {r \in Nodes : revt[r] = x}

\* §4.3's `rev.attesting == att.attesting` filter, and §4.4's line that anything else is the
\* consumer's business. Under the control this filter is dropped.
RevSet(x) == IF AuthorityRevoke THEN Revs(x) ELSE {r \in Revs(x) : attester[r] = attester[x]}

\* ---------------------------------------------------------------------------------------
\* §4.3, with the undefined helper supplied BOTH WAYS and carried as a parameter.
\*
\* `rec = TRUE`  -- `is_self_revoked` is read as the main path's predicate: a matching
\*                  revocation that is itself live.
\* `rec = FALSE` -- it is read structurally: a matching revocation exists.
\*
\* TERMINATION IS BY CONSTRUCTION, NOT BY FUEL, and the construction is `Init`'s restriction.
\* Every recursive call moves to a STRICTLY HIGHER node index -- `Revs(x)` and `Desc(x)` both
\* contain only nodes that point back at x, and `Init` allows a pointer only to a lower index.
\* That is exactly the acyclicity assumption O6 isolated, doing load-bearing work here. Written
\* with no fuel parameter deliberately, so that the reliance is visible instead of buried in a
\* constant nobody reads.
\* ---------------------------------------------------------------------------------------
RECURSIVE Live(_, _)
RECURSIVE SelfRevFull(_, _)
RECURSIVE IsSelfRevoked(_, _)
RECURSIVE HasLiveDesc(_, _)

Live(x, rec) == /\ ~expired[x]
                /\ ~HasLiveDesc(x, rec)
                /\ ~SelfRevFull(x, rec)

\* The MAIN path's self-revocation check. §4.3 writes it recursively; the control flattens it.
SelfRevFull(x, rec) == \E r \in RevSet(x) :
                         IF RecursiveMainRev THEN Live(r, rec) ELSE TRUE

\* The DESCENDANT path's check -- the undefined one.
IsSelfRevoked(x, rec) == IF rec THEN SelfRevFull(x, rec) ELSE RevSet(x) # {}

\* §4.3 has_live_transitive_descendant: the weak check, "not_expired AND not is_self_revoked",
\* deliberately not recursive through supersession.
HasLiveDesc(x, rec) == \E d \in Desc(x) : ~expired[d] /\ ~IsSelfRevoked(d, rec)

\* THE THIRD READING, and it is not hypothetical -- it is what one of the three sibling
\* implementations does. Instead of the weak check the spec prescribes, it asks whether any
\* descendant is FULLY live, and compensates by descending past dead successors ("the
\* rescuing-grandchild case the spec's literal pseudocode mishandles", its own comment). That
\* looks like a different predicate and reads like a divergence.
\* `DescReadingsCoincide` below is the check that it is not one.
HasFullyLiveDesc(x) == \E d \in Desc(x) : Live(d, TRUE)

\* ---------------------------------------------------------------------------------------
\* THE PROPERTIES
\* ---------------------------------------------------------------------------------------

\* FINDING. The two readings of the undefined `is_self_revoked` are not the same predicate.
\* Asserted in a config that expects it to be VIOLATED; nothing in the model is weakened.
SelfRevReadingsAgree == \A x \in Nodes : IsSelfRevoked(x, TRUE) = IsSelfRevoked(x, FALSE)

\* FINDING, and the one that matters: the choice changes `is_attestation_live`'s ANSWER, not
\* merely the value of a helper. Also violated, on the same unweakened model.
LiveReadingsAgree == \A x \in Nodes : Live(x, TRUE) = Live(x, FALSE)

\* §4.3 + §4.4 GREEN: the primitive's liveness check is self-revocation ONLY. An attestation
\* with no matching-attester revocation is never killed BY REVOCATION -- if it is dead, it is
\* dead of expiry or supersession. This is the sentence §4.4 opens with, stated as an
\* invariant; `AuthorityRevoke` is its control.
OnlySelfRevocationKills ==
  \A x \in Nodes :
    ( /\ ~expired[x]
      /\ ~HasLiveDesc(x, TRUE)
      /\ \A r \in Revs(x) : attester[r] # attester[x] ) => Live(x, TRUE)

\* §4.3 GREEN: a revocation that has itself been revoked does not kill its target. This is the
\* revocation-side twin of the "predecessor-revival semantics" §4.3 documents for supersession
\* -- and unlike that one it is NOT documented anywhere; it falls out of the main path's
\* `is_attestation_live(rev, ...)` recursion. Stated here because an undocumented consequence
\* that nothing states is exactly what a model is for. `RecursiveMainRev` is its control.
DeadRevocationSpares ==
  \A x \in Nodes :
    ( /\ ~expired[x]
      /\ ~HasLiveDesc(x, TRUE)
      /\ RevSet(x) # {}
      /\ \A r \in RevSet(x) : ~Live(r, TRUE) ) => Live(x, TRUE)

\* §4.3 GREEN, AND IT IS A COHORT RESULT RATHER THAN A SPEC RESULT. Two of the three sibling
\* implementations compute the descendant check the way §4.3 words it -- weak check, recursive
\* `is_self_revoked`. The third asks whether any descendant is fully live and then walks past
\* dead links to compensate. This says the two compute THE SAME PREDICATE on every acyclic
\* graph: a weak descendant exists iff a fully-live one does, because following weak descendants
\* downward from any weak node terminates at one with no weak descendant of its own.
\*
\* Worth stating as a checked invariant rather than as the paragraph above, which is what it was
\* first: docs/PROPERTIES.md §D.1 is the record of this repo reasoning its way to an impact
\* claim about an implementation cohort and being wrong. This one is run.
DescReadingsCoincide == \A x \in Nodes : HasLiveDesc(x, TRUE) = HasFullyLiveDesc(x)

\* §4.3 GREEN, carried over from AttestLive and re-checked in the richer model: a live
\* attestation never has a live descendant. Corroboration rather than a new claim -- the same
\* property, now with revocation modeled as a graph instead of a flag.
NoLiveAncestorOfLive == \A x \in Nodes : Live(x, TRUE) => \A d \in Desc(x) : ~Live(d, TRUE)

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Each asserted in order to be VIOLATED; the violation is the pass.
\* ---------------------------------------------------------------------------------------

\* A revocation that is itself revoked, by matching attesters both times, is REACHED. Without
\* it `DeadRevocationSpares` is a green over a state space containing no revoked revocation,
\* and both findings would be violations nobody could locate.
WitnessRevokedRevocation ==
  ~(\E x \in Nodes : \E r \in RevSet(x) : RevSet(r) # {} /\ ~Live(r, TRUE))

\* Something is actually DEAD BY REVOCATION somewhere -- otherwise every liveness result above
\* is a statement about a model in which revocation never fires.
WitnessRevocationKills ==
  ~(\E x \in Nodes : ~expired[x] /\ ~HasLiveDesc(x, TRUE) /\ ~Live(x, TRUE))

\* Supersession actually FIRES somewhere. Without this, `DescReadingsCoincide` and
\* `NoLiveAncestorOfLive` are both satisfied by a state space in which no attestation ever has
\* a live descendant -- the first would be `FALSE = FALSE` everywhere and the second vacuous.
\* D13 asked of a green: what else produces it?
\* Expected verdict: violation.
WitnessSupersededByLive == ~(\E x \in Nodes : HasLiveDesc(x, TRUE))

\* ---------------------------------------------------------------------------------------
\* The graph space: every supersedes AND revocation configuration over N nodes, with both
\* pointers restricted to lower indices. See the termination note above -- that restriction is
\* not a convenience, it is the assumption the algorithm needs and does not state.
\* ---------------------------------------------------------------------------------------
Init == /\ sup \in [Nodes -> Nodes \cup {NULL}]
        /\ \A x \in Nodes : sup[x] = NULL \/ sup[x] < x
        /\ revt \in [Nodes -> Nodes \cup {NULL}]
        /\ \A x \in Nodes : revt[x] = NULL \/ revt[x] < x
        /\ attester \in [Nodes -> Peers]
        /\ expired \in [Nodes -> BOOLEAN]

Next == UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK == /\ sup \in [Nodes -> Nodes \cup {NULL}]
          /\ revt \in [Nodes -> Nodes \cup {NULL}]
          /\ attester \in [Nodes -> Peers]
          /\ expired \in [Nodes -> BOOLEAN]
====
