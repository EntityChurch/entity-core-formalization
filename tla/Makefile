# Spike A — TLA+ toolchain, make + podman only (no host java, no loose jar).
#
# All TLC/PlusCal invocations run inside the `entity-tla` podman image, which
# carries the JRE + tla2tools.jar (see ./Containerfile). This dir is bind-mounted
# at /work with LOWERCASE :z for SELinux relabeling (Fedora host) — see the MOUNT
# note below for why uppercase :Z is wrong HERE specifically. (This line said ":Z"
# until 2026-09-06, contradicting the MOUNT line 20 lines below it that was fixed
# on 2026-08-30.)
#
# Usage:
#   make image            build (or rebuild) the toolchain image
#   make translate SPEC=Reentry      PlusCal -> TLA+ (pcal.trans)
#   make tlc       SPEC=Reentry      run TLC model-check (uses Reentry.cfg)
#   make check     SPEC=Reentry      translate then tlc
#   make sany      SPEC=Reentry      parse/typecheck only (SANY), no model-check
#   make repl                         interactive shell in the toolchain container
#   make smoke                        prove the toolchain runs (TLC -help)
#   make clean                        remove TLA+ build artifacts

# Shared podman resource caps (PODMAN_BUILD_CAPS / PODMAN_RUN_CAPS). Every podman
# invocation below carries them so a runaway check dies at the cap, not the host.
include ../caps.mk

IMAGE        ?= entity-tla
SPEC         ?= Reentry
# CFG defaults to SPEC; override to run a second config against the same module
# (e.g. the bug variant: make tlc SPEC=Reentry CFG=ReentryBug).
CFG          ?= $(SPEC)
PODMAN       ?= podman
# SELinux relabel for the bind mount (Fedora host). MUST be lowercase :z, because this
# directory IS shared across containers: RUN uses $(IMAGE) (entity-tla/TLC) and APRUN uses
# $(APIMAGE) (entity-apalache) over the SAME mount. Uppercase :Z relabels the volume PRIVATE
# to one container, so the second image's relabel invalidates the first's and Apalache fails
# mid-sweep with "Configuration error: Could not find or create directory: /work/_apalache-out/
# <spec>.tla" — a flake that reads like a model error and is not one. Found 2026-08-30 when it
# broke `make matrix` twice at different rows; the line above this one already said "Drop to :z
# if shared across containers" and the condition had been true since Apalache was added.
MOUNT        := -v $(CURDIR):/work:z -w /work
RUN          := $(PODMAN) run --rm $(PODMAN_RUN_CAPS) $(MOUNT) $(IMAGE)
# tla2tools workers: bound for a laptop; raise for bigger state spaces.
WORKERS      ?= 4

.PHONY: image smoke translate sany tlc check repl clean matrix

image:
	$(PODMAN) build $(PODMAN_BUILD_CAPS) -t $(IMAGE) -f Containerfile .

# Gate zero: does the containerized toolchain run at all?
smoke:
	$(RUN) tlc2.TLC -help | head -20

# PlusCal -> TLA+ in place (rewrites the translation block in $(SPEC).tla).
translate:
	$(RUN) pcal.trans $(SPEC).tla

# Parse + semantic check only (fast feedback loop while drafting the model).
sany:
	$(RUN) tla2sany.SANY $(SPEC).tla

# Model-check. Uses $(CFG).cfg (defaults to $(SPEC).cfg) against $(SPEC).tla.
tlc:
	$(RUN) tlc2.TLC -workers $(WORKERS) -config $(CFG).cfg $(SPEC).tla

check: translate tlc

repl:
	$(PODMAN) run --rm -it $(PODMAN_RUN_CAPS) $(MOUNT) --entrypoint /bin/bash $(IMAGE)

# ----------------------------------------------------------------------------------
# Green sweep — the base configs / inductive invariants that MUST hold (no defects).
# This is the slice the root `make check` aggregates. Negative controls (the *Bug
# cfgs and ConstInitBug* cinits) are exercised separately; see the reports.
# ----------------------------------------------------------------------------------
# TLC: each module's base .cfg against its .tla (safety + the liveness temporal
# props declared in the cfg). 11 modules: the 7 all-Core concurrency ones, the two added at
# 0.8.2 (Authority = §5.2 dispatch authority; Bounds = §5.9/§4.10 TTL-vs-chain_depth), and
# the two added at the second gate audit (ConnCodes = §4.7 error codes; Bootstrap = §6.9
# pre-loaded handler safety) — both for sections the coverage grid claimed were covered when
# nothing modeled them at all (../docs/COVERAGE-MATRIX.md §3a). StoreLive is Store's liveness slice at a smaller bound — TLC's
# liveness graph exhausts the 2g cap at Store's safety bound of NReq = 4, so the two are
# separate configs rather than one that silently drops a property.
TLC_GREEN := Reentry Conn Store Revoke Emit Register Core Authority Bounds \
              ConnCodes Bootstrap \
              AttestIndex AttestLive AttestRevoke \
              QuorumSignerSet QuorumTrust QuorumKofN \
              IdentityProcess IdentityRecovery IdentityCertChain

# NON-VACUITY WITNESSES (added 0.8.2). TLC has no ProVerif-style reachability query, so a
# witness is an invariant asserted in order to be VIOLATED: the violation exhibits the
# interesting state and proves the green results above are not vacuously true of an inert
# model. Format: MODULE CFG. EXPECTED VERDICT FOR EVERY ROW: violation (exit 12).
# This closes the gap disclosed in ../docs/PROPERTIES.md §C.4 since Phase 1.
# Format: MODULE|CFG|expected TLC verdict line — the same three-field shape as TLC_NEG, and
# for the same reason. This target used to grade on TLC's EXIT STATUS with output sent to
# /dev/null, so a witness cfg naming an operator that does not exist (TLC: "Error: The
# invariant X specified in the configuration file is not defined in the specification",
# exit 151) scored "ok (violated as required)" — identical to a real witnessed state. The
# whole point of a witness is to prove the model is not inert; grading it by a criterion a
# BROKEN CONFIG satisfies reintroduces exactly the vacuity it was added to rule out.
# RegisterSeqWitness retires the last near-tautological positive (../docs/PROPERTIES.md §C.4,
# STATUS item 13): WitnessTreePartial IS the pre-0.8.3 NoPartialResidue, and its violation is
# the proof that §6.2's five writes are now genuinely sequenced rather than collapsed into one
# assignment. A "sequenced" model whose sequence is never reached is the same vacuity in new
# source code; only a violated reachability assertion rules that out.
TLC_WITNESS := \
  "IdentityProcess|IdentityProcessUnbindWitness|Invariant WitnessUnbindReached is violated" \
  "IdentityProcess|IdentityProcessPhase2Witness|Invariant WitnessPhase2Reached is violated" \
  "IdentityProcess|IdentityProcessEventWitness|Invariant WitnessFailureEvent is violated" \
  "IdentityRecovery|IdentityRecoverySeedWitness|Invariant WitnessAnchorSeeded is violated" \
  "IdentityRecovery|IdentityRecoveryAcceptWitness|Invariant WitnessRecoveryAccepted is violated" \
  "IdentityRecovery|IdentityRecoveryFailClosedWitness|Invariant WitnessFailClosedFires is violated" \
  "IdentityCertChain|IdentityCertChainPublicWitness|Invariant WitnessPublicAgentCert is violated" \
  "IdentityCertChain|IdentityCertChainKofNWitness|Invariant WitnessKofNDispatched is violated" \
  "IdentityCertChain|IdentityCertChainDualWitness|Invariant WitnessDualDispatched is violated" \
  "QuorumSignerSet|QuorumSignerSetThreeChainWitness|Invariant WitnessThreeChain is violated" \
  "QuorumSignerSet|QuorumSignerSetPendingWitness|Invariant WitnessPendingUpdate is violated" \
  "QuorumSignerSet|QuorumSignerSetRevertWitness|Invariant WitnessSilentRevert is violated" \
  "QuorumTrust|QuorumTrustCacheWitness|Invariant WitnessCachePopulated is violated" \
  "QuorumTrust|QuorumTrustUnvalidatedWitness|Invariant WitnessUnvalidatedInTree is violated" \
  "QuorumTrust|QuorumTrustColdStartWitness|Invariant WitnessColdStartExposed is violated" \
  "QuorumKofN|QuorumKofNPassWitness|Invariant WitnessKofNPasses is violated" \
  "QuorumKofN|QuorumKofNCollapseWitness|Invariant WitnessResolutionCollapses is violated" \
  "QuorumKofN|QuorumKofNUnresolvableWitness|Invariant WitnessUnresolvableSigner is violated" \
  "AttestRevoke|AttestRevokeChainWitness|Invariant WitnessRevokedRevocation is violated" \
  "AttestRevoke|AttestRevokeSupWitness|Invariant WitnessSupersededByLive is violated" \
  "AttestRevoke|AttestRevokeKillsWitness|Invariant WitnessRevocationKills is violated" \
  "AttestLive|AttestLiveChainWitness|Invariant WitnessThreeChain is violated" \
  "AttestLive|AttestLiveStepWitness|Invariant WitnessSpecWalkSteps is violated" \
  "AttestLive|AttestLiveMoveWitness|Invariant WitnessDagHeadMoves is violated" \
  "AttestIndex|AttestIndexWitness|Invariant WitnessAttestBound is violated" \
  "AttestIndex|AttestIndexEligWitness|Invariant WitnessPartialEligibility is violated" \
  "AttestIndex|AttestIndexSeqWitness|Invariant WitnessIndexPartial is violated" \
  "Reentry|ReentryWitness|Invariant WitnessBothComplete is violated" \
  "Reentry|ReentryWitness3|Invariant WitnessBothComplete is violated" \
  "Core|CoreWitness3|Invariant WitnessExchangeComplete is violated" \
  "Store|StoreWitness|Invariant WitnessStoreLive is violated" \
  "Conn|ConnWitness|Invariant WitnessDispatched is violated" \
  "Revoke|RevokeWitness|Invariant WitnessRevocationObserved is violated" \
  "Revoke|RevokeDeltaWitness|Invariant WitnessDeltaDivergence is violated" \
  "Emit|EmitWitness|Invariant WitnessEventFired is violated" \
  "Register|RegisterWitness|Invariant WitnessHandlerLive is violated" \
  "Register|RegisterSeqWitness|Invariant WitnessTreePartial is violated" \
  "Core|CoreWitness|Invariant WitnessExchangeComplete is violated" \
  "Authority|AuthorityWitness|Invariant WitnessSubAllowed is violated" \
  "Bounds|BoundsWitness|Invariant WitnessDepthBrakeFires is violated" \
  "ConnCodes|ConnCodesWitness|Invariant WitnessAllRowsEmitted is violated" \
  "Bootstrap|BootstrapWitness|Invariant WitnessBootComplete is violated"

