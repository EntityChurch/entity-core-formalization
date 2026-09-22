# ============================================================================
# entity-core-formalization — ROOT Makefile  (make is the door)
#
# Formal design-assurance for the Entity Core Protocol. Four model checkers,
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
# Honest scope: this verifies MODELS of the design AT THE PIN, not the prose and not the
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
        check-provers crosscheck matrix specdrift specdrift-gate driftclaim leanseam \
        lean lean-image lean-smoke leanproof leanproof-neg leanlemma leanlemma-neg \
        coverage runcount ledgercount enginecount retractcheck trackcheck specfreeze \
        obligations floorgap clean caps

# Where each track's live spec lives is DERIVED, per track, from TRACKS.toml's
# `source_repo_path` + `source_dir` -- core from `entity-core-protocol/specs`, the three
# extensions from `entity-system-architecture/specs/extensions`. It is not a variable here
# any more, because one variable cannot name four trees and hard-wiring the core one is
# exactly how `specdrift` spent two days as a one-of-four gate.
#
# To measure a single track against a tree somewhere else, both flags are required:
#   python3 tools/spec-drift.py --track core --live /path/to/specs
# `--live` without `--track` is rejected rather than guessed.

help:
	@echo "entity-core-formalization — make is the door (make + podman only)"
	@echo
	@echo "  make build    build all 5 toolchain images (needs network; ~one-time)"
	@echo "  make smoke    prove every containerized toolchain runs end-to-end"
	@echo "  make check    run the GREEN verification matrix (all 4 engines)"
	@echo "  make matrix   green + negative controls + non-vacuity witnesses (full gate)"
	@echo "  make test     alias of check — the proof matrix IS this repo's suite"
	@echo "  make specdrift  has the spec moved under the pin? (host python3 only)"
	@echo "  make ledgercount is the assumption ledger's shape stated correctly in prose?"
	@echo "  make driftclaim does every doc STATE the drift status specdrift derives?"
	@echo "                  Not in check/matrix: it can go stale with no commit here,"
	@echo "                  so run it at a release boundary and on a schedule."
	@echo "  make floorgap   which obligations sit where NO §9.1 conformance-floor row"
	@echo "                  reaches? entity-system-conformance's CQ-36, asked of the whole"
	@echo "                  snapshot instead of a revision diff. Not a gate: reads a"
	@echo "                  sibling tree, so it is the driftclaim class by construction."
	@echo "  make lean       the LEAN SEAM TIER: leanseam + leanproof + leanlemma + controls."
	@echo "                  Needs the keystone sibling, so it is NOT in matrix —"
	@echo "                  see docs/LEAN-SEAM.md §5/§7 for why a skip would be worse."
	@echo "    make leanseam    has the cited Lean TEXT moved? (host python3 only)"
	@echo "    make leanproof   do THEIR cited PROOFS still hold? (needs entity-lean)"
	@echo "    make leanlemma   do OUR results about their definitions hold, and does"
	@echo "                     the A-31/K2 differential still produce its published"
	@echo "                     numbers? (lean/lemmas/, needs entity-lean)"
	@echo "    make lean-image  build the entity-lean toolchain image (network)"
	@echo "  make specfreeze are the vendored spec snapshots still byte-identical"
	@echo "                  to their own MANIFEST digests? (a pin that can move is not a pin)"
	@echo "  make trackcheck which proof track does each model file belong to?"
	@echo "                  (core / attestation / quorum / identity -- TRACKS.toml)"
	@echo "  make coverage   does COVERAGE-MATRIX.md match what the models actually cite?"
	@echo "  make obligations how much of each pinned spec's NORMATIVE surface is OUTSIDE"
	@echo "                  the models? The one gate here whose denominator is the SPEC's,"
	@echo "                  not ours -- every other one divides by an artifact of ours."
	@echo "  make runcount   is the published run total still what the gate tables produce?"
	@echo "  make enginecount how many ENGINES carry each subject, and which rest on one?"
	@echo "                  (D16 -- docs/CORROBORATION.md is the declaration)"
	@echo "  make retractcheck does any live doc still state a claim we WITHDREW?"
	@echo "                  (D14's grep-the-phrasing rule -- docs/RETRACTIONS.toml)"
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

