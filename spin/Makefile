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
ltl:
	$(RUN) spin -a $(DEFS) $(MODEL).pml
	$(RUN) sh -c "gcc -O2 -o pan pan.c && ./pan -a -f"

shell:
	$(PODMAN) run --rm -it $(PODMAN_RUN_CAPS) $(MOUNT) --entrypoint /bin/sh $(IMAGE)

# Green sweep — the independent-encoding cross-check of the 6 concurrency modules:
# exhaustive SAFETY (verify) + LTL LIVENESS (ltl) on each FIXED model (no DEFS).
# Defect variants (DEFS=-D<DEFECT>) are the negative controls, run separately.
SPIN_GREEN := reentry conn store revoke emit register

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
  "register -DWEDGE          ltl"

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
	    out=$$($(RUN) sh -c "gcc -O2 -o pan pan.c && ./pan -a -f" 2>&1); \
	  fi; \
	  if echo "$$out" | grep -q "errors: 0"; then \
	    echo "FAIL: $$m $$d reported errors: 0 — the property it targets has no teeth."; \
	    exit 1; \
	  else echo "   ok (failed as required)"; fi; \
	done

green:
	@for m in $(SPIN_GREEN); do \
	  echo "== Spin $$m (safety) =="; \
	  $(RUN) spin -a $$m.pml && \
	  $(RUN) sh -c "gcc -O2 -DNOCLAIM -o pan pan.c && ./pan" || exit 1; \
	  echo "== Spin $$m (liveness/LTL) =="; \
	  $(RUN) spin -a $$m.pml && \
	  $(RUN) sh -c "gcc -O2 -o pan pan.c && ./pan -a -f" || exit 1; \
	done

clean:
	rm -f pan pan.* *.trail _spin_nvr.tmp 2>/dev/null || true
