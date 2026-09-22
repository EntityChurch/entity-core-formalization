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
# Lowercase :z — this mount is shared across TWO images (PV_RUN = $(PV_IMAGE), TM_RUN =
# $(TM_IMAGE)). Uppercase :Z relabels it private to one container and the other's relabel
# then invalidates it. Same defect as tla/Makefile; see the note there.
MOUNT     := -v $(CURDIR):/work:z -w /work
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
# no *Bug variants). ProVerif proves all 15; Tamarin proves 14 (RevokeMech is the
# documented non-terminating tool-asymmetry — EXCLUDED here; run it by hand with a
# kill switch, see PHASE2-FORMALIZATION-REPORT.md). Bug controls run separately.
# Added at 0.8.2: Malformed (§5.6 CAP-6a unrepresentable-temporal-field ingest) and
# ChainTopology (§5.8 conformance topology — a NON-ISSUING third-party verifier).
PV_GREEN := Binding BindingReplay Caveats ChainTopology DeepChain DeepChainN DepthBound \
            Expiry Malformed Multisig MultisigKN NoEscalation PersistentRecheck Revoke Unforge
TM_GREEN := Binding Caveats ChainTopology DeepChain DeepChainN DepthBound \
            Expiry Malformed Multisig MultisigKN NoEscalation PersistentRecheck Revoke Unforge

# NEGATIVE CONTROLS. Each is graded against its declared verdict table below (PV_NEG_EXPECT /
# TM_NEG_EXPECT) — NOT against "did something fail", which is what the earlier criterion asked
# and which the corresponding SECURE theory also satisfied. See the DECLARED VERDICTS header.
PV_NEG := BindingBug BindingReplayBug CaveatsBug ChainTopologyBug DeepChainBug DeepChainNBug \
          DepthBoundBug ExpiryBug MalformedBug MultisigBug MultisigKNBug NoEscalationBug \
          PersistentRecheckBug RevokeBug UnforgeBug
# `BindingReplayBug` was on disk but in NO gate list until the second gate audit — so
# `Binding.spthy`'s `no_replay` lemma, which the green slice counts and the reports quote, had
# **no negative control running anywhere in the matrix**. Its control existed and worked; it
# was simply never listed. (There is no `BindingReplay.spthy`: no-replay lives inside
# `Binding.spthy` in Tamarin, via a linear consumed-nonce fact, whereas ProVerif needs a
# separate challenge-response theory because its tables are not atomic under replication. The
# "15 ProVerif / 14 Tamarin" split is that packaging difference, not a coverage gap.)
TM_NEG := BindingBug BindingReplayBug CaveatsBug ChainTopologyBug DeepChainBug DeepChainNBug \
          DepthBoundBug ExpiryBug MalformedBug MultisigBug MultisigKNBug NoEscalationBug \
          PersistentRecheckBug RevokeBug UnforgeBug

