---- MODULE IdentityProcessApalache ----
\* IDENTITY TRACK — Apalache (SMT) second engine on tla/IdentityProcess.tla (§6.3
\* `process_attestation`, the arrival path), and the LAST single-engine subject on this track.
\* docs/CORROBORATION.md ranked it first of what remained, for a reason that is now measured
\* rather than predicted: `identityrecovery` measures the CONSEQUENCE of finding I1 on two
\* engines while the CAUSE — the dispatch row phase 1 makes unreachable — was measured on one.
\*
\* TRACK: `identity` (TRACKS.toml). A bare §N.M means a section of EXTENSION-IDENTITY.md at this
\* track's pin (spec-data/ext-identity-v3.10). Cross-track references write the sigil first
\* (§ATTEST:4.3, §QUORUM:3.3) and are EXCLUDED from every track's coverage set.
\*
\* ── WHAT A SECOND ENGINE WAS POINTED AT (D16), AND IT IS NOT THE INVARIANTS ──────────────────
\* Fourth consecutive application of the same generalization: **point the second engine at the
\* first one's DOMAIN, not at its invariants.** An invariant re-checked is a second opinion on a
\* question already asked; a restriction lifted is a question the first model could not pose.
\*
\* `tla/IdentityProcess.tla` has THREE VARIABLES — `kind`, `src`, `hfail` — and `Next` is
\* `UNCHANGED vars`. It represents EXACTLY ONE ARRIVAL. That is booked as docs/LEAN-SEAM.md
\* **O22**, and it was found by the D18 sweep rather than by a failure: §6.3 phase 2 dispatches
\* handlers that WRITE STATE (`seed_contacts_cache`, `update_handle_cache_to`,
\* `revoke_local_caps_for_attested`, `maybe_issue_local_cap`), and §3.6 steps 2 and 3 READ THE
\* TREE that phase 2a deletes from. A one-arrival model can represent neither half of that loop.
\*
\* This module lifts it: arrivals are unbounded and each one's phase-2 handlers and phase-2a
\* unbind write state the NEXT arrival's phase 1 reads. Nothing else changes — the constants,
\* the kind set, the dispatch table and the pure-function verdict are `IdentityProcess.tla`'s,
\* transcribed from the same pinned text.
\*
\* ── WHAT THAT BOUGHT: TWO FINDINGS, AND BOTH ARE LOOPS THROUGH THE TREE ──────────────────────
\* Fourth consecutive time a lifted restriction has found something the first engine structurally
\* could not see. Both of these are compositions of two arrivals; neither is expressible in a
\* model with one.
\*
\*  N3. **A REVOKED CERT IS ADMITTED, AND THE WINDOW NEVER CLOSES.** §3.6 step 3 is the
\*      authority-revocation check, and it reads its input OUT OF THE LOCAL TREE
\*      (`find_revocations_for(att.content_hash, ctx)`). Finding I2 already established that a
\*      `revocation` arriving over cross-peer sync is UNBOUND by phase 2a, because §3.6 step 1
\*      rejects the kind. Compose the two and the revocation is not merely lost: the cert it
\*      names then PASSES step 3 on every subsequent arrival, forever.
\*
\*      Section 6.4 reasons about exactly this exposure and bounds it (cited without a sigil:
\*      nothing here verifies the cascade -- ../docs/COVERAGE-MATRIX.md §3e): *"a peer that has not yet
\*      observed it will cascade when the revocation arrives via sync"*, and *"the window's bound
\*      is the convergence latency"*. On the pinned text the revocation DOES arrive and the
\*      window does NOT close — the arrival is what deletes it. A paragraph that prices a risk
\*      against a bound its own arrival path removes is a stronger statement than I2 alone, and
\*      it is the reason this row is routed rather than folded into I2.
\*
\*      Row: `RevokedCertNeverAdmitted` under `ConstInitFindingSpec`, where NOTHING IS WEAKENED.
\*      **And it is GREEN under `ConstInitOK`** — under the union of the cohort's repairs the
\*      revocation binds and step 3 finds it. That green is half the result (the O20 lesson):
\*      without it this is "removing an assumption broke something", which is not a measurement.
\*      It also says precisely which repair closes it: `RevocationAdmitted`, which is Go's
\*      `isIdentityKind` addition and which neither Rust nor Python has.
\*
\*  N4. **RETIREMENT IS UNDONE BY RE-ARRIVAL, AND NO SECTION SAYS OTHERWISE.** §6.3 phase 2
\*      dispatches `(identity-retirement, *) -> revoke_local_caps_for_attested` and
\*      `(identity-cert, controller) -> maybe_issue_local_controller_cap`. The dispatch is per
\*      `(kind, function)` and consults NO state. §6.3 is the convergence point "regardless of
\*      source", and its own list of sources includes cross-peer sync and L0 startup, so the
\*      retired cert arrives again as an ordinary event — content-addressed re-delivery, a second
\*      agent of the fleet, a contact re-subscribing. Phase 1 admits it: §4.5 retires a cert
\*      "without rotation" and says nothing about liveness, and §ATTEST:4.3 liveness is supersedes
\*      plus revocation — a retirement is neither. So the cap the retirement revoked is re-issued.
\*
\*      TWO THINGS COULD PREVENT IT AND THE SPEC REQUIRES NEITHER, which is why each is a
\*      constant with a GREEN row rather than a suggestion:
\*        · `IssuanceChecksRetirement` — the issuing handler consults retirement state. The
\*          `maybe_` prefix in `maybe_issue_local_cap` implies a condition and no section states
\*          one, which is N2's shape exactly (see the handler census below).
\*        · `RetirementKillsLiveness` — a retirement makes its target non-live, so step 2 rejects
\*          the re-arrival. §3.6's `identity_confers_function` comment asserts something adjacent
\*          — *"A retired cert does not confer the function"* — and the pseudocode it annotates
\*          returns `false` for the RETIREMENT attestation, never consulting the target.
\*      Row: `RetirementIsDurable`, VIOLATED under `ConstInitOK` (nothing weakened) and GREEN
\*      under each repair.
\*
\* ── THE HANDLER CENSUS, WHICH IS N2's CLASS AND WAS NOT ENUMERATED (D14) ─────────────────────
\* N2 reported that `update_handle_cache_to` is *"named in a normative dispatch table and defined
\* in no section"*. D14 says enumerate the class rather than fix the instance, so the class was
\* enumerated: **ALL SEVEN** handler names in §6.3's phase-2 dispatch table occur EXACTLY ONCE in
\* the whole document, in the table itself. `maybe_issue_local_cap`,
\* `maybe_issue_local_controller_cap`, `maybe_update_identifier_handle`,
\* `handle_dual_sig_handoff`, `update_handle_cache_to`, `revoke_local_caps_for_attested`,
\* `seed_contacts_cache` — seven of seven, none defined. §6.3 calls this "the minimal handler-id
\* set" and normative. N4's two candidate repairs are both statements about handlers that have no
\* text, which is why the finding is against the silence and not against an implementation.
\*
\* ── THE COHORT, MEASURED BEFORE ANY IMPACT CLAIM (docs/PROPERTIES.md §D.1) ───────────────────
\* Read from source at the sibling checkouts, not from memory.
\*
\* On N3 the census is the one section 1.2 of ROUTING-2026-09-07-IDENTITY.md already took, re-read here
\* and unchanged: only entity-core-go admits `revocation` at all (`isIdentityKind` includes
\* `types.KindRevocation`, plus a `KindRevocation` arm in `IdentityTopologyFor` that §3.6's match
\* does not have — two spec-absent additions). Rust and Python reject the kind, so on those two
\* peers every cross-peer revocation is deleted on arrival and N3 is live. **C2 for those two**
\* (they follow the text faithfully and nothing protects the field) and **C3 across the cohort**
\* (a cert is revoked on a Go peer and valid on a Rust peer, from the same wire input).
\*
\* On N4 the cohort splits the OTHER WAY, 2–1, and the two exposed are the two that implement the
\* table as written:
\*   entity-core-rust  EXPOSED. `extensions/identity/src/ops/process_attestation.rs`:
\*                     `KIND_IDENTITY_CERT` + function=controller -> `issue_peer_to_controller_cap
\*                     (&att.attested, &grants)`, unconditional; `KIND_IDENTITY_RETIREMENT` ->
\*                     `revoke_peer_to_controller_cap(&target.attested)`. Neither arm reads the
\*                     other's state.
\*   entity-core-py    EXPOSED, same shape. `_apply_post_validation_side_effects` in
\*                     `packages/entity-handlers/src/entity_handlers/identity.py`:
\*                     `_issue_local_peer_to_controller_cap` on the cert arm,
\*                     `_revoke_local_peer_to_controller_cap` on the retirement arm, no guard.
\*   entity-core-go    NOT EXPOSED, and not because it guards anything. Its `KindIdentityCert`
\*                     arm is an explicit no-op with a written rationale — "the real wiring for
\*                     local cap issuance lives in the configure flow ... No phase-2 handler runs
\*                     here in v2" (`ext/identity/ops.go`). Go therefore implements THREE of the
\*                     seven dispatch rows as no-ops. That is its own divergence, not a defence,
\*                     and it means the three peers do not converge on what §6.3 phase 2 does.
\*
\* Neither census supports "the impls work around it" — on N3 one of three does, on N4 the one
\* that escapes does so by not implementing the row. That is the identity track's standing
\* result (docs/status/CONFORMANCE-DIVERGENCE-REGISTER.md C3) arriving a third time.
\*
\* ── WHAT THIS MODULE DOES *NOT* BUY (D16's counter-clause, stated at the site) ────────────────
\* Not independence from the transcription: same author, same reading of the same pinned text as
\* `IdentityProcess.tla`, so a misreading survives both engines. Not a different QUESTION either
\* — TLC and Apalache are both checkers over TLA+ semantics, and N3 and N4 would be visible to
\* TLC on THIS module too. What moved is the DOMAIN, not the engine's power. docs/CORROBORATION.md
\* records "2" as a count and not as a grade for exactly this reason.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): IdentityProcess's boundary, minus the
\* single-arrival restriction. Still ABSTRACTED AWAY — signature validation and topology dispatch
\* entirely (that is IdentityCertChain), the compromise-recovery anchor and its key (that is
\* IdentityRecovery/Apalache), `properties.function` (no dispatch row is reachable-or-not on
\* account of its function; the retirement/issuance pair is modeled at the KIND level and the
\* cohort's function=controller narrowing is noted, not encoded), the storage path an arrival
\* lands at, ONE cert and ONE revocation and ONE retirement rather than a graph of them, the L0
\* startup path, and every phase-3 event field but the fact of emission. Those sentences carry no
\* § sigil deliberately — a scope disclaimer that cites a section was being counted as coverage of
\* it (../docs/COVERAGE-MATRIX.md §3b).
EXTENDS Naturals

CONSTANTS
  \* @type: Bool;
  PreRouteQPublish,       \* TRUE = a pre-phase-1 branch routes `quorum-publish` past
                          \* `identity_verify_cert`. All three implementations have one;
                          \* §6.3 does not. FALSE = §6.3 AS WRITTEN.
  \* @type: Bool;
  PreRouteQUpdate,        \* the same question for `quorum-update`. Go (via the negated
                          \* `isIdentityKind`) and Python have it; Rust does not.
  \* @type: Bool;
  SeedOnPreRoute,         \* does the pre-phase-1 branch RUN the `(quorum-publish, *) ->
                          \* seed_contacts_cache` row, or merely decline to unbind? Rust and
                          \* Python seed; Go returns 200 and seeds nothing.
  \* @type: Bool;
  RevocationAdmitted,     \* TRUE = `revocation` is admitted by §3.6 step 1 (Go's
                          \* `isIdentityKind`). FALSE = §3.6 AS WRITTEN, which excludes it in an
                          \* explicit comment. THE CONSTANT N3 TURNS ON.
  \* @type: Bool;
  Phase2aScoped,          \* §6.3's phase-2a scope rule (normative, per v2.0 PR-8.3): unbind on
                          \* cross-peer arrival, MUST be skipped for local-handler writes.
                          \* FALSE is a negative control.
  \* @type: Bool;
  EmitOnFailure,          \* §6.3 phase 3: "MUST emit on phase-2 handler failure".
  \* @type: Bool;
  EmitOnSuccess,          \* §6.3 phase 3, v2 scope: "impls MUST NOT emit success events during
                          \* v2". TRUE is a negative control.
  \* @type: Bool;
  UnbindOnHandlerFailure, \* §6.3 phase 2: "handler failure MUST NOT propagate". TRUE is a
                          \* negative control.
  \* @type: Bool;
  IssuanceChecksRetirement, \* N4, REPAIR 1. Does `maybe_issue_local_cap` /
                            \* `maybe_issue_local_controller_cap` consult retirement state before
                            \* issuing? The `maybe_` prefix implies a condition; no section
                            \* writes one. FALSE = the dispatch table as written, and what Rust
                            \* and Python ship.
  \* @type: Bool;
  RetirementKillsLiveness   \* N4, REPAIR 2. Does an `identity-retirement` make its target cert
                            \* non-live, so §3.6 step 2 rejects a re-arrival? §4.5 retires
                            \* "without rotation" and says nothing about liveness; §ATTEST:4.3
                            \* liveness is supersedes plus revocation, and a retirement is
                            \* neither. FALSE = as written.

\* ---------------------------------------------------------------------------------------
\* The kinds that can reach `process_attestation`, transcribed from IdentityProcess.tla — four
\* are identity's own (§3.3), three are kinds identity explicitly does NOT define and which
\* nonetheless arrive at paths section 10.2's sync hook watches (§5.1 layout), and `KForeign` is a kind
\* neither identity nor quorum owns (§ATTEST:3.2's ownership table is open to consumers).
\*
\* KNone is NEW HERE and is not a kind: it is the pre-first-arrival state, because this module
\* has an `Init` that precedes any arrival where the TLC module's `Init` WAS the arrival. Every
\* per-arrival invariant below is guarded by `Started`, and the guard is the whole cost of the
\* lift on the ported rows.
\* ---------------------------------------------------------------------------------------
KNone     == 0
KCert     == 1   \* "identity-cert"                §4.2
KHandoff  == 2   \* "identity-rotation-handoff"    §4.3
KRecovery == 3   \* "identity-rotation-recovery"   §4.4
KRetire   == 4   \* "identity-retirement"          §4.5
KRevoke   == 5   \* "revocation"                   §4.6, owned by §ATTEST:3.3
KQPublish == 6   \* "quorum-publish"               owned by §QUORUM:3.3; §5.1 path
KQUpdate  == 7   \* "quorum-update"                owned by §QUORUM:3.3; §5.1 path
KForeign  == 8   \* a kind identity does not own and quorum does not either

Kinds     == 1..8
AllKinds  == 0..8

\* §6.3's arrival sources, collapsed to the distinction its phase-2a scope rule draws.
SNone   == 0
SLocal  == 1
SSync   == 2
Sources    == 1..2
AllSources == 0..2

VARIABLES
  \* @type: Int;
  cur,          \* the kind of the arrival currently being processed; KNone before the first.
  \* @type: Int;
  csrc,         \* which of §6.3's two paths it arrived on.
  \* @type: Bool;
  cfail,        \* whether the phase-2 handler for this arrival failed (§6.3 phase 2/3).
  \* @type: Bool;
  revArrived,   \* a `revocation` naming the modeled cert has REACHED process_attestation at
                \* this peer. Set whether or not it survives — that is the whole point.
  \* @type: Bool;
  revBound,     \* ...and it is BOUND in the local tree, so §3.6 step 3's
                \* `find_revocations_for` can return it. THE VARIABLE THE ONE-ARRIVAL MODEL
                \* COULD NOT HAVE: it is written by one arrival and read by the next.
  \* @type: Bool;
  retireBound,  \* an `identity-retirement` targeting the cert is bound in the tree.
  \* @type: Bool;
  capIssued,    \* a local peer->controller cap for the attested key is currently in place.
  \* @type: Bool;
  capTornDown,  \* `revoke_local_caps_for_attested` ran AND REMOVED A CAP THAT WAS IN PLACE.
                \* The second half is load-bearing and was added after reading a trace: with the
                \* flag set on "the handler ran", the N4 counterexample was a retirement followed
                \* by a first-ever cert, where nothing had been undone because nothing had been
                \* issued. True instance, wrong mechanism, and easy for a reader to dismiss —
                \* `QuorumSignerSetApalache`'s self-superseding attestation exactly (tla/Makefile,
                \* APALACHE_ENUM_FINDING header). Requiring the teardown forces the three-arrival
                \* trace the finding actually claims.
  \* @type: Bool;
  staleAdmit,   \* N3's outcome flag: an `identity-cert` arrival was ADMITTED by phase 1 while a
                \* revocation naming it had already reached this peer. Stated over the OUTCOME
                \* rather than over the rule, so a counterexample exhibits the consequence.
  \* @type: Bool;
  capReissued,  \* N4's outcome flag: a cap was issued by a dispatch that ran AFTER
                \* `revoke_local_caps_for_attested` had already removed one.
  \* @type: Bool;
  seeded        \* the `(quorum-publish, *) -> seed_contacts_cache` row has run. Carries I1's
                \* consequence into this module's own state; the trust-anchor half is
                \* IdentityRecovery's.

vars == << cur, csrc, cfail, revArrived, revBound, retireBound, capIssued, capTornDown,
           staleAdmit, capReissued, seeded >>

\* ---------------------------------------------------------------------------------------
\* §3.6 `identity_verify_cert` STEP 1, transcribed. `identity_lifecycle_kinds()` is fixed by
\* §3.6 to exactly these three, and the "revocation is NOT in this set" note is the reason the
\* fifth kind is behind a constant rather than in the set.
\* ---------------------------------------------------------------------------------------
LifecycleKinds == {KHandoff, KRecovery, KRetire}

Step1Admits(k) == \/ k = KCert
                  \/ k \in LifecycleKinds
                  \/ (RevocationAdmitted /\ k = KRevoke)

\* §6.3 PHASE 2's dispatch table, as a set of kinds. Seven rows; the three (identity-cert, *)
\* rows differ only in `function`, which this module does not model.
DispatchRow(k) == k \in {KCert, KHandoff, KRecovery, KRetire, KQPublish}

\* THE PRE-PHASE-1 BRANCH THE COHORT ADDED AND §6.3 DOES NOT HAVE.
PreRouted(k) == \/ (PreRouteQPublish /\ k = KQPublish)
                \/ (PreRouteQUpdate  /\ k = KQUpdate)

ReachesPhase1(k) == ~PreRouted(k)

Phase1Ok(k) == ReachesPhase1(k) /\ Step1Admits(k)

\* ---------------------------------------------------------------------------------------
\* THE TWO TREE-READING STEPS OF §3.6, WHICH ARE THE LIFT. Neither exists in
\* `IdentityProcess.tla`, and neither CAN: both read state a previous arrival wrote.
\*
\*   step 2 — `if not ATTESTATION.is_attestation_live(att, ctx): return error("not_live")`
\*   step 3 — `revocations = ATTESTATION.find_revocations_for(att.content_hash, ctx)` and, for
\*            each live one with an authorized revoker, `return error("authority_revoked")`
\*
\* Both are stated here only for `KCert`, which is the modeled target; the module carries one
\* cert, one revocation naming it and one retirement targeting it (fidelity note in the header).
\* `RetirementKillsLiveness` is FALSE as written — §4.5 says nothing about liveness and
\* §ATTEST:4.3's liveness is supersedes plus revocation — so under the pinned text step 2 lets a
\* retired cert straight back through, which is N4's mechanism.
\* ---------------------------------------------------------------------------------------
TreeOk(k) == (k = KCert) => (/\ ~revBound
                             /\ ~(RetirementKillsLiveness /\ retireBound))

\* Phase 1's full verdict: step 1 plus the two steps that read the tree.
Admitted(k) == Phase1Ok(k) /\ TreeOk(k)

\* Phase 2 runs either because phase 1 passed, or because the pre-route branch performed the
\* dispatch row itself. Go's branch does neither — it declines to unbind and stops.
ReachesPhase2(k) == \/ Admitted(k)
                    \/ (PreRouted(k) /\ SeedOnPreRoute /\ k = KQPublish)

\* ---------------------------------------------------------------------------------------
\* PHASE 2a, with its scope rule. NOTE THE WIDENING AGAINST THE TLC MODULE, which is a faithful
\* port and not a change of claim: there, phase 1 could only fail at step 1, so `~Step1Admits(k)`
\* WAS "phase 1 rejected it". Here it can also fail at step 2 or step 3, so the same sentence is
\* written `~Admitted(k)`. Anyone comparing the two files should read this operator and
\* `UnbindOnlyOnRejection` together.
\* ---------------------------------------------------------------------------------------
UnboundByPhase1(k, s) == /\ ReachesPhase1(k)
                         /\ ~Admitted(k)
                         /\ (Phase2aScoped => s = SSync)

\* §6.3 phase 3, v2 scope: FAILURE-only.
EmitsEvent(k, f) == /\ ReachesPhase2(k)
                    /\ (IF f THEN EmitOnFailure ELSE EmitOnSuccess)

\* ---------------------------------------------------------------------------------------
\* The current arrival, lifted to state predicates. `Started` is FALSE only at `Init`.
\* ---------------------------------------------------------------------------------------
Started    == cur \in Kinds
UnboundNow == \/ UnboundByPhase1(cur, csrc)
              \/ (UnbindOnHandlerFailure /\ ReachesPhase2(cur) /\ cfail)
EventNow   == EmitsEvent(cur, cfail)

\* ---------------------------------------------------------------------------------------
\* THE ACTION. One arrival of any kind, on either of §6.3's two paths, with or without a phase-2
\* handler failure — UNBOUNDED, which is the lift. The same attestation may arrive any number of
\* times: §6.3 is "the convergence point ... regardless of source (sync, local
\* :create_attestation, local :supersede_attestation, L0 startup, envelope.included ingestion)"
\* and nothing in it is guarded by "have I processed this content hash before".
\* ---------------------------------------------------------------------------------------
Arrive ==
  \E k \in Kinds, s \in Sources, f \in BOOLEAN :
    /\ cur'   = k
    /\ csrc'  = s
    /\ cfail' = f
    /\ LET p2  == ReachesPhase2(k)
           unb == \/ UnboundByPhase1(k, s)
                  \/ (UnbindOnHandlerFailure /\ p2 /\ f)
           \* PHASE 2's THREE STATE-WRITING HANDLERS. Each runs only if its row was reached and
           \* its handler did not fail; §6.3 isolates failures, so a failed handler writes
           \* nothing and does not stop the others (there is one per kind here, so isolation is
           \* not otherwise observable in this module).
           issues  == /\ k = KCert
                      /\ p2
                      /\ ~f
                      /\ ~(IssuanceChecksRetirement /\ retireBound)
           revokes == (k = KRetire) /\ p2 /\ ~f
           seeds   == (k = KQPublish) /\ p2 /\ ~f
       IN
       /\ revArrived'  = (revArrived  \/ (k = KRevoke))
       /\ revBound'    = (revBound    \/ ((k = KRevoke) /\ ~unb))
       /\ retireBound' = (retireBound \/ ((k = KRetire) /\ ~unb))
       \* N3's flag reads `revArrived` UNPRIMED: the revocation must have arrived on an EARLIER
       \* step, which is the claim. A revocation and a cert in the same step would be a race and
       \* is not what section 6.4's convergence paragraph is about.
       /\ staleAdmit'  = (staleAdmit  \/ ((k = KCert) /\ Admitted(k) /\ revArrived))
       /\ capIssued'   = IF revokes THEN FALSE ELSE (capIssued \/ issues)
       /\ capTornDown' = (capTornDown \/ (revokes /\ capIssued))
       /\ capReissued' = (capReissued \/ (issues /\ capTornDown))
       /\ seeded'      = (seeded \/ seeds)

