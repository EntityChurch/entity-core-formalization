---- MODULE AttestIndex ----
\* ATTESTATION TRACK, first model. The four mandatory attestation indexes and the five
\* normative index invariants I1-I5 (§5.7), over the entity shape §3.1 defines and the
\* optional `kind` key §3.2 makes optional.
\*
\* TRACK: `attestation` (TRACKS.toml). A bare §N.M in this file means a section of
\* EXTENSION-ATTESTATION.md at the snapshot named by this track's pin, NOT of the core
\* protocol. Cross-track references carry the target's prefix, e.g. §CORE:6.2 for the core
\* register lifecycle this model's discipline is borrowed from.
\*
\* WHAT §5.7 SAYS, and what is checkable in it:
\*   I1  after a successful write the entity is in `attesting`, `attested`, `properties.kind`
\*       and `supersedes` -- "the latter only when the attestation has a non-null supersedes
\*       field" -- before the next find_* in the same handler invocation returns.
\*   I2  index updates are atomic with the handler's tree write; if the handler fails the
\*       entity "MUST NOT appear in any index"; partial-index states are NOT permitted.
\*   I3  after a successful invocation, all later invocations on the peer see it indexed.
\*   I4  a revoked or superseded attestation STAYS in the tree and in the indexes; find_*
\*       keeps returning it; indexes do NOT filter by liveness.
\*   I5  at most ONE `properties.kind` entry per attestation, and an attestation with no
\*       `kind` key MUST NOT appear in that index at all.
\*
\* THE SUBTLETY THIS MODULE EXISTS FOR: TWO OF THE FOUR INDEXES ARE CONDITIONAL.
\* `supersedes` applies only when the field is non-null (§5.7 I1's own parenthetical) and
\* `kind` only when the key is present (§5.7 I5; §3.2 makes `kind` a RECOMMENDED convention,
\* not a required field). So "the entity is in all four indexes" is FALSE for an ordinary
\* kind-less, non-superseding attestation, and an invariant written that way would be wrong
\* in the direction that still goes green on a model that never builds one. `a3` below exists
\* precisely to be that entity. The correct reading of I2 is per-entity ELIGIBILITY: a settled
\* attestation is in exactly the indexes it qualifies for, or in none at all.
\*
\* Read alongside I5, I2's parenthetical -- "entity in one index but not another" -- is loose:
\* taken literally it forbids the state I5 REQUIRES for a kind-less attestation. The reading
\* modeled here is that I2 is about the atomicity of one write transaction over the eligible
\* set, and I5 about which indexes are eligible. That is a reading, it is stated here rather
\* than assumed, and it is the first thing a reviewer should push on.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): ABSTRACTED AWAY -- signatures and signature
\* verification (§4 is a separate surface; the Dolev-Yao questions belong to the prover track),
\* content hashing, path binding, the properties map's contents beyond whether a kind key
\* exists, and the chain walks of §5. Revocation is modeled as a per-entity flag rather than
\* as the revocation attestation that section 3.3 defines, because I4's claim is about RETENTION
\* under revocation, not about how revocation is expressed; the flag is the weakest thing that
\* can carry that claim. Those two sentences carry no § sigil deliberately -- a scope
\* disclaimer that cites a section was being counted as coverage of it
\* (../docs/COVERAGE-MATRIX.md section 3b).
EXTENDS Naturals, FiniteSets

CONSTANTS AtomicIndex,   \* TRUE  = §5.7 I2: a failed handler leaves NO index entry -- the
                         \*         in-flight publishes are rolled back with the failure.
                         \* FALSE = negative control: the failure path leaves the entries it
                         \*         had already published -> a permanent partial-index state.
          KindGate,      \* TRUE  = §5.7 I5: only an attestation WITH a kind key is published
                         \*         to the kind index.
                         \* FALSE = negative control: every attestation is published to the
                         \*         kind index, including kind-less `a3`.
          RetainOnRevoke,\* TRUE  = §5.7 I4: revocation does not touch the indexes.
                         \* FALSE = negative control: revocation de-indexes the entity, so
                         \*         find_* stops returning it and liveness filtering has
                         \*         leaked into the index layer.
          SequencedIndex \* TRUE  = the eligible index entries are published ONE PER
                         \*         TRANSITION, with the tree bind and the final entry as a
                         \*         single atomic commit point.
                         \* FALSE = the collapsed shape: tree bind and every index entry in
                         \*         one assignment. See RETIRING A VACUITY BEFORE IT SHIPS.

