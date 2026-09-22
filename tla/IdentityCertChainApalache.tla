---- MODULE IdentityCertChainApalache ----
\* IDENTITY TRACK — Apalache (SMT) cross-check of tla/IdentityCertChain.tla: §3.6
\* `identity_topology_for` and `identity_verify_cert` — the dispatch that decides WHICH
\* SIGNATURES a cert needs — against §4.2's valid-modes table, §5.1's path layout and §9.2's
\* operational-key confinement MUST.
\*
\* **THIS IS THE FIRST SECOND-ENGINE MODULE ON THE IDENTITY TRACK**, and it was chosen first
\* because it is where every K-of-N verdict in the extension is dispatched, which makes it the
\* module the other two lean on. `docs/COVERAGE-MATRIX.md` §3e states the live per-track engine
\* count; this file does not restate it.
\*
\* TRACK: `identity` (TRACKS.toml). A bare §N.M means a section of EXTENSION-IDENTITY.md at this
\* track's pin. Cross-track references write the sigil first (§ATTEST:4.3, §QUORUM:4.2) and are
\* EXCLUDED from every track's coverage set.
\*
\* WHAT A SECOND ENGINE BUYS HERE. `IdentityCertChain` is an enumeration model: `Next` is
\* `UNCHANGED vars` and the state space is the cert-shape space §4.2 describes, crossed with the
\* two facts about a lifecycle attestation's target that §3.6 reads and nothing validates. TLC
\* enumerates those few hundred states; Apalache answers one SMT query over them. An independent
\* METHOD, and NOT an independent reading — this file and its TLC twin are the same author's
\* transcription of the same prose, so a shared misreading of §3.6 survives both. That is the
\* 5th wall (../docs/ASSURANCE-MAP.md).
\*
\* WHAT IT DOES NOT BUY, STATED HARDER ON THIS TRACK THAN ANYWHERE ELSE. Every finding this
\* module carries is STRUCTURAL. Signature cryptography and the K-of-N count are abstracted away
\* in both engines; the identity track still has **no prover model at all** (docs/LEAN-SEAM.md
\* O19), so "an unsigned revocation is honoured" (I5) is a statement about which code path is
\* reached, not a Dolev-Yao result. Two engines on a structural model is two engines on a
\* structural model.
\*
\* THE FOUR FINDINGS ARE REPRODUCED, NOT RE-DERIVED. I4 (`PublicPathNeverControllerSigned`),
\* I5 (`RevocationReachesTopology`), I9 (`HandoffReadingsCoincide`) and I8
\* (`HandoffTargetGuarded`) are each checked in a config that expects a COUNTEREXAMPLE, on the
\* same constants as their TLC cfgs. Retirement condition as always: a green means the section
\* was amended upstream and the row is RETIRED, not repaired.
\*
\* READ THE CONSTANTS BEFORE READING A ROW — THIS TRACK USES ALL THREE FINDING SHAPES.
\* `tla/Makefile:TLC_FINDING`'s header is the canonical statement of them and this module
\* exercises each:
\*   nothing weakened  — `ConstInitFindingHandoffNull` is `ConstInitOK` with `TargetGuarded`
\*                       returned to §3.6 as written (the green sweep runs the guard that the
\*                       section does not have).
\*   toward the SPEC   — `ConstInitFindingRevocation` restores §3.6's own step-1 rejection of
\*                       `kind = "revocation"`; the green sweep runs Go's admission instead,
\*                       because it is the only setting in which the module has anything to say
\*                       about the delegation §ATTEST:TV-A8 makes.
\*   toward ONE IMPL   — nothing here; that shape lives in `IdentityRecovery`.
\* `ConstInitFindingPublicSig` and `ConstInitFindingHandoffSigner` are the "toward the spec"
\* shape as well: §4.2's table admits `agent`/`public`, and §4.3's parenthetical is enforced by
\* no operation, and in both cases the green sweep runs the narrower reading.
\*
\* ENCODER NOTES. No unrolling and no recursion — §3.6's validators are pure functions of one
\* attestation, which is why this module cost an afternoon and `AttestRevoke` cost a day. Two
\* rewrites, both flagged at their sites: `CASE` is replaced by a nested `IF` chain (Apalache
\* accepts `CASE` but the `OTHER` arm plus a guard that is not obviously total is a place a
\* transcription can drift silently, and the chain makes the fall-through explicit), and
\* `tmatch \in (IF … THEN {TRUE} ELSE BOOLEAN)` — a set-valued conditional in `Init`, which the
\* assignment solver does not accept — becomes a free assignment plus a constraint.
\*
\* Fidelity (5th wall): IdentityCertChain.tla's abstraction boundary, unchanged — signature
\* cryptography and the K-of-N count entirely (topology dispatch is what is under test, not what
\* the signatures then prove), the recursive chain walk in `identity_verify_cert` step 5 and its
\* depth bound, `walk_attesting_chain`'s termination, the content-hash tie-break in
\* `resolve_controller_for_grants`, revocation LOOKUP, storage paths as strings (`mode` stands in
\* for the path §5.3 derives from it), and the arrival path entirely (that is IdentityProcess).
\* Those sentences carry no § sigil deliberately (../docs/COVERAGE-MATRIX.md §3b).
EXTENDS Naturals