# ============================================================================================
# DECLARED VERDICTS — the grading tables for both provers, both slices.
#
# WHY THESE EXIST. Until the second gate audit, `proverif-green` ran `proverif $t.pv ||
# exit 1` and graded on the EXIT STATUS alone. **ProVerif exits 0 even when a query is FALSE** — the fact
# already stated in the `proverif-neg` comment below, and never applied to the green slice. So
# a genuine attack found against any of the 15 secure theories would have reported GREEN. The
# green half of the ProVerif track had no verdict gate at all.
#
# `proverif-neg` was weak for the mirror-image reason. It graded on `grep '^RESULT.*is false.'`
# — but ProVerif reports a REACHABLE event as a falsified `not event(...)` query, so the
# NON-VACUITY witness that 13 of the 15 SECURE theories carry also prints `is false`. The
# secure `Revoke.pv` satisfies the criterion its own negative control was graded by. For 13 of
# 15 rows, "ok (query falsified)" carried no information about the security query.
#
# The fix is one grader and two tables: every query/lemma of every theory declares the verdict
# it MUST produce, and the run must produce exactly that set — no more, no less. The
# green/control distinction now lives entirely in the DECLARED VERDICTS, which is where it
# belongs: it makes "a control that fails for the wrong reason" a build failure, because
# failing for the wrong reason shows up as a different verdict pattern.
#
# READING A ProVerif VERDICT. `is true` = the query holds. For a `not event(X)` query that
# means X is UNREACHABLE (the security reading). For a non-vacuity query, `is false` is the
# PASS — it means the honest path is reachable. Both appear below and the difference is the
# whole point of the table.
#
# Format: THEORY|ERE matching exactly one RESULT line|true or false
# The ERE avoids ProVerif's generated variable suffixes (`g` vs `g_1`) so a re-run does not
# need a table edit; it does NOT avoid the query shape, so an edited query does.
PV_EXPECT := \
  "Binding|^RESULT event\(AcceptedExec|true" \
  "Binding|^RESULT not event\(AcceptedExec|false" \
  "BindingReplay|^RESULT inj-event\(AcceptedExec|true" \
  "BindingReplay|^RESULT event\(AcceptedExec|true" \
  "BindingReplay|^RESULT not event\(AcceptedExec|false" \
  "Caveats|AcceptedDeleg\([^,]*,nodeleg\)|true" \
  "Caveats|AcceptedDeleg\([^,]*,okdeleg\)|false" \
  "ChainTopology|pk\(skW\[\]\)|true" \
  "ChainTopology|pk\(skP\[\]\)|true" \
  "ChainTopology|pk\(skA\[\]\)|false" \
  "DeepChain|pk\(skV\[\]\)|true" \
  "DeepChain|pk\(skA\[\]\)|false" \
  "DeepChainN|pk\(skV\[\]\)|true" \
  "DeepChainN|pk\(skB\[\]\)|false" \
  "DepthBound|AcceptedLeaf\([^,]*,two\)|true" \
  "DepthBound|AcceptedLeaf\([^,]*,one\)|false" \
  "Expiry|Accepted\([^,]*,t0\)|true" \
  "Expiry|Accepted\([^,]*,t2\)|false" \
  "Malformed|AcceptedNoExpiry\([^,]*,tbad\)|true" \
  "Malformed|Accepted\([^,]*,tbad\)|true" \
  "Malformed|Accepted\([^,]*,t0\)|true" \
  "Malformed|AcceptedNoExpiry\([^,]*,tabsent\)|false" \
  "Malformed|Accepted\([^,]*,t2\)|false" \
  "Multisig|^RESULT event\(AcceptMulti\) ==>|true" \
  "Multisig|^RESULT not event\(AcceptMulti\)|false" \
  "MultisigKN|^RESULT event\(AcceptMulti\) ==>|true" \
  "MultisigKN|^RESULT not event\(AcceptMulti\)|false" \
  "NoEscalation|AcceptedDeleg\([^,]*,scopeAdmin\)|true" \
  "NoEscalation|AcceptedDeleg\([^,]*,narrow\(scopeAdmin\)\)|false" \
  "PersistentRecheck|AcceptLate|true" \
  "PersistentRecheck|AcceptEarly|false" \
  "Revoke|Accept\(pk\(skGr\[\]\)\)|true" \
  "Revoke|Accept\(pk\(skGo\[\]\)\)|false" \
  "Unforge|^RESULT event\(AcceptedRoot|true" \
  "Unforge|^RESULT event\(AcceptedDeleg|true" \
  "Unforge|^RESULT not event\(AcceptedDeleg|false"

