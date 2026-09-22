---- MODULE AttestIndexApalache ----
\* ATTESTATION TRACK — Apalache (SMT) cross-check of tla/AttestIndex.tla (§5.7, the four
\* mandatory indexes and invariants I1–I5).
\*
\* TRACK: `attestation` (TRACKS.toml). A bare §N.M means a section of EXTENSION-ATTESTATION.md
\* at this track's pin.
\*
\* WHY THIS EXISTS. Every model on the three extension tracks was checked by TLC and by nothing
\* else — nine modules, one engine. The core track's own gate table records the precedent and
\* the verdict: three core modules "previously had TLC coverage ONLY … Single-tool coverage was
\* a hole the audit found, not a scope decision" (tla/Makefile, APALACHE_GREEN header). The same
\* sentence is true of this track, so the same remedy applies. ConnCodesApalache.tla's header
\* states the general rule: **the fix for a genuinely single-tool row is to add engines, not to
\* leave the claim standing.**
\*
\* WHAT THIS BUYS OVER TLC. TLC checks AttestIndex bounded-exhaustively over three attestations
\* and terminating handlers. This proves the §5.7 contract INDUCTIVE: it holds in every typed
\* state satisfying the strengthening, for runs of ANY length, including states TLC's fixed
\* `pc` schedule cannot construct — an `idx` that already holds arbitrary eligible entries for
\* an entity whose handler has not yet reached its commit. Unbounded in STEPS, not in ENTITIES:
\* the three-attestation set is fixed here exactly as in the TLC model, and for the same reason
\* — `a3` (no kind key, no supersedes) is what makes the CONDITIONAL half of I1/I5 checkable at
\* all (docs/PROPERTIES.md, "Unbounded in STEPS, not in PEERS").
\*
\* THE STRENGTHENING is `PhaseIndexSound`: the index content of an attestation is a function of
\* its handler phase — nothing before the write, a subset of the publish set during it, exactly
\* the eligible set once bound, nothing after a rolled-back failure — plus the two structural
\* facts that tie `tree` and `revoked` to that phase. `IndexExactOnBound` is NOT inductive on
\* its own: from an arbitrary state it says nothing about an entity still in `writing`, and the
\* commit step's post-state is then unconstrained. Stated here because a strengthening that is
\* never named is a strengthening nobody can check.
\*
\* THIS MODULE IS A RE-ENCODING, NOT A TRANSLATION. AttestIndex.tla is PlusCal with a `pc` per
\* process; this is the same state machine written directly, with the loop-completion condition
\* that PlusCal expresses as control flow (`while … end while` then `ADecide`) written as an
\* explicit guard, `IndexedIn(e) = PublishSet(e)`. That is the one place a transcription error
\* would hide, and it is called out rather than buried: if the two models disagree, this guard
\* is the first thing to read.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the abstraction boundary is AttestIndex.tla's,
\* unchanged — signatures, content hashing, path binding, the properties map beyond whether a
\* kind key exists, and the chain walks are all outside the model. Revocation is a per-entity
\* flag, because I4's claim is about RETENTION under revocation, not about how revocation is
\* expressed.
EXTENDS Naturals, FiniteSets

CONSTANTS
  \* @type: Bool;
  AtomicIndex,     \* TRUE = §5.7 I2: a failed handler leaves NO index entry (rollback).
  \* @type: Bool;
  KindGate,        \* TRUE = §5.7 I5: only an attestation WITH a kind key reaches the kind index.
  \* @type: Bool;
  RetainOnRevoke   \* TRUE = §5.7 I4: revocation does not touch the indexes.

VARIABLES
  \* @type: Set(Str);
  tree,
  \* @type: Str -> Set(Str);
  idx,
  \* @type: Str -> Str;
  aphase,
  \* @type: Set(Str);
  revoked

vars == << tree, idx, aphase, revoked >>

\* §5.7: the four mandatory indexes.
INDEXES  == {"attesting", "attested", "kind", "supersedes"}
Entities == {"a1", "a2", "a3"}
Phases   == {"init", "writing", "bound", "revoked", "failed"}