\* §5.7: the four mandatory indexes.
INDEXES == {"attesting", "attested", "kind", "supersedes"}

\* Three attestations, chosen to span the eligibility cases rather than to be many:
\*   a1  has a kind key AND a non-null supersedes -> eligible for all four indexes
\*   a2  has a kind key, no supersedes            -> eligible for three
\*   a3  NEITHER                                   -> eligible for two
\* a3 is the load-bearing one. Without it every entity is eligible for the same index set,
\* the conditional half of I1/I5 is never exercised, and a wrong "all four indexes" invariant
\* passes -- the model would confirm a reading the spec does not have.
Entities  == {"a1", "a2", "a3"}
HasKind(e) == e \in {"a1", "a2"}          \* §3.2: `kind` is a recommended key, not a field
HasSup(e)  == e = "a1"                    \* §3.1: `supersedes` is declared optional

\* §5.7 I1/I5: the index set an attestation QUALIFIES for. `attesting` and `attested` are
\* unconditional (§3.1 makes both fields required); the other two follow the optional fields.
Eligible(e) == {"attesting", "attested"}
               \cup (IF HasKind(e) THEN {"kind"}       ELSE {})
               \cup (IF HasSup(e)  THEN {"supersedes"} ELSE {})

\* The entry whose publication IS the commit. `attesting` is eligible for every attestation,
\* so the commit step exists on every path.
COMMIT_IX      == "attesting"
PreCommit(e)   == Eligible(e) \ {COMMIT_IX}

\* RETIRING A VACUITY BEFORE IT SHIPS (docs/PROPERTIES.md §C.4; the §CORE:6.2 Register lesson).
\*
\* Register.tla wrote its five facets in ONE assignment for two releases, which made its
\* all-or-nothing invariant a restatement of that assignment: `tree[h] \in {{}, FACETS}` cannot
\* fail where `tree[h]` is only ever assigned `{}` or `FACETS`. Every tooth was on the control
\* side. The identical trap is available here and is easier to fall into, because "four index
\* writes" reads like one operation: publish all of Eligible(e) in a single step and
\* IndexAllOrNothing restates the step.
\*
\* Under SequencedIndex the PreCommit entries land INDIVIDUALLY and in ANY ORDER, each its own
\* transition another handler can interleave with, so `idx` genuinely passes through partial
\* states. What makes I1/I2 true is then a DISCIPLINE -- the tree bind and the final entry are
\* one atomic commit, and the failure path rolls back what it published -- rather than an
\* assignment. WitnessIndexPartial then proves those partial states are actually REACHED,
\* because a sequenced model whose sequence is never exercised is the same vacuity in new
\* source code.

