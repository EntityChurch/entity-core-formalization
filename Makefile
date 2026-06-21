# ============================================================================
# entity-core-formalization — ROOT Makefile  (make is the door)
#
# Formal design-assurance for the Entity Core Protocol V7. Four model checkers,
# all containerized: a bare host with ONLY `make` + `podman` (no native TLA+/
# Spin/Apalache/Tamarin/ProVerif toolchain) runs everything from here.
#
#   make build        build all 5 toolchain images (TLC, Apalache, Spin,
#                     ProVerif, Tamarin) — the only step that needs network
#   make smoke        prove every containerized toolchain runs end-to-end
#   make check        run the GREEN verification matrix — the properties that
#                     MUST hold, across all four engines (this is the gate)
#   make clean        remove all generated model-checker artifacts
#
# Engine-level / single-spec work delegates to the per-engine Makefiles:
#   make -C tla     ...    TLC + Apalache
#   make -C spin    ...    Spin (independent re-encoding cross-check)
#   make -C tamarin ...    ProVerif + Tamarin
#
# Honest scope: this verifies MODELS of the V7 design, not the prose and not the
# code. What is PROVEN vs only MODELED is stated exactly in docs/PROPERTIES.md
# and docs/FINAL-ASSURANCE-SUMMARY.md. Design assurance, off the release
# critical path — NOT a claim that "the protocol is proven correct."
#
# Resource caps: every podman build/run carries a hard memory ceiling so a
# runaway model-checker dies at the cap instead of thrashing the host. Tune in
# caps.mk; override per-machine via caps.local.mk or env (see RELEASE-READINESS.md).
# ============================================================================
include caps.mk

MAKE ?= make

.PHONY: help build images smoke test lint fmt check check-tla check-spin \
        check-provers crosscheck clean caps

help:
	@echo "entity-core-formalization — make is the door (make + podman only)"
	@echo
	@echo "  make build    build all 5 toolchain images (needs network; ~one-time)"
	@echo "  make smoke    prove every containerized toolchain runs end-to-end"
	@echo "  make check    run the GREEN verification matrix (all 4 engines)"
	@echo "  make test     alias of check — the proof matrix IS this repo's suite"
	@echo "  make clean    remove generated model-checker artifacts"
	@echo "  make caps     print the active resource caps"
	@echo
	@echo "ADR-0019 note (class-4 formal-verification repo): lint/fmt are no-ops —"
	@echo "the model checkers (make check) are the static check; the formal specs"
	@echo "have no autoformatter and spec-data is SHA-pinned (must not be rewritten)."
	@echo
	@echo "Sub-slices:  make check-tla | check-spin | check-provers"
	@echo "Per-engine:  make -C {tla,spin,tamarin} <target>"

# --- build: all toolchain images (the only network step) --------------------
# `images` is kept as an alias so `build` is the conventional Tier-1 entry point.
build:
	$(MAKE) -C tla     image
	$(MAKE) -C tla     apalache-image
	$(MAKE) -C spin    image
	$(MAKE) -C tamarin image          # builds BOTH ProVerif + Tamarin

images: build

# --- ADR-0019 Tier-1 verbs (class-4 formal-verification repo) ----------------
# test = the GREEN proof matrix (alias of check): for a verification repo the
# model-checker run IS the test suite. lint/fmt are honest no-ops: the model
# checkers are the static check, the formal languages (TLA+/Spin/Tamarin) have
# no autoformatter wired, and spec-data/ is SHA-pinned and MUST NOT be rewritten.
test: check

lint:
	@echo "no separate static linter — the model checkers ARE the check (make check)."

fmt:
	@echo "no autoformatter for the formal specs; spec-data is SHA-pinned (do not rewrite)."

# --- smoke: does each containerized toolchain run at all? --------------------
smoke:
	$(MAKE) -C tla     smoke
	$(MAKE) -C tla     apalache-smoke
	$(MAKE) -C spin    smoke
	$(MAKE) -C tamarin smoke

# --- check: the GREEN matrix — properties that MUST hold ---------------------
# TLA+ : 7 modules bounded-exhaustive (TLC, safety+liveness) + 8 invariants
#        proven inductive/unbounded (Apalache).
# Spin : the 6 concurrency modules independently re-encoded (safety + LTL) —
#        the cross-check that the TLA+ transcription is faithful.
# Provers: 13 ProVerif + 12 Tamarin active-attacker lemmas (lockstep).
# Negative controls (the *Bug variants that MUST be caught) are NOT in this
# target — they live next to the specs and in the reports; this gate asserts the
# secure side. See docs/FINAL-ASSURANCE-SUMMARY.md §3 for the full 76-run matrix.
check: check-tla check-spin check-provers
	@echo
	@echo "GREEN matrix complete — every modeled property held. This certifies"
	@echo "MODELS of the V7 design (see docs/PROPERTIES.md for proven-vs-modeled)."

check-tla:
	$(MAKE) -C tla green

check-spin:
	$(MAKE) -C spin green

check-provers:
	$(MAKE) -C tamarin green

# crosscheck is the Spin (independent encoding) + Apalache (unbounded) corroboration
# of the TLA+ track; both are already inside `check`. Exposed as its own name too.
crosscheck: check-spin
	$(MAKE) -C tla apalache-green

clean:
	$(MAKE) -C tla     clean
	$(MAKE) -C spin    clean
	$(MAKE) -C tamarin clean

# Print the resolved caps so a downloader can see what ceiling is in force.
caps:
	@echo "CAP_MEM=$(CAP_MEM)  CAP_SWAP=$(CAP_SWAP)  CAP_PIDS=$(CAP_PIDS)  CAP_CPUS=$(CAP_CPUS)"
	@echo "BUILD: $(PODMAN_BUILD_CAPS)"
	@echo "RUN  : $(PODMAN_RUN_CAPS)"
