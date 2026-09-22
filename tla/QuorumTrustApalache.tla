---- MODULE QuorumTrustApalache ----
\* QUORUM TRACK — Apalache (SMT) second engine on tla/QuorumTrust.tla (§4.2's arrival-time trust
\* model and §4.2.1's cache-invalidation contract), and the LAST single-engine subject anywhere
\* on the extension tracks.
\*
\* TRACK: `quorum` (TRACKS.toml). A bare §N.M means a section of EXTENSION-QUORUM.md at this
\* track's pin (spec-data/ext-quorum-v1.2). §ATTEST:N.M is EXTENSION-ATTESTATION.md and is
\* EXCLUDED from every track's coverage set.
\*
\* ── WHAT A SECOND ENGINE WAS POINTED AT (D16), AND IT IS NOT THE INVARIANTS ──────────────────
\* Fifth consecutive application: **point the second engine at the first one's DOMAIN.** And on
\* this module the domain restriction is one the D18 sweep looked straight at and cleared.
\*
\* `AGENTS.md`'s D18 table carries the row *"`QuorumTrust.tla` — `~cached[q]` on `Walk` · action
\* guard · not in the class: §4.2.1's 'recompute on next call' IS a cache-miss guard, so the
\* guard is the algorithm rather than a restriction on it."* **That reading is correct and it was
\* the wrong question.** D18's own words are *what legal state can this model not represent*, and
\* the sweep asked instead which guards look suspicious. Three legal states this module cannot
\* represent, none of them behind the guard that was examined:
\*
\*   (a) **§4.2.1 TRIGGER 3 HAS NO ACTION.** The contract has THREE invalidation triggers.
\*       `QuorumTrust.tla` models trigger 1 and trigger 2 (correctly, as one `Accept` action —
\*       §4.2.1 says the contract is on post-state) and models all three NON-triggers. Trigger 3
\*       — *"Authority-revocation arrival. When a live revocation attestation targeting a
\*       `quorum-update` or `quorum-publish` previously seen for `quorum_id` arrives and passes
\*       validation, the cache entry for `quorum_id` MUST be invalidated"* — is in no action, no
\*       constant and no invariant. A revocation cannot happen in that model.
\*   (b) **THE TREE IS MONOTONE.** Every write action is guarded by `~tree[a]` and nothing ever
\*       unbinds. §8 permits direct `tree:put` to these paths, and a `tree:put(path, null)` is an
\*       unbind — so the model admits §8's additions and excludes §8's removals, from one clause.
\*   (c) **AN ATTESTATION ARRIVES ONCE.** The same `~tree[a]` guard means an attestation that
\*       failed K-of-N can never later pass, though §4.2.1 trigger 2 names `envelope.included`
\*       ingestion as an arrival source and non-trigger 1 explicitly contemplates the failed one
\*       *"sitting in the tree at a structurally-valid path without being authoritative"*.
\*
\* This module lifts all three, each behind a constant, and runs the obligations INDUCTIVELY
\* (base + step + strengthening closure) rather than bounded-exhaustively.
\*
\* ── WHAT (a) COSTS: A PUBLISHED CLAIM WAS OVER TWO THIRDS OF ITS OWN SUBJECT ──────────────────
\* `docs/status/ROUTING-2026-09-07-QUORUM.md` §"What is *not* wrong" publishes this, and it is the
\* half of that note we thought was the useful half:
\*
\*   > "`tla/QuorumTrust.tla`'s green run says the §4.2.1 contract is **exactly sufficient** given
\*   >  the closure: with reads restricted to validated entries, invalidating on successful local
\*   >  op and on validated arrival, and *not* invalidating on failed validation or raw put, and
\*   >  scoping per quorum, the cache never disagrees with validated state..."
\*
\* **"invalidating on successful local op and on validated arrival" is triggers 1 and 2.** There
\* is a third, and neither the sentence nor the model has it. A sufficiency claim over an
\* incomplete rule set is not a weaker version of the same claim — it is a claim about a
\* different contract.
\*
\* The correction is measured, not assumed, and it comes out in the SPEC'S FAVOUR: with the
\* revocation action added and `RevokeInvalidates` set as §4.2.1 writes it, `CacheMatchesValidated`
\* is **GREEN and inductive**. The contract really is exactly sufficient — now over all three
\* triggers, and now for runs of any length. `ConstInitBugRevokeNoInvalidate` is the control that
\* gives trigger 3 the teeth the other two already had.
\*
\* **`OnlyAcceptInvalidates` is the row that makes the correction visible rather than silent.** It
\* is `tla/QuorumTrust.tla`'s `NoInvalidationWithoutAcceptance`, transcribed unchanged, and its
\* own comment there reads *"Only a validate-accept may clear a cache entry."* **That sentence is
\* false of §4.2.1** and it was green for two days because the model had no action that could
\* falsify it. It is in the witness table here, asserted in order to be VIOLATED, so the
\* falsification is a gate row rather than a paragraph. The live property is
\* `NoInvalidationWithoutTrigger`, which names all three.
\*
\* ── WHAT (b) COSTS: THE CLOSURE THE SPEC NEEDS IS NOT THE ONE WE NAMED ───────────────────────
\* This is the finding, and it is O20's shape — an assumption isolated and found to be the wrong
\* strength, with the greens beside it doing half the work.
\*
\* Q5 says §4.2.1's *"The cache reflects validated quorum state, not raw tree state"* is false of
\* §4.2's algorithm, because the walk is an unfiltered index lookup and §8 permits raw writes.
\* The remedy that made everything green was `WalkClosedOverValidated` — **a read-side closure**:
\* only validated entries are readable. `tla/QuorumTrust.tla` shows that closure is sufficient.
\*
\* It is sufficient only because that model's tree cannot shrink. Lift (b) and it is **not**:
\* a raw `tree:put(path, null)` removes an entry that WAS validated, §4.2.1 non-trigger 2 forbids
\* invalidating on a raw tree-write, and the cache goes on serving a signer set derived from an
\* entity that is no longer there. The read-side closure does not help — the entry passes
\* `valid[a]` and is simply gone. **The closure §4.2 actually needs is write-side: the readable
\* set changes only through validate-accept.** That is a statement about which operations may
\* move the tree, and §8 is the sentence that denies it.
\*
\* Two things make this a strengthening of Q5 rather than a new finding, and the routing note says
\* so: same sentence, same §8 mechanism, opposite direction. What is new is that it **survives the
\* remedy** — Q5 is invisible under `WalkClosedOverValidated = TRUE` and this is not.
\*
\* ── WHAT (c) COSTS: NOTHING, AND THE GREEN IS THE POINT ──────────────────────────────────────
\* Re-arrival was the lift most likely to break something and it breaks nothing. §4.2.1 trigger 2
\* is explicit that *"The invalidation is on the `process_attestation`-style validate-and-accept
\* moment, NOT on the raw tree-write"*, so an attestation that is already bound and later passes
\* K-of-N fires trigger 2 anyway, and the contract handles it. Recorded as a green because a lift
\* that changes nothing is a measurement of the same kind as one that does — and because the
\* opposite result would have been a defect in the sentence just quoted.
\*
\* ── THE COHORT (docs/PROPERTIES.md §D.1 — census before any impact claim) ────────────────────
\* Carried from `ROUTING-2026-09-07-QUORUM.md` §1, re-read at the sibling checkouts: all three
\* implementations perform §4.2's walk as an unfiltered index lookup with no validated-only
\* predicate, faithfully. That census is what Q5 rests on and this module does not restate it.
\* **The cohort question this module's new rows raise is NOT answered here and is declared open**
\* in the routing note: whether any implementation invalidates on trigger 3, and what each does on
\* a raw unbind, are source questions this session did not measure. Naming them is D17's
\* enforcement point, not a substitute for it.
\*
\* ── WHAT THIS MODULE DOES *NOT* BUY (D16's counter-clause, stated at the site) ────────────────
\* Not independence from the transcription — same author, same reading of the same pinned text as
\* `QuorumTrust.tla`. Not a different QUESTION: both engines are checkers over TLA+ semantics, and
\* every finding here would be visible to TLC on this module too. What moved is the DOMAIN.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): `QuorumTrust.tla`'s boundary, minus the three
\* restrictions above. Still ABSTRACTED AWAY — signatures and the K-of-N check itself (an
\* attestation passed validation or did not; `QuorumKofN` models the check), the supersedes chain
\* and `find_live_head` (that is `QuorumSignerSet`, and revocation enters here only as "this entry
\* is no longer authoritative", not as a walk over the liveness graph), the clock and `as_of`, the
\* resolver hook, and the distinction between §4.2.1's two permitted mechanisms (A) and (B) — the
\* contract is explicitly on post-state and both produce the same one. **Bounded in ENTITIES, not
\* in STEPS**: three events over two quorums, which is what §4.2.1 non-trigger 3 needs, and the
\* inductive obligations then hold for runs of any length over that universe. Those sentences
\* carry no § sigil deliberately — a scope disclaimer that cites a section was being counted as
\* coverage of it (../docs/COVERAGE-MATRIX.md section 3b).
EXTENDS Naturals

CONSTANTS
  \* @type: Bool;
  RawWrites,               \* §8 as written: direct `tree:put` is permitted. FALSE restricts the
                           \* model to handler paths, to show a defect does not depend on §8.
  \* @type: Bool;
  RawDeletes,              \* LIFTS restriction (b). §8's permission covers `tree:put(path, null)`
                           \* — an unbind — and `QuorumTrust.tla` has only the additive half.
                           \* FALSE reproduces that model's monotone tree.
  \* @type: Bool;
  AcceptInvalidates,       \* §4.2.1 triggers 1 and 2 as written. FALSE is a negative control.
  \* @type: Bool;
  RevokeInvalidates,       \* §4.2.1 TRIGGER 3 as written — the trigger `QuorumTrust.tla` has no
                           \* action for at all. FALSE is a negative control, and it is the one
                           \* that gives trigger 3 the teeth the other two already had.
  \* @type: Bool;
  RawInvalidates,          \* §4.2.1 non-trigger 2 as written is FALSE: a raw tree-write MUST NOT
                           \* invalidate. TRUE is a negative control.
  \* @type: Bool;
  ScopedInvalidation,      \* §4.2.1 non-trigger 3 as written: per-quorum scope. FALSE is a
                           \* negative control.
  \* @type: Bool;
  WalkClosedOverValidated, \* TRUE = the READ-SIDE closure §4.2's cold-start sentence asserts:
                           \* only validated entries are readable by the walk.
                           \* FALSE = §4.2 as written — the §ATTEST:5.4 index lookup, which
                           \* §ATTEST:5.7 I4 says filters by nothing. That is Q5.
  \* @type: Bool;
  RevocationsEnabled,      \* LIFTS restriction (a). FALSE reproduces `QuorumTrust.tla`'s domain:
                           \* no revocation can occur, so trigger 3 is unreachable and
                           \* `OnlyAcceptInvalidates` is true by absence.
  \* @type: Bool;
  ReArrivalEnabled         \* LIFTS restriction (c). FALSE reproduces the `~tree[a]` write-once
                           \* guard: an attestation arrives exactly once and its validation
                           \* verdict can never change.

\* Bounded universe, disclosed: three events over two quorums. TWO quorums is what §4.2.1
\* non-trigger 3 / TV-QF15 needs (disjoint event sets), and THREE events give one quorum two, so
\* a cache entry can be right about one and wrong about the other. Unbounded in STEPS, not in
\* ENTITIES — the `AttestIndexApalache` disposition, and stated rather than left to be inferred.
Atts    == 1..3
Quorums == 1..2
NOQ     == 0

\* Which quorum each event belongs to. Round-robin, so quorum 1 owns {1, 3} and quorum 2 owns {2}.
Owner(a) == ((a - 1) % 2) + 1

\* ---------------------------------------------------------------------------------------
\* THE CACHE, AND WHY IT IS A MEMBERSHIP FUNCTION RATHER THAN A SET.
\* `QuorumTrust.tla` carries `cval` as `Quorums -> SUBSET Atts`. `SUBSET` is one of the four
\* idioms `AGENTS.md` names as an Apalache blow-up, and the set-valued form buys nothing here
\* because `Owner` PARTITIONS `Atts`: an attestation belongs to exactly one quorum, so one
\* `Atts -> BOOLEAN` carries every quorum's cached walk result at once. `cval[a]` reads "a is in
\* the cached result for a's own quorum". Same for `cleared`, which is a set of quorums there and
\* a `Quorums -> BOOLEAN` here.
\* ---------------------------------------------------------------------------------------
VARIABLES
  \* @type: Int -> Bool;
  tree,      \* §7: bound at `system/quorum/{q}/event/{hash}`. NO LONGER MONOTONE — see RawDelete.
  \* @type: Int -> Bool;
  valid,     \* §4.2.1: passed structural + signature + K-of-N validation on arrival.
  \* @type: Int -> Bool;
  revoked,   \* NEW (lift a): a live revocation targeting this event arrived and passed
             \* validation. Section 3.2 makes a `quorum-update` a SELF-attestation
             \* (`attesting == attested == quorum_id`), so §ATTEST:4.3's self-revocation rule is
             \* what makes the quorum the natural revoker of its own events. Cited without a
             \* sigil: nothing here verifies the attestation's shape, and a background mention
             \* counted as coverage is the class ../docs/COVERAGE-MATRIX.md section 3e audited nine of.
  \* @type: Int -> Bool;
  cached,    \* §4.2.1: is there a cache entry for this quorum.
  \* @type: Int -> Bool;
  cval,      \* what it holds. Meaningful only where `cached[Owner(a)]`.
  \* @type: Int -> Bool;
  clearedF,  \* AUXILIARY: the quorums whose cache the MOST RECENT action invalidated.
  \* @type: Int;
  actQ,      \* AUXILIARY: the quorum the most recent action was an event of.
  \* @type: Str;
  lastKind   \* AUXILIARY: which write path the most recent action was.

vars == << tree, valid, revoked, cached, cval, clearedF, actQ, lastKind >>

\* ---------------------------------------------------------------------------------------
\* WHAT A WALK CAN READ. Three conjuncts where `QuorumTrust.tla` has one branch, and each of the
\* two additions is a lift:
\*   `tree[a]`     — an unbound entity is not readable. Vacuous there (nothing unbinds), load-
\*                   bearing here (RawDelete). Note the TLC module's closure branch drops this
\*                   conjunct entirely and is saved only by `valid => tree`, which RawDelete
\*                   falsifies.
\*   `~revoked[a]` — §4.2's walk ends at `find_live_head`, and §ATTEST:4.3 liveness excludes
\*                   revoked attestations. Modelled as a filter rather than as a graph walk,
\*                   because the walk is `QuorumSignerSet`'s subject and re-transcribing it here
\*                   would re-derive Q1 and Q8 wearing this module's row names.
\*   the closure   — §4.2's own cold-start justification, as a constant. Q5 is its negation.
\* ---------------------------------------------------------------------------------------
Readable(a) == /\ tree[a]
               /\ ~revoked[a]
               /\ (WalkClosedOverValidated => valid[a])

\* "Validated quorum state", which is what §4.2.1's sentence says the cache reflects. Bound,
\* validated, and not since revoked. The middle conjunct is the one §4.2.1 names; the other two
\* are what "state" means once entries can leave.
ValidNow(a) == tree[a] /\ valid[a] /\ ~revoked[a]

\* §4.2.1 non-trigger 3: per-quorum scope, or (control) everything.
ClearOn(q) == [x \in Quorums |-> IF ScopedInvalidation THEN x = q ELSE TRUE]
NoClear    == [x \in Quorums |-> FALSE]

\* @type: (Int -> Bool) => (Int -> Bool);
Dropped(cl) == [x \in Quorums |-> IF cl[x] THEN FALSE ELSE cached[x]]

\* An arrival may occur when the entity is not yet bound, or — lift (c) — again afterwards.
\* §4.2.1 trigger 2 fires on the validate-and-accept MOMENT, "NOT on the raw tree-write", so a
\* re-arrival that validates is a trigger even though it binds nothing new.
MayArrive(a) == ~tree[a] \/ ReArrivalEnabled

\* ---------------------------------------------------------------------------------------
\* THE WRITE PATHS. §4.2.1 names three triggers and three non-triggers; there is one action here
\* per path, and each carries its own cache disposition behind its own constant.
\* ---------------------------------------------------------------------------------------

\* §4.2.1 TRIGGERS 1 and 2: a successful local `:update` / `:publish`, or a validated arrival from
\* any source. One action, because §4.2.1 says the contract is on post-state and both permitted
\* mechanisms produce the same one.
Accept(a) ==
  /\ MayArrive(a)
  /\ tree'     = [tree  EXCEPT ![a] = TRUE]
  /\ valid'    = [valid EXCEPT ![a] = TRUE]
  /\ clearedF' = IF AcceptInvalidates THEN ClearOn(Owner(a)) ELSE NoClear
  /\ cached'   = Dropped(clearedF')
  /\ actQ'     = Owner(a)
  /\ lastKind' = "accept"
  /\ UNCHANGED << revoked, cval >>

\* §4.2.1 TRIGGER 3 — THE ONE `QuorumTrust.tla` HAS NO ACTION FOR. "A live revocation attestation
\* targeting a quorum-update or quorum-publish previously seen for quorum_id arrives and passes
\* validation." The `tree[a]` guard IS the "previously seen" clause, transcribed.
Revoke(a) ==
  /\ RevocationsEnabled
  /\ tree[a]
  /\ ~revoked[a]
  /\ revoked'  = [revoked EXCEPT ![a] = TRUE]
  /\ clearedF' = IF RevokeInvalidates THEN ClearOn(Owner(a)) ELSE NoClear
  /\ cached'   = Dropped(clearedF')
  /\ actQ'     = Owner(a)
  /\ lastKind' = "revoke"
  /\ UNCHANGED << tree, valid, cval >>