Init ==
  /\ cur         = KNone
  /\ csrc        = SNone
  /\ cfail       = FALSE
  /\ revArrived  = FALSE
  /\ revBound    = FALSE
  /\ retireBound = FALSE
  /\ capIssued   = FALSE
  /\ capTornDown = FALSE
  /\ staleAdmit  = FALSE
  /\ capReissued = FALSE
  /\ seeded      = FALSE

\* The stutter disjunct is unconditional: this is a safety/reachability module with no temporal
\* property, so a terminal self-loop is the intended shape.
Next == Arrive \/ UNCHANGED vars

\* `\in` rather than a pointwise conjunction: Apalache reads `x \in S` in an init predicate as an
\* ASSIGNMENT, and IndInit must assign every variable. (Convention inherited from
\* ConnCodesApalache.tla via AttestIndexApalache.tla.)
TypeOK ==
  /\ cur         \in AllKinds
  /\ csrc        \in AllSources
  /\ cfail       \in BOOLEAN
  /\ revArrived  \in BOOLEAN
  /\ revBound    \in BOOLEAN
  /\ retireBound \in BOOLEAN
  /\ capIssued   \in BOOLEAN
  /\ capTornDown \in BOOLEAN
  /\ staleAdmit  \in BOOLEAN
  /\ capReissued \in BOOLEAN
  /\ seeded      \in BOOLEAN

