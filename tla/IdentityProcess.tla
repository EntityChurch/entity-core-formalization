---- MODULE IdentityProcess ----
\* IDENTITY TRACK, first model. §6.3 `process_attestation` -- "the convergence point for any
\* identity-context attestation entering the local tree at the named subtrees, regardless of
\* source". Everything this extension knows about an arriving entity, it learns here.
\*
\* TRACK: `identity` (TRACKS.toml). A bare §N.M means a section of EXTENSION-IDENTITY.md at this
\* track's pin. A cross-track reference writes the sigil first: §ATTEST:3.3 is a section of
\* EXTENSION-ATTESTATION.md and §QUORUM:4.2 one of EXTENSION-QUORUM.md; both are EXCLUDED from
\* every track's coverage set.
\*
\* THE DECISION THIS TRACK HAD TO MAKE BEFORE ITS FIRST LINE, AND HOW IT WAS MADE.
\* The prior checkpoint recorded it as unresolved: identity consumes `current_signer_set`, seven
\* of whose inputs are now known-defective, so a model can either transcribe §QUORUM:4.2 as
\* written (and re-derive Q1-Q7 wearing identity section numbers) or assume the cohort's
\* behaviour (and book that as a Class-O ledger row). The choice is invisible afterwards, which
\* is why it was flagged.
\*
\* IT IS ANSWERED BY THE PATTERN THE QUORUM TRACK ALREADY BUILT, not by picking a side. Where a
\* substrate resolver is called, it is a CONSTANT rather than a transcription -- see
\* `IdentityCertChain`'s `SignerSetIsSound`, which names whether the composed §QUORUM:4.2 result
\* is the one that section's normative sentence asks for. The green sweep sets it TRUE, so the
\* identity results are statements about identity ON THE ASSUMPTION that its substrate works,
\* and no row on this track re-discovers a quorum defect and re-routes it as an identity one.
\* What the assumption costs is a declared ledger row (LEAN-SEAM O16), not a silent scope
\* narrowing. That is `tla/Makefile`'s TLC_FINDING move from the other direction, and it means
\* both of the checkpoint's questions get answered rather than one being chosen.
\*
\* THIS MODULE CALLS NO SUBSTRATE RESOLVER AT ALL, which is why the constant does not appear
\* below: §6.3 phase 1 and §3.6 step 1 are decided entirely by `properties.kind`. The findings
\* here are therefore independent of every quorum finding, and that independence is the reason
\* this module is first.
\*
\* WHAT THIS MODULE IS. NOT a concurrency model -- there is no interleaving here and nothing
\* races. §6.3 phase 1 composed with §3.6 step 1 is a PURE FUNCTION of (arrival kind, arrival
\* source), and the question is whether that function agrees with the rest of the document that
\* describes it. So the module is an exhaustive enumeration over every kind that can arrive at a
\* synced identity path crossed with both arrival sources, in the `AttestLive` shape rather than
\* the `AttestIndex` one. Seven kinds, two sources, one handler-failure bit: 28 states, checked
\* completely.
\*
\* ── WHAT §6.3 SAYS, IN THE ORDER IT SAYS IT ────────────────────────────────────────────────
\*
\*   Phase 1: validate
\*     - identity_verify_cert(attestation, ctx) -- pure; returns ok or error
\*     - On error:
\*         Cross-peer arrival path: phase-2a unbind (per scope rule below)
\*         Local-create path: return error to caller; do NOT unbind
\*
\*   Phase 2: dispatch_side_effects (pluggable, per (kind, function))
\*     - Standard registered handlers (dispatch table):
\*         (identity-cert, agent)         -> maybe_issue_local_cap
\*         (identity-cert, controller)    -> maybe_issue_local_controller_cap
\*         (identity-cert, identifier)    -> maybe_update_identifier_handle
\*         (identity-rotation-handoff, *) -> handle_dual_sig_handoff
\*         (identity-rotation-recovery,*) -> update_handle_cache_to
\*         (identity-retirement, *)       -> revoke_local_caps_for_attested
\*         (quorum-publish, *)            -> seed_contacts_cache
\*     - handler failure MUST NOT propagate or affect other handlers' execution
\*
\*   Phase 3: emit_controller_events (FAILURE-only in v2)
\*
\* and §3.6's `identity_verify_cert` step 1, which is what phase 1 runs:
\*
\*   if att.properties.kind != "identity-cert" and
\*      att.properties.kind not in identity_lifecycle_kinds():
\*     return error("not_identity_attestation")
\*
\* with §3.6 fixing `identity_lifecycle_kinds()` to exactly three values and saying, in its own
\* comment, that revocation is deliberately not among them:
\*
\*   ; Note: "revocation" is NOT in this set -- it's the universal kind
\*   ; (per EXTENSION-ATTESTATION.md §3.3); identity validators dispatch
\*   ; revocation handling separately via authority-revocation rules.
\*
\* ── THE DEFECT, WHICH IS A COMPOSITION AND NOT A TYPO ───────────────────────────────────────
\* Phase 1 is unconditional and step 1's gate admits exactly four kinds. The phase-2 dispatch
\* table has SEVEN rows and one of them names a kind step 1 rejects. So `(quorum-publish, *) ->
\* seed_contacts_cache` is a row of a normative table that phase 1 makes unreachable, and on the
\* cross-peer arrival path the entity is UNBOUND on the way past. `SeedRowReachable`.
\*
\* THE SAME MECHANISM REACHES TWO MORE KINDS, AND NEITHER IS A ROW OF THE TABLE -- which is why
\* they have to be looked for rather than read off:
\*
\*   `revocation`. §4.6 gives identity authority-revocation rules over it; §5.1 stores it under
\*   `internal/cert/` AND `public/cert/`; the section 10.2 sync hook fires `process_attestation`
\*   on `public/cert/` arrivals; section 12.4 has revocations propagating cross-peer by TOFU and
\*   supersedes. Step 1 rejects it, so phase 2a unbinds it. **A revocation cannot arrive over
\*   sync.** And
\*   §3.6's own step 3 reads live revocations out of the tree -- the tree the arrival path just
\*   deleted them from. `RevocationSurvivesArrival`.
\*
\*   `quorum-update`. §5.1 puts it at `system/quorum/{q}/event/{h}`; the section 10.2 sync hook
\*   fires on `system/quorum/*/event/` too; §3.3 says identity does not define the kind. Step 1
\*   rejects
\*   it and phase 2a unbinds it, so the ordinary way a membership change propagates is deleted
\*   on arrival by the extension that consumes it. Composed with the already-routed Q1 -- where
\*   §QUORUM:4.2 falls through to the creation-time roster when the walk finds no head -- the
\*   roster cannot change because the updates never survive to be walked.
\*   `QuorumUpdateSurvivesArrival`.
\*
\* ── THE COHORT, MEASURED BEFORE ANY IMPACT CLAIM ────────────────────────────────────────────
\* (docs/PROPERTIES.md §D.1 is this repo's record of getting an impact argument wrong while its
\* census was right, so the census comes first and separately.)
\*
\* ALL THREE implementations added a kind branch BEFORE phase 1 that §6.3 does not have. That
\* unanimity is the finding. What they do in that branch is not unanimous at all, and the
\* three-way split is a live interop divergence rather than three copies of one workaround:
\*
\*   entity-core-go    `if !isIdentityKind(a.Kind()) { return 200 }` -- a no-op. Not unbound,
\*                     NOT seeded either; the comment defers quorum-publish caching to "quorum's
\*                     sync hook". `isIdentityKind` ALSO includes `types.KindRevocation`, which
\*                     §3.6 explicitly excludes -- so Go is the only implementation on which a
\*                     revocation survives arrival, and it needed a second spec-absent addition
\*                     (a `KindRevocation` arm in `IdentityTopologyFor`) to make that work.
\*   entity-core-rust  `if kind == KIND_QUORUM_PUBLISH { seed_contact_quorum_publish_cache(..);
\*                     return ok }` -- seeds, and seeds WITHOUT validating. Quorum-update is not
\*                     branched, so it falls through to `identity_verify_cert` and is unbound.
\*   entity-core-py    branches quorum-publish AND quorum-update, validates each via
\*                     `process_quorum_attestation`, seeds on success and fail-closed-unbinds on
\*                     failure. Revocation is rejected at `not_identity_attestation`.
\*
\* So: whether an arriving quorum-publish seeds the §9.4 trust anchor differs across all three;
\* whether an arriving quorum-update survives differs; whether an arriving revocation survives
\* differs. Three authors, one gap, three incompatible repairs -- the exception to this repo's
\* usual "three authors deriving the same unwritten rule is the argument for writing it down".
\* Here the argument is stronger: they did not derive the same rule, so the peers do not agree.
\*
\* WHAT THE GREEN SWEEP RUNS, AND WHY IT IS NOT A COHORT CONSENSUS THIS TIME. On the quorum
\* track the green sweep could run "what all three do" because all three did the same thing.
\* Here there is no such setting. The green cfg runs the UNION of the three repairs -- route
\* quorum-publish and quorum-update before phase 1, admit revocation -- which is what §6.3 would
\* have to say for any of the three to be conformant, and which NO implementation currently is.
\* That is a weaker green than this repo usually publishes and the cfg header says so in its
\* first line rather than leaving it to be inferred from the constants.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): ABSTRACTED AWAY -- signature validation and
\* topology dispatch entirely (that is IdentityCertChain), the contacts cache and the §9.4
\* fail-closed rule (that is IdentityRecovery), `properties.function` (no row of the dispatch
\* table is reachable-or-not on account of its function, so the kind alone carries this
\* module's question), the storage path a given arrival lands at -- section 10.2's sync-hook path set
\* and §5.1's layout are read as prose and the model asks only "an arrival that reaches
\* process_attestation", the L0 startup path, envelope.included ingestion, and every phase-3
\* event field but the fact of emission. Those sentences carry no § sigil deliberately -- a
\* scope disclaimer that cites a section was being counted as coverage of it
\* (../docs/COVERAGE-MATRIX.md section 3b).
EXTENDS Naturals, FiniteSets

CONSTANTS PreRouteQPublish, \* TRUE  = a pre-phase-1 branch routes `quorum-publish` past
                            \*         `identity_verify_cert`. All three implementations have
                            \*         one; §6.3 does not.
                            \* FALSE = §6.3 AS WRITTEN: phase 1 is unconditional.
          PreRouteQUpdate,  \* the same question for `quorum-update`. Go (via the negated
                            \* `isIdentityKind`) and Python (explicitly) have it; Rust does not;
                            \* §6.3 does not.
          SeedOnPreRoute,   \* does the pre-phase-1 branch RUN the `(quorum-publish, *) ->
                            \* seed_contacts_cache` dispatch row, or merely decline to unbind?
                            \* Rust and Python seed; Go returns 200 and seeds nothing.
          RevocationAdmitted, \* TRUE  = `revocation` is admitted by step 1 (Go's
                              \*         `isIdentityKind`). FALSE = §3.6 AS WRITTEN, which
                              \*         excludes it in an explicit comment.
          Phase2aScoped,    \* §6.3's phase-2a scope rule (normative, per v2.0 PR-8.3): unbind
                            \* on cross-peer arrival, MUST be skipped for local-handler writes.
                            \* FALSE is a negative control -- the defect the rule was written
                            \* against, a `200` from `:create_attestation` followed by a phantom
                            \* `404` on read.
          EmitOnFailure,    \* §6.3 phase 3: "MUST emit on phase-2 handler failure".
          EmitOnSuccess,    \* §6.3 phase 3, v2 scope: "impls MUST NOT emit success events
                            \* during v2". TRUE is a negative control.
          UnbindOnHandlerFailure \* §6.3 phase 2: "handler failure MUST NOT propagate or affect
                                 \* other handlers' execution", and the entity stays bound --
                                 \* the phase-3 event is the recovery signal, not an unbind.
                                 \* TRUE is a negative control.

\* ---------------------------------------------------------------------------------------
\* The kinds that can reach `process_attestation`. Four are identity's own (§3.3); the other
\* three are kinds identity explicitly DOES NOT define (§3.3 "Kinds identity DOES NOT define")
\* and which nonetheless arrive at paths section 10.2's sync hook watches (§5.1 layout).
\* ---------------------------------------------------------------------------------------
KCert     == 1   \* "identity-cert"                §4.2
KHandoff  == 2   \* "identity-rotation-handoff"    §4.3
KRecovery == 3   \* "identity-rotation-recovery"   §4.4
KRetire   == 4   \* "identity-retirement"          §4.5
KRevoke   == 5   \* "revocation"                   §4.6, owned by §ATTEST:3.3
KQPublish == 6   \* "quorum-publish"               owned by §QUORUM:3.3; §5.1 path
KQUpdate  == 7   \* "quorum-update"                owned by §QUORUM:3.3; §5.1 path
\* A kind owned by neither identity nor quorum -- §ATTEST:3.2's kind-ownership table is open to
\* consumer extensions and §ATTEST:TV-A10 uses `"reputation"` as its worked example. It is here
\* because WITHOUT IT THE GREEN SWEEP IS VACUOUS, which is worth stating rather than hiding: the
\* green cfg runs the union of the three cohort repairs, and under that union kinds 1-5 are all
\* admitted and 6-7 are all pre-routed, so NOTHING is ever rejected, the phase-2a unbind path is
\* dead, and `LocalCreateNeverUnbinds` / `UnbindOnlyOnRejection` are true of a model that never
\* unbinds anything. Found by writing `WitnessUnbindReached` first and watching it come back
\* clean -- which is what a witness is for, and the second time on this track that a first draft
\* was wrong and only running it found out.
KForeign  == 8   \* an attestation kind identity does not own and quorum does not either

Kinds == 1..8

\* §6.3's own list of arrival sources, collapsed to the distinction its phase-2a scope rule
\* draws: "attestations arriving via cross-peer sync (or any non-local-handler path that
\* produces a tree binding)" versus "attestations newly written by a local handler op".
SLocal  == 1
SSync   == 2
Sources == 1..2