# NEGATIVE CONTROLS. Every row MUST fail — a green here means the property has no teeth —
# AND IT MUST FAIL FOR THE STATED REASON. Format: MODULE|CFG|expected TLC verdict line.
#
# The third field was added after the 0.8.2 follow-up audit. Before it, this target graded on
# TLC's EXIT STATUS alone with output sent to /dev/null, and TLC exits non-zero for a parse or
# semantic error exactly as it does for a caught defect — so a control broken by a typo scored
# "ok (failed as required)", and a control that started failing on a DIFFERENT property than
# the one it targets scored the same. That is the repo's recurring failure mode (a Spin control
# that compiled out its own detector; an Apalache control too short to reach its defect): a
# green, or a red, that means something other than what it appears to.
# RegisterAtomicBug's expected verdict changed at 0.8.3-dev, from "NoPartialResidue" to
# "RegisterAllOrNothing". Under sequenced writes NoPartialResidue is scoped to SETTLED
# handlers, because the tree is partial in flight BY DESIGN — so the control now fails on the
# defect its own header names, "a half-built handler is dispatch-visible without its grant".
# The old verdict was an incidental side effect of the collapsed-write shape.
#
# ONE ROW HERE IS NOT A DEFECT CONTROL. `CoreMapFree|CoreMapFreeCarried` is T4's classifier
# (tla/CoreMapFree.tla): it asserts a component invariant, under the Core->component mapping,
# over every TYPE-CORRECT valuation. Its required violation is GOOD NEWS — it exhibits a
# valuation the mapping does not force, which is what proves the composed model's green on
# the same formula (CoreRefines) is a fact about Core rather than about the mapping. It lives
# in this table because "must be violated, on this named formula" is exactly what this
# grader asserts, not because anything is broken. Its six MANUFACTURED siblings are in
# TLC_GREEN_PAIRS, where a passing green is likewise the finding rather than the success.
TLC_NEG := \
  "IdentityProcess|IdentityProcessScopeBug|Invariant LocalCreateNeverUnbinds is violated" \
  "IdentityProcess|IdentityProcessHandlerBug|Invariant UnbindOnlyOnRejection is violated" \
  "IdentityProcess|IdentityProcessNoEmitBug|Invariant FailureIsObservable is violated" \
  "IdentityProcess|IdentityProcessSuccessEventBug|Invariant NoSuccessEvents is violated" \
  "IdentityRecovery|IdentityRecoveryOpenBug|Invariant RecoveryFailClosed is violated" \
  "IdentityRecovery|IdentityRecoveryFreshBug|Invariant AcceptedRecoveryIsQuorumSigned is violated" \
  "IdentityCertChain|IdentityCertChainUpfrontBug|Invariant TopLevelControllerIsKofN is violated" \
  "IdentityCertChain|IdentityCertChainDualBug|Invariant HandoffIsDual is violated" \
  "IdentityCertChain|IdentityCertChainSubstrateBug|Invariant KofNAnswerIsTrustworthy is violated" \
  "QuorumSignerSet|QuorumSignerSetProbeFirstBug|Invariant CohortMatchesNormativeOnChain is violated" \
  "QuorumSignerSet|QuorumSignerSetLiteralBug|Invariant CohortNeverSilentlyReverts is violated" \
  "QuorumTrust|QuorumTrustNoInvalidateBug|Invariant CacheMatchesValidated is violated" \
  "QuorumTrust|QuorumTrustRawInvalidateBug|Invariant NoInvalidationWithoutAcceptance is violated" \
  "QuorumTrust|QuorumTrustCrossQuorumBug|Invariant InvalidationScopedPerQuorum is violated" \
  "QuorumKofN|QuorumKofNDedupeBug|Invariant DedupeCountsPeersOnce is violated" \
  "QuorumKofN|QuorumKofNResolveBug|Invariant UnresolvableNeverCounts is violated" \
  "AttestRevoke|AttestRevokeAuthorityBug|Invariant OnlySelfRevocationKills is violated" \
  "AttestRevoke|AttestRevokeFlatBug|Invariant DeadRevocationSpares is violated" \
  "AttestLive|AttestLiveDirectBug|Invariant NoLiveAncestorOfLive is violated" \
  "AttestLive|AttestLiveHeadFilterBug|Invariant DagHeadIsLive is violated" \
  "AttestIndex|AttestIndexAtomicBug|Invariant NoResidueOnFailure is violated" \
  "AttestIndex|AttestIndexKindBug|Invariant KindIndexEligibleOnly is violated" \
  "AttestIndex|AttestIndexRevokeBug|Invariant IndexRetainedOnRevoke is violated" \
  "Reentry|ReentryBug|Deadlock reached" \
  "Reentry|ReentryFrameBug|Invariant FramesNotInterleaved is violated" \
  "Reentry|ReentryBug3|Deadlock reached" \
  "Core|CoreBug3|Deadlock reached" \
  "Reentry|ReentryFrameBug3|Invariant FramesNotInterleaved is violated" \
  "Store|StoreRaceBug|Invariant StoreRaceFree is violated" \
  "Store|StoreAdmitBug|Invariant ResourceBounded is violated" \
  "Store|StoreRefcountBug|Invariant NoUseAfterFree is violated" \
  "Store|StoreDropBug|Temporal properties Responsive and Recovers were violated" \
  "Conn|ConnBug|Invariant NoEstablishWithoutNonce is violated" \
  "Conn|ConnDropBug|Temporal property AllAnswered was violated" \
  "Revoke|RevokeIgnoreBug|Invariant RevokedNeverPasses is violated" \
  "Revoke|RevokeLeakBug|Invariant VerdictFnOfLayer1 is violated" \
  "Revoke|RevokeNoConvergeBug|Temporal property RevocationConverges was violated" \
  "Revoke|RevokeUnboundedBug|Invariant BoundHonored is violated" \
  "Revoke|RevokeDeltaBlindBug|Invariant VerdictFnOfLayer1_DeltaBlind is violated" \
  "Emit|EmitFireBug|Invariant EventIffRealWork is violated" \
  "Emit|EmitMarkerBug|Invariant EventTypeCorrect is violated" \
  "Emit|EmitStallBug|Temporal property EmitTerminates was violated" \
  "Register|RegisterAtomicBug|Invariant RegisterAllOrNothing is violated" \
  "Register|RegisterSysGuardBug|Invariant NoUserAtSystem is violated" \
  "Register|RegisterWedgeBug|Temporal property RegisterSettles was violated" \
  "Core|CoreBug|Deadlock reached" \
  "Core|CoreEstabBug|Invariant DispatchNeedsEstablished is violated" \
  "Core|CoreRevokeBug|Invariant NoServeWhenRevoked is violated" \
  "Core|CoreFrameBug|Invariant FramesNotInterleaved is violated" \
  "Authority|AuthorityOptAllowBug|Invariant NoGrantlessAllow is violated" \
  "Authority|AuthorityOptDenyBug|Invariant EntryNotSpuriouslyDenied is violated" \
  "Authority|AuthoritySubGateBug|Invariant ResourceAuthorized is violated" \
  "Authority|AuthorityInheritBug|Invariant NoManufacturedTarget is violated" \
  "Bounds|BoundsEqualBug|Invariant DepthBrakeFirst is violated" \
  "Bounds|BoundsRatioBug|Invariant DepthBrakeFirst is violated" \
  "Bounds|BoundsDoubleCountBug|Invariant TtlNotDoubleCounted is violated" \
  "Bounds|BoundsCodeBug|Invariant ReasonCodesDistinct is violated" \
  "ConnCodes|ConnCodesCollapseBug|Invariant ReasonCodesDistinct is violated" \
  "ConnCodes|ConnCodesStatusBug|Invariant StatusMatchesCode is violated" \
  "ConnCodes|ConnCodesSeqReadingBug|Invariant PreHelloAuthIsInvalidNonce is violated" \
  "ConnCodes|ConnCodesAddressOrderBug|Invariant AddressVerdictPhaseIndependent is violated" \
  "ConnCodes|ConnCodesDropBug|Invariant NoSilentDrop is violated" \
  "ConnCodes|ConnCodesBareCloseBug|Invariant NoBareCloseOnly is violated" \
  "ConnCodes|ConnCodesEcfBug|Invariant FramingIsNotEcf is violated" \
  "Bootstrap|BootstrapEarlyIndexBug|Invariant BootAllOrNothing is violated" \
  "Bootstrap|BootstrapGateBug|Invariant NoRegistrationBeforeBootstrap is violated" \
  "Bootstrap|BootstrapConnectBug|Invariant ConnectPreAuthorized is violated" \
  "Core|CoreRefinesGateBug|Invariant RefinesConnDispatched is violated" \
  "CoreMapFree|CoreMapFreeCarried|Invariant FreeConnDispatched is violated"

# FINDINGS. Rows that MUST be violated, on a model in which NOTHING IS BROKEN: every constant
# is the constant the green sweep runs. A negative control weakens the model on purpose and
# its violation proves a property has teeth. A finding row weakens nothing and its violation
# is a statement about the SPEC — the transcribed algorithm fails a contract the spec itself
# writes.
#
# WHY THIS IS A SEPARATE TABLE AND NOT THREE MORE TLC_NEG ROWS. The grading is identical
# (must fail, must fail for the declared reason), so the mechanical argument is for reuse.
# But TLC_NEG's header says "every row MUST fail — a green here means the property has no
# teeth", and that sentence is FALSE of these rows: a green here would mean the spec defect
# had been FIXED upstream, which is the outcome we want and would need the row retired rather
# than repaired. Two opposite meanings behind one exit code is the D13 shape exactly, and
# TLC_NEG already carries one such exception (CoreMapFreeCarried) explained in a paragraph.
# A second exception is a table.
#
# Retirement condition, stated so nobody has to reconstruct it: when the owning repo amends
# the section, re-vendor, re-run, and if the row goes green DELETE it and move the claim into
# the green sweep. Do not "fix" it.
#
# ── A SECOND SHAPE OF FINDING ROW, ADDED WITH THE QUORUM TRACK 2026-09-07 ────────────────
# The paragraph above says a finding row weakens nothing and runs the green sweep's constants.
# That is true of every attestation row and of QuorumSignerSetRevert / Probe / Normative /
# Fork / QuorumKofNAttainable. It is NOT true of four rows, and the difference is worth a
# sentence rather than a discovery:
#
#   QuorumTrustClosure       WalkClosedOverValidated = FALSE
#   QuorumTrustFailPath      WalkClosedOverValidated = FALSE, RawWrites = FALSE
#   QuorumKofNThreshold      CreateValidates         = FALSE
#   QuorumSignerSetReading   (neither -- it names both readings inside the invariant)
#
# In each case the flipped constant moves the model TOWARD the specification, not away from
# it. The green sweep on this track runs the behaviour the three implementations actually
# have -- probe every candidate, read `not_expired` as full temporal validity, reject
# threshold 0 at create, read only validated entries -- because that is the only setting in
# which anything is green at all. The spec's own setting is what these rows assert against.
#
# So on this track the constants tell you which of two subjects a row is about, and BOTH
# directions of flip appear. A row that reads TOWARD the spec and fails is a finding; a row
# that reads AWAY from the spec and fails is a control (TLC_NEG). The grader cannot tell them
# apart -- it checks "must fail, on this named invariant" and nothing more -- so the
# distinction lives in each cfg's own header, and every cfg on this track states in its first
# line which of the two it is. That is a documented limit of this table, recorded here rather
# than left for someone to infer from the constants.
#
# -- A THIRD SHAPE, ADDED WITH THE IDENTITY TRACK 2026-09-07 -----------------------------------
# Two rows flip a constant toward NEITHER the spec nor a cohort consensus, because on their
# question the spec says nothing at all and the three implementations answer three different
# ways:
#
#   IdentityRecoveryAnchor        SeedValidates = FALSE
#   IdentityRecoveryForgedAnchor  SeedValidates = FALSE
#
# §9.4 calls the contacts cache "the trust anchor" and neither §9.4 nor §6.3 says one word about
# what may become one. entity-core-rust therefore validates nothing on the way in,
# entity-core-py validates via the quorum substrate, and entity-core-go does not seed at all.
# The constant is set to Rust's answer because it is the one that reaches the property; the
# FINDING is the silence that let three authors pick three answers, not Rust's choice.
#
# Read together with the two shapes above, that is the general rule this table has arrived at:
# **a finding row's constants name the subject on trial, and the subject is not always the
# spec's own words -- sometimes it is their absence.** Each cfg's first line says which.
#
# ONE INVARIANT ON THIS TRACK IS THE TARGET OF BOTH A FINDING AND A CONTROL.
# `AcceptedRecoveryIsQuorumSigned` is broken by IdentityRecoveryForgedAnchor (finding: the
# unspecified admission rule) and by IdentityRecoveryFreshBug (control: §QUORUM:3.3's named
# wrong answer, validating against the freshest publish seen rather than the one cached). Two
# independent ways to break one property is a good sign about the property and a bad sign for
# anyone reading the table alone; the cfg headers carry the distinction.
TLC_FINDING := \
  "IdentityProcess|IdentityProcessSeedRow|Invariant SeedRowReachable is violated" \
  "IdentityProcess|IdentityProcessRevocation|Invariant RevocationSurvivesArrival is violated" \
  "IdentityProcess|IdentityProcessQUpdate|Invariant QuorumUpdateSurvivesArrival is violated" \
  "IdentityRecovery|IdentityRecoverySeed|Invariant SeedFollowsArrival is violated" \
  "IdentityRecovery|IdentityRecoveryAttainable|Invariant RecoveryAttainable is violated" \
  "IdentityRecovery|IdentityRecoveryAnchor|Invariant AnchorWasValidated is violated" \
  "IdentityRecovery|IdentityRecoveryForgedAnchor|Invariant AcceptedRecoveryIsQuorumSigned is violated" \
  "IdentityRecovery|IdentityRecoveryReplay|Invariant RecoveryIdempotent is violated" \
  "IdentityCertChain|IdentityCertChainPublicSig|Invariant PublicPathNeverControllerSigned is violated" \
  "IdentityCertChain|IdentityCertChainRevocation|Invariant RevocationReachesTopology is violated" \
  "IdentityCertChain|IdentityCertChainHandoffSigner|Invariant HandoffReadingsCoincide is violated" \
  "IdentityCertChain|IdentityCertChainHandoffNull|Invariant HandoffTargetGuarded is violated" \
  "QuorumSignerSet|QuorumSignerSetProbe|Invariant ResultIndependentOfProbe is violated" \
  "QuorumSignerSet|QuorumSignerSetRevert|Invariant SpecNeverSilentlyReverts is violated" \
  "QuorumSignerSet|QuorumSignerSetReading|Invariant NotExpiredReadingsAgree is violated" \
  "QuorumSignerSet|QuorumSignerSetNormative|Invariant SpecMatchesNormative is violated" \
  "QuorumSignerSet|QuorumSignerSetFork|Invariant CohortMatchesNormative is violated" \
  "QuorumTrust|QuorumTrustClosure|Invariant CacheMatchesValidated is violated" \
  "QuorumTrust|QuorumTrustFailPath|Invariant CacheMatchesValidated is violated" \
  "QuorumKofN|QuorumKofNThreshold|Invariant KofNRequiresASignature is violated" \
  "QuorumKofN|QuorumKofNAttainable|Invariant ThresholdAttainable is violated" \
  "AttestRevoke|AttestRevokeReading|Invariant SelfRevReadingsAgree is violated" \
  "AttestRevoke|AttestRevokeVerdict|Invariant LiveReadingsAgree is violated" \
  "AttestLive|AttestLiveSpecHead|Invariant SpecHeadFindsLiveHead is violated" \
  "AttestLive|AttestLiveBackWalk|Invariant BackWalkBoundedAlways is violated"