\* ---------------------------------------------------------------------------------------
\* THE PORTED CLAIMS — every invariant `tla/IdentityProcess.tla` states, now decided by SMT over
\* runs of ANY length rather than over a single arrival. This is the CORROBORATION half and it is
\* deliberately unremarkable: all of them reproduce.
\* ---------------------------------------------------------------------------------------

\* §6.3 GREEN. Phase 2a's scope rule, which exists because unbinding a local create "defeats the
\* create — the caller sees a 200 from :create_attestation followed by a phantom 404 on read".
\* Control: Phase2aScoped = FALSE.
LocalCreateNeverUnbinds == Started => (csrc = SLocal => ~UnboundByPhase1(cur, csrc))

\* §6.3 GREEN. Nothing loses its binding except by failing phase 1 — in particular a phase-2
\* handler failure does not: §6.3 says such a failure "MUST NOT propagate", and phase 3's event IS
\* the recovery signal. See the `UnboundByPhase1` comment for why the consequent reads
\* `~Admitted` here and `~Step1Admits` in the TLC module. Control: UnbindOnHandlerFailure = TRUE.
UnbindOnlyOnRejection == Started => (UnboundNow => ~Admitted(cur))

\* §6.3 GREEN, phase 3 v2 scope, both halves. "MUST emit on phase-2 handler failure" and "impls
\* MUST NOT emit success events during v2". Two controls, one per half.
FailureIsObservable == Started => ((ReachesPhase2(cur) /\ cfail) => EventNow)
NoSuccessEvents     == Started => ((ReachesPhase2(cur) /\ ~cfail) => ~EventNow)