# Negative controls. Same grader, different declared verdicts. Each control's TARGET security
# query flips to `false`; everything else must hold steady, which is what distinguishes "the
# injected defect broke the property" from "the variant broke the model".
#
# NB `BindingBug` and `UnforgeBug` declare ONE row because those two bug theories carry only
# the query their defect targets — they do not mirror the secure theory's full query set. That
# is a narrower control than the others and is recorded here rather than left to be inferred.
PV_NEG_EXPECT := \
  "BindingBug|^RESULT event\(AcceptedExec|false" \
  "BindingReplayBug|^RESULT inj-event\(AcceptedExec|false" \
  "BindingReplayBug|^RESULT \(but event\(AcceptedExec|true" \
  "BindingReplayBug|^RESULT event\(AcceptedExec|true" \
  "BindingReplayBug|^RESULT not event\(AcceptedExec|false" \
  "CaveatsBug|AcceptedDeleg\([^,]*,nodeleg\)|false" \
  "CaveatsBug|AcceptedDeleg\([^,]*,okdeleg\)|false" \
  "ChainTopologyBug|pk\(skW\[\]\)|true" \
  "ChainTopologyBug|pk\(skP\[\]\)|false" \
  "ChainTopologyBug|pk\(skA\[\]\)|false" \
  "DeepChainBug|pk\(skV\[\]\)|false" \
  "DeepChainBug|pk\(skA\[\]\)|false" \
  "DeepChainNBug|pk\(skV\[\]\)|false" \
  "DeepChainNBug|pk\(skB\[\]\)|false" \
  "DepthBoundBug|AcceptedLeaf\([^,]*,two\)|false" \
  "DepthBoundBug|AcceptedLeaf\([^,]*,one\)|false" \
  "ExpiryBug|Accepted\([^,]*,t0\)|false" \
  "ExpiryBug|Accepted\([^,]*,t2\)|false" \
  "MalformedBug|AcceptedNoExpiry\([^,]*,tbad\)|false" \
  "MalformedBug|Accepted\([^,]*,tbad\)|true" \
  "MalformedBug|Accepted\([^,]*,t0\)|true" \
  "MalformedBug|AcceptedNoExpiry\([^,]*,tabsent\)|false" \
  "MalformedBug|Accepted\([^,]*,t2\)|false" \
  "MultisigBug|^RESULT event\(AcceptMulti\) ==>|false" \
  "MultisigBug|^RESULT not event\(AcceptMulti\)|false" \
  "MultisigKNBug|^RESULT event\(AcceptMulti\) ==>|false" \
  "MultisigKNBug|^RESULT not event\(AcceptMulti\)|false" \
  "NoEscalationBug|AcceptedDeleg\([^,]*,scopeAdmin\)|false" \
  "NoEscalationBug|AcceptedDeleg\([^,]*,narrow\(scopeAdmin\)\)|false" \
  "PersistentRecheckBug|AcceptLate|false" \
  "PersistentRecheckBug|AcceptEarly|false" \
  "RevokeBug|Accept\(pk\(skGr\[\]\)\)|false" \
  "RevokeBug|Accept\(pk\(skGo\[\]\)\)|false" \
  "UnforgeBug|^RESULT event\(AcceptedDeleg|false"