.PHONY: tlc-green apalache-green green tlc-witness tlc-neg tlc-finding
# D13 applied to the GREEN sweep, not only to the controls. This target used to grade on
# TLC's EXIT STATUS alone (`|| exit 1`). TLC exits 0 for "no error found" and also for runs
# that checked far less than intended, so exit status is a symptom of success, not the
# assertion of it. Every green row now additionally requires TLC's positive completion line.
TLC_OK := Model checking completed. No error has been found.

# ...and the completion line is NOT sufficient on its own. Asked D13's question of it: what
# else produces "No error has been found"? A cfg that declares NO INVARIANT and NO PROPERTY.
# TLC enumerates the state space, checks nothing, exits 0 and prints exactly that line. So
# each green row must ALSO be shown to assert something: its cfg declares at least one
# INVARIANT or PROPERTY. That is a check on the CONFIG, not on the output, because no output
# distinguishes "verified everything" from "verified nothing" here.
tlc_asserts = grep -qE '^[[:space:]]*(INVARIANT|PROPERTY)' $(1).cfg || { \
	    echo "FAIL: $(1).cfg declares no INVARIANT and no PROPERTY — it checks NOTHING,"; \
	    echo "      and TLC reports that outcome with the same line as a real green run."; \
	    exit 1; }

# Green rows whose CFG name differs from the module name (module|cfg). The scalar TLC_GREEN
# list above assumes cfg == module; these are the N-peer variants, which share one module,
# plus RevokeDeltaZero.
#
# RevokeDeltaZero is a GREEN row that exists to catch a wrong GREEN. §5.10's cross-clock
# clause (W7 Knob 3) ends "`delta = 0` reproduces today's exact behavior", which is an
# equivalence the spec states about any implementation of it — so it can be RUN rather than
# read. Pinning DeltaVals = {0} re-checks the full invariant set against the pre-0.8.3
# boundary; a transcription that got a sign wrong, applied the tolerance to one side of the
# window only, or attached it to the wrong operand still passes Revoke.cfg (which admits
# delta = 1 and therefore EXPECTS a wider window) and fails here. D13 applied to a green
# row: "the invariants hold" is satisfied by a model with the wrong window.
#
# THE CoreMapFreeMfg* ROWS ARE GREEN ROWS WHOSE GREEN IS THE FINDING, NOT THE SUCCESS.
# They are T4's classifier (tla/CoreMapFree.tla): each asserts a component invariant, under
# the Core->component refinement mapping, over EVERY type-correct valuation rather than the
# reachable ones. Holding there means the invariant is a tautology of the MAPPING and says
# nothing about Core — "MANUFACTURED". A violation would be the interesting outcome and
# would move the row to CARRIED (which is CoreMapFreeCarried, in TLC_NEG for that reason).
# So these six sit in the green sweep while asserting that six component properties are NOT
# carried by the composed model. Anyone reading the gate table should read them that way
# round; each cfg says so in its own header.
TLC_GREEN_PAIRS := \
  "Reentry|Reentry3" \
  "Core|Core3" \
  "Revoke|RevokeDeltaZero" \
  "Core|CoreRefines" \
  "CoreMapFree|CoreMapFreeMfgConnTokens" \
  "CoreMapFree|CoreMapFreeMfgConnNonce" \
  "CoreMapFree|CoreMapFreeMfgStoreRace" \
  "CoreMapFree|CoreMapFreeMfgStoreUAF" \
  "CoreMapFree|CoreMapFreeMfgStoreBounded" \
  "CoreMapFree|CoreMapFreeMfgStoreReject"

tlc-green:
	@for s in $(TLC_GREEN); do \
	  echo "== TLC $$s (MUST report: $(TLC_OK)) =="; \
	  $(call tlc_asserts,$$s); \
	  out=$$($(RUN) tlc2.TLC -workers $(WORKERS) -config $$s.cfg $$s.tla 2>&1) || { \
	    echo "$$out" | grep -E '^Error:' | head -5; exit 1; }; \
	  echo "$$out" | grep -qF "$(TLC_OK)" || { \
	    echo "FAIL: $$s exited 0 but never reported completion — it did not verify what it claims."; \
	    echo "$$out" | tail -5; exit 1; }; \
	  echo "   ok (No error has been found)"; \
	done
	@for row in $(TLC_GREEN_PAIRS); do \
	  mod=$$(echo "$$row" | cut -d'|' -f1); cfg=$$(echo "$$row" | cut -d'|' -f2); \
	  echo "== TLC $$mod/$$cfg (MUST report: $(TLC_OK)) =="; \
	  $(call tlc_asserts,$$cfg); \
	  out=$$($(RUN) tlc2.TLC -workers $(WORKERS) -config $$cfg.cfg $$mod.tla 2>&1) || { \
	    echo "$$out" | grep -E '^Error:' | head -5; exit 1; }; \
	  echo "$$out" | grep -qF "$(TLC_OK)" || { \
	    echo "FAIL: $$cfg exited 0 but never reported completion."; \
	    echo "$$out" | tail -5; exit 1; }; \
	  echo "   ok (No error has been found)"; \
	done
	@echo "== TLC Store (liveness slice, StoreLive.cfg) =="
	@$(call tlc_asserts,StoreLive); \
	  out=$$($(RUN) tlc2.TLC -workers $(WORKERS) -config StoreLive.cfg Store.tla 2>&1) || { \
	  echo "$$out" | grep -E '^Error:' | head -5; exit 1; }; \
	  echo "$$out" | grep -qF "$(TLC_OK)" || { \
	    echo "FAIL: StoreLive exited 0 but never reported completion."; exit 1; }; \
	  echo "   ok (No error has been found)"

# Each witness MUST be violated, AND MUST BE VIOLATED FOR THE DECLARED REASON. Both halves
# matter: a clean run means the witnessed state became unreachable (the model went inert); a
# non-zero exit for any OTHER reason means the witness never ran at all.
tlc-witness:
	@for row in $(TLC_WITNESS); do \
	  mod=$$(echo "$$row" | cut -d'|' -f1); cfg=$$(echo "$$row" | cut -d'|' -f2); \
	  want=$$(echo "$$row" | cut -d'|' -f3); \
	  echo "== TLC witness $$mod/$$cfg (MUST be violated: $$want) =="; \
	  out=$$($(RUN) tlc2.TLC -workers $(WORKERS) -config $$cfg.cfg $$mod.tla 2>&1); rc=$$?; \
	  if [ $$rc -eq 0 ]; then \
	    echo "FAIL: $$cfg reported NO violation — the witnessed state is unreachable, so"; \
	    echo "      $$mod's green results may be vacuous. This is a real regression."; \
	    exit 1; \
	  fi; \
	  if ! echo "$$out" | grep -qF "$$want"; then \
	    echo "FAIL: $$cfg failed, but NOT by exhibiting the witnessed state."; \
	    echo "      expected: $$want"; \
	    echo "      got:      $$(echo "$$out" | grep -E '^Error:' | head -3 | tr '\n' ' ')"; \
	    echo "      TLC exits non-zero for a bad config exactly as for a violation; without"; \
	    echo "      this check a witness naming a nonexistent operator scores as a pass."; \
	    exit 1; \
	  fi; \
	  echo "   ok (violated as required: $$want)"; \
	done

# Each negative control MUST fail. Inverted exit status: a clean run is the failure.
tlc-neg:
	@for row in $(TLC_NEG); do \
	  mod=$$(echo "$$row" | cut -d'|' -f1); cfg=$$(echo "$$row" | cut -d'|' -f2); \
	  want=$$(echo "$$row" | cut -d'|' -f3); \
	  echo "== TLC neg control $$mod/$$cfg (MUST fail: $$want) =="; \
	  out=$$($(RUN) tlc2.TLC -workers $(WORKERS) -config $$cfg.cfg $$mod.tla 2>&1); rc=$$?; \
	  if [ $$rc -eq 0 ]; then \
	    echo "FAIL: $$cfg reported GREEN — the property it targets has no teeth."; \
	    exit 1; \
	  fi; \
	  if ! echo "$$out" | grep -qF "$$want"; then \
	    echo "FAIL: $$cfg failed, but NOT for the reason it exists to demonstrate."; \
	    echo "      expected: $$want"; \
	    echo "      got:      $$(echo "$$out" | grep -E '^Error:' | head -3 | tr '\n' ' ')"; \
	    echo "      A control that fails for the wrong reason is not evidence of teeth."; \
	    exit 1; \
	  fi; \
	  echo "   ok (failed as required: $$want)"; \
	done

# Each finding row MUST be violated, and for the declared reason. Graded exactly like a
# control and meaning the opposite: see TLC_FINDING's header. A clean run here is not a
# regression in the model — it is a signal that the upstream section changed under the pin,
# which cannot happen without a re-vendor, so in practice it means the row is stale.
tlc-finding:
	@for row in $(TLC_FINDING); do \
	  mod=$$(echo "$$row" | cut -d'|' -f1); cfg=$$(echo "$$row" | cut -d'|' -f2); \
	  want=$$(echo "$$row" | cut -d'|' -f3); \
	  echo "== TLC finding $$mod/$$cfg (MUST be violated: $$want) =="; \
	  out=$$($(RUN) tlc2.TLC -workers $(WORKERS) -config $$cfg.cfg $$mod.tla 2>&1); rc=$$?; \
	  if [ $$rc -eq 0 ]; then \
	    echo "FAIL: $$cfg reported GREEN. This row asserts a defect in the SPEC as pinned;"; \
	    echo "      a green means the pinned text no longer has it. Re-read the section,"; \
	    echo "      then RETIRE the row and move the claim into the green sweep. Do not"; \
	    echo "      repair the model to make it fail again."; \
	    exit 1; \
	  fi; \
	  if ! echo "$$out" | grep -qF "$$want"; then \
	    echo "FAIL: $$cfg failed, but NOT on the invariant that states the finding."; \
	    echo "      expected: $$want"; \
	    echo "      got:      $$(echo "$$out" | grep -E '^Error:' | head -3 | tr '\n' ' ')"; \
	    exit 1; \
	  fi; \
	  echo "   ok (violated as required: $$want)"; \
	done