(*--algorithm attestindex
variables
  tree    = {},                            \* attestations bound in the tree (authoritative)
  idx     = [ix \in INDEXES |-> {}],       \* §5.7 the four indexes: derived state
  aphase  = [e \in Entities |-> "init"],   \* init -> writing -> bound -> revoked | failed
  revoked = {};                            \* §5.7 I4 subject; revocation itself is abstracted

define
  \* Which indexes currently hold e.
  IndexedIn(e) == {ix \in INDEXES : e \in idx[ix]}

  \* An attestation is SETTLED when its handler invocation has finished, either way. I2 is a
  \* claim about handler boundaries -- "if the handler fails" / "atomic with the handler's
  \* tree write" -- not about what is momentarily in flight. Under SequencedIndex `idx` passes
  \* through partial states by construction; what §5.7 forbids is COMING TO REST in one.
  Settled(e) == aphase[e] \in {"init", "bound", "revoked", "failed"}
  Bound(e)   == aphase[e] \in {"bound", "revoked"}

  \* §5.7 I1 + I3: a successfully written attestation is in EXACTLY its eligible indexes --
  \* every one of them (I1's write-then-read) and no others (I5's exclusion, generalized to
  \* both conditional indexes). This is the invariant that is wrong if written as "all four".
  IndexExactOnBound == \A e \in Entities : Bound(e) => IndexedIn(e) = Eligible(e)

  \* §5.7 I2: a handler that fails leaves the entity in NO index. The rollback is what makes
  \* the index update atomic with the tree write from an observer's side.
  NoResidueOnFailure == \A e \in Entities :
                          aphase[e] = "failed" => IndexedIn(e) = {}

  \* §5.7 I2, the settled form: no attestation comes to rest half-indexed. Follows from the
  \* two above and is stated separately because it is the sentence §5.7 actually writes.
  IndexAllOrNothing == \A e \in Entities :
                         Settled(e) => IndexedIn(e) \in {{}, Eligible(e)}

  \* §5.7 I5: an attestation with no `kind` key is never in the kind index. Stated on its own
  \* -- not folded into IndexExactOnBound -- because it must hold IN FLIGHT too: there is no
  \* moment at which a kind-less attestation is legitimately kind-indexed, whereas being
  \* short some eligible entries mid-handler is exactly what sequencing means.
  KindIndexEligibleOnly == \A e \in Entities : e \in idx["kind"] => HasKind(e)

  \* §5.7 I5 again, the other half: at most ONE kind entry per attestation. Set membership
  \* makes multiplicity unrepresentable here, so this is a MODELING BOUNDARY rather than a
  \* proved property, and is recorded as such rather than asserted as a checked invariant.
  \* (An index that could hold an entity twice would need a bag; §5.7's own test vector TV-I5
  \* is about which entities appear, not how often.)

  \* §5.7 I4: revocation does NOT de-index. The entity stays in the tree and in every index it
  \* qualified for; consumers filter liveness themselves. The hazard this forbids is an
  \* implementation that treats the index as a liveness cache.
  IndexRetainedOnRevoke == \A e \in Entities :
                             e \in revoked => IndexedIn(e) = Eligible(e) /\ e \in tree

  \* NON-VACUITY WITNESS for the sequencing itself. Asserted in order to be VIOLATED: the
  \* violation exhibits an `idx` in which some attestation holds a PROPER, NON-EMPTY subset of
  \* its eligible entries -- the state the collapsed-write shape cannot reach at all. Without
  \* it, "the index publishes are sequenced" is a claim about this file's source rather than
  \* about the state space.
  WitnessIndexPartial == \A e \in Entities : IndexedIn(e) \in {{}, Eligible(e)}
end define;

\* One process per attestation: a handler invocation that writes it, then may revoke it.
\* They run concurrently, so one handler's partial index state is observable while another
\* handler is mid-write -- which is the interleaving I2 and I3 are about.
fair process att \in Entities
begin
  AStart:
    \* The handler begins its write. Nothing is in the tree and nothing is observable yet;
    \* under the collapsed shape this step IS the whole write.
    if SequencedIndex then
      aphase[self] := "writing";
    else
      \* Collapsed: tree bind and every eligible entry in one transition. Kept as a mode
      \* rather than deleted so the vacuity it produces stays demonstrable -- run the
      \* WitnessIndexPartial config against it and the witness does not fire.
      tree := tree \cup {self} ||
      idx := [ix \in INDEXES |-> IF ix \in Eligible(self) THEN idx[ix] \cup {self} ELSE idx[ix]] ||
      aphase[self] := "bound";
    end if;
  AWriteSeq:
    \* §5.7: the PreCommit entries, ONE PER TRANSITION and in ANY ORDER. The nondeterministic
    \* `with` is what makes this a real interleaving rather than a fixed order. Under KindGate
    \* = FALSE the publish set widens to include `kind` for kind-less attestations, which is
    \* the I5 control and is visible here rather than at the commit.
    while aphase[self] = "writing"
          /\ (IF KindGate THEN PreCommit(self) ELSE PreCommit(self) \cup {"kind"})
             \ IndexedIn(self) # {} do
      with ix \in (IF KindGate THEN PreCommit(self) ELSE PreCommit(self) \cup {"kind"})
                  \ IndexedIn(self) do
        idx[ix] := idx[ix] \cup {self};
      end with;
    end while;
  ADecide:
    \* Either the handler completes -- §5.7 I2's atomic commit: the tree write and the final
    \* index entry in ONE step -- or it fails, in which case I2 requires every entry it has
    \* already published to disappear with it.
    if aphase[self] = "writing" then
      either
        tree := tree \cup {self} ||
        idx[COMMIT_IX] := idx[COMMIT_IX] \cup {self} ||
        aphase[self] := "bound";
      or
        if AtomicIndex then
          \* §5.7 I2: "if the handler fails the entity MUST NOT appear in any index."
          idx := [ix \in INDEXES |-> idx[ix] \ {self}] ||
          aphase[self] := "failed";
        else
          \* NEG CONTROL: the handler fails and its published entries survive it. The entity
          \* is in no tree and in some indexes -- a permanent partial-index state, which is
          \* the state §5.7 I2 exists to forbid.
          aphase[self] := "failed";
        end if;
      end either;
    end if;
  ARevoke:
    \* §5.7 I4: a revoked attestation stays in the tree AND in the indexes.
    if aphase[self] = "bound" then
      either
        if RetainOnRevoke then
          revoked := revoked \cup {self} || aphase[self] := "revoked";
        else
          \* NEG CONTROL: revocation de-indexes. find_* stops returning the entity, so a
          \* consumer that relies on is_attestation_live to filter cannot see it at all.
          revoked := revoked \cup {self} ||
          idx := [ix \in INDEXES |-> idx[ix] \ {self}] ||
          aphase[self] := "revoked";
        end if;
      or
        skip;      \* not every attestation is revoked
      end either;
    end if;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "462be876" /\ chksum(tla) = "7b04678c")
