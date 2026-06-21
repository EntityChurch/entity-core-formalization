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

.PHONY: green
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