# The 6th image, `entity-lean`, is deliberately NOT built here. `build` provisions exactly
# what `make matrix` needs on a bare clone; entity-lean serves only `make lean`, which needs
# a keystone sibling a bare clone does not have. Build it with `make lean-image`.

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
# Coverage: does the coverage CLAIM match the models' own §-citations? (see below)
# TLA+ : 11 modules bounded-exhaustive (TLC, safety+liveness; + Store's liveness
#        slice) + 23 invariants proven inductive/unbounded (Apalache).
# Spin : all 11 modules independently re-encoded (7 safety + LTL, 4 structural
#        safety-only) — the cross-check that the TLA+ transcription is faithful.
# Provers: 15 ProVerif + 14 Tamarin active-attacker lemmas (lockstep), each
#        graded against a declared per-query / per-lemma verdict table.
# Negative controls and non-vacuity witnesses are NOT in this target — see
# `make matrix`, which is the honest full gate. See docs/PROPERTIES.md.
check: specfreeze trackcheck coverage obligations runcount ledgercount enginecount retractcheck check-tla check-spin check-provers
	@echo
	@echo "GREEN matrix complete — every modeled property held. This certifies"
	@echo "MODELS of the design at the pin (see docs/PROPERTIES.md for proven-vs-modeled)."
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
matrix: specfreeze trackcheck coverage obligations runcount ledgercount enginecount retractcheck
	$(MAKE) -C tla     matrix
	$(MAKE) -C spin    green
	$(MAKE) -C spin    neg
	$(MAKE) -C tamarin matrix
	@echo
	@echo "FULL matrix complete — properties held, controls caught, witnesses fired."
	@echo "NOT covered by this target: the Lean seam tier ('make lean'), which needs a"
	@echo "keystone sibling checkout. It is excluded rather than skipped — see the target."

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
	@python3 tools/spec-drift.py || true

specdrift-gate:
	@python3 tools/spec-drift.py

# --- driftclaim: does the PROSE state the drift status the measurement derives? ----------
# D15's third enforcement point, after `coverage` and `runcount`, and it was earned the same
# way: eight canonical documents said "`make specdrift` reports no drift" while all three
# pinned files differed from live, two of them claiming "byte-for-byte across all three
# normative files". The claim was tied to no derivation, `specdrift` is wired `|| true` so
# running it cannot fail, and `specdrift-gate` — which can — was invoked by NO target.
#
# D13 — what does this assert? That every site in CLAIM_SITES states the derived status, and
# that every site still states one AT ALL: silence fails here, because deleting the sentence
# is otherwise the cheapest way to go green. What it does NOT assert: that the prose around
# the anchor describes the drift correctly, or that no undeclared site contradicts it.
#
# WHY THIS ONE IS NOT LIKE THE OTHERS, and why it is not in `check` or `matrix`. Every other
# stale-claim gate here guards a number WE make stale by editing our own tree, so running it
# on our diffs suffices. This claim goes stale when a SIBLING REPO COMMITS — our tree
# untouched, every other gate green. Running it only on change cannot reach that in
# principle. It also needs ../entity-core-protocol, and `matrix` must run on a bare clone
# with make + podman alone. So, like `leanseam`, it is EXCLUDED rather than skipped inside,
# and it FAILS LOUDLY on a missing sibling instead of passing quietly. Run it at a release
# boundary and on a schedule.
driftclaim:
	@python3 tools/spec-drift.py --check-claims

# --- floorgap: which obligations sit where NO §9.1 conformance-floor row reaches? ---------
# `entity-system-conformance`'s CQ-36 asked arch whether six new cross-peer MUSTs from
# 0.8.2.22-.24 are floor or declared non-floor, and said plainly that it found them by diffing
# revisions: "the diff selects where to start reading; it must never select where to stop."
# This asks the same question of the whole snapshot.
#
# NOT A GATE, and deliberately not in `check` or `matrix` — same reasoning as `driftclaim` and
# `leanseam`: one input is ../entity-system-conformance, a sibling tree, so nothing that runs on
# our diffs can see it move. It is the `driftclaim` class by construction.
#
# D13 — what does it assert? That the snapshot it measures is byte-identical to the one that
# seat pins (a mismatch is a REFUSAL, not a warning), that the §9.1 citation scan still works
# (named control sections must come back FLOORED), and that our reading of §9.1 agrees with
# their derived ECP-INDEX. What it does NOT assert: that an unfloored obligation BELONGS on the
# floor (arch's ruling, and CQ-36 is the ask), or that a floored one is TESTED — §3.1 is
# floored by ECP-R7 and carries the MUST that enabled the 0.8.2.23 forgery. A floor row is not
# a vector. The unit is the SECTION, so every error under-reports the gap.
floorgap:
	@python3 tools/floorgap.py