VARIABLES kind,  \* the arriving attestation's properties.kind
          src,   \* which of §6.3's two paths it arrived on
          hfail  \* whether the phase-2 handler for this kind fails (§6.3 phase 2/3)

vars == << kind, src, hfail >>

\* ---------------------------------------------------------------------------------------
\* §3.6 `identity_verify_cert` STEP 1, transcribed. `identity_lifecycle_kinds()` is fixed by
\* §3.6 to exactly these three, and the "revocation is NOT in this set" note is the reason the
\* fifth kind is behind a constant rather than in the set.
\* ---------------------------------------------------------------------------------------
LifecycleKinds == {KHandoff, KRecovery, KRetire}

Step1Admits(k) == \/ k = KCert
                  \/ k \in LifecycleKinds
                  \/ (RevocationAdmitted /\ k = KRevoke)

\* ---------------------------------------------------------------------------------------
\* §6.3 PHASE 2's dispatch table, as a set of kinds. Seven rows; the (identity-cert, *) rows
\* differ only in `function`, which this module does not model (see the fidelity note).
\* ---------------------------------------------------------------------------------------
DispatchRow(k) == k \in {KCert, KHandoff, KRecovery, KRetire, KQPublish}

\* ---------------------------------------------------------------------------------------
\* THE PRE-PHASE-1 BRANCH THE COHORT ADDED AND §6.3 DOES NOT HAVE.
\* ---------------------------------------------------------------------------------------
PreRouted(k) == \/ (PreRouteQPublish /\ k = KQPublish)
                \/ (PreRouteQUpdate  /\ k = KQUpdate)

