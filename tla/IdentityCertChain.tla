---- MODULE IdentityCertChain ----
\* IDENTITY TRACK, third model. §3.6 `identity_topology_for` and `identity_verify_cert` -- the
\* dispatch that decides WHICH SIGNATURES a cert needs -- checked against §4.2's valid-modes
\* table, §5.1's path layout and §9.2's operational-key confinement MUST.
\*
\* TRACK: `identity` (TRACKS.toml). A bare §N.M means a section of EXTENSION-IDENTITY.md at this
\* track's pin. Cross-track references write the sigil first (§ATTEST:4.3, §QUORUM:4.2) and are
\* EXCLUDED from every track's coverage set.
\*
\* WHAT THIS MODULE IS. An exhaustive enumeration over the cert-shape space §4.2 describes:
\* (kind x function x mode x attesting-is-a-quorum-id x deployment shape), crossed with the two
\* facts about a lifecycle attestation's target that §3.6 reads and nothing validates. Four
\* hundred-odd states, checked completely. Like `IdentityProcess` and unlike `AttestIndex`, there
\* is no interleaving here: §3.6's validators are pure functions of an attestation and the
\* question is whether they agree with the tables that describe them.
\*
\* ── THE SUBSTRATE ASSUMPTION, MADE VISIBLE RATHER THAN ASSUMED ──────────────────────────────
\* `SignerSetIsSound` is the constant that answers the "transcribe §QUORUM:4.2 as written, or
\* assume the cohort's behaviour?" question the prior checkpoint flagged as needing to be settled
\* before this track started. §3.6's two K-of-N arms call `QUORUM.current_signer_set(att.attesting,
\* ctx)` and the answer that comes back is what every top-level controller cert, every recovery
\* and every retirement is validated against. SEVEN routed findings say that answer can be the
\* CREATION-TIME roster.
\*
\* Rather than choose, the assumption is a knob and both settings are run. TRUE is the green
\* sweep: identity's results are then statements about identity, on the stated assumption that
\* its substrate resolves correctly. FALSE is a NEGATIVE CONTROL (`IdentityCertChainSubstrateBug`)
\* whose job is to show what rests on it -- and what rests on it is every K-of-N verdict this
\* extension reaches. That is LEAN-SEAM O16, and it is a control rather than a finding on purpose:
\* the defect it exhibits is already routed as Q1 and re-routing it wearing an identity section
\* number is exactly the double-count the checkpoint warned about.
\*
\* ── FINDING I4: §9.2's MUST AND §4.2a's TABLE CANNOT BOTH BE SATISFIED ──────────────────────
\* §9.2 (normative, MUST, and §10.1 restates it as a conformance commitment):
\*   "implementations MUST reject attestations under `system/identity/public/` carrying
\*    signatures from any currently-live controller of the trusted quorum"
\*   and, in the same paragraph, "no controller signature on `public/` paths in either three-key
\*    default or four-key advanced".
\* §10.1: "operational keys never sign attestations under `public/` paths"; "Operational-key
\*    confinement (§9.2): structural enforcement of operational-key signatures restricted to
\*    `internal/` paths."
\*
\* §4.2's per-function valid-modes table (normative) gives `agent` "any of the four" modes.
\* §4.2a gives mode=public the path `system/identity/public/cert/{hash_hex}` and the use case
\* "Public-facing infrastructure". §5.1's path layout lists `identity-cert (function=agent,
\* mode=public)` under `public/cert/{hash_hex}` explicitly. And §2.3 fixes the signer: an agent
\* cert's `attesting` is "the issuing controller (3-key) or identifier (4-key)", which §3.6's
\* topology arm `("identity-cert", "agent", _) -> {mode: "single", expected_signer: att.attesting}`
\* then requires a signature from.
\*
\* So in the THREE-KEY DEFAULT -- section 11.3, "The recommended default" -- an agent cert with
\* mode="public" is signed by the controller and lives under `public/`, and §9.2 requires
\* rejecting it. The two normative statements are jointly unsatisfiable for a configuration the
\* document recommends and gives a worked use case for. `AgentPublicAllowed` names the two
\* readings and the finding cfg runs §4.2a's.
\*
\* The FOUR-KEY shape is NOT affected and that asymmetry is the tell: there the agent cert is
\* signed by the identifier, which is not a controller, so §9.2 is satisfiable. §9.2 reads as
\* though it were written with the four-key shape in view.
\*
\* NOT CLAIMED, and deliberately: §5.1 also lists `identity-rotation-handoff (target
\* handle-bearing)` under `public/cert/`, and a handoff of a 3-key controller cert is dual-signed
\* by the OLD CONTROLLER KEY. Whether a key being rotated out is "currently-live" for §9.2's
\* purposes is a genuine reading question the document does not settle, so this module asserts
\* nothing about it. The agent case needs no such reading.
\*
\* ── FINDING I5: A CROSS-SPEC ONE, AND IT NAMES A REJECTION POINT THAT DOES NOT EXIST ────────
\* Three statements, pairwise inconsistent, two documents:
\*
\*   (a) §ATTEST:3.3: "The attestation primitive validates the signature on the revocation."
\*   (b) §ATTEST:4.3 + §ATTEST:6 + the v1.1 SI-1 history entry: the substrate is
\*       SIGNATURE-AGNOSTIC. "Signature validation is not part of liveness"; the `:create`
\*       handler "does NOT validate the signature".
\*   (c) §ATTEST's TV-A8 resolves (a) against (b) by naming who does validate it:
\*         "A's signature is invalid (raw `tree:put` bypassed `:create` validation)
\*          -> expected output A (substrate is signature-agnostic; consumers layer signature
\*          validation per topology -- IDENTITY'S `identity_verify_cert` REJECTS A AT
\*          TOPOLOGY-DISPATCH STEP)"
\*
\* And §3.6's `identity_verify_cert` step 1 rejects `kind = "revocation"` -- "revocation" is not
\* "identity-cert" and §3.6 states in an explicit comment that it is deliberately not in
\* `identity_lifecycle_kinds()`. `identity_topology_for`'s match has no revocation arm either.
\* **The topology-dispatch step TV-A8 delegates to is never reached for the kind TV-A8 is about.**
\*
\* Consequence on the pinned text: an invalid-signature revocation written by raw `tree:put` --
\* which §ATTEST:8 permits and TV-A8 constructs on purpose -- is honoured by §3.6 step 3, which
\* checks `is_attestation_live(rev)` and `identity_is_authorized_revoker(rev.attesting, ...)` and
\* nothing else. Neither is a signature check. Any cert whose chain roots at the named quorum
\* becomes `authority_revoked`. Denial of authority, no signature required.
\* `RevocationReachesTopology`.
\*
\* ── FINDINGS I6 AND I7: THE HANDOFF ARM, TWICE ──────────────────────────────────────────────
\* §3.6, verbatim:
\*     ("identity-rotation-handoff", _, _):
\*       ; Dual-sig from old + new key
\*       target = lookup_target_cert(att, ctx)
\*       return {mode: "dual", signers: [target.attested, att.attested]}
\*       ; (att.attesting is old key = target.attested; att.attested is new key)
\*
\* I6. The parenthetical ASSERTS `att.attesting = target.attested` and nothing enforces it.
\*     §6.0c `:create_attestation` validates (kind, function, mode) and the required properties
\*     fields; §6.0b's non-REBIND branch preserves the predecessor's attesting/attested; a
\*     cross-peer arrival is validated by §3.6 and §3.6 is the thing reading the field. Go took
\*     the parenthetical at its word and wrote `Signers: []hash.Hash{att.Attesting, att.Attested}`
\*     -- no target lookup at all. The two readings coincide exactly when the unenforced identity
\*     holds, and when it does not they require signatures from DIFFERENT KEYS: §3.6 wants one
\*     from the cert being rotated, Go wants one from a field the attestation's author supplied.
\*     `HandoffReadingsCoincide`.
\*
\* I7. `lookup_target_cert` is documented in the same section as returning null ("-> attestation
\*     or null", and its body ends `return ctx.content_store.get(target_hash)`), and
\*     `identity_confers_function` -- twenty lines above, on the same helper -- guards it:
\*     `if target is null: return false`. The topology arm does not, and dereferences
\*     `target.attested` immediately. A handoff arriving over sync before its target does exactly
\*     this; section 5.2's tiers promise no ordering. An asymmetry inside one section between two callers
\*     of one helper. `HandoffTargetGuarded`.
\*
\* ── THE COHORT ──────────────────────────────────────────────────────────────────────────────
\*   I4: all three implementations accept `function=agent, mode=public` at `public/cert/` and
\*       NONE enforces §9.2's MUST at all -- there is no live-controller-key scan on any
\*       `public/` arrival in any of the three. §9.2's "structural enforcement" is unimplemented
\*       three times over, which is itself the census: the MUST that contradicts the table is the
\*       one nobody built.
\*   I5: entity-core-go alone reaches topology dispatch for a revocation, and needed TWO
\*       spec-absent additions to do it (`types.KindRevocation` in `isIdentityKind`, and a
\*       `KindRevocation` arm in `IdentityTopologyFor` returning single-sig from `att.Attesting`).
\*       Rust and Python both reject at `not_identity_attestation`.
\*   I6: Go uses `att.Attesting`; the spec says `target.attested`. The two agree only under the
\*       unenforced identity.
\*   I7: Go's shortcut sidesteps the null dereference by never looking the target up -- so the
\*       implementation that diverges on I6 is the one that cannot hit I7. The two findings are
\*       the same three lines read two ways.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): ABSTRACTED AWAY -- signature cryptography and
\* the K-of-N count entirely (topology dispatch is what is under test, not what the signatures
\* then prove), the recursive chain walk in `identity_verify_cert` step 5 and its depth bound
\* (that is DeepChain/Bounds' question and is not re-asked here), `walk_attesting_chain`'s
\* termination, the content-hash tie-break in section 3.2's `resolve_controller_for_grants`, revocation
\* LOOKUP (`find_revocations_for`), storage paths as strings -- `mode` stands in for the path
\* §5.3 derives from it -- and the arrival path entirely (that is IdentityProcess). Those
\* sentences carry no § sigil deliberately -- a scope disclaimer that cites a section was being
\* counted as coverage of it (../docs/COVERAGE-MATRIX.md section 3b).
EXTENDS Naturals

CONSTANTS SignerSetIsSound,   \* does §QUORUM:4.2 `current_signer_set` return the roster its own
                              \* normative sentence asks for? TRUE is the green sweep's declared
                              \* assumption; FALSE is a negative control and is the routed Q1.
          TopologyFirst,      \* §10.1 MUST: "dispatch on topology BEFORE running signature
                              \* validation ... MUST NOT run a single-sig check upfront on
                              \* attestations whose `attesting` is a quorum_id." FALSE is that
                              \* forbidden order, as a negative control.
          AgentPublicAllowed, \* the two readings of an unsatisfiable pair. TRUE = §4.2's table
                              \* and §4.2a and §5.1 as written (agent certs may be public).
                              \* FALSE = §9.2's MUST read as narrowing the table.
          RevocationAdmitted, \* is `revocation` admitted by §3.6 step 1? FALSE is §3.6 as
                              \* written; TRUE is Go's `isIdentityKind`.
          RevocationDispatched, \* does `identity_topology_for` have a `revocation` arm? FALSE is
                                \* §3.6 as written; TRUE is Go's.
          HandoffSignerFromTarget, \* TRUE = §3.6 as written (`target.attested`);
                                   \* FALSE = Go (`att.attesting`).
          TargetGuarded,      \* a null guard on `lookup_target_cert` in the handoff topology
                              \* arm. FALSE is §3.6 as written.
          HandoffIsDualSig,   \* §4.1's kind table and §10.1 both require dual-sig on a handoff.
                              \* FALSE is a negative control.
          HandoffIdentityEnforced \* does ANY operation validate §4.3's parenthetical
                                  \* `att.attesting = target.attested`? TRUE narrows the state
                                  \* space to handoffs where it holds; FALSE is the pinned text,
                                  \* where §6.0b, §6.0c and §3.6 between them check every other
                                  \* field of a handoff and not this one.

\* §3.3's four identity kinds plus the universal one §4.6 gives identity rules over.
KCert     == 1
KHandoff  == 2
KRecovery == 3
KRetire   == 4
KRevoke   == 5
Kinds     == 1..5

\* §4.2's function values. App-defined is one representative of an open vocabulary; §4.2's
\* registered-values table carries `encryption` with `"public"` among its valid modes.
FController == 1
FAgent      == 2
FIdentifier == 3
FApp        == 4
Funcs       == 1..4

\* §4.2a's four publication modes; §5.3 derives the canonical storage path from this alone
\* ("The `properties.mode` field is a storage-path selector", §4.2 per PI-12).
MInternal  == 1
MPublic    == 2
MRel       == 3
MEmbedded  == 4
Modes      == 1..4

\* The three-key and four-key shapes (sections 7.1 and 7.2) -- which peer signs an agent
\* cert. The RULE is §2.3's function-correspondence table; those two sections only name the
\* shapes and nothing here is verified about them, so they carry no sigil.
ThreeKey == 1
FourKey  == 2
Shapes   == 1..2

\* Topology verdicts from §3.6.
TNone   == 0
TKofN   == 1
TSingle == 2
TDual   == 3

VARIABLES kind, func, mode, aq, shape,
          tres,  \* does `lookup_target_cert` resolve? section 5.2 promises none.
          tmatch \* is §4.3's unenforced parenthetical true here -- att.attesting = target.attested?

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
       THEN IF func = FController /\ aq THEN TKofN ELSE TSingle
  ELSE IF kind = KHandoff
       THEN (IF HandoffIsDualSig THEN TDual ELSE TSingle)
  ELSE IF kind \in {KRecovery, KRetire} THEN TKofN
  ELSE IF kind = KRevoke /\ RevocationDispatched THEN TSingle
  ELSE TNone

\* ---------------------------------------------------------------------------------------
\* §4.2's per-function valid-modes table (normative), plus §6.0c's `400 invalid_mode_for_function`
\* which is where it is enforced. `AgentPublicAllowed` is the one contested cell.
\* Lifecycle kinds carry no `function` of their own (§4.3) and are stored "at the same audience
\* tier as the target cert" (§4.1's table), so their mode is inherited and not constrained here.
\* ---------------------------------------------------------------------------------------
Admissible ==
  IF kind # KCert
  THEN TRUE
  ELSE CASE func = FController /\ aq  -> mode \in {MPublic, MInternal}
         [] func = FController /\ ~aq -> mode = MInternal
         [] func = FAgent             -> IF AgentPublicAllowed
                                         THEN mode \in Modes
                                         ELSE mode \in {MInternal, MRel, MEmbedded}
         [] func = FIdentifier        -> mode = MInternal
         [] OTHER                     -> IF AgentPublicAllowed
                                         THEN mode \in Modes
                                         ELSE mode \in {MInternal, MRel, MEmbedded}

\* §5.3: the (kind, function, mode) tuple deterministically computes the canonical storage path.
\* Only the `public/` question is asked here.
UnderPublic == mode = MPublic

\* §2.3's function-correspondence table: who signs. A controller's key signs a sub-controller
\* cert, an identifier cert, an app-defined cert, and -- in the THREE-KEY default only -- an
\* agent cert. In the four-key shape the identifier signs agent certs, which is why §9.2 is
\* satisfiable there and not here.
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

\* FINDING I6. §3.6's signer list and Go's differ exactly when §4.3's unenforced parenthetical
\* is false. Scoped to the case where the target resolves, because when it does not the two
\* readings differ for the reason I7 is about instead.
HandoffReadingsCoincide == (kind = KHandoff /\ tres) => tmatch

\* FINDING I7. The topology arm dereferences `target.attested` with no null guard, in the same
\* section where `identity_confers_function` guards the same call.
\* Scoped by `HandoffSignerFromTarget` on purpose: Go's shortcut never looks the target up, so
\* the implementation that diverges on I6 is precisely the one that cannot reach I7.
HandoffTargetGuarded ==
  (kind = KHandoff /\ ~tres /\ HandoffSignerFromTarget) => TargetGuarded

\* ---------------------------------------------------------------------------------------
\* THE GREENS.
\* ---------------------------------------------------------------------------------------

\* §3.6 / §10.1 GREEN. A top-level controller cert -- `attesting` is a quorum_id -- dispatches
\* K-of-N, never single-sig. §10.1 states the negation as a MUST NOT.
\* Control: TopologyFirst = FALSE.
TopLevelControllerIsKofN ==
  (kind = KCert /\ func = FController /\ aq) => Topology = TKofN

\* §3.6 / §4.2b GREEN. A sub-controller cert -- `attesting` is another controller's key -- is
\* single-sig from that controller. The chain terminating at the quorum is what carries the
\* authority, not a second K-of-N.
SubControllerIsSingle ==
  (kind = KCert /\ func = FController /\ ~aq) => Topology = TSingle

\* §4.1 / §10.1 GREEN. Handoff is dual-signed (old + new). Control: HandoffIsDualSig = FALSE.
HandoffIsDual == kind = KHandoff => Topology = TDual

\* §4.4 / §4.5 GREEN. Recovery and retirement are always quorum-driven K-of-N, whatever the
\* function they inherit and whatever the deployment shape -- §3.6's arms for both ignore
\* `function` entirely, which is what "always quorum-driven" means operationally.
LifecycleIsQuorumDriven ==
  kind \in {KRecovery, KRetire} => Topology = TKofN

\* GREEN, AND IT IS THE DECLARED SUBSTRATE ASSUMPTION MADE CHECKABLE (LEAN-SEAM O16). Every
\* K-of-N verdict this extension reaches is taken against whatever §QUORUM:4.2 hands back. This
\* says so out loud rather than leaving it in a fidelity note. Control: SignerSetIsSound = FALSE,
\* which is the already-routed Q1 and exhibits what identity's greens rest on.
KofNAnswerIsTrustworthy == Topology = TKofN => SignerSetIsSound

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Asserted in order to be VIOLATED.
\* ---------------------------------------------------------------------------------------

\* The contested cell is REACHED: an agent cert the §4.2 table admits, at mode=public, in the
\* three-key default, signed by a controller. Without this, FINDING I4 would be a violation of
\* something unreachable.
WitnessPublicAgentCert ==
  ~(kind = KCert /\ func = FAgent /\ mode = MPublic /\ shape = ThreeKey
    /\ Admissible /\ ControllerSigned)

\* A K-of-N dispatch is reached at all; otherwise TopLevelControllerIsKofN and
\* KofNAnswerIsTrustworthy are statements about a model that never dispatches K-of-N.
WitnessKofNDispatched == Topology # TKofN

\* A dual dispatch is reached, with the target resolving -- the state FINDINGS I6 and I7 divide
\* between them.
WitnessDualDispatched == ~(Topology = TDual /\ tres)

\* ---------------------------------------------------------------------------------------
\* The space: every cert shape §4.2 can describe, crossed with the two facts about a lifecycle
\* attestation's target that §3.6 reads and no operation validates.
\* ---------------------------------------------------------------------------------------
Init == /\ kind   \in Kinds
        /\ func   \in Funcs
        /\ mode   \in Modes
        /\ aq     \in BOOLEAN
        /\ shape  \in Shapes
        /\ tres   \in BOOLEAN
        \* §4.3's parenthetical is an assertion, not a validated field. Under the pinned text
        \* `tmatch` ranges freely; the green sweep narrows it to model an enforcement rule that
        \* would have to be ADDED for §3.6's reading and Go's to be the same rule.
        /\ tmatch \in (IF HandoffIdentityEnforced THEN {TRUE} ELSE BOOLEAN)

Next == UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK == /\ kind  \in Kinds
          /\ func  \in Funcs
          /\ mode  \in Modes
          /\ shape \in Shapes
          /\ aq     \in BOOLEAN
          /\ tres   \in BOOLEAN
          /\ tmatch \in BOOLEAN
====