# --- leanseam: has the Lean side moved under the assumption ledger? ----------
# docs/LEAN-SEAM.md records, per abstraction in the models, the proposition the
# model RELIES ON and the Lean theorem that discharges it. Those correspondences
# are a human reading of two texts; this detects when one of the texts changes.
#
# D13 — what does this assert? Exactly one claim: nothing on the Lean side has
# moved under us (pinned files byte-identical; every cited name still present and
# still under a `#print axioms` gate; prose citations and pin block in sync both
# ways). It does NOT assert any correspondence is CORRECT — that is the human
# reading, and re-doing it is the work a red run is asking for.
#
# Deliberately NOT part of `make matrix`: matrix must run on a bare clone with
# only make + podman, and this needs a sibling keystone checkout. A target folded
# into the gate that skips when its input is absent asserts nothing — so this one
# FAILS LOUDLY on a missing sibling rather than passing quietly. Host python3 only.
KEYSTONE ?= ../entity-core-keystone

leanseam:
	@python3 tools/lean-seam.py --keystone "$(KEYSTONE)"

# --- lean: the SEAM TIER — the text has not moved AND the proofs still hold --------------
# `leanseam` answers "is the ledger still about the current Lean text?". It cannot answer
# "does that text still prove what the ledger says it proves", and until this tier existed
# nothing did: `lake build EntityCoreProofs` is called "the proof check" in the keystone
# lakefile and three of its status docs, and is invoked by no Makefile, script or workflow
# in that tree. Ten rows of our ledger cited a Lean theorem by name and rested on a build
# nobody ran (Class L was eleven rows on 2026-08-30 — nine CLOSED, two CLOSED-MODULO-H, and
# L2 closed by construction with no theorem to run; "eleven CLOSED" was a recalled figure,
# see D15). Those are the figures AT THE FINDING and are left there deliberately; the tier
# has since paid out and the live counts are 13 rows / 12 CLOSED / 40 gates. Derive them
# from `make leanseam` and `make leanproof`, which print them — do not recall them.
#
# D13 — what does `leanproof` assert, and what else satisfies it? NOT lake's exit status,
# which is satisfied by a proof containing `sorry` (a WARNING in Lean; lake prints "Build
# completed successfully" and exits 0) and by a hand-written `axiom` standing in for a proof
# (no warning at all). Both were built and observed, not reasoned about — docs/LEAN-SEAM.md
# §7. It asserts the DECLARED AXIOM SET of every `#print axioms` gate, in both directions,
# plus the tie to the ledger's own pin block. `leanproof-neg` is those two cases plus a
# deleted gate line and a broken proof, each required to fail for its own stated reason.
#
# Why not in `matrix`: the root matrix must run on a bare clone with make + podman alone,
# and this needs the keystone sibling. A gate that silently skips its input asserts nothing.
lean: leanseam leanproof leanproof-neg leanlemma leanlemma-neg
	@echo
	@echo "LEAN SEAM TIER complete — cited text unmoved, cited proofs hold, controls caught,"
	@echo "and our own results about the peer's definitions re-derived (A-31/K2)."
	@echo "NOTE: this asserts the Lean side is SOUND, never that the correspondences in"
	@echo "docs/LEAN-SEAM.md §1 are the RIGHT ones. That reading is still a human's."

lean-image:
	$(MAKE) -C lean image

lean-smoke:
	$(MAKE) -C lean smoke KEYSTONE=$(KEYSTONE)

leanproof:
	$(MAKE) -C lean green KEYSTONE=$(KEYSTONE)

leanproof-neg:
	$(MAKE) -C lean neg KEYSTONE=$(KEYSTONE)

# --- leanlemma: do OUR Lean results about the peer's definitions still hold? -------------
# A SECOND, SEPARATE claim from `leanproof`, and the separation is the point. `leanproof`
# watches keystone's tree: its subject is somebody else's proofs. `lean/lemmas/` is ours —
# the A-31 star-free theorem (`matchesSeg` on a star-free pattern IS list equality, all
# lengths) and the K2 differential behind it. Folding ours into theirs would mean a typo of
# ours turns red the one gate whose job is reporting movement in a tree we do not control.
#
# It also closes a reproducibility hole this repo made on 2026-09-10: the sweep that
# answered arch's A-31 hold ran in a scratch directory and was never committed, so the
# measurement a counterpart has now folded against could not be re-run from this tree.
# `eval` rows put its numbers under the gate — 3276 pairs, 108 disagreements, 1521 star-free
# pairs clean — and `site` rows fail the build when a document still states a figure the
# sweep no longer produces.
#
# D13 — what does this assert? NOT lake's exit status: a `sorry` is a warning and exits 0,
# a substituted `axiom` exits 0 with no warning at all. It asserts the declared AXIOM SET of
# every `#print axioms` gate under our namespace, the exact `#eval` output one-to-one, and
# the declared prose sites. `leanlemma-neg` is four controls, each required to fail for its
# OWN reason — including `neg-eval`, which narrows the differential's input set so the sweep
# reports clean while asserting nothing, which is the failure a green cannot show you.
leanlemma:
	@python3 tools/lean-lemma.py --keystone "$(KEYSTONE)" --caps "$(PODMAN_RUN_CAPS)"