\* §2.2 / §12.3 GREEN, the three-parallel-mechanisms wall stated at the arrival path: identity
\* does not run side-effect handlers for a kind it does not own. Holds under every setting of
\* every constant here, which is the point — it separates "identity declines to dispatch a
\* foreign kind" (correct, and true) from "identity DELETES a foreign kind's entity" (I2 and I3).
ForeignKindNotDispatched == Started => (cur = KForeign => ~ReachesPhase2(cur))

\* FINDING I1 (ported). §6.3's phase-2 dispatch table has a row phase 1 makes unreachable. Stated
\* over the whole table rather than over the one row, so a second unreachable row added later
\* fails this too.
\*
\* SECOND ANTECEDENT WIDENING, AND IT WAS FOUND BY RUNNING RATHER THAN BY READING. The first
\* draft was the TLC operator verbatim and it FAILED the inductive step under `ConstInitOK` — on
\* `revBound = TRUE /\ cur = KCert`, a cert that does not dispatch because §3.6 step 3 revoked it.
\* That is correct behaviour and not I1; the ported form only reads as "every row is reachable"
\* in a domain where the tree cannot reject anything, which is exactly the domain O22 names. So
\* the claim is scoped to what it was always about — THE KIND GATE — and says: a dispatch row is
\* reached whenever nothing in the tree rejects the attestation. Same shape as
\* `UnbindOnlyOnRejection`'s `~Step1Admits` -> `~Admitted`, and the second of two ported
\* invariants whose antecedent the single-arrival domain hid.
SeedRowReachable == Started => (DispatchRow(cur) => (TreeOk(cur) => ReachesPhase2(cur)))