ReachesPhase1(k) == ~PreRouted(k)

Phase1Ok(k) == ReachesPhase1(k) /\ Step1Admits(k)

\* Phase 2 runs either because phase 1 passed, or because the pre-route branch performed the
\* dispatch row itself. Go's branch does neither -- it declines to unbind and stops.
ReachesPhase2(k) == \/ Phase1Ok(k)
                    \/ (PreRouted(k) /\ SeedOnPreRoute /\ k = KQPublish)

\* ---------------------------------------------------------------------------------------
\* PHASE 2a, with its scope rule. Two ways an arrival loses its tree binding: phase 1 rejected
\* it, or (the control) a phase-2 handler failure was allowed to propagate.
\* ---------------------------------------------------------------------------------------
UnboundByPhase1(k, s) == /\ ReachesPhase1(k)
                         /\ ~Step1Admits(k)
                         /\ (Phase2aScoped => s = SSync)

UnboundByHandler(k) == UnbindOnHandlerFailure /\ ReachesPhase2(k) /\ hfail

Unbound(k, s) == UnboundByPhase1(k, s) \/ UnboundByHandler(k)

\* §6.3 phase 3, v2 scope: FAILURE-only.
EventEmitted(k) == /\ ReachesPhase2(k)
                   /\ IF hfail THEN EmitOnFailure ELSE EmitOnSuccess