leanlemma-neg:
	@python3 tools/lean-lemma.py --keystone "$(KEYSTONE)" --caps "$(PODMAN_RUN_CAPS)" --neg

# --- retractcheck: is a withdrawn claim still live somewhere? ----------------
# D14's second half has always been a rule with no program behind it: "a withdrawn claim has a
# shape, and the shape is its PHRASING, not its subject -- grep the retracted words." It was
# earned three times and failed a fourth and fifth on 2026-09-09, when two documents kept the
# pre-2026-09-09 engine position while `runcount` and `enginecount` were green over both.
#
# D13 -- what does this assert? That every pattern in docs/RETRACTIONS.toml occurs ZERO times
# across the live document set (git-tracked, minus dated history and frozen pins) and at least
# once at its own declared `witness`. That second half is the per-row positive control, and it
# is the difference between this gate and a list of regexes nobody has run: a mistyped pattern
# reports a clean pass forever. What it does NOT assert is that the registry is COMPLETE --
# nothing can derive the set of claims we have withdrawn, and the tool says so in its output.
retractcheck:
	@python3 tools/retractcheck.py

# --- coverage: does the coverage CLAIM match what the models actually cite? ---
# Matrix A in docs/COVERAGE-MATRIX.md is DERIVED from the models' own §-citations so the
# number cannot be one someone chose. Deriving is not checking: the derivation was done by
# hand and written into prose nothing re-reads, and two phantom rows lived there for a
# release — §4.7 (a section-range endpoint in one comment) and §6.9 (two out-of-scope
# DISCLAIMERS). D13 asked of a derived metric: what does this number assert, and what else
# produces it? A § mention is not a claim.
#
# Asserts: the cited §N.M set equals Matrix A's rows in BOTH directions; the stated
# numerator equals that set's size; the denominator equals the pinned spec's numbered-section
# count; and neither citation-hygiene tripwire fires. Does NOT assert the engine columns —
# a citation says a model is ABOUT a section, not which engine verifies what. Host python3
# only, so it is safe to keep in `check`.
coverage:
	@python3 tools/coverage-check.py

# --- obligations: how much of the pinned spec is OUTSIDE the models? --------------------
# THE ONE GATE HERE WHOSE DENOMINATOR IS NOT OURS. `coverage` divides by the sections our
# models cite, `runcount` by our gate tables, `enginecount` by our green tables, `ledgercount`
# by our ledger. All four were green on 2026-09-14 when 0.8.2.23 closed a capability forgery
# whose enabling MUST -- `spec-data/v0.8.2` §3.1, "The content_hash MUST match the map key" --
# sat in our own pin with no enforcing operation and no vector, in a section no model cites.
# That is D17's shape, never pointed at the core track.
#
# D13 -- what does this assert? That the obligation surface OUTSIDE the models is enumerated
# and every obligation-bearing section none of them cites carries a WRITTEN disposition from a
# closed vocabulary. What else satisfies it? A tree where every row says UNEXAMINED -- allowed
# deliberately, and the tool prints that count as its HEADLINE so the number a reader sees is
# the size of the hole rather than the fact that someone wrote it down.
#
# It does NOT assert any obligation is verified. A cited section can carry engine dots in
# Matrix A with every one of its MUSTs unmodeled; closing that needs per-obligation ids, which
# `entity-system-conformance` is minting (ECP-R1..R98). Consume those when they land.
obligations:
	@python3 tools/obligations.py