\* FINDING I2 (ported). A `revocation` arriving over sync is unbound by the extension whose §4.6
\* defines authority-revocation rules for it and whose §3.6 step 3 reads it back out of the tree.
RevocationSurvivesArrival == Started => (cur = KRevoke => ~UnboundNow)

\* FINDING I3 (ported). A `quorum-update` arriving over sync at the path §5.1 gives it, on the
\* hook section 10.2 declares, is unbound by identity — which §3.3 says does not define the kind.
QuorumUpdateSurvivesArrival == Started => (cur = KQUpdate => ~UnboundNow)

\* ---------------------------------------------------------------------------------------
\* THE TWO CLAIMS THE LIFT MADE EXPRESSIBLE. Both are about STATE ACROSS ARRIVALS and neither has
\* a `Started` guard, because neither is about the current arrival at all.
\* ---------------------------------------------------------------------------------------

\* FINDING N3. No `identity-cert` is admitted by §3.6 after a revocation naming it has reached
\* this peer. VIOLATED under `ConstInitFindingSpec` (§6.3 and §3.6 as written, nothing weakened):
\* the revocation arrives over sync, step 1 rejects the kind, phase 2a deletes it, and step 3
\* then finds nothing on every later arrival. GREEN under `ConstInitOK`, which is the measurement
\* — `RevocationAdmitted` is the repair that closes it and only one implementation has it.
RevokedCertNeverAdmitted == ~staleAdmit