# Apalache: prove each module's key safety invariant INDUCTIVE (unbounded) —
# base case (Init => Inv, length 0) and inductive step (IndInit /\ Next => Inv',
# length 1). Operator names are in each *Apalache.tla
# header. Format per line: MODULE CINIT INV INDINIT
# 23 invariants across 11 modules (was 8 across 5 at v0.8.0; 18 across 9 before the second
# gate audit added ConnCodesApalache and BootstrapApalache). Added at 0.8.2: StoreApalache
# InvUAF (§4.8 RT-13a refcount use-after-free), and three modules that previously had TLC
# coverage ONLY — ReentryApalache (§6.11(a') frame-write atomicity), AuthorityApalache (all
# four §5.2 rules) and BoundsApalache (§5.9 / §4.10(b)). Single-tool coverage was a hole the
# audit found, not a scope decision.
#
# THE FOURTEEN IdentityRecoveryApalache ROWS ARE THE SAME REMEDY ON THE LAST EXTENSION SUBJECT
# THAT NEEDED IT (2026-09-09, D16, docs/CORROBORATION.md). Read them in three groups, because
# they assert three different things and the table cannot show that:
#   ConstInitOK (6)          — CORROBORATION. Identical constants to tla/IdentityRecovery.cfg
#                              with rotations OFF, which is that model's domain exactly. Same
#                              claims, decided by SMT over runs of ANY length rather than
#                              bounded-exhaustively — and `RecoveryIdempotent` therefore now
#                              covers UNBOUNDED replay where `MaxDeliveries == 2` covered two.
#   ConstInitRotations (5)   — THE MEASUREMENT, and the reason the group exists (O20's shape).
#                              With §4.3 handle rotation admitted — nothing weakened, a
#                              normative kind of the pinned spec — these five still hold. That
#                              is what makes finding N1 "the lift costs AVAILABILITY, not
#                              AUTHENTICITY" rather than "removing an assumption broke
#                              something", which is not a measurement. Deleting them as
#                              redundant with the ConstInitOK rows would delete the result.
#   ConstInitRekeyRetain +
#   ConstInitHandoffRekey (3) — THE REMEDIES, CHECKED. Each names a fix for a finding below and
#                              is green under it. A remedy this repo proposed without measuring
#                              is exactly what came back corrected once already
#                              (docs/PROPERTIES.md §D.1), so they are rows and not prose.
#
# THE ELEVEN IdentityProcessApalache ROWS CLOSE THE LAST SINGLE-ENGINE SUBJECT ON THE IDENTITY
# TRACK (2026-09-09, D16, docs/CORROBORATION.md), and read them in two groups:
#   ConstInitOK (9)          — CORROBORATION. Every claim tla/IdentityProcess.tla makes, on that
#                              model's own constants, now decided over runs of ANY LENGTH rather
#                              than over the ONE ARRIVAL its three variables can represent
#                              (docs/LEAN-SEAM.md O22). `RevokedCertNeverAdmitted` is in this
#                              group and is NOT a ported claim: it is finding N3's GREEN half,
#                              and it is what makes N3 a measurement of which repair closes it
#                              rather than "a lifted restriction broke something" (the O20
#                              lesson). Two ported operators needed their ANTECEDENT widened —
#                              see `UnbindOnlyOnRejection` and `SeedRowReachable` in the module,
#                              which say why and what the single-arrival domain hid.
#   ConstInitIssueChecksRetire +
#   ConstInitRetireKillsLive (2) — THE REMEDIES, CHECKED. §6.3's dispatch table names seven
#                              handlers and defines none of them, so N4's two candidate fixes are
#                              both statements about text that does not exist. Each is green
#                              under its own cinit, for the reason the block above gives.
#
# THE NINE QuorumTrustApalache ROWS CLOSE THE LAST SINGLE-ENGINE SUBJECT ANYWHERE ON THE EXTENSION
# TRACKS (2026-09-09, D16, docs/CORROBORATION.md). Two groups, and the split is by CINIT:
#   ConstInitTLCDomain (4)   — CORROBORATION, and it is a real cinit rather than a synonym for
#                              ConstInitOK: it switches OFF the three lifts (revocations,
#                              re-arrival, raw unbind) so the model's domain is
#                              tla/QuorumTrust.tla's exactly. Every claim that model makes
#                              reproduces, now over runs of ANY length.
#   ConstInitOK (5)          — THE SAME CLAIMS WITH THE LIFTS ON, and the fifth row is new.
#                              `RevokeLeavesNoStaleEntry` is §4.2.1 TRIGGER 3's own obligation and
#                              had no row on this subject before, because the TLC module has no
#                              revocation action. `CacheMatchesValidated` green HERE is the
#                              measurement that matters: the §4.2.1 contract is exactly sufficient
#                              over ALL THREE triggers, where the claim it corrects was over two.
#                              See `OnlyAcceptInvalidates` in APALACHE_NEG for the falsification
#                              of the two-trigger form, which was green for two days.
APALACHE_GREEN := \
  "RevokeApalache ConstInitOK InvDet IndInitDet" \
  "RevokeApalache ConstInitOK InvRev IndInitRev" \
  "StoreApalache  ConstInitOK InvRace IndInitRace" \
  "StoreApalache  ConstInitOK InvBound IndInitBound" \
  "StoreApalache  ConstInitOK InvUAF IndInitUAF" \
  "ConnApalache   ConstInitOK Inv IndInit" \
  "EmitApalache   ConstInitOK InvIff IndInitIff" \
  "EmitApalache   ConstInitOK InvType IndInitType" \
  "RegisterApalache ConstInitOK Inv IndInit" \
  "RegisterApalache ConstInitOK InvAoN IndInitAoN" \
  "ReentryApalache ConstInitOK InvFrame IndInitFrame" \
  "ReentryApalache ConstInitOK3 InvFrame IndInitFrame" \
  "AuthorityApalache ConstInitOK InvGrantless IndInitGrantless" \
  "AuthorityApalache ConstInitOK InvEntry IndInitEntry" \
  "AuthorityApalache ConstInitOK InvResource IndInitResource" \
  "AuthorityApalache ConstInitOK InvTarget IndInitTarget" \
  "BoundsApalache ConstInitOK InvBrake IndInitBrake" \
  "BoundsApalache ConstInitOK InvCount IndInitCount" \
  "BoundsApalache ConstInitOK InvCodes IndInitCodes" \
  "CoreApalache ConstInitOK InvComposed IndInitComposed" \
  "CoreApalache ConstInitOK3 InvComposed IndInitComposed" \
  "ConnCodesApalache ConstInitOK ReasonCodesDistinct IndInit" \
  "ConnCodesApalache ConstInitOK StatusMatchesCode IndInit" \
  "ConnCodesApalache ConstInitOK StateConflictsAre409 IndInit" \
  "ConnCodesApalache ConstInitOK AddressVerdictPhaseIndependent IndInit" \
  "ConnCodesApalache ConstInitOK PreHelloAuthIsInvalidNonce IndInit" \
  "ConnCodesApalache ConstInitOK PreAdmissionRefusalIsCoded IndInit" \
  "ConnCodesApalache ConstInitOK RefusalCodeMatchesCause IndInit" \
  "ConnCodesApalache ConstInitOK FramingIsNotEcf IndInit" \
  "BootstrapApalache ConstInitOK InvAllOrNothing IndInitAllOrNothing" \
  "BootstrapApalache ConstInitOK InvRegGate IndInitRegGate" \
  "BootstrapApalache ConstInitOK InvConnect IndInitConnect" \
  "AttestIndexApalache ConstInitOK Inv IndInitIx" \
  "IdentityRecoveryApalache ConstInitOK RecoveryFailClosed IndInitRec" \
  "IdentityRecoveryApalache ConstInitOK AcceptedRecoveryIsQuorumSigned IndInitRec" \
  "IdentityRecoveryApalache ConstInitOK RecoveryIdempotent IndInitRec" \
  "IdentityRecoveryApalache ConstInitOK AnchorWasValidated IndInitRec" \
  "IdentityRecoveryApalache ConstInitOK RecoveryAttainable IndInitRec" \
  "IdentityRecoveryApalache ConstInitOK SeedFollowsArrival IndInitRec" \
  "IdentityRecoveryApalache ConstInitRotations RecoveryFailClosed IndInitRec" \
  "IdentityRecoveryApalache ConstInitRotations AcceptedRecoveryIsQuorumSigned IndInitRec" \
  "IdentityRecoveryApalache ConstInitRotations RecoveryAttainable IndInitRec" \
  "IdentityRecoveryApalache ConstInitRotations SeedFollowsArrival IndInitRec" \
  "IdentityRecoveryApalache ConstInitRotations RecoveryIdempotent IndInitRec" \
  "IdentityRecoveryApalache ConstInitRekeyRetain RecoveryIdempotent IndInitRec" \
  "IdentityRecoveryApalache ConstInitHandoffRekey AnchorSurvivesHandoff IndInitHandoff" \
  "IdentityRecoveryApalache ConstInitHandoffRekey HandoffKeepsRecoveryAvailable IndInitHandoff" \
  "IdentityProcessApalache ConstInitOK LocalCreateNeverUnbinds IndInitP" \
  "IdentityProcessApalache ConstInitOK UnbindOnlyOnRejection IndInitP" \
  "IdentityProcessApalache ConstInitOK FailureIsObservable IndInitP" \
  "IdentityProcessApalache ConstInitOK NoSuccessEvents IndInitP" \
  "IdentityProcessApalache ConstInitOK ForeignKindNotDispatched IndInitP" \
  "IdentityProcessApalache ConstInitOK SeedRowReachable IndInitP" \
  "IdentityProcessApalache ConstInitOK RevocationSurvivesArrival IndInitP" \
  "IdentityProcessApalache ConstInitOK QuorumUpdateSurvivesArrival IndInitP" \
  "IdentityProcessApalache ConstInitOK RevokedCertNeverAdmitted IndInitP" \
  "IdentityProcessApalache ConstInitIssueChecksRetire RetirementIsDurable IndInitRetire" \
  "IdentityProcessApalache ConstInitRetireKillsLive RetirementIsDurable IndInitRetire" \
  "QuorumTrustApalache ConstInitOK CacheMatchesValidated IndInitCache" \
  "QuorumTrustApalache ConstInitOK NoInvalidationWithoutTrigger IndInitRules" \
  "QuorumTrustApalache ConstInitOK InvalidationScopedPerQuorum IndInitRules" \
  "QuorumTrustApalache ConstInitOK AcceptLeavesNoStaleEntry IndInitRules" \
  "QuorumTrustApalache ConstInitOK RevokeLeavesNoStaleEntry IndInitRules" \
  "QuorumTrustApalache ConstInitTLCDomain CacheMatchesValidated IndInitCache" \
  "QuorumTrustApalache ConstInitTLCDomain NoInvalidationWithoutTrigger IndInitRules" \
  "QuorumTrustApalache ConstInitTLCDomain InvalidationScopedPerQuorum IndInitRules" \
  "QuorumTrustApalache ConstInitTLCDomain AcceptLeavesNoStaleEntry IndInitRules"