# --- runcount: is the published run TOTAL still what the gate tables produce? ------------
# The companion to `coverage`, and the other half of STATUS §Next item 9. The matrix run
# total was hand-derived and hand-copied into six places; it moved 238 -> 242 -> 258 in one
# week and two sites were missed, one of them the blurb that decides what a public reader
# sees (it sat at 203). D15: a derived number is a claim, and a claim needs a gate.
#
# Asserts: the per-target counts derived from TLC_*/APALACHE_*/SPIN_*/PV_*/TM_* in the three
# engine Makefiles, their total, that each declared prose site states that total, and that
# docs/STATUS.md's per-slice table agrees row by row. Does NOT assert the runs pass (that is
# `matrix`), nor that every run is in a table — a run in no gate table is invisible to this
# and to the matrix alike, which is exactly how `BindingReplayBug` went unrun for a release.
#
# It grades ANCHORED sites, not "any number near the word runs": the first draft did the
# latter and falsely flagged three files whose 203/204/238 are true statements about the
# past. A gate that cannot tell a live claim from a historical one would have had us delete
# accurate history to go green. Host python3 only, so it is safe in `check`.
runcount:
	@python3 tools/runcount.py

# --- ledgercount: does the prose state the assumption ledger's ACTUAL shape? -------------
# The third of the D15 derived-claim gates, and the one with the worst record behind it.
# docs/LEAN-SEAM.md's row and verdict counts have been published WRONG four times: "eleven
# CLOSED rows" across five files; the Class-L verdicts in the tier audit; "21 of 23 rows are
# CLOSED and the two open ones are L1 and L7" (every number wrong AND the attribution — L1
# and L7 were CLOSED-MODULO-H, and the actually-open rows were T4 and O4); and "14 CLOSED …
# 2 OPEN", written two hours before O4 closed in the same session. `leanseam` and `leanproof`
# derive THEOREM counts and say nothing about rows or verdicts, so none of the four was ever
# reachable by an existing gate.
#
# D13 — what does this assert? The counts, parsed from the ledger itself, AND the row
# structure (contiguous ids per class, so a silently deleted row fails rather than producing
# a smaller number that still looks tidy), AND that every declared prose site states them.
# What else satisfies it? Nothing silent — a site that stops making the claim fails.
# What it does NOT assert: that any verdict is CORRECT. A row reading CLOSED that should read
# OPEN passes here exactly as an honest one does; the ledger is a human reading of two texts
# and `leanseam` says so in its own output.
#
# ITS FIRST DRAFT ANCHORED ROW COUNTS ONLY — and would have gone green on all four historical
# errors, because every one of them was a VERDICT error and three had the row total right.
# Found by flipping a verdict and watching it pass. `closed` and `open` are anchored now.
#
# Unlike `driftclaim`, this one belongs in `check` and `matrix`: it depends on nothing outside
# this repo, so it goes stale only when we edit our own tree — which is exactly the condition
# a change-triggered gate covers. Host python3 only.
ledgercount:
	@python3 tools/ledgercount.py

# --- enginecount: how many ENGINES actually carry each subject? --------------------------
# The enforcement point for D16 (two structurally different engines per published claim, and a
# one-engine claim declares itself). `docs/CORROBORATION.md` is the declaration; the GREEN
# tables in the three engine Makefiles are the evidence; this derives one from the other.
#
# WHY IT EXISTS: the corroboration figure lived only in a sentence. "Five of the nine extension
# modules rest on two engines" went into `AGENTS.md` by hand on 2026-09-08, was true that day,
# and was stale within a day — the run total's failure (three times in one week), the ledger
# counts' failure (four times) and the coverage pair's failure, in a fourth artifact, with no
# gate able to see it because there was no ledger to derive from.
#
# D13 — what does this assert? Membership of every model file in exactly one subject (both
# directions vs TRACKS.toml); that each row's engine set EQUALS the one derived from the green
# tables; that every subject under two engines is declared with a reason, both directions; and
# that every declared prose site states the derived pair.
#
# What else satisfies it — the question that decided the derivation: A FILE EXISTING IS NOT AN
# ENGINE CHECKING ANYTHING. `tamarin/BindingReplayBug.spthy` is on disk with no
# `BindingReplay.spthy` beside it, so counting by extension would have published "two provers
# carry the replay result" on the strength of a file whose whole job is to fail. An engine
# counts only where its GREEN table names one of the subject's files.
#
# What it does NOT assert, said out loud: that two engines are independent of the
# TRANSCRIPTION. They are not — one author, one reading, one 5th wall — and the tool prints so.
#
# In `check` and `matrix`: its inputs are entirely inside this repo. Host python3 only.
enginecount:
	@python3 tools/enginecount.py