CONSTANTS
  \* does §QUORUM:4.2 `current_signer_set` return the roster its own normative sentence asks
  \* for? TRUE is the green sweep's declared assumption; FALSE is a negative control and is the
  \* routed Q1. LEAN-SEAM O16.
  \* @type: Bool;
  SignerSetIsSound,
  \* §10.1 MUST: dispatch on topology BEFORE running signature validation. FALSE is the
  \* forbidden order, as a negative control.
  \* @type: Bool;
  TopologyFirst,
  \* the two readings of an unsatisfiable pair. TRUE = §4.2's table, §4.2a and §5.1 as written.
  \* FALSE = §9.2's MUST read as narrowing the table.
  \* @type: Bool;
  AgentPublicAllowed,
  \* is `revocation` admitted by §3.6 step 1? FALSE is §3.6 as written; TRUE is Go's.
  \* @type: Bool;
  RevocationAdmitted,
  \* does `identity_topology_for` have a `revocation` arm? FALSE is §3.6 as written.
  \* @type: Bool;
  RevocationDispatched,
  \* TRUE = §3.6 as written (`target.attested`); FALSE = Go (`att.attesting`).
  \* @type: Bool;
  HandoffSignerFromTarget,
  \* a null guard on `lookup_target_cert` in the handoff topology arm. FALSE is §3.6 as written.
  \* @type: Bool;
  TargetGuarded,
  \* §4.1's kind table and §10.1 both require dual-sig on a handoff. FALSE is a control.
  \* @type: Bool;
  HandoffIsDualSig,
  \* does ANY operation validate §4.3's parenthetical `att.attesting = target.attested`?
  \* @type: Bool;
  HandoffIdentityEnforced

\* §3.3's four identity kinds plus the universal one §4.6 gives identity rules over.
KCert     == 1
KHandoff  == 2
KRecovery == 3
KRetire   == 4
KRevoke   == 5
Kinds     == 1..5

\* §4.2's function values. App-defined is one representative of an open vocabulary.
FController == 1
FAgent      == 2
FIdentifier == 3
FApp        == 4
Funcs       == 1..4

\* §4.2a's four publication modes; §5.3 derives the canonical storage path from this alone.
MInternal  == 1
MPublic    == 2
MRel       == 3
MEmbedded  == 4
Modes      == 1..4

\* The three-key and four-key shapes — which peer signs an agent cert. The RULE is §2.3's
\* function-correspondence table; the two sections that name the shapes carry no sigil because
\* nothing here is verified about them.
ThreeKey == 1
FourKey  == 2
Shapes   == 1..2

\* Topology verdicts from §3.6.
TNone   == 0
TKofN   == 1
TSingle == 2
TDual   == 3

VARIABLES
  \* @type: Int;
  kind,
  \* @type: Int;
  func,
  \* @type: Int;
  mode,
  \* `attesting` is a quorum_id
  \* @type: Bool;
  aq,
  \* @type: Int;
  shape,
  \* does `lookup_target_cert` resolve? §5.2 promises no arrival ordering.
  \* @type: Bool;
  tres,
  \* is §4.3's unenforced parenthetical true here — att.attesting = target.attested?
  \* @type: Bool;
  tmatch

vars == << kind, func, mode, aq, shape, tres, tmatch >>

\* ---------------------------------------------------------------------------------------
\* §3.6 `identity_verify_cert` STEP 1, and §3.6's `identity_lifecycle_kinds()`.
\* ---------------------------------------------------------------------------------------
Step1Admits(k) == \/ k = KCert
                  \/ k \in {KHandoff, KRecovery, KRetire}
                  \/ (RevocationAdmitted /\ k = KRevoke)

