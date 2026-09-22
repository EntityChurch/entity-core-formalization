# Spike A — TLA+ toolchain, make + podman only (no host java, no loose jar).
#
# All TLC/PlusCal invocations run inside the `entity-tla` podman image, which
# carries the JRE + tla2tools.jar (see ./Containerfile). The repo dir is bind-
# mounted at /work with :Z for SELinux relabeling (Fedora host).
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
              ConnCodes Bootstrap

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
TLC_WITNESS := \
  "Reentry|ReentryWitness|Invariant WitnessBothComplete is violated" \
  "Reentry|ReentryWitness3|Invariant WitnessBothComplete is violated" \
  "Core|CoreWitness3|Invariant WitnessExchangeComplete is violated" \
  "Store|StoreWitness|Invariant WitnessStoreLive is violated" \
  "Conn|ConnWitness|Invariant WitnessDispatched is violated" \
  "Revoke|RevokeWitness|Invariant WitnessRevocationObserved is violated" \
  "Emit|EmitWitness|Invariant WitnessEventFired is violated" \
  "Register|RegisterWitness|Invariant WitnessHandlerLive is violated" \
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
TLC_NEG := \
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
  "Emit|EmitFireBug|Invariant EventIffRealWork is violated" \
  "Emit|EmitMarkerBug|Invariant EventTypeCorrect is violated" \
  "Emit|EmitStallBug|Temporal property EmitTerminates was violated" \
  "Register|RegisterAtomicBug|Invariant NoPartialResidue is violated" \
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
  "Bootstrap|BootstrapEarlyIndexBug|Invariant BootAllOrNothing is violated" \
  "Bootstrap|BootstrapGateBug|Invariant NoRegistrationBeforeBootstrap is violated" \
  "Bootstrap|BootstrapConnectBug|Invariant ConnectPreAuthorized is violated"

.PHONY: tlc-green apalache-green green tlc-witness tlc-neg
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
# list above assumes cfg == module; these are the N-peer variants, which share one module.
TLC_GREEN_PAIRS := \
  "Reentry|Reentry3" \
  "Core|Core3"

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
  "BootstrapApalache ConstInitOK InvAllOrNothing IndInitAllOrNothing" \
  "BootstrapApalache ConstInitOK InvRegGate IndInitRegGate" \
  "BootstrapApalache ConstInitOK InvConnect IndInitConnect"

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
APALACHE_NEG := \
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
  "CoreApalache ConstInitBugRevoke NoServeWhenRevoked       Init 8" \
  "ConnCodesApalache ConstInitBugCollapse ReasonCodesDistinct Init 6" \
  "ConnCodesApalache ConstInitBugStatus   StatusMatchesCode   Init 6" \
  "ConnCodesApalache ConstInitSeqReading  PreHelloAuthIsInvalidNonce Init 6" \
  "BootstrapApalache ConstInitBugEarlyIndex BootAllOrNothing             Init 6" \
  "BootstrapApalache ConstInitBugGate       NoRegistrationBeforeBootstrap Init 6" \
  "BootstrapApalache ConstInitBugConnect    ConnectPreAuthorized          Init 6"

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

# Full TLA+ green slice: bounded-exhaustive (TLC) + unbounded inductive (Apalache).
green: tlc-green apalache-green

# The FULL matrix: green + every negative control + every non-vacuity witness. `green` alone
# proves the properties hold; it does NOT prove they could have failed or that the model does
# anything. This target proves all three.
matrix: tlc-green apalache-green tlc-neg apalache-neg tlc-witness

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
apalache:
	$(APRUN) check --init=$(INIT) --next=$(NEXT) --inv=$(INV) --length=$(LEN) $(SPEC).tla

clean:
	rm -f *.old *_TTrace_*.tla *_TTrace_*.bin 2>/dev/null || true
	rm -rf states/ _apalache-out/ x/ .apalache/ 2>/dev/null || true