# THE STRENGTHENING MUST PRESERVE ITSELF, AND UNTIL 2026-09-08 NOTHING CHECKED THAT.
#
# `apalache-green` checks two things per row: Init => Inv, and IndInit /\ Next => Inv'. Where
# IndInit is just Inv (ConnCodes, Bootstrap) those two ARE the inductive proof. Where IndInit
# is `TypeOK /\ <strengthening> /\ Inv` — 20 of the 27 rows AS THE TABLE STOOD ON 2026-09-08 —
# they are not. Preservation
# of Inv FROM strengthened states says nothing unless the strengthening is itself preserved,
# and `docs/PROPERTIES.md` names the strengthenings ("RefcountSound", "DecisionSound") without
# ever asserting that closure. The published claim was "proved INDUCTIVE"; what was checked was
# weaker.
#
# Asked D13's question of our own gate — what does this assert, and what else satisfies it? —
# and then answered it by RUNNING it rather than reasoning: every row was measured, and
# all 27 CLOSED. Nothing was wrong. The claim was under-asserted, which is the cheaper half of
# D13 and the half that goes unnoticed, because the result of checking is that nothing changes.
#
# BOTH FIGURES IN THE TWO PARAGRAPHS ABOVE ARE DATED ON PURPOSE, AND THE DATE WAS ADDED BECAUSE
# THEY HAD ALREADY GONE STALE. `APALACHE_GREEN` was 27 rows when this header was written; the
# fourteen IdentityRecoveryApalache rows landed on 2026-09-09 and nothing here moved, so for one
# day this block described a table 14 rows smaller than the one beneath it. That is D15's
# mechanism inside a D13 gate's own documentation — a number about our own past that reads as a
# live claim about the table below it, which is the exact shape `tools/runcount.py` refuses to
# gate and says so. The live invariant is not a count and does not go stale: EVERY ROW OF
# `APALACHE_GREEN` WHOSE `IndInit` IS NOT ITS `Inv` MUST HAVE A ROW HERE. Adding a green row with
# a named strengthening and no closure row re-opens exactly the gap this target was built to
# close, and no tool checks that — it is a reading, which is why it is stated as a rule rather
# than as a figure.
#
# Format: MODULE CINIT IND. Each row checks IND /\ Next => IND', i.e. the strengthening is
# preserved. Together with the base and step rows above, THIS is the inductive proof.
APALACHE_CLOSURE := \
  "RevokeApalache ConstInitOK IndInitDet" \
  "RevokeApalache ConstInitOK IndInitRev" \
  "StoreApalache ConstInitOK IndInitRace" \
  "StoreApalache ConstInitOK IndInitBound" \
  "StoreApalache ConstInitOK IndInitUAF" \
  "ConnApalache ConstInitOK IndInit" \
  "EmitApalache ConstInitOK IndInitIff" \
  "EmitApalache ConstInitOK IndInitType" \
  "RegisterApalache ConstInitOK IndInit" \
  "RegisterApalache ConstInitOK IndInitAoN" \
  "ReentryApalache ConstInitOK IndInitFrame" \
  "ReentryApalache ConstInitOK3 IndInitFrame" \
  "AuthorityApalache ConstInitOK IndInitGrantless" \
  "AuthorityApalache ConstInitOK IndInitEntry" \
  "AuthorityApalache ConstInitOK IndInitResource" \
  "AuthorityApalache ConstInitOK IndInitTarget" \
  "BoundsApalache ConstInitOK IndInitBrake" \
  "BoundsApalache ConstInitOK IndInitCount" \
  "BoundsApalache ConstInitOK IndInitCodes" \
  "CoreApalache ConstInitOK IndInitComposed" \
  "CoreApalache ConstInitOK3 IndInitComposed" \
  "ConnCodesApalache ConstInitOK IndInit" \
  "BootstrapApalache ConstInitOK IndInitAllOrNothing" \
  "BootstrapApalache ConstInitOK IndInitRegGate" \
  "BootstrapApalache ConstInitOK IndInitConnect" \
  "AttestIndexApalache ConstInitOK IndInitIx" \
  "IdentityRecoveryApalache ConstInitOK IndInitRec" \
  "IdentityRecoveryApalache ConstInitRotations IndInitRec" \
  "IdentityRecoveryApalache ConstInitRekeyRetain IndInitRec" \
  "IdentityRecoveryApalache ConstInitHandoffRekey IndInitHandoff" \
  "IdentityProcessApalache ConstInitOK IndInitP" \
  "IdentityProcessApalache ConstInitIssueChecksRetire IndInitRetire" \
  "IdentityProcessApalache ConstInitRetireKillsLive IndInitRetire" \
  "QuorumTrustApalache ConstInitOK IndInitCache" \
  "QuorumTrustApalache ConstInitOK IndInitRules" \
  "QuorumTrustApalache ConstInitTLCDomain IndInitCache" \
  "QuorumTrustApalache ConstInitTLCDomain IndInitRules"

# ----------------------------------------------------------------------------------
# EXTENSION-TRACK ENUMERATION MODELS — a second engine for models with no transitions.
#
# AttestLiveApalache is not a transition system: `Next` is `UNCHANGED vars` and the state space
# IS the graph space, so every claim is settled at --length=0 and the base/inductive-step shape
# above does not apply. Hence a separate table rather than a flag on the existing one: two
# meanings behind one table is the failure `TLC_FINDING` was split out to avoid (D13, sixth
# instance).
#
# Format: MODULE CINIT INV. Every row MUST report OK.
#
# AttestRevokeApalache's first five rows are the ENCODING'S OWN OBLIGATIONS, not results about
# §4.3, and they are in the green table because every other row in this module is false without
# them. Apalache has no `RECURSIVE`, so §4.3's four mutually recursive operators are built as a
# ladder of state variables (see that module's header for why the nested-operator form OOMs).
# That trades one obligation for two: a ladder must justify its DEPTH, and the equation it
# solves must have EXACTLY ONE SOLUTION.
#   UnrollDeep                — the reachability ladder saturated (R3 = R4)
#   LadderIsFixedPointRec     — the liveness ladder's top satisfies §4.3's equation, which is
#   LadderIsFixedPointStruct    simultaneously "deep enough" and "a solution exists"
#   FixedPointUnique{Rec,Struct} — ...and it is the only one, so the ladder's answer is THE
#                               answer rather than one the solver was free to pick
# Neither failure would produce an error message, which is the D13 reason they are rows.
#
# THE TENTH ROW IS THE OTHER HALF OF AN ASYMMETRY AND ITS GREEN IS PART OF A FINDING.
# `AttestRevokeApalache ConstInitSupUnordered FixedPointUniqueStruct` holds where its `Rec`
# sibling (in APALACHE_ENUM_FINDING) does not: with the supersedes order lifted, §4.3's liveness
# is still well defined under the STRUCTURAL reading of `is_self_revoked` and is NOT well
# defined under the recursive one. The undefined helper does not merely change the answer — one
# reading has an answer and the other does not. Read this row with F5, not as a result.
#
# THE FIVE `QuorumSignerSetApalache ConstInitSupUnordered` GREENS ARE THE SAME KIND OF ROW
# (2026-09-08, LEAN-SEAM O20). With §QUORUM:4.2's hard-coded index order LIFTED, four of the
# resolver's five checked properties still hold and one does not (`CohortNeverSilentlyReverts`,
# in APALACHE_ENUM_FINDING). Those greens are what make this a MEASUREMENT of the assumption
# rather than a demonstration that weakening a model breaks something, and
# `CohortNeverSilentlyRevertsWhenAcyclic` is the row that says which weaker property was
# actually load-bearing: acyclicity, not the index order. Deleting them as redundant would
# delete the result.
APALACHE_ENUM_GREEN := \
  "AttestLiveApalache ConstInitOK UnrollDeep" \
  "AttestLiveApalache ConstInitOK MaxOfExact" \
  "AttestLiveApalache ConstInitOK NoLiveAncestorOfLive" \
  "AttestLiveApalache ConstInitOK DagHeadIsLive" \
  "AttestLiveApalache ConstInitOK DagHeadFindsLiveHead" \
  "AttestLiveApalache ConstInitOK HeadResolutionIsIdentity" \
  "AttestLiveApalache ConstInitOK SpecWalkNeverExhausts" \
  "AttestLiveApalache ConstInitOK BackWalkBoundedWhenAcyclic" \
  "AttestRevokeApalache ConstInitOK UnrollDeep" \
  "AttestRevokeApalache ConstInitOK LadderIsFixedPointRec" \
  "AttestRevokeApalache ConstInitOK LadderIsFixedPointStruct" \
  "AttestRevokeApalache ConstInitOK FixedPointUniqueRec" \
  "AttestRevokeApalache ConstInitOK FixedPointUniqueStruct" \
  "AttestRevokeApalache ConstInitOK OnlySelfRevocationKills" \
  "AttestRevokeApalache ConstInitOK DeadRevocationSpares" \
  "AttestRevokeApalache ConstInitOK DescReadingsCoincide" \
  "AttestRevokeApalache ConstInitOK NoLiveAncestorOfLive" \
  "AttestRevokeApalache ConstInitSupUnordered FixedPointUniqueStruct" \
  "QuorumSignerSetApalache ConstInitOK UnrollDeep" \
  "QuorumSignerSetApalache ConstInitOK MostRecentExact" \
  "QuorumSignerSetApalache ConstInitOK LeastExact" \
  "QuorumSignerSetApalache ConstInitOK SpecWalkNeverExhausts" \
  "QuorumSignerSetApalache ConstInitOK CohortMatchesNormativeOnChain" \
  "QuorumSignerSetApalache ConstInitOK CohortNeverSilentlyReverts" \
  "QuorumSignerSetApalache ConstInitOK ResolvedHeadIsCurrent" \
  "QuorumSignerSetApalache ConstInitSupUnordered UnrollDeep" \
  "QuorumSignerSetApalache ConstInitSupUnordered SpecWalkNeverExhausts" \
  "QuorumSignerSetApalache ConstInitSupUnordered ResolvedHeadIsCurrent" \
  "QuorumSignerSetApalache ConstInitSupUnordered CohortMatchesNormativeOnChain" \
  "QuorumSignerSetApalache ConstInitSupUnordered CohortNeverSilentlyRevertsWhenAcyclic" \
  "QuorumKofNApalache ConstInitOK CountAgreesWithCardinality" \
  "QuorumKofNApalache ConstInitOK KofNRequiresASignature" \
  "QuorumKofNApalache ConstInitOK DedupeCountsPeersOnce" \
  "QuorumKofNApalache ConstInitOK UnresolvableNeverCounts" \
  "IdentityCertChainApalache ConstInitOK PublicPathNeverControllerSigned" \
  "IdentityCertChainApalache ConstInitOK RevocationReachesTopology" \
  "IdentityCertChainApalache ConstInitOK HandoffReadingsCoincide" \
  "IdentityCertChainApalache ConstInitOK HandoffTargetGuarded" \
  "IdentityCertChainApalache ConstInitOK TopLevelControllerIsKofN" \
  "IdentityCertChainApalache ConstInitOK SubControllerIsSingle" \
  "IdentityCertChainApalache ConstInitOK HandoffIsDual" \
  "IdentityCertChainApalache ConstInitOK LifecycleIsQuorumDriven" \
  "IdentityCertChainApalache ConstInitOK KofNAnswerIsTrustworthy"

# Enumeration-model rows that MUST produce a counterexample. Three kinds share this table and
# the cfg-less rows make the kind invisible, so each is named here:
#   NEGATIVE CONTROLS   — a deliberately weakened model. BugDirect (pre-ratification §4.3),
#                         BugDagFilter (the forward enumeration without its liveness filter).
#   NON-VACUITY WITNESSES — asserted in order to be violated; the violation IS the pass.
#                         WitnessThreeChain, WitnessDagHeadMoves, and AttestRevokeApalache's
#                         three. The last three carry an EXTRA job their TLC twins do not:
#                         that module's `Init` constrains six ladder variables by equations, and
#                         an over-constrained `Init` admits no state at all, in which case every
#                         green in the file holds VACUOUSLY and Apalache reports OK. A violated
#                         witness is the proof that `Init` is satisfiable.
#   MEASUREMENTS        — BackWalkBoundedAlways exhibits a graph on which §5.2 as written does
#                         not terminate; ConstInitLadderShort proves each module's own unrolling
#                         bound fails LOUDLY one node past it instead of silently truncating
#                         (AttestLive: N = 4 vs its N = 3; AttestRevoke: N = 5 vs its N = 4, on
#                         BOTH of its ladders — reachability and liveness;
#                         QuorumSignerSet: N = 4 vs its N = 3).
#
# ONE WITNESS IS A ROW ON ONE CINIT AND A GREEN ON THE OTHER, WHICH IS NOT A CONTRADICTION.
# `QuorumSignerSetApalache ConstInitSupUnordered WitnessSupCycle` must be violated (a supersedes
# cycle is constructible once the index order is lifted); the same operator under `ConstInitOK`
# HOLDS, and holding is correct there because the order forbids cycles. The pair is the check
# that the two cinits differ in the dimension O20 says they differ in, so it is deliberately NOT
# listed under ConstInitOK here — a witness row means "must be violated", and this one must not.
# Format: MODULE CINIT INV.
APALACHE_ENUM_NEG := \
  "AttestLiveApalache ConstInitBugDirect NoLiveAncestorOfLive" \
  "AttestLiveApalache ConstInitBugDagFilter DagHeadIsLive" \
  "AttestLiveApalache ConstInitOK WitnessThreeChain" \
  "AttestLiveApalache ConstInitOK WitnessDagHeadMoves" \
  "AttestLiveApalache ConstInitOK BackWalkBoundedAlways" \
  "AttestLiveApalache ConstInitLadderShort UnrollDeep" \
  "AttestRevokeApalache ConstInitBugAuthority OnlySelfRevocationKills" \
  "AttestRevokeApalache ConstInitBugFlat DeadRevocationSpares" \
  "AttestRevokeApalache ConstInitOK WitnessRevokedRevocation" \
  "AttestRevokeApalache ConstInitOK WitnessRevocationKills" \
  "AttestRevokeApalache ConstInitOK WitnessSupersededByLive" \
  "AttestRevokeApalache ConstInitLadderShort UnrollDeep" \
  "AttestRevokeApalache ConstInitLadderShort LadderIsFixedPointRec" \
  "QuorumSignerSetApalache ConstInitBugProbe CohortMatchesNormativeOnChain" \
  "QuorumSignerSetApalache ConstInitBugLiteral CohortNeverSilentlyReverts" \
  "QuorumSignerSetApalache ConstInitOK WitnessThreeChain" \
  "QuorumSignerSetApalache ConstInitOK WitnessPendingUpdate" \
  "QuorumSignerSetApalache ConstInitOK WitnessSilentRevert" \
  "QuorumSignerSetApalache ConstInitSupUnordered WitnessSupCycle" \
  "QuorumSignerSetApalache ConstInitLadderShort UnrollDeep" \
  "QuorumKofNApalache ConstInitBugDedupe DedupeCountsPeersOnce" \
  "QuorumKofNApalache ConstInitBugResolve UnresolvableNeverCounts" \
  "QuorumKofNApalache ConstInitOK WitnessKofNPasses" \
  "QuorumKofNApalache ConstInitOK WitnessResolutionCollapses" \
  "QuorumKofNApalache ConstInitOK WitnessUnresolvableSigner" \
  "IdentityCertChainApalache ConstInitBugUpfront TopLevelControllerIsKofN" \
  "IdentityCertChainApalache ConstInitBugDual HandoffIsDual" \
  "IdentityCertChainApalache ConstInitBugSubstrate KofNAnswerIsTrustworthy" \
  "IdentityCertChainApalache ConstInitWitnessPublic WitnessPublicAgentCert" \
  "IdentityCertChainApalache ConstInitOK WitnessKofNDispatched" \
  "IdentityCertChainApalache ConstInitOK WitnessDualDispatched"