# The shared grader. $(1) = theory list, $(2) = expectation table, $(3) = slice label.
# Fails if: ProVerif errors out; a declared query matches zero or several RESULT lines; a
# verdict differs from the declaration; or the RESULT count differs from the declared count
# (which is what catches a query silently added to or dropped from a theory).
define PV_GRADE
	@for t in $(1); do \
	  echo "== ProVerif $(3) $$t =="; \
	  out=$$($(PV_RUN) proverif $$t.pv 2>&1) || { echo "$$out" | tail -20; \
	    echo "FAIL: $$t — ProVerif exited non-zero (parse/type error). Nothing was verified."; \
	    exit 1; }; \
	  results=$$(echo "$$out" | grep '^RESULT' || true); \
	  got=$$(echo "$$results" | grep -c . || true); \
	  want=0; \
	  for row in $(2); do \
	    th=$$(echo "$$row" | cut -d'|' -f1); [ "$$th" = "$$t" ] || continue; \
	    want=$$((want+1)); \
	    re=$$(echo "$$row" | cut -d'|' -f2); vw=$$(echo "$$row" | cut -d'|' -f3); \
	    hit=$$(echo "$$results" | grep -E -- "$$re" || true); \
	    n=$$(echo "$$hit" | grep -c . || true); \
	    if [ "$$n" -ne 1 ]; then \
	      echo "FAIL: $$t — the declared query /$$re/ matched $$n RESULT lines, expected 1."; \
	      echo "      A declaration that matches nothing grades nothing."; \
	      echo "$$results" | sed 's/^/      /'; exit 1; fi; \
	    case "$$hit" in *" is $$vw."*) ;; \
	      *) echo "FAIL: $$t — /$$re/ was declared '$$vw' and is not."; \
	         echo "      got: $$hit"; \
	         echo "      A verdict that differs from its declaration is the defect this"; \
	         echo "      table exists to catch — do not update the table to match the tool"; \
	         echo "      until you know WHY the verdict moved."; exit 1;; esac; \
	  done; \
	  if [ "$$want" -eq 0 ]; then \
	    echo "FAIL: $$t is in the theory list but declares NO expected verdicts — it would"; \
	    echo "      run ungraded, which is exactly the hole this table closes."; exit 1; fi; \
	  if [ "$$got" -ne "$$want" ]; then \
	    echo "FAIL: $$t printed $$got RESULT lines but declares $$want — a query was added or"; \
	    echo "      dropped. An undeclared query is an ungraded query."; \
	    echo "$$results" | sed 's/^/      /'; exit 1; fi; \
	  echo "   ok ($$want/$$want verdicts exactly as declared)"; \
	done
endef

.PHONY: proverif-green tamarin-green green proverif-neg tamarin-neg neg
proverif-green:
	$(call PV_GRADE,$(PV_GREEN),$(PV_EXPECT),green)

# A WELLFORMEDNESS FAILURE IS A BUILD FAILURE. Tamarin exits 0 when every lemma verifies even
# if its own message-derivation checks failed — it prints "WARNING: N wellformedness check
# failed! The analysis results might be wrong!" and returns success. Four green theories were
# shipping that warning unnoticed until the 0.8.2 follow-up audit; one of them (DeepChainN) had
# a genuinely free variable in a rule conclusion. A tool telling us the result might be wrong is
# not a green, so it is gated rather than left to be read in scrollback.
#
# Graded per lemma against TM_EXPECT rather than on the exit status. Tamarin's exit status IS
# meaningful (unlike ProVerif's), but it only says "every lemma the file happens to contain was
# proven" — it cannot notice a lemma that was deleted, and it does not distinguish a security
# lemma from the `exists-trace` non-vacuity lemma beside it.
tamarin-green:
	$(call TM_GRADE,$(TM_GREEN),$(TM_EXPECT),green)

# Each negative control is graded by the SAME grader as the green slice, against
# PV_NEG_EXPECT. The previous criterion — "at least one RESULT is false" — was satisfied by
# the SECURE theory for 13 of these 15 rows, because a non-vacuity query reports a reachable
# event as `is false`. See the PV_EXPECT header.
proverif-neg:
	$(call PV_GRADE,$(PV_NEG),$(PV_NEG_EXPECT),neg control)