\* FINDING N4. A local cap removed by `revoke_local_caps_for_attested` is not re-issued by a
\* later dispatch. VIOLATED under `ConstInitOK` — NOTHING IS WEAKENED there; the constants are the
\* green sweep's and the trace is three ordinary arrivals. GREEN under either
\* `ConstInitIssueChecksRetire` or `ConstInitRetireKillsLive`, which is what makes the two
\* candidate repairs checked rather than proposed (docs/PROPERTIES.md §D.1 is the record of
\* publishing a remedy that was not).
RetirementIsDurable == ~capReissued

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Asserted in order to be VIOLATED; the violation is the pass.
\*
\* THESE ARE LOAD-BEARING ON THIS MODULE SPECIFICALLY, and the TLC twin is the evidence: its
\* green sweep was VACUOUS on its first draft, because under the union of the cohort's repairs
\* every kind was either admitted or pre-routed, so the phase-2a unbind path was dead and two
\* greens were true of a model that never unbinds anything. `WitnessCapIssued` plays the same
\* role for N3's green: `~staleAdmit` is satisfied by a peer that admits no cert at all.
\* ---------------------------------------------------------------------------------------

\* The unbind path is REACHED at all (KForeign is what keeps it live — see the TLC module).
WitnessUnbindReached == Started => ~UnboundByPhase1(cur, csrc)