\* §3.2 `kind` is a recommended key, not a field; §3.1 `supersedes` is declared optional.
HasKind(e) == e \in {"a1", "a2"}
HasSup(e)  == e = "a1"

\* §5.7 I1/I5: the index set an attestation QUALIFIES for.
Eligible(e) == {"attesting", "attested"}
               \cup (IF HasKind(e) THEN {"kind"}       ELSE {})
               \cup (IF HasSup(e)  THEN {"supersedes"} ELSE {})

COMMIT_IX    == "attesting"
PreCommit(e) == Eligible(e) \ {COMMIT_IX}

\* What the writing phase publishes before the commit. Under KindGate = FALSE the set widens to
\* include `kind` for a kind-less attestation — the I5 negative control, visible here exactly as
\* it is in AttestIndex.tla's AWriteSeq.
PublishSet(e) == IF KindGate THEN PreCommit(e) ELSE PreCommit(e) \cup {"kind"}

IndexedIn(e) == {ix \in INDEXES : e \in idx[ix]}
Settled(e)   == aphase[e] \in {"init", "bound", "revoked", "failed"}
Bound(e)     == aphase[e] \in {"bound", "revoked"}

\* ----- the §5.7 invariants, transcribed from AttestIndex.tla -----

\* I1 + I3: a successfully written attestation is in EXACTLY its eligible indexes.
IndexExactOnBound     == \A e \in Entities : Bound(e) => IndexedIn(e) = Eligible(e)

\* I2: a handler that fails leaves the entity in NO index.
NoResidueOnFailure    == \A e \in Entities : aphase[e] = "failed" => IndexedIn(e) = {}

\* I2, settled form: no attestation comes to rest half-indexed.
IndexAllOrNothing     == \A e \in Entities : Settled(e) => IndexedIn(e) \in {{}, Eligible(e)}

\* I5: an attestation with no `kind` key is never in the kind index — in flight as well as at rest.
KindIndexEligibleOnly == \A e \in Entities : e \in idx["kind"] => HasKind(e)

\* I4: revocation does NOT de-index; the entity stays in the tree and in every eligible index.
IndexRetainedOnRevoke == \A e \in Entities :
                           e \in revoked => (IndexedIn(e) = Eligible(e) /\ e \in tree)

\* `\in SUBSET` / `\in [_ -> _]` rather than `\subseteq`: Apalache reads `x \in S` in an init
\* predicate as an ASSIGNMENT, and IndInit must assign every variable. The subset form is the
\* same proposition but gives the assignment finder nothing to bind, which surfaces as a 255
\* config error rather than a counterexample — the confusion `apalache-neg`'s EXITCODE check
\* exists to keep out of the grading. (Convention inherited from ConnCodesApalache.tla.)
TypeOK ==
  /\ tree    \in SUBSET Entities
  /\ revoked \in SUBSET Entities
  /\ aphase  \in [Entities -> Phases]
  /\ idx     \in [INDEXES -> SUBSET Entities]

Inv == /\ TypeOK
       /\ IndexExactOnBound
       /\ NoResidueOnFailure
       /\ IndexAllOrNothing
       /\ KindIndexEligibleOnly
       /\ IndexRetainedOnRevoke

\* ----- the strengthening -----
\* The index content of an attestation is determined by its handler phase. Each conjunct is the
\* fact the corresponding transition needs about its PRE-state in order to leave the §5.7
\* contract standing in its POST-state.
PhaseIndexSound ==
  /\ \A e \in Entities : aphase[e] = "init"    => IndexedIn(e) = {}
  /\ \A e \in Entities : aphase[e] = "writing" => IndexedIn(e) \subseteq PublishSet(e)
  /\ \A e \in Entities : aphase[e] = "failed"  => (AtomicIndex => IndexedIn(e) = {})
  /\ \A e \in Entities : Bound(e) => (IndexedIn(e) = Eligible(e) /\ e \in tree)
  /\ \A e \in Entities : (e \in revoked) <=> (aphase[e] = "revoked")
  /\ \A e \in Entities : (e \in tree) => Bound(e)