# THE FINDING ROWS — same two-meanings problem `TLC_FINDING` exists for, one engine over.
# Each row must be VIOLATED. A green here does NOT mean the model regressed — it means the
# section was amended upstream and the row must be RETIRED, with the claim moved into
# APALACHE_ENUM_GREEN. Do not repair the model to make it fail again.
#
# TWO OF `TLC_FINDING`'s THREE SHAPES APPEAR HERE, and the second one arrived 2026-09-08.
#   Shape 1 — NOTHING IS WEAKENED, the constants are the green sweep's. `ConstInitFinding` is
#     `ConstInitOK` verbatim: AttestLive's F1 row, and AttestRevoke's two F4 rows.
#   Shape 2 — THE CONSTANT FLIPS *TOWARD* THE SPEC. `ConstInitSupUnordered` and
#     `ConstInitRevUnordered` LIFT the index-ordering restriction that `AttestRevoke.tla`
#     hard-codes. That looks like weakening the model and is the opposite: the spec states no
#     ordering assumption anywhere, so removing it moves the model toward the pinned text and
#     the restriction was ours. Same shape as the quorum track's four rows; see TLC_FINDING's
#     header, which is the canonical statement of it.
#
# THE FIVE F5 ROWS ARE ONE FINDING AND MUST BE READ AS A SET, WITH ONE GREEN.
#   SupUnordered / LadderIsFixedPointRec + FixedPointUniqueRec — §4.3's equation has no
#     solution, or several, on a configuration where BOTH GRAPHS ARE ACYCLIC. The dependency
#     cycle runs supersedes-reach then revoked-by, and §4.3's only stated cycle defence (the
#     `visited` set inside has_live_transitive_descendant) is scoped to one of the two hops.
#   RevUnordered / the same two, plus FixedPointUniqueStruct — the revocation side, where even
#     the structural reading breaks.
#   SupUnordered / FixedPointUniqueStruct is GREEN and is in APALACHE_ENUM_GREEN: the structural
#     reading survives the composed cycle. That asymmetry is the finding's sharpest edge and it
#     is why the green row is listed there with a pointer back here.
# Retiring these needs §4.3 to state the assumption, not merely to define the helpers.
#
# THE TWO `QuorumSignerSetApalache ConstInitSupUnordered` ROWS ARE SHAPE 2 ON THE QUORUM TRACK
# (2026-09-08, LEAN-SEAM O20), and the SECOND of them exists because the FIRST one's
# counterexample was not the one worth routing. `CohortNeverSilentlyReverts` returns
# `sup = <<1, 1, 2>>` — an attestation that supersedes ITSELF — which is a true instance and an
# easy thing for a reader to dismiss. `CohortNeverSilentlyRevertsNoSelfLoop` forbids the
# self-loop and is violated on a genuine two-node cycle, so the routed mechanism is the one the
# counterexample exhibits. Both rows are kept: the pair is the statement that the defect is not
# an artifact of the degenerate case.
# Format: MODULE CINIT INV.
APALACHE_ENUM_FINDING := \
  "AttestLiveApalache ConstInitFinding SpecHeadFindsLiveHead" \
  "AttestRevokeApalache ConstInitFinding SelfRevReadingsAgree" \
  "AttestRevokeApalache ConstInitFinding LiveReadingsAgree" \
  "AttestRevokeApalache ConstInitSupUnordered LadderIsFixedPointRec" \
  "AttestRevokeApalache ConstInitSupUnordered FixedPointUniqueRec" \
  "AttestRevokeApalache ConstInitRevUnordered LadderIsFixedPointRec" \
  "AttestRevokeApalache ConstInitRevUnordered FixedPointUniqueRec" \
  "AttestRevokeApalache ConstInitRevUnordered FixedPointUniqueStruct" \
  "QuorumSignerSetApalache ConstInitFinding ResultIndependentOfProbe" \
  "QuorumSignerSetApalache ConstInitFinding SpecNeverSilentlyReverts" \
  "QuorumSignerSetApalache ConstInitFinding NotExpiredReadingsAgree" \
  "QuorumSignerSetApalache ConstInitFinding SpecMatchesNormative" \
  "QuorumSignerSetApalache ConstInitFinding CohortMatchesNormative" \
  "QuorumSignerSetApalache ConstInitSupUnordered CohortNeverSilentlyReverts" \
  "QuorumSignerSetApalache ConstInitSupUnordered CohortNeverSilentlyRevertsNoSelfLoop" \
  "QuorumKofNApalache ConstInitFindingThreshold KofNRequiresASignature" \
  "QuorumKofNApalache ConstInitFindingAttainable ThresholdAttainable" \
  "IdentityCertChainApalache ConstInitFindingPublicSig PublicPathNeverControllerSigned" \
  "IdentityCertChainApalache ConstInitFindingRevocation RevocationReachesTopology" \
  "IdentityCertChainApalache ConstInitFindingHandoffSigner HandoffReadingsCoincide" \
  "IdentityCertChainApalache ConstInitFindingHandoffNull HandoffTargetGuarded"