\* Phase 2 is REACHED, on a kind that has a dispatch row, with the handler succeeding.
WitnessPhase2Reached == Started => ~(ReachesPhase2(cur) /\ DispatchRow(cur) /\ ~cfail)

\* A phase-2 failure produces a phase-3 event.
WitnessFailureEvent == Started => ~(ReachesPhase2(cur) /\ cfail /\ EventNow)

\* A cert is ever ADMITTED and its issuing handler ever runs. Without this, N3's green is a
\* statement about a peer that rejects everything, which is precisely the shape of finding I2 one
\* module over — so it is not a hypothetical concern here.
WitnessCapIssued == ~capIssued

\* The retirement handler ever TEARS A CAP DOWN. Without it `RetirementIsDurable` is green by
\* never revoking anything, and N4's counterexample is the ordering artifact described at
\* `capTornDown` rather than the mechanism.
WitnessCapTornDown == ~capTornDown

\* A revocation ever BINDS. This is the antecedent N3's green rests on: under `ConstInitOK` the
\* claim is "step 3 finds it", which asserts nothing if nothing is ever there to find.
WitnessRevBound == ~revBound

\* The `(quorum-publish, *) -> seed_contacts_cache` row ever RUNS. `SeedRowReachable` says the row
\* is REACHABLE; this says it is REACHED, which is a different claim and the one I1's repair is
\* about. It exists because `seeded` was otherwise a variable this module WROTE AND NEVER READ, and
\* a variable nothing reads asserts nothing — D13's question asked of the state rather than of a
\* grader.
WitnessSeeded == ~seeded

