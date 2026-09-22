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
        check-provers crosscheck matrix specdrift specdrift-gate clean caps

# Where the live spec lives, for `make specdrift`. Override per-host:
#   make specdrift LIVE_SPECS=/path/to/entity-core-protocol/specs
LIVE_SPECS ?= ../entity-core-protocol/specs

help:
	@echo "entity-core-formalization — make is the door (make + podman only)"
	@echo
	@echo "  make build    build all 5 toolchain images (needs network; ~one-time)"
	@echo "  make smoke    prove every containerized toolchain runs end-to-end"
	@echo "  make check    run the GREEN verification matrix (all 4 engines)"
	@echo "  make matrix   green + negative controls + non-vacuity witnesses (full gate)"
	@echo "  make test     alias of check — the proof matrix IS this repo's suite"
	@echo "  make specdrift  has the spec moved under the pin? (host python3 only)"
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
# TLA+ : 9 modules bounded-exhaustive (TLC, safety+liveness; + Store's liveness
#        slice) + 9 invariants proven inductive/unbounded (Apalache).
# Spin : the 6 concurrency modules independently re-encoded (safety + LTL) —
#        the cross-check that the TLA+ transcription is faithful.
# Provers: 15 ProVerif + 14 Tamarin active-attacker lemmas (lockstep).
# Negative controls and non-vacuity witnesses are NOT in this target — see
# `make matrix`, which is the honest full gate. See docs/PROPERTIES.md.
check: check-tla check-spin check-provers
	@echo
	@echo "GREEN matrix complete — every modeled property held. This certifies"
	@echo "MODELS of the V8 design (see docs/PROPERTIES.md for proven-vs-modeled)."
	@echo "NOTE: green alone does not show the properties COULD have failed, nor"
	@echo "that the models reach any interesting state. Run 'make matrix' for that."

# --- matrix: green + negative controls + non-vacuity witnesses ---------------
# The full gate, and the one to trust. Three questions, not one:
#   green    — does every modeled property hold?
#   neg      — could it have failed? (every *Bug control MUST be caught)
#   witness  — does the model do anything at all? (every witness MUST be violated)
# A green-only run cannot distinguish a correct model from an inert one; the
# witness slice is what closes that, and it was missing from the TLA+ track
# entirely before 0.8.2 (docs/PROPERTIES.md §C.4).
matrix:
	$(MAKE) -C tla     matrix
	$(MAKE) -C spin    green
	$(MAKE) -C spin    neg
	$(MAKE) -C tamarin matrix
	@echo
	@echo "FULL matrix complete — properties held, controls caught, witnesses fired."

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

# --- specdrift: has the pin gone stale? --------------------------------------
# Every result here is a statement about spec-data/<pin>/, never about the live
# spec. This makes that distinction checkable instead of asserted: it reports
# which spec sections THE MODELS CITE have moved since the pin was taken, and
# which model files depend on them. Host python3 only — no toolchain, no image.
#
# `specdrift` REPORTS (always succeeds — drift is information, not a build break).
# `specdrift-gate` FAILS on drift, for use as a precondition.
specdrift:
	@python3 tools/spec-drift.py --live "$(LIVE_SPECS)" || true

specdrift-gate:
	@python3 tools/spec-drift.py --live "$(LIVE_SPECS)"

clean:
	$(MAKE) -C tla     clean
	$(MAKE) -C spin    clean
	$(MAKE) -C tamarin clean

# Print the resolved caps so a downloader can see what ceiling is in force.
caps:
	@echo "CAP_MEM=$(CAP_MEM)  CAP_SWAP=$(CAP_SWAP)  CAP_PIDS=$(CAP_PIDS)  CAP_CPUS=$(CAP_CPUS)"
	@echo "BUILD: $(PODMAN_BUILD_CAPS)"
	@echo "RUN  : $(PODMAN_RUN_CAPS)"