\* §4.2.1 non-trigger 1: fails K-of-N. "MUST NOT invalidate the cache. The attestation may sit in
\* the tree at a structurally-valid path without being authoritative."
FailValidation(a) ==
  /\ MayArrive(a)
  /\ tree'     = [tree EXCEPT ![a] = TRUE]
  /\ clearedF' = NoClear
  /\ actQ'     = Owner(a)
  /\ lastKind' = "fail"
  /\ UNCHANGED << valid, revoked, cached, cval >>

\* §8 additive half: "Direct tree:put to system/quorum/... paths is permitted but bypasses the
\* quorum handler's validation." §4.2.1 non-trigger 2: MUST NOT invalidate.
RawPut(a) ==
  /\ RawWrites
  /\ MayArrive(a)
  /\ tree'     = [tree EXCEPT ![a] = TRUE]
  /\ clearedF' = IF RawInvalidates THEN ClearOn(Owner(a)) ELSE NoClear
  /\ cached'   = Dropped(clearedF')
  /\ actQ'     = Owner(a)
  /\ lastKind' = "raw"
  /\ UNCHANGED << valid, revoked, cval >>

\* §8 SUBTRACTIVE half — LIFT (b). The same permitted `tree:put`, to null. `valid[a]` is left
\* alone on purpose: the entity WAS validated on arrival, and §4.2.1's sentence is about what the
\* cache reflects, not about rewriting history. Non-trigger 2 governs it — it is a raw tree-write
\* — so it MUST NOT invalidate, which is what makes the cache outlive its own entry.
RawDelete(a) ==
  /\ RawDeletes
  /\ tree[a]
  /\ tree'     = [tree EXCEPT ![a] = FALSE]
  /\ clearedF' = IF RawInvalidates THEN ClearOn(Owner(a)) ELSE NoClear
  /\ cached'   = Dropped(clearedF')
  /\ actQ'     = Owner(a)
  /\ lastKind' = "del"
  /\ UNCHANGED << valid, revoked, cval >>

