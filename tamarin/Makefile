# Spike B — Tamarin/ProVerif toolchain, make + podman only (no host installs).
#
# Two images (both fiddly to install on a host, so both containerized):
#   entity-proverif  (lead — more automated; Containerfile.proverif, opam install)
#   entity-tamarin   (comparison; Containerfile.tamarin, published image)
# Run both on the SAME cap-unforgeability fragment; report which closes cleaner.
#
# Usage:
#   make image                      build BOTH toolchain images
#   make image-proverif             build just the ProVerif image
#   make image-tamarin              build just the Tamarin image
#   make smoke                      prove both provers resolve in their containers
#   make proverif THEORY=Unforge    run ProVerif on Unforge.pv (lead)
#   make tamarin  THEORY=Unforge    run Tamarin auto-prove on Unforge.spthy (compare)
#   make tamarin-interactive THEORY=Unforge   hand-guided proof (port 3001)
#   make clean                      remove proof artifacts

# Shared podman resource caps (PODMAN_BUILD_CAPS / PODMAN_RUN_CAPS).
include ../caps.mk

PV_IMAGE  ?= entity-proverif
TM_IMAGE  ?= entity-tamarin
THEORY    ?= Unforge
PODMAN    ?= podman
MOUNT     := -v $(CURDIR):/work:Z -w /work
PV_RUN    := $(PODMAN) run --rm $(PODMAN_RUN_CAPS) $(MOUNT) $(PV_IMAGE)
TM_RUN    := $(PODMAN) run --rm $(PODMAN_RUN_CAPS) $(MOUNT) $(TM_IMAGE)

.PHONY: image image-proverif image-tamarin smoke proverif tamarin tamarin-interactive clean

image: image-proverif image-tamarin

image-proverif:
	$(PODMAN) build $(PODMAN_BUILD_CAPS) -t $(PV_IMAGE) -f Containerfile.proverif .

image-tamarin:
	$(PODMAN) build $(PODMAN_BUILD_CAPS) -t $(TM_IMAGE) -f Containerfile.tamarin .

# Gate zero for Spike B: do both provers resolve in their containers?
smoke:
	@echo "== ProVerif ==" && $(PV_RUN) proverif -help 2>&1 | head -3 || true
	@echo "== Tamarin ==" && $(TM_RUN) tamarin-prover --version 2>&1 | head -3 || true

proverif:
	$(PV_RUN) proverif $(THEORY).pv

tamarin:
	$(TM_RUN) tamarin-prover --prove $(THEORY).spthy

# Interactive Tamarin for hand-guided proofs when auto-prove stalls (the go/no-go
# gate is precisely "auto vs. heavy hand-holding").
tamarin-interactive:
	$(PODMAN) run --rm -it $(PODMAN_RUN_CAPS) $(MOUNT) -p 3001:3001 $(TM_IMAGE) \
		tamarin-prover interactive --interface='*4' $(THEORY).spthy

# Green sweep — the active-attacker lemmas that MUST hold (secure theories only,
# no *Bug variants). ProVerif proves all 13; Tamarin proves 12 (RevokeMech is the
# documented non-terminating tool-asymmetry — EXCLUDED here; run it by hand with a
# kill switch, see PHASE2-FORMALIZATION-REPORT.md). Bug controls run separately.
PV_GREEN := Binding BindingReplay Caveats DeepChain DeepChainN DepthBound Expiry \
            Multisig MultisigKN NoEscalation PersistentRecheck Revoke Unforge
TM_GREEN := Binding Caveats DeepChain DeepChainN DepthBound Expiry \
            Multisig MultisigKN NoEscalation PersistentRecheck Revoke Unforge

.PHONY: proverif-green tamarin-green green
proverif-green:
	@for t in $(PV_GREEN); do \
	  echo "== ProVerif $$t =="; $(PV_RUN) proverif $$t.pv || exit 1; \
	done

tamarin-green:
	@for t in $(TM_GREEN); do \
	  echo "== Tamarin $$t =="; $(TM_RUN) tamarin-prover --prove $$t.spthy || exit 1; \
	done

# Both provers, lockstep — the active-attacker green slice.
green: proverif-green tamarin-green

clean:
	rm -rf output/ *.proof 2>/dev/null || true
