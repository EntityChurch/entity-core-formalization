---- MODULE QuorumTrust ----
\* QUORUM TRACK, second model. §4.2's trust model and §4.2.1's cache-invalidation contract —
\* the "validate once on arrival, trust on every read" posture, and what it rests on.
\*
\* TRACK: `quorum` (TRACKS.toml). A bare §N.M means a section of EXTENSION-QUORUM.md at this
\* track's pin. §ATTEST:N.M is EXTENSION-ATTESTATION.md and is excluded from both coverage sets.
\*
\* WHY THIS ONE WAS WRITTEN DOWN BEFORE ANY MODEL EXISTED. `TRACKS.toml`'s quorum note has said,
\* since the track was scoped and before a line of it was modeled: *"the whole live signer set
\* rests on every write path running arrival-time validation, and nothing states that every path
\* does. That is an unstated closure assumption and belongs in docs/LEAN-SEAM.md the day a model
\* exists, whatever the answer turns out to be."* This is that model, and the answer is worse
\* than the note guessed: the assumption is not merely unstated, it is CONTRADICTED, twice, by
\* the same document.
\*
\* WHAT §4.2 SAYS.
\*   "Each `quorum-update` is validated against the predecessor's signer set at the moment it
\*    enters the local tree (via §4.2.1 validate-accept). Validated `quorum-update` attestations
\*    are trusted on subsequent reads; `current_signer_set` walks the live chain head and trusts
\*    cached prior validation. End-to-end re-validation of the chain on every
\*    `current_signer_set` call is NOT performed and is NOT required."
\* and, on cold start:
\*   "Each `quorum-update` in the chain, at this point, has already been validated at arrival
\*    time (per §4.2.1) and tree-bound ONLY ON VALIDATION SUCCESS — so the walk trusts the
\*    existing tree state."
\*
\* THAT LAST CLAUSE IS THE LOAD-BEARING ONE, AND THE DOCUMENT FALSIFIES IT TWICE.
\*   - §4.2.1 non-trigger 1, on an attestation that FAILS K-of-N: *"The attestation may sit in
\*     the tree at a structurally-valid path without being authoritative."* Tree-bound, not
\*     validated. In the same subsection that the cold-start sentence cites as its authority.
\*   - §8: *"Direct `tree:put` to `system/quorum/...` paths is permitted but bypasses the quorum
\*     handler's validation."* Tree-bound, not validated, by a mechanism the spec allows.
\*
\* And nothing filters them back out on the read side. §4.2's walk is
\* `find_attestations_targeting`, which is §ATTEST:5.4 — an index lookup on the `attested` field
\* — and §ATTEST:5.7 I4 says explicitly that the indexes do NOT filter by liveness or by
\* anything else: entities stay indexed and `find_attestations_*` keeps returning them. There is
\* no validated-only predicate anywhere in §4.2's algorithm. All three implementations do the
\* same index lookup, faithfully, with no validation filter.
\*
\* So the cache — which §4.2.1 says "reflects validated quorum state, not raw tree state" — is
\* populated from a walk over raw tree state. `CacheMatchesValidated` is that sentence, and it
\* is asserted in configs that expect it to be VIOLATED.
\*
\* WHAT THE GREEN BUYS, AND IT IS THE POINT OF THE MODULE. Under `WalkClosedOverValidated`, the
\* §4.2.1 trigger and non-trigger set is EXACTLY SUFFICIENT: invalidate on successful local op
\* and on validated arrival, do not invalidate on failed validation or on a raw put, scope per
\* quorum — and the cache never disagrees with the validated state, across every interleaving of
\* writes, walks and cold starts. The contract is sound; the closure it silently requires is the
\* thing that is missing. That is a conditional result and it is stated as one, because "the
\* invalidation rules are wrong" would have been the easy conclusion and it is not the true one.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): ABSTRACTED AWAY -- signatures and the K-of-N
\* check itself (an attestation either passed validation or did not; `QuorumKofN` models the
\* check), the supersedes chain and liveness entirely (`QuorumSignerSet` models the walk; here a
\* walk's RESULT is the set of entries it read, because what is under test is which entries are
\* readable at all), the clock, the resolver hook, the distinction between the two mechanisms
\* §4.2.1 permits for satisfying validate-accept -- the contract is explicitly "on post-state,
\* not implementation" and both mechanisms are modeled by the same accept action, which is what
\* that sentence means. Those sentences carry no § sigil deliberately -- a scope disclaimer that
\* cites a section was being counted as coverage of it (../docs/COVERAGE-MATRIX.md §3b).
EXTENDS Naturals, FiniteSets