\* §4.2 / §4.2.1 "Recompute on next call": a cache miss walks the chain fresh and repopulates.
\* The `~cached[q]` guard is the algorithm and not a restriction on it — §4.2 says a cache HIT
\* does not walk ("trusts cached prior validation"), so a walk under a populated cache is not a
\* legal state. That is the one thing the D18 sweep looked at and it was right about it.
Walk(q) ==
  /\ ~cached[q]
  /\ cached'   = [cached EXCEPT ![q] = TRUE]
  /\ cval'     = [x \in Atts |-> IF Owner(x) = q THEN Readable(x) ELSE cval[x]]
  /\ clearedF' = NoClear
  /\ actQ'     = q
  /\ lastKind' = "walk"
  /\ UNCHANGED << tree, valid, revoked >>

\* §4.2's cold-start posture: "On cold start (process restart, fresh peer-state import), the cache
\* is empty."
ColdStart ==
  /\ \E q \in Quorums : cached[q]
  /\ cached'   = [x \in Quorums |-> FALSE]
  /\ clearedF' = NoClear
  /\ actQ'     = NOQ
  /\ lastKind' = "cold"
  /\ UNCHANGED << tree, valid, revoked, cval >>

Init ==
  /\ tree     = [a \in Atts |-> FALSE]
  /\ valid    = [a \in Atts |-> FALSE]
  /\ revoked  = [a \in Atts |-> FALSE]
  /\ cached   = [q \in Quorums |-> FALSE]
  /\ cval     = [a \in Atts |-> FALSE]
  /\ clearedF = [q \in Quorums |-> FALSE]
  /\ actQ     = NOQ
  /\ lastKind = "init"