VARIABLES pc, tree, idx, aphase, revoked

(* define statement *)
IndexedIn(e) == {ix \in INDEXES : e \in idx[ix]}





Settled(e) == aphase[e] \in {"init", "bound", "revoked", "failed"}
Bound(e)   == aphase[e] \in {"bound", "revoked"}




IndexExactOnBound == \A e \in Entities : Bound(e) => IndexedIn(e) = Eligible(e)



NoResidueOnFailure == \A e \in Entities :
                        aphase[e] = "failed" => IndexedIn(e) = {}



IndexAllOrNothing == \A e \in Entities :
                       Settled(e) => IndexedIn(e) \in {{}, Eligible(e)}





KindIndexEligibleOnly == \A e \in Entities : e \in idx["kind"] => HasKind(e)










IndexRetainedOnRevoke == \A e \in Entities :
                           e \in revoked => IndexedIn(e) = Eligible(e) /\ e \in tree






WitnessIndexPartial == \A e \in Entities : IndexedIn(e) \in {{}, Eligible(e)}


vars == << pc, tree, idx, aphase, revoked >>

ProcSet == (Entities)

Init == (* Global variables *)
        /\ tree = {}
        /\ idx = [ix \in INDEXES |-> {}]
        /\ aphase = [e \in Entities |-> "init"]
        /\ revoked = {}
        /\ pc = [self \in ProcSet |-> "AStart"]

AStart(self) == /\ pc[self] = "AStart"
                /\ IF SequencedIndex
                      THEN /\ aphase' = [aphase EXCEPT ![self] = "writing"]
                           /\ UNCHANGED << tree, idx >>
                      ELSE /\ /\ aphase' = [aphase EXCEPT ![self] = "bound"]
                              /\ idx' = [ix \in INDEXES |-> IF ix \in Eligible(self) THEN idx[ix] \cup {self} ELSE idx[ix]]
                              /\ tree' = (tree \cup {self})
                /\ pc' = [pc EXCEPT ![self] = "AWriteSeq"]
                /\ UNCHANGED revoked

AWriteSeq(self) == /\ pc[self] = "AWriteSeq"
                   /\ IF aphase[self] = "writing"
                         /\ (IF KindGate THEN PreCommit(self) ELSE PreCommit(self) \cup {"kind"})
                            \ IndexedIn(self) # {}
                         THEN /\ \E ix \in (IF KindGate THEN PreCommit(self) ELSE PreCommit(self) \cup {"kind"})
                                           \ IndexedIn(self):
                                   idx' = [idx EXCEPT ![ix] = idx[ix] \cup {self}]
                              /\ pc' = [pc EXCEPT ![self] = "AWriteSeq"]
                         ELSE /\ pc' = [pc EXCEPT ![self] = "ADecide"]
                              /\ idx' = idx
                   /\ UNCHANGED << tree, aphase, revoked >>