# Apalache NEGATIVE CONTROLS. Format: MODULE CINIT INV INIT LENGTH. Every row MUST report an
# error. NOTE the §4.8 refcount control (ConstInitBugRefs) runs BOUNDED FROM Init against the
# UNSTRENGTHENED InvUAFPlain, not inductively: RefcountSound asserts the split RMW states are
# unreachable, so under SyncRefs = FALSE it is false and any inductive obligation carrying it
# would be satisfied VACUOUSLY — a green that means nothing. Stated here because the
# distinction is invisible from the row itself.
#
# THE LENGTH COLUMN IS LOAD-BEARING AND IS A TRAP. A bounded run that is too SHORT to reach
# the defect reports NoError, which is textually identical to "the invariant holds" — so an
# under-set length silently converts a negative control into a false pass. ReasonCodesDistinct
# needs >= 5 (five Advance steps to reach the ceiling) and was observed passing at 4 during
# the 0.8.2 audit. Lengths here carry margin over the shortest witness. Same failure family as
# vacuity: a green that means nothing.
#
# TWO KINDS SHARE THIS TABLE AS OF 2026-09-09, AND A ROW DOES NOT SHOW WHICH IT IS — so each is
# named here, exactly as `APALACHE_ENUM_NEG`'s header names its three. Both must be VIOLATED
# and the reasons are opposite:
#   NEGATIVE CONTROLS     — a deliberately WEAKENED model; the violation proves the property
#                           has teeth. Everything above, plus IdentityRecoveryApalache's
#                           ConstInitBugOpen (§9.4's MUST removed) and ConstInitBugFresh
#                           (§QUORUM:3.3's named wrong answer, validating against the freshest
#                           publish SEEN rather than the one CACHED).
#   NON-VACUITY WITNESSES — asserted IN ORDER TO BE VIOLATED on a model where nothing is
#                           weakened; the violation exhibits a state and IS the pass.
#                           IdentityRecoveryApalache's four. They are load-bearing rather than
#                           a formality on this subject specifically: its headline finding IS a
#                           vacuity (§9.4's prohibition is green because the accepting path does
#                           not exist), so a green there means nothing without
#                           `WitnessRecoveryAccepted` beside it. `WitnessChainedAccept` is the
#                           odd one — it exhibits the REMEDY for finding N2 (two recoveries in a
#                           row are accepted under copy-and-keep), which is why it runs under
#                           ConstInitRekeyRetain and not under ConstInitOK.
#
# IdentityProcessApalache's TEN ROWS (2026-09-09) SPLIT THE SAME TWO WAYS, four and six:
#   CONTROLS  — ConstInitBugScope (§6.3's phase-2a scope rule removed), ConstInitBugHandler (a
#               phase-2 failure allowed to propagate into an unbind), ConstInitBugNoEmit (phase 3
#               dropped), ConstInitBugSuccessEvent (success-path emission, a v2 MUST NOT). Each
#               is the TLC twin's cfg of the same name, one engine over.
#   WITNESSES — the six ConstInitOK rows, and on THIS module they are load-bearing rather than a
#               formality. The TLC twin's green sweep was VACUOUS on its first draft: under the
#               union of the cohort's repairs nothing was ever rejected, so the phase-2a unbind
#               path was dead and two greens were true of a model that never unbinds anything.
#               `WitnessCapIssued` and `WitnessRevBound` carry the same job for the rows the LIFT
#               added — `RevokedCertNeverAdmitted` is green by admitting no cert at all, and
#               `RetirementIsDurable` is green by never tearing a cap down, so each has a witness
#               that must exhibit the state its green is about. `WitnessCapTornDown` runs at
#               length 4 rather than 3 because the teardown it must exhibit needs an issuance
#               before it; see that module's `capTornDown` comment for why the shorter trace was
#               the wrong one to route.
#
# QuorumTrustApalache's TEN ROWS (2026-09-09) split four controls and six witnesses, and ONE OF
# THE WITNESSES IS NOT A VACUITY CHECK — it is a retraction with a gate row behind it:
#   CONTROLS  — ConstInitBugNoInvalidate (§4.2.1 triggers 1+2 removed), ConstInitBugRawInvalidate
#               (non-trigger 2 inverted), ConstInitBugCrossQuorum (non-trigger 3 inverted) are the
#               TLC module's three controls one engine over. **ConstInitBugRevokeNoInvalidate is
#               NEW and is the point**: §4.2.1 TRIGGER 3 had no teeth-test anywhere in this repo,
#               because no model had an action that could fire it.
#   WITNESSES — WitnessCachePopulated / WitnessUnvalidatedInTree / WitnessColdStartExposed are
#               ported. WitnessRevocationFires and WitnessRevokeCleared are new and load-bearing
#               for the same reason as the control above: without them every trigger-3 claim is a
#               claim about an action that never fires, which is the state the TLC module was in
#               without anyone noticing.
#               **OnlyAcceptInvalidates is the odd row and it is deliberate.** It is
#               tla/QuorumTrust.tla's `NoInvalidationWithoutAcceptance` transcribed UNCHANGED,
#               whose comment there reads "Only a validate-accept may clear a cache entry." That
#               sentence is FALSE of §4.2.1, which has three triggers; it was green for two days
#               because the model had no action that could falsify it. Its required violation
#               here is the correction, expressed as a gate row rather than as a paragraph
#               nothing re-reads. `NoInvalidationWithoutTrigger` in APALACHE_GREEN is the claim
#               that survives.
# ----------------------------------------------------------------------------------
# APALACHE FINDING ROWS ON A TRANSITION SYSTEM — the third table this repo has split out for
# the same reason, and the reason is D13's sixth instance rather than tidiness.
#
# `APALACHE_NEG` (above) and `APALACHE_ENUM_FINDING` (below) each already carry the rule. What
# neither can carry is a row that (a) must be VIOLATED, (b) weakens NOTHING, and (c) needs a
# bounded run from `Init` because the module has real transitions. `APALACHE_ENUM_FINDING` runs
# every row at `--length=0`, which is right for the enumeration models and settles nothing on a
# state machine; `APALACHE_NEG`'s header says "the invariant has no teeth" on a green, and THAT
# SENTENCE IS FALSE OF A FINDING ROW — a green here would mean the defect was fixed upstream and
# the row must be RETIRED, not repaired. Two opposite meanings behind one exit code is exactly
# what `TLC_FINDING` was split out to prevent.
#
# Format: MODULE CINIT INV INIT LENGTH. Every row MUST be violated, and the LENGTH column is the
# same trap it is in APALACHE_NEG: a run too short to reach the defect reports NoError, which
# reads identically to "the property holds". Lengths carry margin over the shortest trace, and
# every trace below was READ rather than inferred from the exit code — which is how the first
# draft of `RecoveryAttainable` under ConstInitRotations was caught asserting the wrong thing
# (its counterexample had `handoffSeen = FALSE`; see that module's `rejGenuine` comment).
#
# All three of TLC_FINDING's shapes appear here:
#   Shape 1 — NOTHING IS WEAKENED. ConstInitFindingSeed is §6.3 AS WRITTEN (phase 1 rejects
#     `quorum-publish`, so the phase-2 seed row never runs), and ConstInitRotations is the green
#     sweep's constants plus a §4.3 handle rotation, which is a normative kind of the pinned
#     spec. Findings I1/R1, I2/R2 and N1.
#   Shape 2 — THE CONSTANT FLIPS TOWARD ONE IMPLEMENTATION, because on this question the spec
#     says nothing. ConstInitGo and ConstInitRustPy are the two readings of §6.3's
#     `update_handle_cache_to`, a handler NAMED in a normative dispatch table and DEFINED IN NO
#     SECTION. Finding N2, and read its two rows as a PAIR: each reading satisfies one of two
#     properties the spec states and neither satisfies both. Retiring one of them without the
#     other would leave a reader thinking one implementation is simply right.
#   Shape 3 — TOWARD ONE IMPLEMENTATION on a silence. ConstInitFindingAnchor is entity-core-rust's
#     unvalidating admission rule (I6/R3): there is no validation step to omit, because none is
#     written.
#
# IdentityProcessApalache's FIVE ROWS (2026-09-09) ARE SHAPES 1 AND 2, AND THE SPLIT IS NOT WHERE
# A READER WOULD GUESS — the two cinits do NOT correspond to the two findings.
#   ConstInitFindingSpec (4 rows) — SHAPE 2, the constant flipped TOWARD the spec. §6.3 and §3.6
#     AS WRITTEN: no pre-route branch, and `revocation` excluded by §3.6's explicit comment. The
#     three ported rows carry I1, I2 and I3 to a second engine; the fourth, `RevokedCertNeverAdmitted`,
#     is finding N3 and is NEW — it needs two arrivals and the TLC twin has one.
#   ConstInitOK (1 row) — SHAPE 1, NOTHING WEAKENED, and it is the sharpest row in the file for
#     that reason. `RetirementIsDurable` is violated on the GREEN SWEEP'S OWN CONSTANTS, which on
#     this track are the UNION of all three implementations' repairs — so finding N4 survives
#     every workaround the cohort invented, and no setting of any constant here makes it go away
#     except the two that add text §6.3 does not have (APALACHE_GREEN's last two rows).
# Read `ConstInitOK` appearing in BOTH this table and APALACHE_GREEN as the point rather than as
# an inconsistency: nine claims hold on those constants and a tenth does not.
#
# QuorumTrustApalache's THREE ROWS ARE ALL SHAPE 2 — the constant flips TOWARD the spec.
#   ConstInitFindingClosure / ConstInitFindingFailPath — Q5, ported. `WalkClosedOverValidated`
#     FALSE is §4.2 AS WRITTEN (the §ATTEST:5.4 index lookup, which §ATTEST:5.7 I4 says filters by
#     nothing); TRUE is the closure §4.2's cold-start sentence merely ASSERTS. The FailPath row
#     runs with §8 switched off, so the defect is shown not to depend on raw writes at all.
#   ConstInitFindingDelete — NEW, and read it against ConstInitOK rather than alone. The ONLY
#     difference from the green sweep is that §8's permitted `tree:put` may write NULL. The
#     read-side closure is IN FORCE and the cache still goes stale, because §4.2.1 non-trigger 2
#     forbids invalidating on a raw tree-write and the entry it removed was validated. So the
#     closure Q5's remedy names is READ-side and what §4.2 actually needs is WRITE-side. Same
#     sentence and same §8 mechanism as Q5, opposite direction, and it SURVIVES Q5's remedy —
#     which is why it is routed as a strengthening of Q5 rather than as a new finding.
APALACHE_FINDING := \
  "IdentityRecoveryApalache ConstInitFindingSeed   SeedFollowsArrival             Init 3" \
  "IdentityRecoveryApalache ConstInitFindingSeed   RecoveryAttainable             Init 5" \
  "IdentityRecoveryApalache ConstInitFindingAnchor AnchorWasValidated             Init 3" \
  "IdentityRecoveryApalache ConstInitFindingAnchor AcceptedRecoveryIsQuorumSigned Init 5" \
  "IdentityRecoveryApalache ConstInitRotations AnchorSurvivesHandoff         Init 4" \
  "IdentityRecoveryApalache ConstInitRotations HandoffKeepsRecoveryAvailable Init 5" \
  "IdentityRecoveryApalache ConstInitRustPy    SecondRecoveryHasAnchor       Init 6" \
  "IdentityRecoveryApalache ConstInitGo        RecoveryIdempotent            Init 6" \
  "IdentityProcessApalache ConstInitFindingSpec SeedRowReachable            Init 2" \
  "IdentityProcessApalache ConstInitFindingSpec RevocationSurvivesArrival   Init 2" \
  "IdentityProcessApalache ConstInitFindingSpec QuorumUpdateSurvivesArrival Init 2" \
  "IdentityProcessApalache ConstInitFindingSpec RevokedCertNeverAdmitted    Init 4" \
  "IdentityProcessApalache ConstInitOK          RetirementIsDurable         Init 5" \
  "QuorumTrustApalache ConstInitFindingClosure  CacheMatchesValidated Init 4" \
  "QuorumTrustApalache ConstInitFindingFailPath CacheMatchesValidated Init 4" \
  "QuorumTrustApalache ConstInitFindingDelete   CacheMatchesValidated Init 5"

APALACHE_NEG := \
  "AttestIndexApalache ConstInitBugAtomic NoResidueOnFailure    Init 8" \
  "AttestIndexApalache ConstInitBugKind   KindIndexEligibleOnly Init 8" \
  "AttestIndexApalache ConstInitBugRetain IndexRetainedOnRevoke Init 8" \
  "StoreApalache ConstInitBugRace  InvRace      IndInitRace 1" \
  "StoreApalache ConstInitBugAdmit ResourceBounded Init     8" \
  "StoreApalache ConstInitBugRefs  InvUAFPlain  Init        8" \
  "ReentryApalache ConstInitBugFrame FramesNotInterleaved Init 8" \
  "ReentryApalache ConstInitBugFrame3 FramesNotInterleaved Init 8" \
  "AuthorityApalache ConstInitBugAllow   NoGrantlessAllow         Init 6" \
  "AuthorityApalache ConstInitBugDeny    EntryNotSpuriouslyDenied Init 6" \
  "AuthorityApalache ConstInitBugSubGate ResourceAuthorized       Init 6" \
  "AuthorityApalache ConstInitBugInherit NoManufacturedTarget     Init 6" \
  "BoundsApalache ConstInitBugEqual  DepthBrakeFirst     Init 10" \
  "BoundsApalache ConstInitBugRatio  DepthBrakeFirst     Init 10" \
  "BoundsApalache ConstInitBugDouble TtlNotDoubleCounted Init 4" \
  "BoundsApalache ConstInitBugCode   ReasonCodesDistinct Init 6" \
  "CoreApalache ConstInitBugFrame  FramesNotInterleaved     Init 8" \
  "CoreApalache ConstInitBugFrame3 FramesNotInterleaved     Init 8" \
  "CoreApalache ConstInitBugEstab  DispatchNeedsEstablished Init 6" \
  "RegisterApalache ConstInitBugAoN RegisterAllOrNothing Init 6" \
  "CoreApalache ConstInitBugRevoke NoServeWhenRevoked       Init 8" \
  "ConnCodesApalache ConstInitBugCollapse ReasonCodesDistinct Init 6" \
  "ConnCodesApalache ConstInitBugStatus   StatusMatchesCode   Init 6" \
  "ConnCodesApalache ConstInitSeqReading  PreHelloAuthIsInvalidNonce Init 6" \
  "ConnCodesApalache ConstInitBugAddressOrder AddressVerdictPhaseIndependent Init 6" \
  "ConnCodesApalache ConstInitBugDrop      NoSilentDrop       Init 3" \
  "ConnCodesApalache ConstInitBugBareClose NoBareCloseOnly    Init 3" \
  "ConnCodesApalache ConstInitBugEcf       FramingIsNotEcf    Init 3" \
  "BootstrapApalache ConstInitBugEarlyIndex BootAllOrNothing             Init 6" \
  "BootstrapApalache ConstInitBugGate       NoRegistrationBeforeBootstrap Init 6" \
  "BootstrapApalache ConstInitBugConnect    ConnectPreAuthorized          Init 6" \
  "IdentityRecoveryApalache ConstInitBugOpen  RecoveryFailClosed             Init 4" \
  "IdentityRecoveryApalache ConstInitBugFresh AcceptedRecoveryIsQuorumSigned Init 5" \
  "IdentityRecoveryApalache ConstInitOK WitnessAnchorSeeded     Init 3" \
  "IdentityRecoveryApalache ConstInitOK WitnessRecoveryAccepted Init 5" \
  "IdentityRecoveryApalache ConstInitOK WitnessFailClosedFires  Init 3" \
  "IdentityRecoveryApalache ConstInitRekeyRetain WitnessChainedAccept Init 8" \
  "IdentityProcessApalache ConstInitBugScope        LocalCreateNeverUnbinds Init 3" \
  "IdentityProcessApalache ConstInitBugHandler      UnbindOnlyOnRejection   Init 3" \
  "IdentityProcessApalache ConstInitBugNoEmit       FailureIsObservable     Init 3" \
  "IdentityProcessApalache ConstInitBugSuccessEvent NoSuccessEvents         Init 3" \
  "IdentityProcessApalache ConstInitOK WitnessUnbindReached Init 3" \
  "IdentityProcessApalache ConstInitOK WitnessPhase2Reached Init 3" \
  "IdentityProcessApalache ConstInitOK WitnessFailureEvent  Init 3" \
  "IdentityProcessApalache ConstInitOK WitnessCapIssued     Init 3" \
  "IdentityProcessApalache ConstInitOK WitnessCapTornDown   Init 4" \
  "IdentityProcessApalache ConstInitOK WitnessRevBound      Init 3" \
  "IdentityProcessApalache ConstInitOK WitnessSeeded        Init 3" \
  "QuorumTrustApalache ConstInitBugNoInvalidate       CacheMatchesValidated        Init 5" \
  "QuorumTrustApalache ConstInitBugRevokeNoInvalidate CacheMatchesValidated        Init 5" \
  "QuorumTrustApalache ConstInitBugRawInvalidate      NoInvalidationWithoutTrigger Init 3" \
  "QuorumTrustApalache ConstInitBugCrossQuorum        InvalidationScopedPerQuorum  Init 3" \
  "QuorumTrustApalache ConstInitOK WitnessCachePopulated    Init 3" \
  "QuorumTrustApalache ConstInitOK WitnessUnvalidatedInTree Init 3" \
  "QuorumTrustApalache ConstInitOK WitnessColdStartExposed  Init 4" \
  "QuorumTrustApalache ConstInitOK WitnessRevocationFires   Init 3" \
  "QuorumTrustApalache ConstInitOK WitnessRevokeCleared     Init 4" \
  "QuorumTrustApalache ConstInitOK OnlyAcceptInvalidates    Init 4"