Next == \/ \E a \in Atts : Accept(a) \/ FailValidation(a) \/ RawPut(a)
                             \/ RawDelete(a) \/ Revoke(a)
        \/ \E q \in Quorums : Walk(q)
        \/ ColdStart
        \/ UNCHANGED vars

\* `\in [_ -> _]` rather than a pointwise conjunction: Apalache reads `x \in S` in an init
\* predicate as an ASSIGNMENT, and IndInit must assign every variable.
TypeOK ==
  /\ tree     \in [Atts -> BOOLEAN]
  /\ valid    \in [Atts -> BOOLEAN]
  /\ revoked  \in [Atts -> BOOLEAN]
  /\ cached   \in [Quorums -> BOOLEAN]
  /\ cval     \in [Atts -> BOOLEAN]
  /\ clearedF \in [Quorums -> BOOLEAN]
  /\ actQ     \in {NOQ, 1, 2}
  /\ lastKind \in {"init", "accept", "revoke", "fail", "raw", "del", "walk", "cold"}

\* ---------------------------------------------------------------------------------------
\* THE PROPERTIES
\* ---------------------------------------------------------------------------------------

\* §4.2.1's own sentence, verbatim: "The cache reflects validated quorum state, not raw tree
\* state." GREEN under the read-side closure with a monotone tree; VIOLATED without the closure
\* (that is Q5) and ALSO violated with the closure once the tree can shrink (that is the finding
\* this module adds — see the header, lift (b)).
CacheMatchesValidated ==
  \A q \in Quorums :
    cached[q] => (\A a \in Atts : Owner(a) = q => (cval[a] = ValidNow(a)))