ADecide(self) == /\ pc[self] = "ADecide"
                 /\ IF aphase[self] = "writing"
                       THEN /\ \/ /\ /\ aphase' = [aphase EXCEPT ![self] = "bound"]
                                     /\ idx' = [idx EXCEPT ![COMMIT_IX] = idx[COMMIT_IX] \cup {self}]
                                     /\ tree' = (tree \cup {self})
                               \/ /\ IF AtomicIndex
                                        THEN /\ /\ aphase' = [aphase EXCEPT ![self] = "failed"]
                                                /\ idx' = [ix \in INDEXES |-> idx[ix] \ {self}]
                                        ELSE /\ aphase' = [aphase EXCEPT ![self] = "failed"]
                                             /\ idx' = idx
                                  /\ tree' = tree
                       ELSE /\ TRUE
                            /\ UNCHANGED << tree, idx, aphase >>
                 /\ pc' = [pc EXCEPT ![self] = "ARevoke"]
                 /\ UNCHANGED revoked

ARevoke(self) == /\ pc[self] = "ARevoke"
                 /\ IF aphase[self] = "bound"
                       THEN /\ \/ /\ IF RetainOnRevoke
                                        THEN /\ /\ aphase' = [aphase EXCEPT ![self] = "revoked"]
                                                /\ revoked' = (revoked \cup {self})
                                             /\ idx' = idx
                                        ELSE /\ /\ aphase' = [aphase EXCEPT ![self] = "revoked"]
                                                /\ idx' = [ix \in INDEXES |-> idx[ix] \ {self}]
                                                /\ revoked' = (revoked \cup {self})
                               \/ /\ TRUE
                                  /\ UNCHANGED <<idx, aphase, revoked>>
                       ELSE /\ TRUE
                            /\ UNCHANGED << idx, aphase, revoked >>
                 /\ pc' = [pc EXCEPT ![self] = "Done"]
                 /\ tree' = tree

att(self) == AStart(self) \/ AWriteSeq(self) \/ ADecide(self)
                \/ ARevoke(self)

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == (\E self \in Entities: att(self))
           \/ Terminating

Spec == /\ Init /\ [][Next]_vars
        /\ \A self \in Entities : WF_vars(att(self))

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION

\* ===== Liveness (checked as PROPERTY; needs the WF supplied by `fair process`) =====

\* §5.7 I2/I3: every handler invocation SETTLES -- it commits or it fails, and either way it
\* stops holding a partial index state. A handler that hangs mid-write is the one way a
\* partial-index state becomes permanent without any invariant above being violated, because
\* every one of them is scoped to Settled(e). Without this property the safety results would
\* be silent about exactly the state they exclude.
AttestSettles == \A e \in Entities : <>(aphase[e] \in {"bound", "revoked", "failed"})

\* NON-VACUITY WITNESS (PROPERTIES.md §C.4 / AttestIndexWitness.cfg). TLC has no ProVerif-style
\* reachability query, so a witness is an invariant that MUST BE VIOLATED; the violation is the
\* PASS. This one exhibits a reachable state in which an attestation is actually BOUND and
\* fully indexed -- so §5.7's I1-I5 results are not vacuously true of a peer that never
\* successfully writes an attestation. Expected verdict: VIOLATION.
WitnessAttestBound == ~(\E e \in Entities : e \in tree /\ IndexedIn(e) = Eligible(e))

\* NON-VACUITY WITNESS for the CONDITIONAL half of §5.7 I1/I5 (AttestIndexWitness.cfg checks
\* the one above; this is checked in the same run). Asserted to be VIOLATED: the violation
\* exhibits a bound attestation whose eligible index set is a PROPER SUBSET of all four --
\* i.e. kind-less `a3` really does reach a bound state indexed in two indexes and not four.
\* This is what rules out the wrong reading of I1 passing unnoticed: if every bound entity
\* were in all four indexes, "the entity appears in all four" and "the entity appears in
\* exactly its eligible set" would be indistinguishable on this model.
WitnessPartialEligibility ==
  ~(\E e \in Entities : Bound(e) /\ Eligible(e) # INDEXES /\ IndexedIn(e) = Eligible(e))
====