# Every row MUST fail, AND MUST FAIL BY FINDING A COUNTEREXAMPLE — not by erroring out.
#
# This target used to grade on the EXIT STATUS with output sent to /dev/null, which is the
# same defect fixed in `tlc-neg` and in spin/Makefile, left standing here. Apalache
# distinguishes the two cases in its exit code and this check reads it:
#   EXITCODE: ERROR (12)  — "Checker has found an error": a real counterexample.
#   EXITCODE: ERROR (255) — a CONFIGURATION error, e.g. `--inv=` naming an operator that does
#                           not exist. Also non-zero. Under the old grading that scored
#                           "ok (counterexample found as required)".
# So a control whose invariant or cinit was renamed or typo'd counted as teeth. Verified by
# pointing one row at a nonexistent invariant: 255, and the old target passed it.
#
# RESIDUAL, stated because the check cannot close it: Apalache prints "State N: state
# invariant K violated" — an INDEX, not the invariant's name — so this asserts that A
# counterexample was found for the invariant NAMED ON THE COMMAND LINE, not which conjunct of
# a conjunctive invariant broke. TLC's controls do assert the name; Apalache's cannot.
.PHONY: apalache-neg
apalache-neg:
	@for row in $(APALACHE_NEG); do \
	  set -- $$row; mod=$$1; ci=$$2; inv=$$3; init=$$4; len=$$5; \
	  echo "== Apalache neg control $$mod $$ci/$$inv (MUST find a counterexample) =="; \
	  out=$$($(APRUN) check --cinit=$$ci --init=$$init --next=Next --inv=$$inv --length=$$len $$mod.tla 2>&1); rc=$$?; \
	  if [ $$rc -eq 0 ]; then \
	    echo "FAIL: $$ci/$$inv reported NoError — the invariant has no teeth."; \
	    echo "      (Check the --length: a bounded run too SHORT to reach the defect also"; \
	    echo "      reports NoError, textually identical to 'the invariant holds'.)"; \
	    exit 1; \
	  fi; \
	  if ! echo "$$out" | grep -qF "EXITCODE: ERROR (12)"; then \
	    echo "FAIL: $$ci/$$inv failed WITHOUT finding a counterexample — the run errored out"; \
	    echo "      before verifying anything, so it is not evidence of teeth."; \
	    echo "$$out" | grep -E "Configuration error|EXITCODE|^.*error" | tail -4 | sed 's/^/      /'; \
	    exit 1; \
	  fi; \
	  echo "   ok (counterexample found as required)"; \
	done

apalache-green:
	@for row in $(APALACHE_GREEN); do \
	  set -- $$row; mod=$$1; ci=$$2; inv=$$3; ind=$$4; \
	  echo "== Apalache $$mod $$inv (base) =="; \
	  $(APRUN) check --cinit=$$ci --init=Init --next=Next --inv=$$inv --length=0 $$mod.tla || exit 1; \
	  echo "== Apalache $$mod $$inv (inductive step) =="; \
	  $(APRUN) check --cinit=$$ci --init=$$ind --next=Next --inv=$$inv --length=1 $$mod.tla || exit 1; \
	done

# The closure half of the inductive proof: the strengthening preserves ITSELF. Without this the
# base and step rows prove Inv is preserved from strengthened states and nothing more. See the
# APALACHE_CLOSURE header.
.PHONY: apalache-closure
apalache-closure:
	@for row in $(APALACHE_CLOSURE); do \
	  set -- $$row; mod=$$1; ci=$$2; ind=$$3; \
	  echo "== Apalache $$mod $$ind (strengthening closure: $$ind /\\ Next => $$ind') =="; \
	  out=$$($(APRUN) check --cinit=$$ci --init=$$ind --next=Next --inv=$$ind --length=1 $$mod.tla 2>&1); rc=$$?; \
	  if [ $$rc -ne 0 ] || ! echo "$$out" | grep -qF "EXITCODE: OK"; then \
	    echo "FAIL: $$mod/$$ind is NOT preserved by Next."; \
	    echo "      The base and step rows for this module therefore do NOT establish that its"; \
	    echo "      invariant is inductive -- they establish preservation from states the"; \
	    echo "      strengthening describes, and nothing shows a run stays in those states."; \
	    echo "$$out" | grep -E "EXITCODE|error" | tail -3 | sed 's/^/      /'; \
	    exit 1; \
	  fi; \
	  echo "   ok (strengthening preserved)"; \
	done

.PHONY: apalache-enum-green apalache-enum-neg apalache-enum-finding
apalache-enum-green:
	@for row in $(APALACHE_ENUM_GREEN); do \
	  set -- $$row; mod=$$1; ci=$$2; inv=$$3; \
	  echo "== Apalache $$mod $$ci/$$inv (enumeration, length 0) =="; \
	  out=$$($(APRUN) check --cinit=$$ci --init=Init --next=Next --inv=$$inv --length=0 $$mod.tla 2>&1); rc=$$?; \
	  if [ $$rc -ne 0 ] || ! echo "$$out" | grep -qF "EXITCODE: OK"; then \
	    echo "FAIL: $$mod $$ci/$$inv did not report OK."; \
	    echo "$$out" | grep -E "EXITCODE|Configuration error|error" | tail -3 | sed 's/^/      /'; \
	    exit 1; \
	  fi; \
	  echo "   ok"; \
	done

apalache-enum-neg:
	@for row in $(APALACHE_ENUM_NEG); do \
	  set -- $$row; mod=$$1; ci=$$2; inv=$$3; \
	  echo "== Apalache enum control $$mod $$ci/$$inv (MUST find a counterexample) =="; \
	  out=$$($(APRUN) check --cinit=$$ci --init=Init --next=Next --inv=$$inv --length=0 $$mod.tla 2>&1); rc=$$?; \
	  if [ $$rc -eq 0 ]; then \
	    echo "FAIL: $$ci/$$inv reported NoError -- this row has no teeth."; exit 1; \
	  fi; \
	  if ! echo "$$out" | grep -qF "EXITCODE: ERROR (12)"; then \
	    echo "FAIL: $$ci/$$inv failed WITHOUT finding a counterexample -- the run errored out"; \
	    echo "      before verifying anything, so it is not evidence of teeth."; \
	    echo "$$out" | grep -E "Configuration error|EXITCODE" | tail -3 | sed 's/^/      /'; \
	    exit 1; \
	  fi; \
	  echo "   ok (counterexample found as required)"; \
	done

apalache-enum-finding:
	@for row in $(APALACHE_ENUM_FINDING); do \
	  set -- $$row; mod=$$1; ci=$$2; inv=$$3; \
	  echo "== Apalache FINDING $$mod $$ci/$$inv (MUST be violated -- nothing is weakened) =="; \
	  out=$$($(APRUN) check --cinit=$$ci --init=Init --next=Next --inv=$$inv --length=0 $$mod.tla 2>&1); rc=$$?; \
	  if [ $$rc -eq 0 ]; then \
	    echo "GREEN ON A FINDING ROW: $$mod $$ci/$$inv now HOLDS."; \
	    echo "      This is NOT a model regression and MUST NOT be repaired by editing the"; \
	    echo "      model. It means the spec defect was fixed upstream. RETIRE the row: delete"; \
	    echo "      it here, move the claim into APALACHE_ENUM_GREEN, and strike the finding in"; \
	    echo "      docs/status/FINDINGS-INDEX.md."; \
	    exit 1; \
	  fi; \
	  if ! echo "$$out" | grep -qF "EXITCODE: ERROR (12)"; then \
	    echo "FAIL: $$ci/$$inv failed WITHOUT a counterexample -- not evidence of the finding."; \
	    echo "$$out" | grep -E "Configuration error|EXITCODE" | tail -3 | sed 's/^/      /'; \
	    exit 1; \
	  fi; \
	  echo "   ok (counterexample found as required -- the finding still stands)"; \
	done

# The transition-system twin of the target above. Same grading and the same retirement message;
# the difference is the bounded run from a named INIT, because these modules have transitions
# and `--length=0` would settle nothing about them. See the APALACHE_FINDING header for why
# this is a third table rather than a flag on either of the two that already exist.
.PHONY: apalache-finding
apalache-finding:
	@for row in $(APALACHE_FINDING); do \
	  set -- $$row; mod=$$1; ci=$$2; inv=$$3; init=$$4; len=$$5; \
	  echo "== Apalache FINDING $$mod $$ci/$$inv (MUST be violated -- nothing is weakened) =="; \
	  out=$$($(APRUN) check --cinit=$$ci --init=$$init --next=Next --inv=$$inv --length=$$len $$mod.tla 2>&1); rc=$$?; \
	  if [ $$rc -eq 0 ]; then \
	    echo "GREEN ON A FINDING ROW: $$mod $$ci/$$inv now HOLDS."; \
	    echo "      This is NOT a model regression and MUST NOT be repaired by editing the"; \
	    echo "      model. Either the spec defect was fixed upstream -- in which case RETIRE"; \
	    echo "      the row, move the claim into APALACHE_GREEN and strike the finding in"; \
	    echo "      docs/status/FINDINGS-INDEX.md -- or the --length is too SHORT to reach it,"; \
	    echo "      which reports identically. Check the length before believing the retirement."; \
	    exit 1; \
	  fi; \
	  if ! echo "$$out" | grep -qF "EXITCODE: ERROR (12)"; then \
	    echo "FAIL: $$ci/$$inv failed WITHOUT a counterexample -- not evidence of the finding."; \
	    echo "$$out" | grep -E "Configuration error|EXITCODE" | tail -3 | sed 's/^/      /'; \
	    exit 1; \
	  fi; \
	  echo "   ok (counterexample found as required -- the finding still stands)"; \
	done

# Full TLA+ green slice: bounded-exhaustive (TLC) + unbounded inductive (Apalache).
green: tlc-green apalache-green apalache-closure apalache-enum-green

# The FULL matrix: green + every negative control + every non-vacuity witness. `green` alone
# proves the properties hold; it does NOT prove they could have failed or that the model does
# anything. This target proves all three.
matrix: tlc-green apalache-green apalache-closure apalache-enum-green \
        tlc-neg apalache-neg apalache-enum-neg tlc-witness tlc-finding apalache-enum-finding \
        apalache-finding

# ----------------------------------------------------------------------------------
# Apalache — the SYMBOLIC (SMT) cross-check engine (cross-check #A). Same .tla models,
# a second independent engine, and — via inductive invariants — UNBOUNDED proofs.
# See Containerfile.apalache and ../docs/HANDOFF-CROSSCHECK.md.
# ----------------------------------------------------------------------------------
APIMAGE      ?= entity-apalache
APRUN        := $(PODMAN) run --rm $(PODMAN_RUN_CAPS) $(MOUNT) $(APIMAGE)
# Generic check knobs (override per module/property in the cross-check phase):
INIT         ?= Init
NEXT         ?= Next
INV          ?= Inv
LEN          ?= 1

.PHONY: apalache-image apalache-smoke apalache-typecheck apalache

apalache-image:
	$(PODMAN) build $(PODMAN_BUILD_CAPS) -t $(APIMAGE) -f Containerfile.apalache .

# Real toolchain smoke: typecheck + the TWO inductive-proof obligations on SmokeApalache.
# Proves Z3 actually verifies end-to-end AND demonstrates an unbounded (all-N) proof.
apalache-smoke:
	$(APRUN) typecheck SmokeApalache.tla
	@echo "--- base case: Init => Inv ---"
	$(APRUN) check --init=Init --next=Next --inv=Inv --length=0 SmokeApalache.tla
	@echo "--- inductive step: Inv /\\ Next => Inv-prime ---"
	$(APRUN) check --init=IndInit --next=Next --inv=Inv --length=1 SmokeApalache.tla

# Snowcat type-check a module (Apalache needs @type annotations; first step when porting).
apalache-typecheck:
	$(APRUN) typecheck $(SPEC).tla

# Generic symbolic check. e.g. make apalache SPEC=Store INV=StoreRaceFree INIT=Init NEXT=Next LEN=1
# CINIT is optional and passed only when set: every module whose Init quantifies over `1..N`
# REQUIRES one (Apalache: "Expected a constant integer range in [ .. ], found 1..N"), so without
# this knob the generic target could not reproduce a single row of the gate tables by hand —
# which is what it exists for. Added 2026-09-08 while porting AttestRevokeApalache.
#   make apalache SPEC=AttestRevokeApalache CINIT=ConstInitOK INV=UnrollDeep LEN=0
apalache:
	$(APRUN) check $(if $(CINIT),--cinit=$(CINIT)) --init=$(INIT) --next=$(NEXT) --inv=$(INV) --length=$(LEN) $(SPEC).tla

clean:
	rm -f *.old *_TTrace_*.tla *_TTrace_*.bin 2>/dev/null || true
	rm -rf states/ _apalache-out/ x/ .apalache/ 2>/dev/null || true