CONSTANTS NA,                     \* quorum-event attestations, 1..NA
          NQ,                     \* quorums, 1..NQ. Their caches are scoped independently, and
                                  \* TWO is what §4.2.1 non-trigger 3 / TV-QF15 needs.
          RawWrites,              \* TRUE  = §8 as written: direct tree:put is permitted.
                                  \* FALSE = restricts the model to handler paths only, to show
                                  \*         the defect does not depend on §8 at all.
          AcceptInvalidates,      \* TRUE  = §4.2.1 triggers 1 and 2 as written.
                                  \* FALSE = negative control: a validate-accept leaves the
                                  \*         cache alone.
          RawInvalidates,         \* FALSE = §4.2.1 non-trigger 2 as written: a raw tree:put
                                  \*         does not invalidate.
                                  \* TRUE  = negative control.
          ScopedInvalidation,     \* TRUE  = §4.2.1 non-trigger 3 as written: per-quorum scope.
                                  \* FALSE = negative control: one quorum's event clears every
                                  \*         cache.
          WalkClosedOverValidated \* TRUE  = the closure §4.2's cold-start sentence ASSERTS:
                                  \*         only validated entries are readable by the walk.
                                  \* FALSE = §4.2 as written: the walk is the §ATTEST:5.4 index
                                  \*         lookup and reads whatever is bound.

Atts    == 1..NA
Quorums == 1..NQ

\* Which quorum each event is an event OF. A definition rather than a cfg constant: TLC's
\* config grammar has no tuple literal, and deriving the split from the bounds means it cannot
\* silently disagree with them. Round-robin, so every quorum owns at least one event whenever
\* NA >= NQ. §4.2.1 non-trigger 3 needs only that two quorums have disjoint event sets.
Owner(a) == ((a - 1) % NQ) + 1

AttsOf(q) == {a \in Atts : Owner(a) = q}
NOQ       == 0

\* THE CACHE IS TWO VARIABLES, NOT ONE, AND THAT IS A BUG FIX RATHER THAN A STYLE CHOICE.
\* The first draft carried presence and value in one variable with a `"none"` sentinel. `{}` is
\* a REAL walk result -- the tree holds no event for this quorum yet -- so the sentinel and a
\* legitimate value had to be told apart by `=`, and TLC does not return FALSE when asked to
\* compare a set with a string: it ERRORS OUT ("Attempted to check equality of the set {} with
\* the value: none"). Every config died evaluating its own invariant, which grades as a failure
\* and, in the finding and control configs, as a failure with a NON-ZERO EXIT -- indistinguishable
\* from the violation those rows are supposed to demonstrate if the grader read exit status.
\* It does not (D13), and that is why this was caught here instead of shipping green.
VARIABLES tree,      \* §7: bound at system/quorum/{q}/event/{hash}
          valid,     \* §4.2.1: passed structural + signature + K-of-N validation on arrival
          cached,    \* §4.2.1: is there a cache entry for this quorum
          cval,      \* §4.2.1: what it holds. Meaningful only where cached[q]
          cleared,   \* AUXILIARY: the quorums whose cache the most recent action invalidated
          actQ,      \* AUXILIARY: the quorum the most recent action was an event of
          lastKind   \* AUXILIARY: which of the write paths the most recent action was

vars == << tree, valid, cached, cval, cleared, actQ, lastKind >>

\* What a walk can read, and it is the whole question. §4.2 walks the §ATTEST:5.4 index, which
\* §ATTEST:5.7 I4 keeps populated regardless of liveness or authority; nothing in §4.2 filters
\* to validated entries. The alternative is the closure §4.2's cold-start justification claims
\* already holds.
Readable(a) == IF WalkClosedOverValidated THEN valid[a] ELSE tree[a]

TreeSetOf(q)  == {a \in AttsOf(q) : Readable(a)}
ValidSetOf(q) == {a \in AttsOf(q) : valid[a]}

Invalidate(q) == IF ScopedInvalidation THEN {q} ELSE Quorums

Drop(S) == [x \in Quorums |-> IF x \in S THEN FALSE ELSE cached[x]]

\* ---------------------------------------------------------------------------------------
\* THE WRITE PATHS. §4.2.1 names three and gives each a different cache disposition.
\* ---------------------------------------------------------------------------------------

\* §4.2.1 triggers 1 and 2: a successful local `system/quorum:update` / `:publish`, or a
\* validated arrival from any source -- "local handler op, cross-peer sync, envelope.included
\* ingestion, or L0 bootstrap path". One action, because §4.2.1 says the contract is on
\* post-state and both permitted mechanisms produce the same one.
Accept(a) ==
  /\ ~tree[a]
  /\ tree'    = [tree  EXCEPT ![a] = TRUE]
  /\ valid'   = [valid EXCEPT ![a] = TRUE]
  /\ cleared' = IF AcceptInvalidates THEN Invalidate(Owner(a)) ELSE {}
  /\ cached'  = Drop(cleared')
  /\ actQ'    = Owner(a)
  /\ lastKind' = "accept"
  /\ UNCHANGED cval

\* §4.2.1 non-trigger 1: fails K-of-N. "MUST NOT invalidate the cache. The attestation may sit
\* in the tree at a structurally-valid path without being authoritative."
FailValidation(a) ==
  /\ ~tree[a]
  /\ tree'    = [tree EXCEPT ![a] = TRUE]
  /\ cleared' = {}
  /\ actQ'    = Owner(a)
  /\ lastKind' = "fail"
  /\ UNCHANGED << valid, cached, cval >>

