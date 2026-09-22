# Spin — INDEPENDENT-ENCODING cross-check (cross-check #B), make + podman only.
#
# Spin verifies in three steps: `spin -a model.pml` emits a C verifier (pan.c); `gcc` compiles
# it; `./pan` runs the exhaustive check. All inside the `entity-spin` image (see ./Containerfile).
#
# Usage:
#   make image                build (or rebuild) the toolchain image
#   make smoke                prove the toolchain verifies end-to-end (spin -a; gcc; ./pan)
#   make verify MODEL=<name>  exhaustive safety check of <name>.pml
#   make ltl MODEL=<name>     exhaustive check incl. liveness/acceptance cycles (pan -a)
#   make shell                interactive shell in the toolchain container
#   make clean                remove generated verifier artifacts

# Shared podman resource caps (PODMAN_BUILD_CAPS / PODMAN_RUN_CAPS).
include ../caps.mk

IMAGE   ?= entity-spin
PODMAN  ?= podman
MOUNT   := -v $(CURDIR):/work:Z -w /work
RUN     := $(PODMAN) run --rm $(PODMAN_RUN_CAPS) $(MOUNT) $(IMAGE)
MODEL   ?= smoke
# DEFS: preprocessor macros passed to spin, e.g. DEFS=-DSERIALIZED to select a defect variant.
DEFS    ?=

.PHONY: image smoke verify ltl shell clean

image:
	$(PODMAN) build $(PODMAN_BUILD_CAPS) -t $(IMAGE) -f Containerfile .

# Real toolchain smoke: generate + compile + run the exhaustive verifier. Expect "errors: 0".
smoke:
	$(RUN) spin -a smoke.pml
	$(RUN) sh -c "gcc -O2 -o pan pan.c && ./pan"

# Exhaustive safety verification of MODEL.pml (assertions, invalid-end/deadlock states).
# -DNOCLAIM compiles out any LTL never claim so invalid-end-state (deadlock) detection
# stays enabled — a never claim otherwise disables it.
verify:
	$(RUN) spin -a $(DEFS) $(MODEL).pml
	$(RUN) sh -c "gcc -O2 -DNOCLAIM -o pan pan.c && ./pan"

# Exhaustive check of the LTL liveness property (never claim, acceptance cycles) under
# weak fairness (pan -f). Use for the EventuallyResolved-class properties.
#
# -DNFAIR=3 is required, not cosmetic: pan's weak-fairness algorithm caps the number of
# processes, and at the default NFAIR=2 that cap is 6. The composed `core` model runs 8
# (init + 2 links + revoker + 2 clients + 2 servers) and aborts with "too many processes"
# — which is a TOOL error, not a verification result, and would be easy to mistake for one.
# Applied uniformly so no model can silently hit the cap later; the only cost is a slightly
# larger state vector on the smaller models.
LTLFLAGS ?= -DNFAIR=3
ltl:
	$(RUN) spin -a $(DEFS) $(MODEL).pml
	$(RUN) sh -c "gcc -O2 $(LTLFLAGS) -o pan pan.c && ./pan -a -f"

shell:
	$(PODMAN) run --rm -it $(PODMAN_RUN_CAPS) $(MOUNT) --entrypoint /bin/sh $(IMAGE)

# Green sweep — the independent-encoding cross-check of all 9 concurrency modules
# (7 with an LTL claim below, plus the 2 structural ones in SPIN_GREEN_SAFETY):
# exhaustive SAFETY (verify) + LTL LIVENESS (ltl) on each FIXED model (no DEFS).
# Defect variants (DEFS=-D<DEFECT>) are the negative controls, run separately.
# Models carrying an LTL liveness claim — checked BOTH ways (safety + acceptance cycles).
# `core` added at 0.8.2: the composed whole-protocol model previously had NO independent
# re-encoding at all, which the audit flagged as the worst-placed single-tool gap in the repo.
SPIN_GREEN := reentry conn store revoke emit register core

# Structural models with no concurrency and therefore no LTL claim — safety only. Added at
# 0.8.2 alongside their TLA+ modules, which had shipped with TLC coverage only. Spin's
# contribution here is an independently-written enumerator agreeing on the verdicts, NOT
# interleaving search; that weaker form of corroboration is stated in each .pml header.
SPIN_GREEN_SAFETY := authority bounds