# Per-lemma declared verdicts for the Tamarin controls. Format: THEORY|LEMMA|verified|falsified.
#
# The previous criterion was `grep -q "falsified"` — ANY falsified lemma anywhere in the
# theory. That cannot distinguish the three cases it needs to:
#   (a) the TARGET security lemma broke — the control has teeth;
#   (b) a DIFFERENT security lemma broke — the control is measuring something else;
#   (c) the theory's own `exists-trace` NON-VACUITY lemma collapsed — the variant made the
#       honest path unreachable, and "falsified - no trace found" also matches /falsified/.
# (c) was not hypothetical here. `ChainTopologyBug`, `DeepChainBug` and `DeepChainNBug` all
# used to report `falsified - no trace found` on their own reachability lemma as well as on
# the security lemma they target — so each falsified its non-vacuity witness and its target
# at once, and a run could not show which had broken. Each was an "honest consequence of the
# injected defect" (re-framing a bare-`*` leaf moves which namespace it covers, so the
# grantee's own namespace stops being reachable) and each was still a bad control, for the
# reason (c) exists: the same word reports both.
#
# NARROWED at the second gate audit, all three together (D14 — the class, not the instance).
# §5.5a gives two pattern forms, and only the peer-relative one has a frame to get wrong: an
# absolute `/{p}/` + wildcard canonicalizes to itself in every frame. Each of the three
# theories now carries an ABSOLUTE-form leaf alongside its bare-`*` one, byte-identical in
# the green twin and the control, so each control still differs from its green by exactly the
# injected defect while the honest path survives it. All three now report their reachability
# lemma `verified` and falsify their TARGET ALONE — the escalation is exhibited ALONGSIDE
# normal operation rather than instead of it. The rows below carry the new verdicts.
TM_EXPECT := \
  "Binding|binding|verified" \
  "Binding|no_replay|verified" \
  "Binding|accepted_reachable|verified" \
  "Caveats|no_delegation_honored|verified" \
  "Caveats|accepted_reachable|verified" \
  "ChainTopology|no_escalation_to_verifier|verified" \
  "ChainTopology|no_escalation_to_root|verified" \
  "ChainTopology|authorized_own_namespace_reachable|verified" \
  "DeepChain|no_xpeer_escalation|verified" \
  "DeepChain|legit_reachable|verified" \
  "DeepChainN|no_xpeer_escalation|verified" \
  "DeepChainN|legit_reachable|verified" \
  "DepthBound|depth_bound_honored|verified" \
  "DepthBound|accepted_reachable|verified" \
  "Expiry|expiry_validity|verified" \
  "Expiry|accepted_reachable|verified" \
  "Malformed|cap6a_no_fail_open|verified" \
  "Malformed|cap6a_malformed_refused|verified" \
  "Malformed|expiry_still_enforced|verified" \
  "Malformed|noexpiry_reachable|verified" \
  "Malformed|accepted_reachable|verified" \
  "Multisig|threshold|verified" \
  "Multisig|accept_reachable|verified" \
  "MultisigKN|threshold|verified" \
  "MultisigKN|accept_reachable|verified" \
  "NoEscalation|no_escalation|verified" \
  "NoEscalation|accepted_reachable|verified" \
  "PersistentRecheck|revoked_never_passes|verified" \
  "PersistentRecheck|reused_twice|verified" \
  "Revoke|revoked_never_passes|verified" \
  "Revoke|accept_reachable|verified" \
  "Unforge|root_unforgeable|verified" \
  "Unforge|deleg_unforgeable|verified" \
  "Unforge|accepted_reachable|verified"

# `BindingBug` and `UnforgeBug` declare one lemma each: like their ProVerif twins they carry
# only the lemma their defect targets, with no reachability lemma to hold steady.
TM_NEG_EXPECT := \
  "BindingBug|binding|falsified" \
  "BindingReplayBug|binding|verified" \
  "BindingReplayBug|no_replay|falsified" \
  "BindingReplayBug|accepted_reachable|verified" \
  "CaveatsBug|no_delegation_honored|falsified" \
  "CaveatsBug|accepted_reachable|verified" \
  "ChainTopologyBug|no_escalation_to_verifier|verified" \
  "ChainTopologyBug|no_escalation_to_root|falsified" \
  "ChainTopologyBug|authorized_own_namespace_reachable|verified" \
  "DeepChainBug|no_xpeer_escalation|falsified" \
  "DeepChainBug|legit_reachable|verified" \
  "DeepChainNBug|no_xpeer_escalation|falsified" \
  "DeepChainNBug|legit_reachable|verified" \
  "DepthBoundBug|depth_bound_honored|falsified" \
  "DepthBoundBug|accepted_reachable|verified" \
  "ExpiryBug|expiry_validity|falsified" \
  "ExpiryBug|accepted_reachable|verified" \
  "MalformedBug|cap6a_no_fail_open|falsified" \
  "MalformedBug|cap6a_malformed_refused|verified" \
  "MalformedBug|expiry_still_enforced|verified" \
  "MalformedBug|noexpiry_reachable|verified" \
  "MalformedBug|accepted_reachable|verified" \
  "MultisigBug|threshold|falsified" \
  "MultisigBug|accept_reachable|verified" \
  "MultisigKNBug|threshold|falsified" \
  "MultisigKNBug|accept_reachable|verified" \
  "NoEscalationBug|no_escalation|falsified" \
  "NoEscalationBug|accepted_reachable|verified" \
  "PersistentRecheckBug|revoked_never_passes|falsified" \
  "PersistentRecheckBug|reused_twice|verified" \
  "RevokeBug|revoked_never_passes|falsified" \
  "RevokeBug|accept_reachable|verified" \
  "UnforgeBug|deleg_unforgeable|falsified"