\* ---------------------------------------------------------------------------------------
\* THE FINDINGS. Each is asserted in a config where nothing is weakened: the constants are
\* §6.3 and §3.6 AS WRITTEN, and the invariant is a contract those same documents state.
\* ---------------------------------------------------------------------------------------

\* FINDING I1. §6.3's phase-2 dispatch table has a row phase 1 makes unreachable. Stated over
\* the whole table rather than over the one row, so that the assertion is "the table is
\* reachable" and a second unreachable row added later fails this too.
SeedRowReachable == DispatchRow(kind) => ReachesPhase2(kind)

\* FINDING I2. A `revocation` arriving over sync is unbound by the extension whose §4.6 defines
\* authority-revocation rules for it and whose §3.6 step 3 reads it back out of the tree.
RevocationSurvivesArrival == kind = KRevoke => ~Unbound(kind, src)

\* FINDING I3. A `quorum-update` arriving over sync at the path §5.1 gives it, on the hook
\* section 10.2 declares, is unbound by identity -- which §3.3 says does not define the kind.
QuorumUpdateSurvivesArrival == kind = KQUpdate => ~Unbound(kind, src)

\* ---------------------------------------------------------------------------------------
\* THE GREENS. Under the union of the three cohort repairs (see the header): the arrival path
\* keeps every entity it is not entitled to delete, and phases 2 and 3 obey their own
\* normative sentences.
\* ---------------------------------------------------------------------------------------

