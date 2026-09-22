# ============================================================================================
# The Lean seam tier — do the proofs our assumption ledger cites still HOLD?
#
# This workspace holds NO Lean source. `docs/LEAN-SEAM.md` cites 21 theorems (+1 pinned as a
# rejected correspondence) in the sibling `entity-core-keystone` peer; this builds them, from
# a read-only copy of that peer's tree, and grades the result. See ./README.md for what the
# tier asserts and — more to the point — what it does not.
#
#   make image        build the entity-lean toolchain image (the only network step)
#   make smoke        prove the toolchain runs and matches the version keystone pins
#   make green        the proofs hold: build + declared axiom sets + ledger tie   (1 run)
#   make neg          the five negative controls, each with its declared reason   (5 runs)
#   make matrix       green + neg                                                 (6 runs)
#   make clean        remove the scratch worktrees
#
# NOT IN `make matrix` AT THE REPO ROOT, deliberately, for the same reason `leanseam` is not:
# the root matrix runs on a bare clone with only make + podman, and this needs a sibling
# keystone checkout. A gate folded into the matrix that SKIPS when its input is absent
# asserts nothing — the exact failure D13 exists to remove — so this one fails loudly on a
# missing sibling and is reached by `make lean` at the root instead.
#
# NOT SEEN BY `make coverage`. The coverage grid is derived from §-citations in
# tla/*.tla, spin/*.pml, tamarin/*.{pv,spthy} only. A `§` written in this directory is
# invisible to that derivation — it can neither inflate the coverage number nor be checked
# by it. Section numbers below and in proof-gate.expect are orientation for a reader, not
# coverage claims.
# ============================================================================================

# Shared podman resource caps (PODMAN_RUN_CAPS / PODMAN_BUILD_CAPS) — every podman
# invocation here carries them, as everywhere else in this repo.
include ../caps.mk

IMAGE    ?= entity-lean
PODMAN   ?= podman
# Relative paths are resolved against the REPO ROOT by tools/lean-proof.py, so this reads
# the same here as it does in the root Makefile (which is where `make lean` sets it).
KEYSTONE ?= ../entity-core-keystone
GATE     := python3 ../tools/lean-proof.py --keystone "$(KEYSTONE)" --image $(IMAGE) \
            --caps "$(PODMAN_RUN_CAPS)"

.PHONY: image smoke green neg matrix clean

image:
	$(PODMAN) build $(PODMAN_BUILD_CAPS) -t $(IMAGE) -f Containerfile .

# Gate zero: does the toolchain run, and is it the Lean the peer pins? A proof checked by a
# different compiler than the one that ships is not a check of the peer, so the version
# agreement is asserted on every green run too — this target just makes it the first thing
# you can ask.
smoke:
	@$(PODMAN) run --rm --network=none $(PODMAN_RUN_CAPS) $(IMAGE) bash -lc 'lean --version && lake --version'
	@ks="$(KEYSTONE)"; case "$$ks" in /*) ;; *) ks="../$$ks";; esac; \
	  echo "keystone pins: $$(cat $$ks/protocol-generator/lean/lean-toolchain 2>/dev/null \
	    || echo '<no sibling checkout — this tier needs one; see ./README.md>')"

# GREEN — the proofs hold. Graded against lean/proof-gate.expect (40 declared axiom-gated
# declarations, exact axiom set per declaration, in both directions) plus the tie to the
# ledger's own pin block. NOT graded on lake's exit status: a `sorry` and a hand-written
# `axiom` both exit 0, which is what `neg-sorry` and `neg-axiom` below demonstrate.
green:
	@$(GATE)

# NEGATIVE CONTROLS — could the green have failed? Each mutates the peer's proof source in a
# scratch copy (keystone's tree is mounted read-only and never written) and must fail for its
# OWN declared reason, not merely fail:
#   neg-sorry    a `sorry` in a cited theorem     -> lake exits 0. SORRY_WARNING + 3x SORRY_AX
#   neg-axiom    an `axiom` replacing a proof     -> lake exits 0, no warning. 3x UNTRUSTED_AXIOM
#   neg-ungate   the `#print axioms` line deleted -> MISSING_GATE + LEDGER_UNCOVERED
#   neg-broken   a broken proof                   -> BUILD_ERROR (the only one exit status sees)
# The first two are the whole argument for this gate existing in the shape it does.
neg:
	@$(GATE) --neg

matrix: green neg

clean:
	rm -rf _work