# NEGATIVE CONTROLS — each row MUST report errors > 0. Format: MODEL DEFS MODE.
# MODE is `safety` (assertions / invalid-end) or `ltl` (acceptance cycles under -a -f).
# Added at 0.8.2: store NOSYNCREFS (§4.8 RT-13a refcount use-after-free) and
# reentry NOATOMICFRAME (§6.11(a') frame-write atomicity).
SPIN_NEG := \
  "reentry  -DSERIALIZED     safety" \
  "reentry  -DNOATOMICFRAME  safety" \
  "conn     -DNOENFORCE      safety" \
  "conn     -DDROPFRAME      ltl" \
  "store    -DNOSERIALIZE    safety" \
  "store    -DNOADMIT        safety" \
  "store    -DNOSYNCREFS     safety" \
  "store    -DSILENTDROP     ltl" \
  "revoke   -DNOHONOR        safety" \
  "revoke   -DLEAKL1         safety" \
  "revoke   -DNOCONVERGE     ltl" \
  "emit     -DEMITFIRE       safety" \
  "emit     -DEMITMARKER     safety" \
  "emit     -DEMITSTALL      ltl" \
  "register -DNOATOMIC       safety" \
  "register -DNOSYSGUARD     safety" \
  "register -DWEDGE          ltl" \
  "authority -DOPTALLOW      safety" \
  "authority -DOPTDENY       safety" \
  "authority -DNOSUBCHECK    safety" \
  "authority -DINHERITRES    safety" \
  "bounds   -DEQUALMAG       safety" \
  "bounds   -DRATIOBOUND     safety" \
  "bounds   -DDOUBLECOUNT    safety" \
  "bounds   -DSHARECODE      safety" \
  "core     -DSERIALIZED     safety" \
  "core     -DNOATOMICFRAME  safety" \
  "core     -DNOESTABGATE    safety" \
  "core     -DNOREVGATE      safety"

.PHONY: green neg
# Each negative control MUST fail. Inverted exit status: a clean run is the failure.
neg:
	@for row in $(SPIN_NEG); do \
	  set -- $$row; m=$$1; d=$$2; mode=$$3; \
	  echo "== Spin neg control $$m $$d ($$mode, MUST fail) =="; \
	  $(RUN) spin -a $$d $$m.pml >/dev/null || exit 1; \
	  if [ "$$mode" = "safety" ]; then \
	    out=$$($(RUN) sh -c "gcc -O2 -DNOCLAIM -o pan pan.c && ./pan" 2>&1); \
	  else \
	    out=$$($(RUN) sh -c "gcc -O2 $(LTLFLAGS) -o pan pan.c && ./pan -a -f" 2>&1); \
	  fi; \
	  if echo "$$out" | grep -q "errors: 0"; then \
	    echo "FAIL: $$m $$d reported errors: 0 — the property it targets has no teeth."; \
	    exit 1; \
	  fi; \
	  if ! echo "$$out" | grep -qE "errors: [1-9]"; then \
	    echo "FAIL: $$m $$d produced no pan error count at all — the run did not verify"; \
	    echo "      anything (compile failure? pan aborted?). Absence of 'errors: 0' is NOT"; \
	    echo "      evidence a defect was caught; only a positive error count is."; \
	    echo "$$out" | tail -5; \
	    exit 1; \
	  fi; \
	  echo "   ok (failed as required: $$(echo "$$out" | grep -oE 'errors: [1-9][0-9]*' | head -1))"; \
	done

# A green run must positively report "errors: 0". Relying on pan's exit status alone would let
# a compile failure or an aborted run — neither of which verifies anything — pass as green,
# the mirror image of the neg-control weakness fixed below.
green:
	@for m in $(SPIN_GREEN); do \
	  echo "== Spin $$m (safety) =="; \
	  $(RUN) spin -a $$m.pml || exit 1; \
	  out=$$($(RUN) sh -c "gcc -O2 -DNOCLAIM -o pan pan.c && ./pan" 2>&1); echo "$$out"; \
	  echo "$$out" | grep -q "errors: 0" || { echo "FAIL: $$m safety did not report errors: 0"; exit 1; }; \
	  echo "== Spin $$m (liveness/LTL) =="; \
	  $(RUN) spin -a $$m.pml || exit 1; \
	  out=$$($(RUN) sh -c "gcc -O2 $(LTLFLAGS) -o pan pan.c && ./pan -a -f" 2>&1); echo "$$out"; \
	  echo "$$out" | grep -q "errors: 0" || { echo "FAIL: $$m liveness did not report errors: 0"; exit 1; }; \
	done
	@for m in $(SPIN_GREEN_SAFETY); do \
	  echo "== Spin $$m (safety; no LTL claim) =="; \
	  $(RUN) spin -a $$m.pml || exit 1; \
	  out=$$($(RUN) sh -c "gcc -O2 -DNOCLAIM -o pan pan.c && ./pan" 2>&1); echo "$$out"; \
	  echo "$$out" | grep -q "errors: 0" || { echo "FAIL: $$m safety did not report errors: 0"; exit 1; }; \
	done

clean:
	rm -f pan pan.* *.trail _spin_nvr.tmp 2>/dev/null || true