\* §4.2.1's THREE triggers, stated as the complete set of things that may clear a cache entry.
\* This is the live form of `QuorumTrust.tla`'s `NoInvalidationWithoutAcceptance`; see
\* `OnlyAcceptInvalidates` below for the form it had and why it was green.
NoInvalidationWithoutTrigger ==
  (\E q \in Quorums : clearedF[q]) => lastKind \in {"accept", "revoke"}

\* §4.2.1 non-trigger 3, TV-QF15: "Activity on `quorum_id_other` MUST NOT invalidate the cache for
\* `quorum_id`. Cache entries are independently scoped per `quorum_id`."
InvalidationScopedPerQuorum ==
  \A q \in Quorums : clearedF[q] => q = actQ

\* §4.2.1 triggers 1 and 2, TV-QF12 / TV-QF13: a validate-accept leaves no stale entry behind for
\* the quorum it was an event of.
AcceptLeavesNoStaleEntry ==
  (lastKind = "accept" /\ actQ # NOQ) => ~cached[actQ]

\* §4.2.1 TRIGGER 3's own obligation, which had no row on this subject until this module: the
\* revocation arrival leaves no stale entry either. Same shape as the row above, and the reason
\* it is separate is that its trigger is separate.
RevokeLeavesNoStaleEntry ==
  (lastKind = "revoke" /\ actQ # NOQ) => ~cached[actQ]

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Each asserted in order to be VIOLATED; the violation is the pass.
\* ---------------------------------------------------------------------------------------

\* A populated cache is REACHED. Without it every property above is a statement about a system
\* whose cache is permanently empty, and `CacheMatchesValidated` in particular is vacuous.
WitnessCachePopulated == ~(\E q \in Quorums : cached[q])

\* An entity is bound in the tree WITHOUT having been validated — the precondition Q5 turns on,
\* and the thing §4.2's cold-start sentence asserts cannot happen.
WitnessUnvalidatedInTree == ~(\E a \in Atts : tree[a] /\ ~valid[a])

\* The cold-start state the spec describes, with an unvalidated entity already in the tree: every
\* cache empty, so the next read walks — and trusts.
WitnessColdStartExposed ==
  ~(/\ \A q \in Quorums : ~cached[q]
    /\ \E a \in Atts : tree[a] /\ ~valid[a])

\* TRIGGER 3 IS REACHED AT ALL. Without it every claim this module makes about the third trigger
\* is a claim about an action that never fires, which is precisely the state `QuorumTrust.tla` was
\* in without anyone noticing.
WitnessRevocationFires ==
  ~(\E a \in Atts : revoked[a])

\* ...and it actually CLEARS something. `RevokeLeavesNoStaleEntry` is satisfied by a revocation
\* that never had a populated cache to clear.
WitnessRevokeCleared ==
  ~(lastKind = "revoke" /\ \E q \in Quorums : clearedF[q])

\* THE ROW THAT MAKES A CORRECTION VISIBLE RATHER THAN SILENT, and it is not a control.
\* This is `tla/QuorumTrust.tla`'s `NoInvalidationWithoutAcceptance` transcribed unchanged, whose
\* comment there reads "Only a validate-accept may clear a cache entry; a failed validation and a
\* raw `tree:put` must leave it exactly as it was." **§4.2.1 has a third trigger, so that sentence
\* is false of the contract** — and it was GREEN for two days because the model it was written in
\* had no action that could falsify it. Its violation here, under constants where nothing is
\* weakened, IS the correction. Read it beside `NoInvalidationWithoutTrigger`, which is the claim
\* that survives.
OnlyAcceptInvalidates ==
  (\E q \in Quorums : clearedF[q]) => lastKind = "accept"

\* ---------------------------------------------------------------------------------------
\* THE STRENGTHENINGS. `make apalache-closure` additionally requires each to preserve ITSELF —
\* without that, the base and step rows prove preservation FROM strengthened states and nothing
\* shows a run stays in them (D13, eighth instance).
\* ---------------------------------------------------------------------------------------

\* For `CacheMatchesValidated`. Where the read-side closure holds and the tree is monotone, a
\* validated entry is a bound entry, so `Readable` and `ValidNow` coincide and a walk writes
\* exactly the validated set. Guarded by the two constants that make it true; under either
\* negation it is exactly the finding (Q5 under the first, lift (b) under the second).
ReadableIsValidNow ==
  (WalkClosedOverValidated /\ ~RawDeletes)
    => (\A a \in Atts : Readable(a) = ValidNow(a))

\* Also for `CacheMatchesValidated`, and it is the conjunct `tla/QuorumTrust.tla` carries inside
\* its own `TypeOK` (`\A a : valid[a] => tree[a]`). It is NOT a type fact — it is an invariant of
\* the write paths — and it is GUARDED here because `RawDelete` legitimately falsifies it: §8's
\* unbind leaves an entity that WAS validated and is no longer bound, which is the whole of lift
\* (b). Dropping it was the first draft's bug: Apalache's inductive step starts from an arbitrary
\* TYPED state, and `valid[a] /\ ~tree[a]` is type-correct, unreachable, and enough to break the
\* cache invariant via `FailValidation` binding the entity a step later. Found by reading the
\* counterexample, which is the only way it was ever going to be found.
ValidImpliesBound ==
  ~RawDeletes => (\A a \in Atts : valid[a] => tree[a])

IndInitCache == TypeOK /\ ValidImpliesBound /\ ReadableIsValidNow /\ CacheMatchesValidated

\* For the three one-step rules. They are properties of the action that just fired, so `TypeOK`
\* is all they need — stated separately so the cache strengthening cannot quietly carry them.
IndInitRules == TypeOK /\ NoInvalidationWithoutTrigger /\ InvalidationScopedPerQuorum
                /\ AcceptLeavesNoStaleEntry /\ RevokeLeavesNoStaleEntry

\* ---------------------------------------------------------------------------------------
\* CONSTANT INITS. Each says which document is on trial. `tla/Makefile`'s TLC_FINDING header is
\* the canonical statement of the three shapes: a control WEAKENS the model; a finding weakens
\* NOTHING, or flips a constant TOWARD the spec, or toward one implementation on a silence.
\* ---------------------------------------------------------------------------------------

\* GREEN SWEEP. §4.2.1 exactly as written — all three triggers on, all three non-triggers off —
\* with §8's additive half permitted, the read-side closure §4.2's cold-start sentence asserts,
\* and both lifts that cost nothing (revocations, re-arrival). This is the cinit that says the
\* contract is exactly sufficient, and unlike the claim it replaces it is over ALL THREE triggers.
ConstInitOK ==
  /\ RawWrites = TRUE  /\ RawDeletes = FALSE
  /\ AcceptInvalidates = TRUE  /\ RevokeInvalidates = TRUE  /\ RawInvalidates = FALSE
  /\ ScopedInvalidation = TRUE /\ WalkClosedOverValidated = TRUE
  /\ RevocationsEnabled = TRUE /\ ReArrivalEnabled = TRUE

\* `tla/QuorumTrust.tla`'s DOMAIN, reproduced exactly: no revocation, no unbind, one arrival per
\* attestation. This is where the second engine CORROBORATES rather than extends — the same
\* claims, decided by SMT over runs of any length rather than bounded-exhaustively. Every row
\* under this cinit is a row that model already carries.
ConstInitTLCDomain ==
  /\ RawWrites = TRUE  /\ RawDeletes = FALSE
  /\ AcceptInvalidates = TRUE  /\ RevokeInvalidates = TRUE  /\ RawInvalidates = FALSE
  /\ ScopedInvalidation = TRUE /\ WalkClosedOverValidated = TRUE
  /\ RevocationsEnabled = FALSE /\ ReArrivalEnabled = FALSE

\* FINDING Q5 (ported) — §4.2 AS WRITTEN. The walk is the §ATTEST:5.4 index lookup and
\* §ATTEST:5.7 I4 says the indexes filter by nothing, so the cache is populated from raw tree
\* state. Nothing is weakened: this constant reads TOWARD the specification.
ConstInitFindingClosure ==
  /\ RawWrites = TRUE  /\ RawDeletes = FALSE
  /\ AcceptInvalidates = TRUE  /\ RevokeInvalidates = TRUE  /\ RawInvalidates = FALSE
  /\ ScopedInvalidation = TRUE /\ WalkClosedOverValidated = FALSE
  /\ RevocationsEnabled = TRUE /\ ReArrivalEnabled = TRUE

\* FINDING Q5, WITH §8 SWITCHED OFF (ported). The defect survives without any raw write, so it is
\* not "§8 permits a foot-gun" — it is the handler path's own failed-validation branch.
ConstInitFindingFailPath ==
  /\ RawWrites = FALSE /\ RawDeletes = FALSE
  /\ AcceptInvalidates = TRUE  /\ RevokeInvalidates = TRUE  /\ RawInvalidates = FALSE
  /\ ScopedInvalidation = TRUE /\ WalkClosedOverValidated = FALSE
  /\ RevocationsEnabled = TRUE /\ ReArrivalEnabled = TRUE

\* THE NEW FINDING — Q5's mechanism in the direction the first model could not represent. The
\* read-side closure is IN FORCE here; the only change from `ConstInitOK` is that §8's permitted
\* `tree:put` may write null. Nothing is weakened: §8 permits it in the same sentence that permits
\* the additive half `ConstInitOK` already allows.
ConstInitFindingDelete ==
  /\ RawWrites = TRUE  /\ RawDeletes = TRUE
  /\ AcceptInvalidates = TRUE  /\ RevokeInvalidates = TRUE  /\ RawInvalidates = FALSE
  /\ ScopedInvalidation = TRUE /\ WalkClosedOverValidated = TRUE
  /\ RevocationsEnabled = TRUE /\ ReArrivalEnabled = TRUE

\* NEG CONTROL — §4.2.1 triggers 1 and 2 removed: a validate-accept leaves the cache alone.
ConstInitBugNoInvalidate ==
  /\ RawWrites = TRUE  /\ RawDeletes = FALSE
  /\ AcceptInvalidates = FALSE /\ RevokeInvalidates = TRUE  /\ RawInvalidates = FALSE
  /\ ScopedInvalidation = TRUE /\ WalkClosedOverValidated = TRUE
  /\ RevocationsEnabled = TRUE /\ ReArrivalEnabled = TRUE

\* NEG CONTROL — §4.2.1 TRIGGER 3 removed. New with this module, and the point of it: until now
\* the third trigger had no teeth-test anywhere, because it had no action.
ConstInitBugRevokeNoInvalidate ==
  /\ RawWrites = TRUE  /\ RawDeletes = FALSE
  /\ AcceptInvalidates = TRUE  /\ RevokeInvalidates = FALSE /\ RawInvalidates = FALSE
  /\ ScopedInvalidation = TRUE /\ WalkClosedOverValidated = TRUE
  /\ RevocationsEnabled = TRUE /\ ReArrivalEnabled = TRUE

\* NEG CONTROL — §4.2.1 non-trigger 2 inverted: a raw `tree:put` invalidates.
ConstInitBugRawInvalidate ==
  /\ RawWrites = TRUE  /\ RawDeletes = FALSE
  /\ AcceptInvalidates = TRUE  /\ RevokeInvalidates = TRUE  /\ RawInvalidates = TRUE
  /\ ScopedInvalidation = TRUE /\ WalkClosedOverValidated = TRUE
  /\ RevocationsEnabled = TRUE /\ ReArrivalEnabled = TRUE

\* NEG CONTROL — §4.2.1 non-trigger 3 inverted: one quorum's event clears every cache.
ConstInitBugCrossQuorum ==
  /\ RawWrites = TRUE  /\ RawDeletes = FALSE
  /\ AcceptInvalidates = TRUE  /\ RevokeInvalidates = TRUE  /\ RawInvalidates = FALSE
  /\ ScopedInvalidation = FALSE /\ WalkClosedOverValidated = TRUE
  /\ RevocationsEnabled = TRUE /\ ReArrivalEnabled = TRUE
====