\* ----- transitions (re-encoding of AttestIndex.tla's four labels) -----

Init ==
  /\ tree    = {}
  /\ idx     = [ix \in INDEXES |-> {}]
  /\ aphase  = [e \in Entities |-> "init"]
  /\ revoked = {}

\* AStart: the handler begins its write. Nothing observable yet.
AStart(e) ==
  /\ aphase[e] = "init"
  /\ aphase'   = [aphase EXCEPT ![e] = "writing"]
  /\ UNCHANGED << tree, idx, revoked >>

\* AWriteSeq: the pre-commit entries, ONE PER TRANSITION and in ANY ORDER. The existential over
\* `ix` is what makes this a real interleaving rather than a fixed order — another entity's
\* handler can run between any two of them.
APublish(e) ==
  /\ aphase[e] = "writing"
  /\ \E ix \in PublishSet(e) \ IndexedIn(e) :
       idx' = [idx EXCEPT ![ix] = idx[ix] \cup {e}]
  /\ UNCHANGED << tree, aphase, revoked >>

\* ADecide, commit arm: §5.7 I2's atomic commit — the tree write and the FINAL index entry in
\* ONE step. The guard is the loop-completion condition PlusCal expresses as control flow.
ACommit(e) ==
  /\ aphase[e] = "writing"
  /\ IndexedIn(e) = PublishSet(e)
  /\ tree'   = tree \cup {e}
  /\ idx'    = [idx EXCEPT ![COMMIT_IX] = idx[COMMIT_IX] \cup {e}]
  /\ aphase' = [aphase EXCEPT ![e] = "bound"]
  /\ UNCHANGED revoked

\* ADecide, failure arm. Under AtomicIndex every published entry disappears with the failure;
\* under the negative control they survive it, which is the permanent partial-index state §5.7
\* I2 exists to forbid.
AFail(e) ==
  /\ aphase[e] = "writing"
  /\ IndexedIn(e) = PublishSet(e)
  /\ idx'    = IF AtomicIndex THEN [ix \in INDEXES |-> idx[ix] \ {e}] ELSE idx
  /\ aphase' = [aphase EXCEPT ![e] = "failed"]
  /\ UNCHANGED << tree, revoked >>

\* ARevoke: §5.7 I4 — a revoked attestation stays in the tree AND in the indexes.
ARevoke(e) ==
  /\ aphase[e] = "bound"
  /\ revoked' = revoked \cup {e}
  /\ aphase'  = [aphase EXCEPT ![e] = "revoked"]
  /\ idx'     = IF RetainOnRevoke THEN idx ELSE [ix \in INDEXES |-> idx[ix] \ {e}]
  /\ UNCHANGED tree

Next ==
  \/ \E e \in Entities : (AStart(e) \/ APublish(e) \/ ACommit(e) \/ AFail(e) \/ ARevoke(e))
  \/ UNCHANGED vars

\* ----- inductive-step init: arbitrary typed state satisfying the strengthened invariant -----
IndInitIx == TypeOK /\ PhaseIndexSound /\ Inv

\* ----- constant inits -----
\* CORRECT: §5.7 as written — atomic index updates, the kind gate, retention under revocation.
ConstInitOK          == AtomicIndex = TRUE  /\ KindGate = TRUE  /\ RetainOnRevoke = TRUE

\* NEG CONTROL — §5.7 I2: the failure path leaves the entries it had already published, so an
\* attestation comes to rest in a permanent partial-index state.
ConstInitBugAtomic   == AtomicIndex = FALSE /\ KindGate = TRUE  /\ RetainOnRevoke = TRUE

\* NEG CONTROL — §5.7 I5: every attestation is published to the kind index, including kind-less
\* `a3`. This is the control `a3` exists for; without that entity the config is indistinguishable
\* from the correct one.
ConstInitBugKind     == AtomicIndex = TRUE  /\ KindGate = FALSE /\ RetainOnRevoke = TRUE

\* NEG CONTROL — §5.7 I4: revocation de-indexes, so liveness filtering has leaked into the index
\* layer and find_* stops returning a revoked attestation.
ConstInitBugRetain   == AtomicIndex = TRUE  /\ KindGate = TRUE  /\ RetainOnRevoke = FALSE
====