# The shared Tamarin grader. $(1) = theory list, $(2) = table, $(3) = label.
# Wellformedness is gated on both slices — it matters MORE on the controls, because this
# target captures the prover's output and echoes only a verdict line, so a warning printed by
# a control was invisible even in scrollback.
define TM_GRADE
	@for t in $(1); do \
	  echo "== Tamarin $(3) $$t =="; \
	  out=$$($(TM_RUN) tamarin-prover --prove $$t.spthy 2>&1) || true; \
	  if echo "$$out" | grep -qE "wellformedness check[s]? failed"; then \
	    echo "FAIL: $$t — Tamarin reported a wellformedness failure: 'the analysis results"; \
	    echo "      might be wrong'. Tamarin exits 0 in that state. Not a green. Fix the rule."; \
	    exit 1; fi; \
	  summary=$$(echo "$$out" | grep -E '^  [A-Za-z0-9_]+ \((all-traces|exists-trace)\):' || true); \
	  got=$$(echo "$$summary" | grep -c . || true); \
	  want=0; \
	  for row in $(2); do \
	    th=$$(echo "$$row" | cut -d'|' -f1); [ "$$th" = "$$t" ] || continue; \
	    want=$$((want+1)); \
	    lem=$$(echo "$$row" | cut -d'|' -f2); vw=$$(echo "$$row" | cut -d'|' -f3); \
	    hit=$$(echo "$$summary" | grep -E "^  $$lem \(" || true); \
	    if [ -z "$$hit" ]; then \
	      echo "FAIL: $$t declares lemma '$$lem' but the run reported no verdict for it."; \
	      echo "$$summary" | sed 's/^/      /'; exit 1; fi; \
	    case "$$hit" in *": $$vw"*) ;; \
	      *) echo "FAIL: $$t lemma '$$lem' was declared '$$vw' and is not."; \
	         echo "      got: $$hit"; exit 1;; esac; \
	  done; \
	  if [ "$$want" -eq 0 ]; then \
	    echo "FAIL: $$t is in the theory list but declares NO expected lemma verdicts."; \
	    exit 1; fi; \
	  if [ "$$got" -ne "$$want" ]; then \
	    echo "FAIL: $$t reported $$got lemma verdicts but declares $$want — a lemma was added"; \
	    echo "      or dropped. An undeclared lemma is an ungraded lemma."; \
	    echo "$$summary" | sed 's/^/      /'; exit 1; fi; \
	  echo "   ok ($$want/$$want lemmas exactly as declared)"; \
	done
endef

tamarin-neg:
	$(call TM_GRADE,$(TM_NEG),$(TM_NEG_EXPECT),neg control)

neg: proverif-neg tamarin-neg

# Both provers, lockstep — the active-attacker green slice.
green: proverif-green tamarin-green

# The FULL prover matrix: both provers on both the secure theories and the bug controls.
matrix: green neg

clean:
	rm -rf output/ *.proof 2>/dev/null || true
