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
# :Z relabels the bind mount for SELinux (Fedora). Drop to :z if shared across containers.
MOUNT        := -v $(CURDIR):/work:Z -w /work
RUN          := $(PODMAN) run --rm $(PODMAN_RUN_CAPS) $(MOUNT) $(IMAGE)
# tla2tools workers: bound for a laptop; raise for bigger state spaces.
WORKERS      ?= 4

.PHONY: image smoke translate sany tlc check repl clean

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
# props declared in the cfg). 7 modules = the all-Core concurrency surface.
TLC_GREEN := Reentry Conn Store Revoke Emit Register Core

.PHONY: tlc-green apalache-green green
tlc-green:
	@for s in $(TLC_GREEN); do \
	  echo "== TLC $$s =="; \
	  $(RUN) tlc2.TLC -workers $(WORKERS) -config $$s.cfg $$s.tla || exit 1; \
	done

# Apalache: prove each module's key safety invariant INDUCTIVE (unbounded) —
# base case (Init => Inv, length 0) and inductive step (IndInit /\ Next => Inv',
# length 1). 8 invariants across 5 modules. Operator names are in each *Apalache.tla
# header. Format per line: MODULE CINIT INV INDINIT
APALACHE_GREEN := \
  "RevokeApalache ConstInitOK InvDet IndInitDet" \
  "RevokeApalache ConstInitOK InvRev IndInitRev" \
  "StoreApalache  ConstInitOK InvRace IndInitRace" \
  "StoreApalache  ConstInitOK InvBound IndInitBound" \
  "ConnApalache   ConstInitOK Inv IndInit" \
  "EmitApalache   ConstInitOK InvIff IndInitIff" \
  "EmitApalache   ConstInitOK InvType IndInitType" \
  "RegisterApalache ConstInitOK Inv IndInit"

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