\* ---------------------------------------------------------------------------------------
\* §3.6 `identity_topology_for`, transcribed arm by arm. The match in §3.6 has NO catch-all:
\* every arm is a (kind, function, is_quorum_id) triple and nothing matches `revocation`, which
\* is consistent with step 1 and is exactly what makes §ATTEST:TV-A8's delegation empty.
\* ---------------------------------------------------------------------------------------
Topology ==
  \* §10.1's forbidden order, as a control: a single-sig check run upfront on an attestation
  \* whose `attesting` is a quorum_id never reaches the K-of-N arm.
  IF ~TopologyFirst /\ aq THEN TSingle
  ELSE IF kind = KCert
       THEN (IF func = FController /\ aq THEN TKofN ELSE TSingle)
  ELSE IF kind = KHandoff
       THEN (IF HandoffIsDualSig THEN TDual ELSE TSingle)
  ELSE IF kind = KRecovery \/ kind = KRetire THEN TKofN
  ELSE IF kind = KRevoke /\ RevocationDispatched THEN TSingle
  ELSE TNone

\* ---------------------------------------------------------------------------------------
\* §4.2's per-function valid-modes table (normative), plus §6.0c's
\* `400 invalid_mode_for_function` which is where it is enforced. `AgentPublicAllowed` is the
\* one contested cell. Lifecycle kinds carry no `function` of their own (§4.3) and are stored
\* "at the same audience tier as the target cert" (§4.1's table), so their mode is inherited and
\* not constrained here.
\*
\* Written as a nested IF rather than IdentityCertChain.tla's `CASE … [] OTHER`: the two are the
\* same function, and the chain makes the fall-through arm (`FApp`, the open-vocabulary
\* representative) explicit at the point where it is taken. Flagged because a rewritten
\* conditional is a place a transcription drifts, and because the arm order carries the meaning —
\* `FController /\ aq` must be tested before `FController /\ ~aq`.
\* ---------------------------------------------------------------------------------------
AgentModes == IF AgentPublicAllowed THEN Modes ELSE {MInternal, MRel, MEmbedded}

Admissible ==
  IF kind # KCert THEN TRUE
  ELSE IF func = FController /\ aq  THEN mode = MPublic \/ mode = MInternal
  ELSE IF func = FController        THEN mode = MInternal
  ELSE IF func = FAgent             THEN mode \in AgentModes
  ELSE IF func = FIdentifier        THEN mode = MInternal
  ELSE                                   mode \in AgentModes

\* §5.3: the (kind, function, mode) tuple deterministically computes the canonical storage path.
\* Only the `public/` question is asked here.
UnderPublic == mode = MPublic

\* §2.3's function-correspondence table: who signs. A controller's key signs a sub-controller
\* cert, an identifier cert, an app-defined cert, and — in the THREE-KEY default only — an agent
\* cert. In the four-key shape the identifier signs agent certs, which is why §9.2 is satisfiable
\* there and not here.
ControllerSigned ==
  /\ kind = KCert
  /\ \/ (func = FController /\ ~aq)
     \/ (func = FAgent /\ shape = ThreeKey)
     \/ func = FIdentifier
     \/ func = FApp

\* ---------------------------------------------------------------------------------------
\* THE FINDINGS.
\* ---------------------------------------------------------------------------------------

\* FINDING I4. §9.2's MUST, asserted over exactly the cert shapes §4.2's table admits.
PublicPathNeverControllerSigned ==
  (Admissible /\ UnderPublic) => ~ControllerSigned

\* FINDING I5. §ATTEST:TV-A8 delegates the rejection of an invalid-signature revocation to
\* identity's topology-dispatch step. For that delegation to mean anything, a revocation must
\* reach topology dispatch.
RevocationReachesTopology ==
  kind = KRevoke => (Step1Admits(kind) /\ Topology # TNone)

\* FINDING I9. §3.6's signer list and Go's differ exactly when §4.3's unenforced parenthetical
\* is false. Scoped to the case where the target resolves, because when it does not the two
\* readings differ for the reason I8 is about instead.
HandoffReadingsCoincide == (kind = KHandoff /\ tres) => tmatch

\* FINDING I8. The topology arm dereferences `target.attested` with no null guard, in the same
\* section where `identity_confers_function` guards the same call. Scoped by
\* `HandoffSignerFromTarget` on purpose: Go's shortcut never looks the target up, so the
\* implementation that diverges on I9 is precisely the one that cannot reach I8.
HandoffTargetGuarded ==
  (kind = KHandoff /\ ~tres /\ HandoffSignerFromTarget) => TargetGuarded

\* ---------------------------------------------------------------------------------------
\* THE GREENS.
\* ---------------------------------------------------------------------------------------

\* §3.6 / §10.1 GREEN. A top-level controller cert dispatches K-of-N, never single-sig.
\* Control: TopologyFirst = FALSE.
TopLevelControllerIsKofN ==
  (kind = KCert /\ func = FController /\ aq) => Topology = TKofN

\* §3.6 / §4.2b GREEN. A sub-controller cert is single-sig from that controller.
SubControllerIsSingle ==
  (kind = KCert /\ func = FController /\ ~aq) => Topology = TSingle

\* §4.1 / §10.1 GREEN. Handoff is dual-signed (old + new). Control: HandoffIsDualSig = FALSE.
HandoffIsDual == kind = KHandoff => Topology = TDual

\* §4.4 / §4.5 GREEN. Recovery and retirement are always quorum-driven K-of-N, whatever the
\* function they inherit and whatever the deployment shape.
LifecycleIsQuorumDriven ==
  (kind = KRecovery \/ kind = KRetire) => Topology = TKofN

\* GREEN, AND IT IS THE DECLARED SUBSTRATE ASSUMPTION MADE CHECKABLE (LEAN-SEAM O16). Every
\* K-of-N verdict this extension reaches is taken against whatever §QUORUM:4.2 hands back.
\* Control: SignerSetIsSound = FALSE, which is the already-routed Q1.
KofNAnswerIsTrustworthy == Topology = TKofN => SignerSetIsSound

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Asserted in order to be VIOLATED.
\* ---------------------------------------------------------------------------------------

\* The contested cell is REACHED: an agent cert the §4.2 table admits, at mode=public, in the
\* three-key default, signed by a controller.
WitnessPublicAgentCert ==
  ~(kind = KCert /\ func = FAgent /\ mode = MPublic /\ shape = ThreeKey
    /\ Admissible /\ ControllerSigned)

\* A K-of-N dispatch is reached at all.
WitnessKofNDispatched == Topology # TKofN

\* A dual dispatch is reached, with the target resolving — the state I8 and I9 divide between
\* them.
WitnessDualDispatched == ~(Topology = TDual /\ tres)

\* ---------------------------------------------------------------------------------------
\* The space: every cert shape §4.2 can describe, crossed with the two facts about a lifecycle
\* attestation's target that §3.6 reads and no operation validates. `Init` IS the model; `Next`
\* stutters. Every check runs at --length=0.
\* ---------------------------------------------------------------------------------------
TypeOK == /\ kind  \in Kinds
          /\ func  \in Funcs
          /\ mode  \in Modes
          /\ shape \in Shapes
          /\ aq     \in BOOLEAN
          /\ tres   \in BOOLEAN
          /\ tmatch \in BOOLEAN

Init == /\ kind   \in Kinds
        /\ func   \in Funcs
        /\ mode   \in Modes
        /\ aq     \in BOOLEAN
        /\ shape  \in Shapes
        /\ tres   \in BOOLEAN
        \* §4.3's parenthetical is an assertion, not a validated field. Under the pinned text
        \* `tmatch` ranges freely; the green sweep narrows it to model an enforcement rule that
        \* would have to be ADDED for §3.6's reading and Go's to be the same rule.
        \* IdentityCertChain.tla writes this as `tmatch \in (IF … THEN {TRUE} ELSE BOOLEAN)`;
        \* Apalache's assignment solver does not accept a set-valued conditional as the source
        \* of an assignment, so the free assignment and the narrowing are separated here. Same
        \* space, and the separation is noted because it is exactly the kind of rewrite that
        \* silently drops a constraint if the second conjunct is forgotten.
        /\ tmatch \in BOOLEAN
        /\ HandoffIdentityEnforced => tmatch

Next == UNCHANGED vars

\* ----- constant inits -----
\* Parity with the TLC green sweep: IdentityCertChain.cfg's constants exactly.
ConstInitOK ==
  /\ SignerSetIsSound = TRUE /\ TopologyFirst = TRUE /\ AgentPublicAllowed = FALSE
  /\ RevocationAdmitted = TRUE /\ RevocationDispatched = TRUE
  /\ HandoffSignerFromTarget = TRUE /\ TargetGuarded = TRUE /\ HandoffIsDualSig = TRUE
  /\ HandoffIdentityEnforced = TRUE

\* FINDING I4 — §4.2's table, §4.2a and §5.1 as written admit `agent`/`public`; the green sweep
\* runs §9.2's narrowing instead. Constant moves TOWARD the spec's own table.
\* Expected: counterexample on PublicPathNeverControllerSigned.
ConstInitFindingPublicSig ==
  /\ SignerSetIsSound = TRUE /\ TopologyFirst = TRUE /\ AgentPublicAllowed = TRUE
  /\ RevocationAdmitted = TRUE /\ RevocationDispatched = TRUE
  /\ HandoffSignerFromTarget = TRUE /\ TargetGuarded = TRUE /\ HandoffIsDualSig = TRUE
  /\ HandoffIdentityEnforced = TRUE

\* FINDING I5 — §3.6's own step 1 and its arm-less match, restored. The green sweep runs Go's
\* two spec-absent additions, because they are the only setting in which a revocation reaches
\* the step §ATTEST:TV-A8 delegates to at all.
\* Expected: counterexample on RevocationReachesTopology.
ConstInitFindingRevocation ==
  /\ SignerSetIsSound = TRUE /\ TopologyFirst = TRUE /\ AgentPublicAllowed = FALSE
  /\ RevocationAdmitted = FALSE /\ RevocationDispatched = FALSE
  /\ HandoffSignerFromTarget = TRUE /\ TargetGuarded = TRUE /\ HandoffIsDualSig = TRUE
  /\ HandoffIdentityEnforced = TRUE

\* FINDING I9 — §4.3's parenthetical enforced by no operation, which is the pinned text.
\* Expected: counterexample on HandoffReadingsCoincide.
ConstInitFindingHandoffSigner ==
  /\ SignerSetIsSound = TRUE /\ TopologyFirst = TRUE /\ AgentPublicAllowed = FALSE
  /\ RevocationAdmitted = TRUE /\ RevocationDispatched = TRUE
  /\ HandoffSignerFromTarget = TRUE /\ TargetGuarded = TRUE /\ HandoffIsDualSig = TRUE
  /\ HandoffIdentityEnforced = FALSE

\* FINDING I8 — §3.6's handoff arm has no null guard; the green sweep supplies one.
\* Expected: counterexample on HandoffTargetGuarded.
ConstInitFindingHandoffNull ==
  /\ SignerSetIsSound = TRUE /\ TopologyFirst = TRUE /\ AgentPublicAllowed = FALSE
  /\ RevocationAdmitted = TRUE /\ RevocationDispatched = TRUE
  /\ HandoffSignerFromTarget = TRUE /\ TargetGuarded = FALSE /\ HandoffIsDualSig = TRUE
  /\ HandoffIdentityEnforced = TRUE

\* NEG CONTROL — §10.1's forbidden order: a single-sig check run upfront on an attestation whose
\* `attesting` is a quorum_id. Expected: counterexample on TopLevelControllerIsKofN.
ConstInitBugUpfront ==
  /\ SignerSetIsSound = TRUE /\ TopologyFirst = FALSE /\ AgentPublicAllowed = FALSE
  /\ RevocationAdmitted = TRUE /\ RevocationDispatched = TRUE
  /\ HandoffSignerFromTarget = TRUE /\ TargetGuarded = TRUE /\ HandoffIsDualSig = TRUE
  /\ HandoffIdentityEnforced = TRUE

\* NEG CONTROL — handoff dispatched single-sig. Expected: counterexample on HandoffIsDual.
ConstInitBugDual ==
  /\ SignerSetIsSound = TRUE /\ TopologyFirst = TRUE /\ AgentPublicAllowed = FALSE
  /\ RevocationAdmitted = TRUE /\ RevocationDispatched = TRUE
  /\ HandoffSignerFromTarget = TRUE /\ TargetGuarded = TRUE /\ HandoffIsDualSig = FALSE
  /\ HandoffIdentityEnforced = TRUE

\* NEG CONTROL, AND IT IS THE ONE TO READ (LEAN-SEAM O16) — the substrate is the already-routed
\* Q1. Its violation exhibits what every identity K-of-N verdict rests on.
\* Expected: counterexample on KofNAnswerIsTrustworthy.
ConstInitBugSubstrate ==
  /\ SignerSetIsSound = FALSE /\ TopologyFirst = TRUE /\ AgentPublicAllowed = FALSE
  /\ RevocationAdmitted = TRUE /\ RevocationDispatched = TRUE
  /\ HandoffSignerFromTarget = TRUE /\ TargetGuarded = TRUE /\ HandoffIsDualSig = TRUE
  /\ HandoffIdentityEnforced = TRUE

\* WITNESS cinit — the contested cell needs §4.2's table as written to be reachable at all.
ConstInitWitnessPublic == ConstInitFindingPublicSig
====