\* ---------------------------------------------------------------------------------------
\* THE STRENGTHENINGS, and what each is FOR. A strengthening that is never named is a
\* strengthening nobody can check (AttestIndexApalache's header), and `make apalache-closure`
\* additionally requires each to preserve ITSELF — without that, the base and step rows prove
\* preservation FROM strengthened states and nothing shows a run stays in them (D13, eighth
\* instance).
\* ---------------------------------------------------------------------------------------

\* For `RevokedCertNeverAdmitted`. Where step 1 admits the kind, a revocation that ARRIVED is a
\* revocation that BOUND — phase 2a has no reason to fire on it — so step 3 has it. Guarded by
\* the constant because under `RevocationAdmitted = FALSE` it is exactly FALSE, which is N3
\* rather than a modelling failure. The inductive step starts from an arbitrary typed state, in
\* which "arrived but not bound" is expressible; this is what rules it out on the runs that
\* actually happen.
RevBindsWhenAdmitted == RevocationAdmitted => (revArrived => revBound)

\* For `RetirementIsDurable` under either repair. A retirement that ran its handler is a
\* retirement that is BOUND, so both repairs have something to consult. True by construction —
\* `revokes` requires the retirement to have been admitted, and an admitted arrival is never
\* unbound — and needed because the inductive step may start from a state where it is false.
RetireVisible == capTornDown => retireBound

\* The ported claims plus the strengthening they need. `TypeOK` is first because IndInit must
\* assign every variable.
IndInitP == /\ TypeOK
            /\ RevBindsWhenAdmitted
            /\ LocalCreateNeverUnbinds /\ UnbindOnlyOnRejection
            /\ FailureIsObservable /\ NoSuccessEvents /\ ForeignKindNotDispatched
            /\ SeedRowReachable /\ RevocationSurvivesArrival /\ QuorumUpdateSurvivesArrival
            /\ RevokedCertNeverAdmitted

\* N4's two repair rows, and nothing else — kept separate so the repair's own assumption cannot
\* quietly strengthen the ported rows above.
IndInitRetire == TypeOK /\ RetireVisible /\ RetirementIsDurable

\* ---------------------------------------------------------------------------------------
\* CONSTANT INITS. Each says which document is on trial. The tla/Makefile TLC_FINDING header is
\* the canonical statement of the three shapes: a control WEAKENS the model; a finding weakens
\* NOTHING, or flips a constant TOWARD the spec, or toward one implementation where the spec is
\* silent.
\* ---------------------------------------------------------------------------------------

\* GREEN SWEEP — tla/IdentityProcess.cfg's constants exactly, plus the two new ones at their
\* AS-WRITTEN values. Read that cfg's header before quoting any green here: these constants are
\* NOT a cohort consensus, because there is none. They are the UNION of the three repairs — what
\* §6.3 would have to say for ANY of the three to be conformant, and which NO implementation
\* currently is.
\*
\* N4 IS A FINDING ROW ON THIS CINIT, which is the sharpest thing in the file: it is violated on
\* the union of every repair the cohort invented, so no implementation's workaround touches it.
ConstInitOK ==
  /\ PreRouteQPublish = TRUE  /\ PreRouteQUpdate = TRUE  /\ SeedOnPreRoute = TRUE
  /\ RevocationAdmitted = TRUE  /\ Phase2aScoped = TRUE
  /\ EmitOnFailure = TRUE  /\ EmitOnSuccess = FALSE  /\ UnbindOnHandlerFailure = FALSE
  /\ IssuanceChecksRetirement = FALSE /\ RetirementKillsLiveness = FALSE

\* FINDING — §6.3 AND §3.6 AS WRITTEN. The three pre-route constants are FALSE because the spec
\* has no pre-route branch; `RevocationAdmitted` is FALSE because §3.6 says in an explicit comment
\* that it is. Nothing is weakened. Carries I1, I2, I3 and N3.
ConstInitFindingSpec ==
  /\ PreRouteQPublish = FALSE /\ PreRouteQUpdate = FALSE /\ SeedOnPreRoute = FALSE
  /\ RevocationAdmitted = FALSE /\ Phase2aScoped = TRUE
  /\ EmitOnFailure = TRUE  /\ EmitOnSuccess = FALSE  /\ UnbindOnHandlerFailure = FALSE
  /\ IssuanceChecksRetirement = FALSE /\ RetirementKillsLiveness = FALSE

\* N4's REPAIR 1, MEASURED. `maybe_issue_local_cap` consults retirement state — the condition the
\* handler's own name implies and no section states.
ConstInitIssueChecksRetire ==
  /\ PreRouteQPublish = TRUE  /\ PreRouteQUpdate = TRUE  /\ SeedOnPreRoute = TRUE
  /\ RevocationAdmitted = TRUE  /\ Phase2aScoped = TRUE
  /\ EmitOnFailure = TRUE  /\ EmitOnSuccess = FALSE  /\ UnbindOnHandlerFailure = FALSE
  /\ IssuanceChecksRetirement = TRUE  /\ RetirementKillsLiveness = FALSE

\* N4's REPAIR 2, MEASURED. A retirement makes its target non-live, so §3.6 step 2 rejects the
\* re-arrival. This is the reading §3.6's `identity_confers_function` COMMENT asserts ("a retired
\* cert does not confer the function") and its pseudocode does not implement.
ConstInitRetireKillsLive ==
  /\ PreRouteQPublish = TRUE  /\ PreRouteQUpdate = TRUE  /\ SeedOnPreRoute = TRUE
  /\ RevocationAdmitted = TRUE  /\ Phase2aScoped = TRUE
  /\ EmitOnFailure = TRUE  /\ EmitOnSuccess = FALSE  /\ UnbindOnHandlerFailure = FALSE
  /\ IssuanceChecksRetirement = FALSE /\ RetirementKillsLiveness = TRUE

\* NEG CONTROL — §6.3's phase-2a scope rule removed (normative, per v2.0 PR-8.3), so the
\* fail-closed unbind fires on locally-created attestations too. §6.3 names the symptom: a 200
\* from :create_attestation followed by a phantom 404 on read.
ConstInitBugScope ==
  /\ PreRouteQPublish = TRUE  /\ PreRouteQUpdate = TRUE  /\ SeedOnPreRoute = TRUE
  /\ RevocationAdmitted = TRUE  /\ Phase2aScoped = FALSE
  /\ EmitOnFailure = TRUE  /\ EmitOnSuccess = FALSE  /\ UnbindOnHandlerFailure = FALSE
  /\ IssuanceChecksRetirement = FALSE /\ RetirementKillsLiveness = FALSE

\* NEG CONTROL — a phase-2 handler failure is allowed to propagate into an unbind, which §6.3
\* forbids in so many words.
ConstInitBugHandler ==
  /\ PreRouteQPublish = TRUE  /\ PreRouteQUpdate = TRUE  /\ SeedOnPreRoute = TRUE
  /\ RevocationAdmitted = TRUE  /\ Phase2aScoped = TRUE
  /\ EmitOnFailure = TRUE  /\ EmitOnSuccess = FALSE  /\ UnbindOnHandlerFailure = TRUE
  /\ IssuanceChecksRetirement = FALSE /\ RetirementKillsLiveness = FALSE

\* NEG CONTROL — phase 3 dropped. Without it a recovery_signal never reaches the controller and
\* §6.3's retention contract ("the tombstone IS the signal") has nothing to retain.
ConstInitBugNoEmit ==
  /\ PreRouteQPublish = TRUE  /\ PreRouteQUpdate = TRUE  /\ SeedOnPreRoute = TRUE
  /\ RevocationAdmitted = TRUE  /\ Phase2aScoped = TRUE
  /\ EmitOnFailure = FALSE /\ EmitOnSuccess = FALSE  /\ UnbindOnHandlerFailure = FALSE
  /\ IssuanceChecksRetirement = FALSE /\ RetirementKillsLiveness = FALSE

\* NEG CONTROL — success-path emission, which §6.3's v2 scope makes a MUST NOT rather than an
\* omission.
ConstInitBugSuccessEvent ==
  /\ PreRouteQPublish = TRUE  /\ PreRouteQUpdate = TRUE  /\ SeedOnPreRoute = TRUE
  /\ RevocationAdmitted = TRUE  /\ Phase2aScoped = TRUE
  /\ EmitOnFailure = TRUE  /\ EmitOnSuccess = TRUE  /\ UnbindOnHandlerFailure = FALSE
  /\ IssuanceChecksRetirement = FALSE /\ RetirementKillsLiveness = FALSE
====