\* §8: "Direct tree:put to system/quorum/... paths is permitted but bypasses the quorum
\* handler's validation." §4.2.1 non-trigger 2: it MUST NOT invalidate the cache.
RawPut(a) ==
  /\ RawWrites
  /\ ~tree[a]
  /\ tree'    = [tree EXCEPT ![a] = TRUE]
  /\ cleared' = IF RawInvalidates THEN Invalidate(Owner(a)) ELSE {}
  /\ cached'  = Drop(cleared')
  /\ actQ'    = Owner(a)
  /\ lastKind' = "raw"
  /\ UNCHANGED << valid, cval >>

\* §4.2 / §4.2.1 "Recompute on next call": a cache miss walks the chain fresh and repopulates.
Walk(q) ==
  /\ ~cached[q]
  /\ cached'  = [cached EXCEPT ![q] = TRUE]
  /\ cval'    = [cval   EXCEPT ![q] = TreeSetOf(q)]
  /\ cleared' = {}
  /\ actQ'    = q
  /\ lastKind' = "walk"
  /\ UNCHANGED << tree, valid >>

\* §4.2's cold-start posture: "On cold start (process restart, fresh peer-state import), the
\* cache is empty."
ColdStart ==
  /\ \E q \in Quorums : cached[q]
  /\ cached'  = [x \in Quorums |-> FALSE]
  /\ cleared' = {}
  /\ actQ'    = NOQ
  /\ lastKind' = "cold"
  /\ UNCHANGED << tree, valid, cval >>

\* ---------------------------------------------------------------------------------------
\* THE PROPERTIES
\* ---------------------------------------------------------------------------------------

\* §4.2.1's own sentence, verbatim: "The cache reflects validated quorum state, not raw tree
\* state." GREEN under the closure and VIOLATED without it -- which is the finding.
CacheMatchesValidated ==
  \A q \in Quorums : cached[q] => cval[q] = ValidSetOf(q)

\* §4.2.1 non-triggers 1 and 2, TV-QF14. Only a validate-accept may clear a cache entry; a
\* failed validation and a raw `tree:put` must leave it exactly as it was. Not a tautology of
\* the transcription: the model offers three write paths and this says which of them may fire.
NoInvalidationWithoutAcceptance ==
  cleared # {} => lastKind = "accept"

\* §4.2.1 non-trigger 3, TV-QF15: "Activity on `quorum_id_other` MUST NOT invalidate the cache
\* for `quorum_id`. Cache entries are independently scoped per `quorum_id`."
InvalidationScopedPerQuorum ==
  cleared \subseteq {actQ}

\* §4.2.1 triggers 1 and 2, TV-QF12 / TV-QF13: a validate-accept leaves no stale entry behind
\* for the quorum it was an event of.
AcceptLeavesNoStaleEntry ==
  (lastKind = "accept") => ~cached[actQ]

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Each asserted in order to be VIOLATED; the violation is the pass.
\* ---------------------------------------------------------------------------------------

\* A populated cache is REACHED. Without it every property above is a statement about a system
\* whose cache is permanently empty, and `CacheMatchesValidated` in particular is vacuous.
WitnessCachePopulated == ~(\E q \in Quorums : cached[q])

\* An entity is bound in the tree WITHOUT having been validated. This is the precondition the
\* whole finding turns on, and §4.2's cold-start sentence asserts it cannot happen.
WitnessUnvalidatedInTree == ~(\E a \in Atts : tree[a] /\ ~valid[a])

\* The cold-start state the spec describes, with an unvalidated entity already in the tree: every
\* cache empty, so the next read walks -- and trusts. Without this the finding could be an
\* artifact of a cache that was never cleared.
WitnessColdStartExposed ==
  ~(/\ \A q \in Quorums : ~cached[q]
    /\ \E a \in Atts : tree[a] /\ ~valid[a])

\* ---------------------------------------------------------------------------------------
Init == /\ tree     = [a \in Atts |-> FALSE]
        /\ valid    = [a \in Atts |-> FALSE]
        /\ cached   = [q \in Quorums |-> FALSE]
        /\ cval     = [q \in Quorums |-> {}]
        /\ cleared  = {}
        /\ actQ     = NOQ
        /\ lastKind = "init"

Next == \/ \E a \in Atts : Accept(a) \/ FailValidation(a) \/ RawPut(a)
        \/ \E q \in Quorums : Walk(q)
        \/ ColdStart

Spec == Init /\ [][Next]_vars

TypeOK == /\ tree  \in [Atts -> BOOLEAN]
          /\ valid \in [Atts -> BOOLEAN]
          /\ \A a \in Atts : valid[a] => tree[a]
          /\ cached \in [Quorums -> BOOLEAN]
          /\ \A q \in Quorums : cval[q] \subseteq AttsOf(q)
          /\ cleared \subseteq Quorums
          /\ actQ \in Quorums \cup {NOQ}
====