\* §6.3 GREEN. Phase 2a's scope rule, which exists because unbinding a local create "defeats
\* the create -- the caller sees a 200 from :create_attestation followed by a phantom 404 on
\* read". Control: Phase2aScoped = FALSE.
LocalCreateNeverUnbinds == src = SLocal => ~UnboundByPhase1(kind, src)

\* §6.3 GREEN. Nothing loses its binding except by failing phase 1. In particular a phase-2
\* handler failure does not: §6.3 says such a failure "MUST NOT propagate", and phase 3's event
\* IS the recovery signal. Control: UnbindOnHandlerFailure = TRUE.
UnbindOnlyOnRejection == Unbound(kind, src) => ~Step1Admits(kind)

\* §6.3 GREEN, phase 3 v2 scope, both halves. "MUST emit on phase-2 handler failure" and
\* "impls MUST NOT emit success events during v2". Two controls, one per half.
FailureIsObservable == (ReachesPhase2(kind) /\ hfail) => EventEmitted(kind)
NoSuccessEvents     == (ReachesPhase2(kind) /\ ~hfail) => ~EventEmitted(kind)

\* §2.2 / §12.3 GREEN, the three-parallel-mechanisms wall stated at the arrival path: identity
\* does not run side-effect handlers for a kind it does not own. Holds under every setting of
\* every constant here, which is the point -- the wall is not something the cohort's repairs
\* had to add, and stating it separates "identity declines to dispatch a foreign kind" (correct,
\* and true) from "identity DELETES a foreign kind's entity" (findings I2 and I3, and true only
\* because the two kinds in question are ones §5.1 puts on identity's own watched paths).
ForeignKindNotDispatched == kind = KForeign => ~ReachesPhase2(kind)

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Each asserted in order to be VIOLATED; the violation is the pass.
\* Without them every green above is satisfiable by a model in which no arrival ever reaches
\* anything -- which, given that FINDING I1 is exactly "a table row is unreachable", is not a
\* hypothetical concern on this module.
\* ---------------------------------------------------------------------------------------

\* The unbind path is REACHED at all. If it is not, LocalCreateNeverUnbinds and
\* UnbindOnlyOnRejection are statements about a model that never unbinds anything.
WitnessUnbindReached == ~UnboundByPhase1(kind, src)

\* Phase 2 is REACHED, on a kind that has a dispatch row, with the handler succeeding.
WitnessPhase2Reached == ~(ReachesPhase2(kind) /\ DispatchRow(kind) /\ ~hfail)

\* A phase-2 failure produces a phase-3 event. NoSuccessEvents would hold vacuously on a model
\* that emits nothing ever.
WitnessFailureEvent == ~(ReachesPhase2(kind) /\ hfail /\ EventEmitted(kind))

\* ---------------------------------------------------------------------------------------
\* The space: every kind that can arrive, on both of §6.3's arrival paths, with and without a
\* phase-2 handler failure. Nothing evolves -- §6.3 phase 1 is a pure function of these three
\* and the whole question is what that function computes.
\* ---------------------------------------------------------------------------------------
Init == /\ kind  \in Kinds
        /\ src   \in Sources
        /\ hfail \in BOOLEAN

Next == UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK == /\ kind  \in Kinds
          /\ src   \in Sources
          /\ hfail \in BOOLEAN
====