# --- trackcheck: which PROTOCOL is each model file about? --------------------------------
# Until 2026-09-06 this repo had one subject and every artifact assumed it. Extension
# protocols (attestation, quorum, identity) arrive with their own spec bodies and their own
# section numbering, which turns that assumption into a claim. `TRACKS.toml` is the claim;
# this is the gate.
#
# The failure it heads off is not hypothetical and it arrives THROUGH the existing gates.
# `§(\d+\.\d+)` -- the pattern the published coverage number is derived from -- is
# DOCUMENT-BLIND: `EXTENSION-ATTESTATION §5.7` and core `§5.7` are the same token, and core
# already has a `5.7` row. The first extension model's citations would have been credited to
# core's grid with `make coverage` reporting OK -- a phantom row produced by the gate built to
# stop phantom rows. Second half, quieter: `coverage-check.py` and `spec-drift.py` globbed
# `tla/*.tla` NON-RECURSIVELY, so moving models into `tla/attestation/` -- the obvious first
# reorganization -- would have hidden them from both while both stayed green. Both now read
# the registry; this asserts the registry is complete.
#
# D13 -- what does this assert? That every model file found by a RECURSIVE walk belongs to
# exactly one track and that every declared file exists (both directions), that the walk
# agrees with git and no unstaged-but-runnable model file exists, that each track is
# well-formed for its status, and that the declared prose sites state the inventory. What
# else satisfies it? Nothing silent: a track that stops publishing its count fails, and a
# `scoped` track that acquires a model file fails until it is promoted WITH a pin -- the step
# where someone states which snapshot the results are about.
#
# What it does NOT assert, said out loud: that a file is on the RIGHT track. Membership is a
# human's declaration. Same standing caveat as the assumption ledger's.
#
# In `check` and `matrix`, unlike `driftclaim`: its inputs are entirely inside this repo, so a
# change-triggered gate is sufficient in kind. Host python3 + git only.
trackcheck:
	@python3 tools/trackcheck.py

# --- specfreeze: is every vendored snapshot still the bytes it claims to be? -------------
# `AGENTS.md`: "An existing spec-data/vX/ snapshot is FROZEN ... a pin whose bytes can change
# is not a pin, and every result here is quoted against one." `v0.8.2/MANIFEST.md` says the
# same in the same words and offers `Verify: sha256sum spec-data/v0.8.2/*.md` -- an instruction
# to a human. NOTHING re-hashed a snapshot. The most strongly stated rule in this repo had no
# enforcement point at all, which by AGENTS-STANDARD's own rule means it did not count.
#
# It is not a small hole: every published result is a statement about those bytes, `specdrift`
# measures FROM them and `coverage` counts its denominator IN them, so a drifted snapshot moves
# all three at once and reads as a MODEL error rather than a data error. (Checked by hand
# before the tool existed -- all six matched. The point is that nobody could have known.)
#
# D13 -- what does it assert? Per snapshot: every .md that is not MANIFEST/README has a SHA-256
# row and hashes to it, AND every row has a file. Both directions, because an UNPINNED file in
# a pinned directory is as broken as one whose bytes moved. What else satisfies it? Not an
# empty snapshot and not a MANIFEST with no digest rows -- both FAIL rather than passing
# vacuously. What it does NOT assert: that a snapshot faithfully copies its upstream. That is
# checked once, at vendor time, against the source blob, and is unknowable afterwards from
# inside this repo -- because upstream moves and a pin must not.
#
# Teeth-tested five ways by breaking it: mutated file, unpinned file added, pinned file
# removed, manifest byte-count wrong with a right digest, manifest with no rows.
#
# In `check` and `matrix`: it reads only this repo. Host python3 only.
#   Vendor a new snapshot:  tools/vendor-spec.py vendor --track <t> --date YYYY-MM-DD
#   (refuses to write into an existing snapshot -- that is the freeze, at the only
#    moment it can be enforced)
specfreeze:
	@python3 tools/vendor-spec.py verify

clean:
	$(MAKE) -C tla     clean
	$(MAKE) -C spin    clean
	$(MAKE) -C tamarin clean
	$(MAKE) -C lean    clean

# Print the resolved caps so a downloader can see what ceiling is in force.
caps:
	@echo "CAP_MEM=$(CAP_MEM)  CAP_SWAP=$(CAP_SWAP)  CAP_PIDS=$(CAP_PIDS)  CAP_CPUS=$(CAP_CPUS)"
	@echo "BUILD: $(PODMAN_BUILD_CAPS)"
	@echo "RUN  : $(PODMAN_RUN_CAPS)"
