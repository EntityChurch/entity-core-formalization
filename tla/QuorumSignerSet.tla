---- MODULE QuorumSignerSet ----
\* QUORUM TRACK, first model. §4.2 `current_signer_set` — the resolver that decides, for every
\* consumer of this extension, WHO IS ALLOWED TO SIGN.
\*
\* TRACK: `quorum` (TRACKS.toml). A bare §N.M means a section of EXTENSION-QUORUM.md at this
\* track's pin. A cross-track reference writes the sigil first: §ATTEST:5.3 is a section of
\* EXTENSION-ATTESTATION.md and is EXCLUDED from both tracks' coverage sets.
\*
\* WHY THIS MODULE EXISTS AND WHY THE CLOCK IS IN IT FROM THE START.
\* `AttestLive` and `AttestRevoke` both abstracted the clock to one `expired` flag per node and
\* declared it. §4.2 makes that abstraction untenable: it carries a normative MUST about
\* historical state ("`current_signer_set(quorum_id, ctx, as_of)` MUST return the signer set +
\* threshold live at the `as_of` timestamp"), and the sentence that defines the contract is
\* written in terms of `not_before`. So `not_before`, `expires_at` and `as_of` are all modeled
\* here as a real clock, and the first thing that falls out is a defect neither prior module
\* could see. A declared abstraction is a to-do list, not an absolution (LEAN-SEAM O9).
\*
\* WHAT §4.2 SAYS. Two things, and they are not the same thing.
\*
\* (1) THE ALGORITHM:
\*       updates = find_attestations_targeting(quorum_id, kind == "quorum-update", ctx)
\*       if updates is not empty:
\*         head = EXTENSION_ATTESTATION.find_live_head(updates[0], ctx, as_of=as_of)
\*         if head is not null:
\*           signers   = head.properties.new_signers
\*           threshold = head.properties.new_threshold
\*     — note what happens when `head` is null: `signers` KEEPS THE VALUE IT WAS GIVEN four
\*     lines earlier, `quorum.data.signers`, the roster frozen into the quorum entity at
\*     `:create`. A null head is not an error and not an empty set. It is a SILENT REVERT to
\*     the creation-time roster.
\*
\* (2) THE NORMATIVE SENTENCE, in the same section: "`current_signer_set` MUST return the signer
\*     set + threshold that was live at the `as_of` timestamp — i.e. the most recent
\*     `quorum-update` whose `not_before <= as_of` (or the quorum entity's initial signers if no
\*     such update exists), with no successor that was itself live at `as_of`."
\*
\* This module computes both and compares them. `SpecMatchesNormative` is asserted in a config
\* that expects it to be VIOLATED, on a model in which nothing is weakened.
\*
\* THREE INDEPENDENT DEFECTS, each its own finding row.
\*
\*  A. `updates[0]`. §ATTEST:5.4 `find_attestations_targeting` returns a LIST out of a field
\*     index and specifies no order. §4.2 walks forward from its first element. Composed with
\*     the §ATTEST:5.3 defect this repo already routed — the forward walk cannot traverse a
\*     chain of three — the ANSWER DEPENDS ON WHICH ELEMENT THE INDEX HAPPENS TO YIELD FIRST.
\*     `ResultIndependentOfProbe`.
\*
\*  B. The silent revert. On a chain of three, `find_live_head` returns null from the oldest
\*     element, so §4.2 falls through to the genesis roster WHILE A MEMBERSHIP CHANGE IS IN
\*     FORCE. A `quorum-update` that removed a compromised signer is undone by the resolver
\*     that exists to apply it. `SpecNeverSilentlyReverts`.
\*
\*  C. `not_before` and the undefined `not_expired`. §ATTEST:4.3's descendant filter is
\*     `not_expired(next, as_of) and not is_self_revoked(next, ctx, as_of)`. **Neither helper is
\*     defined anywhere in that document** — the finding this repo routed as F4, argued there on
\*     `is_self_revoked`. Here it is `not_expired` that bites, and it bites harder: read
\*     literally (the expires_at check, which is what the name says and what §ATTEST:4.3 writes
\*     four lines above as a SEPARATE check from `not_before`), an attestation whose `not_before`
\*     is still in the future is "not expired" and therefore counts as a live descendant. It
\*     kills its predecessor without being usable itself. **Scheduling a membership change in
\*     advance takes the quorum to its genesis roster until the change takes effect.**
\*     `NotExpiredReadingsAgree`.
\*
\* THE COHORT, MEASURED BEFORE ANY IMPACT CLAIM (docs/PROPERTIES.md §D.1 is the record of this
\* repo getting an impact argument wrong while its census was right).
\*   - `updates[0]`: NONE of the three implementations does it. entity-core-go and
\*     entity-core-py probe EVERY candidate and take the lowest content_hash among the heads
\*     found; entity-core-rust probes the chain ROOTS and takes the first that yields a head.
\*     Three independent authors, three workarounds, same direction.
\*   - `as_of`: §ATTEST:5.3's signature is `find_live_head(start, ctx)` — there is no `as_of`
\*     parameter and its internal `is_attestation_live(s, ctx)` forwards none. §4.2's claim that
\*     "`find_live_head` already takes `as_of`" is false against the pinned text. Go added the
\*     parameter; Rust wrote the gap into a code comment ("find_live_head doesn't currently take
\*     as_of (that's a follow-up amendment), so we walk the chain ourselves") and hand-rolled
\*     the walk; Python hand-rolled it too. This is the routed F3, confirmed at two levels.
\*   - `not_expired`: ALL THREE read it as full temporal validity. Go's `shallowEffective`,
\*     Rust's `is_self_valid_basic` and Python's `_is_temporally_invalid` each check `expires_at`
\*     AND `not_before`. The unanimous cohort reading is the one the document does not write.
\* So defect C is spec-only and the divergence is in the SAFE direction, exactly as F1 was. The
\* `DescTemporal` constant is that reading, and a negative control flips it.
\*
\* A NOTE ON WHAT `CohortMatchesNormativeOnChain` IS AND IS NOT. It is guarded by
\* `WellFormedChain` — one root, at most one successor per node — because that is the shape §3.2
\* describes ("a `quorum-update` supersedes the previous `quorum-update` for the same quorum").
\* Off that shape the cohort's repairs and the normative sentence disagree, and they disagree
\* with each other: Go/Py take the LOWEST content_hash across probes, §ATTEST:5.3 takes the
\* HIGHEST inside a walk. `CohortMatchesNormative` unguarded is a fourth finding row for exactly
\* that reason. Nothing in §6.2 validates the chain shape — `supersedes` is an optional
\* caller-supplied hash — so the well-formed case is a convention, not an invariant.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): ABSTRACTED AWAY -- signatures and K-of-N
\* validation entirely (that is `QuorumKofN`), the cache and the arrival-time trust model (that
\* is `QuorumTrust`), revocation of a quorum-update (the revocation dimension is measured in
\* `AttestRevoke`; composing it with the clock is future work and is the reason
\* `DescReadingsCoincide` over there is scoped to a model with no not_before), the resolver hook
\* and every resolution mode, content hashing (a node's number stands in for its content hash,
\* and both orderings below are taken over that number), the roster VALUES themselves -- what is
\* under test is WHICH update supplies the roster, so a head's identity is the answer and the
\* signer list it carries is not modeled. Those sentences carry no § sigil deliberately -- a
\* scope disclaimer that cites a section was being counted as coverage of it
\* (../docs/COVERAGE-MATRIX.md §3b).
EXTENDS Naturals, FiniteSets

CONSTANTS N,               \* quorum-update attestations, 1..N. THREE is the smallest chain on
                           \* which §ATTEST:5.3's forward walk fails, so it is the smallest
                           \* model on which §4.2 inherits the failure.
          T,               \* the clock runs over 1..T. TWO distinct instants suffice: one at
                           \* which a not_before is in the future and one at which it is not.
          ProbeAllUpdates, \* TRUE  = what all three implementations do: probe every element of
                           \*         `updates`, take the lowest-numbered head found.
                           \* FALSE = negative control, and it is §4.2 AS WRITTEN: probe
                           \*         `updates[0]` only. The control's failure is the measure of
                           \*         how much the cohort's workaround is doing.
          DescTemporal     \* the reading of §ATTEST:4.3's UNDEFINED `not_expired`, inside
                           \* has_live_transitive_descendant.
                           \* TRUE  = full temporal validity (expires_at AND not_before). What
                           \*         Go, Rust and Python all compute.
                           \* FALSE = negative control, and it is the LITERAL reading: the
                           \*         expires_at check alone, which is what the helper is named
                           \*         after and what §ATTEST:4.3 writes as a separate check.

Nodes   == 1..N
Times   == 1..T
NULL    == 0
\* GENESIS and NULL are deliberately the same value. §4.2 has no third outcome: either
\* `find_live_head` yields a head, or `signers` still holds `quorum.data.signers`. Naming the
\* fall-through makes the finding rows below readable as English.
GENESIS == 0

VARIABLES sup,   \* §3.2 supersedes: the per-quorum back-pointer, NULL for the initial entry
          nb,    \* §3.2 not_before, NULL when the field is absent
          xp     \* §3.2 expires_at, NULL when the field is absent

vars == << sup, nb, xp >>

\* ---------------------------------------------------------------------------------------
\* The supersedes graph. §ATTEST:5.6a find_attestations_with_supersedes is the inverse pointer;
\* NO SIGIL on that section number -- this model assumes its contract and verifies nothing
\* about it.
\* ---------------------------------------------------------------------------------------
Succ(p) == {c \in Nodes : sup[c] = p}

RECURSIVE GrowF(_, _)
GrowF(S, k) == IF k = 0 THEN S
               ELSE LET S2 == S \cup UNION {Succ(p) : p \in S}
                    IN IF S2 = S THEN S ELSE GrowF(S2, k - 1)

Desc(x) == GrowF(Succ(x), N)

Roots == {x \in Nodes : sup[x] = NULL}

\* The shape §3.2 describes and §6.2 does not enforce: a single per-quorum chain.
WellFormedChain == /\ Cardinality(Roots) = 1
                   /\ \A x \in Nodes : Cardinality(Succ(x)) <= 1

\* ---------------------------------------------------------------------------------------
\* §ATTEST:4.3's two temporal checks, kept apart on purpose -- the document writes them as two
\* consecutive `if` statements and then names only one of them in the descendant filter.
\* ---------------------------------------------------------------------------------------
NotExpiredOnly(x, t) == xp[x] = NULL \/ t < xp[x]
Effective(x, t)      == /\ NotExpiredOnly(x, t)
                        /\ nb[x] = NULL \/ nb[x] <= t

\* The undefined helper, both ways. `rd` TRUE is the cohort's reading.
NotExpired(x, t, rd) == IF rd THEN Effective(x, t) ELSE NotExpiredOnly(x, t)

\* §ATTEST:4.3 has_live_transitive_descendant, minus self-revocation (declared above).
\* Termination is by construction: `Init` allows a supersedes pointer only to a LOWER index, so
\* `Desc` is finite and strictly increasing. That restriction is the acyclicity assumption
\* LEAN-SEAM O6 isolated, doing load-bearing work again.
HasLiveDesc(x, t, rd) == \E d \in Desc(x) : NotExpired(d, t, rd)

\* §ATTEST:4.3 is_attestation_live, restricted to the dimensions this module models.
Live(x, t, rd) == Effective(x, t) /\ ~HasLiveDesc(x, t, rd)

\* ---------------------------------------------------------------------------------------
\* §ATTEST:5.3 find_live_head, transcribed including its tie-break:
\*     max(live_successors, key=lambda s: (s.not_before or 0, s.content_hash))
\* -- so a HIGHER not_before wins, ties broken by a HIGHER content_hash (node number here).
\* ---------------------------------------------------------------------------------------
NbOr0(x) == IF nb[x] = NULL THEN 0 ELSE nb[x]

MostRecent(S) == CHOOSE x \in S :
                   \A y \in S : \/ NbOr0(x) > NbOr0(y)
                                \/ (NbOr0(x) = NbOr0(y) /\ x >= y)

\* The walk. `fuel` is N because each step moves to a strictly higher node index (`Init`), so N
\* steps cannot be exceeded; it is present so the recursion is well-founded to TLC rather than
\* to a reader. §ATTEST:5.3 itself is a `while True` with no bound, which is the observation
\* AttestLive's BackWalkBoundedAlways owns.
RECURSIVE HeadFrom(_, _, _, _)
HeadFrom(cur, t, rd, fuel) ==
  IF fuel = 0 THEN NULL
  ELSE LET ls == {s \in Succ(cur) : Live(s, t, rd)}
       IN IF ls = {}
          THEN (IF Live(cur, t, rd) THEN cur ELSE NULL)
          ELSE HeadFrom(MostRecent(ls), t, rd, fuel - 1)

SpecHead(start, t, rd) == HeadFrom(start, t, rd, N)

\* §4.2's whole algorithm from one probe element. A null head is the silent fall-through.
SpecResult(start, t, rd) == LET h == SpecHead(start, t, rd)
                            IN IF h = NULL THEN GENESIS ELSE h

\* ---------------------------------------------------------------------------------------
\* WHAT §4.2's NORMATIVE SENTENCE ASKS FOR, independently of how §4.2 computes it.
\* "the most recent quorum-update whose not_before <= as_of ... with no successor that was
\* itself live at as_of." Read "live at as_of" as the sentence's own plain sense -- within its
\* validity window at that instant -- and "successor" transitively, consistent with
\* §ATTEST:4.3's transitive supersession. Both of those are readings; both are stated here
\* rather than assumed, because the sentence pins neither and "most recent" names no field.
\* The tie-break adopted is §ATTEST:5.3's own, for the same reason.
\* ---------------------------------------------------------------------------------------
LiveAt(x, t) == Effective(x, t)

NormCandidates(t) == {x \in Nodes : LiveAt(x, t) /\ \A d \in Desc(x) : ~LiveAt(d, t)}

NormativeResult(t) == IF NormCandidates(t) = {}
                      THEN GENESIS
                      ELSE MostRecent(NormCandidates(t))

\* ---------------------------------------------------------------------------------------
\* THE RESOLUTION ACTUALLY PERFORMED. Every node in this model IS a quorum-update targeting the
\* quorum, so `updates` is `Nodes` and "probe every element" quantifies over Nodes.
\* Go and Python take the LOWEST content_hash among the heads their probes find; that is `Least`
\* below. Under the control this collapses to §4.2's literal `updates[0]`, modeled as the
\* lowest-numbered probe -- any fixed choice would do, and the point of the finding rows is that
\* the choice is not fixed at all.
\* ---------------------------------------------------------------------------------------
Least(S) == CHOOSE x \in S : \A y \in S : x <= y

ProbeHeads(t) == {SpecHead(u, t, DescTemporal) : u \in Nodes} \ {NULL}

Resolve(t) == IF ProbeAllUpdates
              THEN (IF ProbeHeads(t) = {} THEN GENESIS ELSE Least(ProbeHeads(t)))
              ELSE SpecResult(Least(Nodes), t, DescTemporal)

\* ---------------------------------------------------------------------------------------
\* THE FINDINGS. Each is asserted in a config where every constant is the green sweep's
\* constant and nothing in the model is weakened.
\* ---------------------------------------------------------------------------------------

\* FINDING A. §4.2 walks from `updates[0]` and §ATTEST:5.4 defines no order on `updates`, so
\* this asks whether the choice can matter. It can: on a chain of three the oldest element
\* yields null and the middle yields the true head.
\*
\* BOTH THIS ROW AND THE NEXT ARE GUARDED BY `WellFormedChain`, AND THE GUARD IS THE POINT.
\* Unguarded, both are violated -- but by a SMALLER and less interesting state than the one
\* the prose claims: TLC's minimal counterexample is a probe of an already-dead update among
\* several unrelated roots, which is a true instance and not the mechanism being routed. With
\* the guard, `Cardinality(Roots) = 1` and `Cardinality(Succ(x)) <= 1` leave exactly one shape
\* on three nodes -- the linear chain 1 <- 2 <- 3 -- so the exhibited state IS the chain of
\* three, and the finding says what it means. A finding whose stated mechanism is not the one
\* its counterexample exhibits is docs/PROPERTIES.md §D.1 happening again; the guard is how
\* that is avoided here rather than apologised for later.
ResultIndependentOfProbe ==
  \A t \in Times :
    WellFormedChain =>
      \A u, v \in Nodes :
        SpecResult(u, t, DescTemporal) = SpecResult(v, t, DescTemporal)

\* FINDING B, and the one with teeth. §4.2 returns the CREATION-TIME roster while a
\* quorum-update is live and in force. Stated as: if any update is live at `as_of`, the answer
\* is not the fall-through. Guarded as above, so the counterexample is an ordinary quorum whose
\* membership has been changed three times and nothing else.
SpecNeverSilentlyReverts ==
  \A t \in Times :
    (WellFormedChain /\ \E x \in Nodes : LiveAt(x, t)) =>
      \A u \in Nodes : SpecResult(u, t, DescTemporal) # GENESIS

\* FINDING C. The two readings of §ATTEST:4.3's undefined `not_expired` do not agree on §4.2's
\* answer. The counterexample is a scheduled membership change: under the literal reading a
\* not-yet-effective successor is "not expired", so it kills its predecessor without being
\* usable itself, and the quorum drops to its genesis roster until the change takes effect.
NotExpiredReadingsAgree ==
  \A t \in Times : \A u \in Nodes :
    SpecResult(u, t, TRUE) = SpecResult(u, t, FALSE)

\* FINDING D. §4.2's algorithm against §4.2's own normative sentence, directly.
SpecMatchesNormative ==
  \A t \in Times : \A u \in Nodes :
    SpecResult(u, t, DescTemporal) = NormativeResult(t)

\* FINDING E. The cohort's repairs match the normative sentence on the chain shape §3.2
\* describes and NOT off it -- and off it they do not match each other either (Go/Py take the
\* lowest content_hash across probes; §ATTEST:5.3 takes the highest within a walk). §6.2
\* validates `new_threshold` and does not validate the chain shape, so nothing makes the
\* well-formed case an invariant.
CohortMatchesNormative == \A t \in Times : Resolve(t) = NormativeResult(t)

\* ---------------------------------------------------------------------------------------
\* THE GREENS.
\* ---------------------------------------------------------------------------------------

\* §4.2 GREEN, and it is a COHORT result rather than a spec result -- the same disposition as
\* AttestRevoke's DescReadingsCoincide. On the single-chain shape §3.2 describes, the repair all
\* three implementations independently wrote computes exactly what §4.2's normative sentence
\* asks for. The spec's own algorithm does not (FINDING D). Control: ProbeAllUpdates = FALSE.
CohortMatchesNormativeOnChain ==
  WellFormedChain => \A t \in Times : Resolve(t) = NormativeResult(t)

\* §4.2 GREEN. The safety property the whole section exists to provide: the resolver does not
\* hand back the creation-time roster while a membership change is in force. True of the
\* cohort's algorithm, and FINDING B is the same sentence about the spec's.
\* Control: DescTemporal = FALSE -- which is what makes the reading load-bearing rather than
\* editorial.
CohortNeverSilentlyReverts ==
  \A t \in Times :
    (\E x \in Nodes : LiveAt(x, t)) => Resolve(t) # GENESIS

\* §4.2 GREEN. Whatever head is returned is itself within its validity window at `as_of` and has
\* no live successor -- i.e. it is a normative candidate. Weaker than
\* CohortMatchesNormativeOnChain (it does not say WHICH candidate) and stated separately because
\* it holds unguarded, on forked graphs too, where the stronger one does not.
ResolvedHeadIsCurrent ==
  \A t \in Times :
    Resolve(t) # GENESIS =>
      /\ LiveAt(Resolve(t), t)
      /\ \A d \in Desc(Resolve(t)) : ~LiveAt(d, t)

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Each asserted in order to be VIOLATED; the violation is the pass.
\* ---------------------------------------------------------------------------------------

\* A well-formed chain of THREE, all three within their validity windows at some instant. This
\* is the configuration FINDING A and FINDING B are about; without it both are violations of
\* something unreachable and the greens are statements about chains of two.
WitnessThreeChain ==
  ~(/\ WellFormedChain
     /\ \E t \in Times : \A y \in Nodes : Effective(y, t)
     /\ \E x \in Nodes : Cardinality(Desc(x)) = 2)

\* A SCHEDULED update: not yet effective at `t`, with an effective predecessor. FINDING C is
\* about this state and nothing else.
WitnessPendingUpdate ==
  ~(\E t \in Times : \E x \in Nodes :
      /\ nb[x] # NULL /\ nb[x] > t
      /\ sup[x] # NULL /\ Effective(sup[x], t))

\* The fall-through is REACHED: §4.2 returns the genesis roster at an instant when some update
\* is live. This is FINDING B's state exhibited directly, and without it that row could be
\* satisfied by an antecedent that never holds.
WitnessSilentRevert ==
  ~(\E t \in Times :
      /\ \E x \in Nodes : LiveAt(x, t)
      /\ \E u \in Nodes : SpecResult(u, t, DescTemporal) = GENESIS)

\* ---------------------------------------------------------------------------------------
\* The graph space: every supersedes configuration over N nodes with the pointer restricted to
\* lower indices (see the termination note above), crossed with every assignment of not_before
\* and expires_at over the modeled clock, NULL included.
\* ---------------------------------------------------------------------------------------
Init == /\ sup \in [Nodes -> Nodes \cup {NULL}]
        /\ \A x \in Nodes : sup[x] = NULL \/ sup[x] < x
        /\ nb \in [Nodes -> Times \cup {NULL}]
        /\ xp \in [Nodes -> Times \cup {NULL}]

Next == UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK == /\ sup \in [Nodes -> Nodes \cup {NULL}]
          /\ nb  \in [Nodes -> Times \cup {NULL}]
          /\ xp  \in [Nodes -> Times \cup {NULL}]
====
