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
# Uppercase :Z is correct HERE and only here: spin/ is mounted by exactly one image
# ($(IMAGE)), so a private relabel has nothing to conflict with. tla/ and tamarin/ are each
# shared by two images and use :z — see the note in tla/Makefile.
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

# Green sweep — the independent-encoding cross-check of all 11 modules
# (7 with an LTL claim below, plus the 4 structural ones in SPIN_GREEN_SAFETY):
# exhaustive SAFETY (verify) + LTL LIVENESS (ltl) on each FIXED model (no DEFS).
# Defect variants (DEFS=-D<DEFECT>) are the negative controls, run separately.
# Models carrying an LTL liveness claim — checked BOTH ways (safety + acceptance cycles).
# `core` added at 0.8.2: the composed whole-protocol model previously had NO independent
# re-encoding at all, which the audit flagged as the worst-placed single-tool gap in the repo.
SPIN_GREEN := reentry conn store revoke emit register core

# Structural models with no concurrency and therefore no LTL claim — safety only. `authority`
# and `bounds` were added at 0.8.2 alongside their TLA+ modules, which had shipped with TLC
# coverage only; `conncodes` (§4.7) and `bootstrap` (§6.9) at the second gate audit, alongside
# brand-new TLA+ modules for two sections the coverage grid claimed were covered when nothing
# modeled them (../docs/COVERAGE-MATRIX.md §3a). Spin's contribution here is an
# independently-written enumerator agreeing on the verdicts, NOT interleaving search; that
# weaker form of corroboration is stated in each .pml header.
SPIN_GREEN_SAFETY := authority bounds conncodes bootstrap

# N=3 green rows (2026-08-30). `reentry` and `core` are the two models whose peer topology was
# hard-wired binary by `other(p) == 1 - p`; both now take -DNPEERS and run a directed ring.
# Format: MODEL|DEFS|LTLFLAGS. LTLFLAGS is per-row because `core` at 3 peers runs 11 processes
# (3 link + 3 client + 3 server + revoker + init) and pan's weak-fairness construction caps at
# NFAIR=3 -> 10 procs; it aborts with "too many processes" rather than reporting a wrong
# verdict, but it aborts, so the bound is carried explicitly instead of being discovered.
SPIN_GREEN_N3 := \
  "reentry|-DNPEERS=3|$(LTLFLAGS)" \
  "core|-DNPEERS=3|-DNFAIR=4" \
  "revoke|-DDELTAZERO|$(LTLFLAGS)"

# The revoke row above is not an N-peer variant — it reuses this table because it has the same
# MODEL|DEFS|LTLFLAGS shape. It is §5.10 (0.8.1 W7 Knob 3) run at delta == 0, which the clause
# states "reproduces today's exact behavior". A GREEN row whose job is to catch a wrong GREEN:
# the default revoke build admits delta == 1 and therefore EXPECTS a wider validity window, so
# a transcription with a sign error or a one-sided tolerance passes it and fails here.

# NEGATIVE CONTROLS — each row MUST report errors > 0. Format: MODEL DEFS MODE.
# MODE is `safety` (assertions / invalid-end) or `ltl` (acceptance cycles under -a -f).
# Added at 0.8.2: store NOSYNCREFS (§4.8 RT-13a refcount use-after-free) and
# reentry NOATOMICFRAME (§6.11(a') frame-write atomicity).
# NEGATIVE CONTROLS — each row MUST fail, AND MUST FAIL FOR THE STATED REASON.
# Format: MODEL|DEFS|MODE|expected pan failure signature.
# MODE is `safety` (assertions / invalid-end) or `ltl` (acceptance cycles under -a -f).
#
# THE FOURTH FIELD was added at the second gate audit. Before it this target graded on
# `errors: [1-9]` alone, which cannot distinguish HOW a control failed — and pan has three
# unrelated ways to report a positive error count:
#   assertion violated <expr>   the targeted property broke                  <- the only pass
#   invalid end state           the model DEADLOCKED (or a process blocked)
#   acceptance cycle            a liveness claim broke
# So a control whose model blocks on a mis-written guard scores exactly as one that catches
# its defect. That is not hypothetical: writing bootstrap.pml's registration precondition as
# a two-stage guard `(!registered) -> (index...) ->` made -DGATEONE and -DNOCONNGATE both
# report `errors: 1` from an invalid end state, never reaching their assertions, and the old
# criterion accepted both. Audited against all 29 pre-existing rows at the same time: every
# one was in fact failing for its stated reason, so nothing here changed verdict — the gate
# was blind, not wrong. (`reentry`/`core -DSERIALIZED` legitimately expect `invalid end
# state`: the Class-G reentry defect IS a deadlock.)
#
# The signature is matched against pan's `pan:N:` ERROR LINE ONLY, never against the whole
# run output. pan prints its enabled search options in every run --
#     assertion violations  +
#     invalid end states    +
# -- so a signature grepped over the full output would find "invalid end state" in EVERY run,
# passing the two rows that legitimately expect a deadlock no matter how they actually failed.
# That hole was introduced by the first draft of this very check and caught by teeth-testing
# it, which is the argument for teeth-testing a grader rather than reasoning about it.
#
# Both sides are whitespace-normalized (`tr -s ' '`) before comparison: pan pads its error
# line with a double space after "assertion violated", which is invisible in a diff and would
# otherwise make every assertion row a false failure.
#
# The signature is a DISCRIMINATING FRAGMENT of pan's error line, not the whole compiled
# assertion expression. The fragment names which property broke — which is what the check
# has to establish — while pinning the full expression would make any cosmetic edit
# elsewhere in the model read as a regression. Same trade as TLC_NEG's verdict line.
# register -DNOATOMIC's signature changed at 0.8.3-dev, from the NoPartialResidue assertion
# `(tree[0]==0)||(tree[0]==5)` to RegisterAllOrNothing's `!(disp[0])||(tree[0]==5)`. Sequenced
# writes make a partial tree legitimate IN FLIGHT, so NoPartialResidue is now scoped to settled
# handlers and no longer the assertion this control trips. The new signature is the defect the
# control's own header names — "a half-built handler is dispatch-visible without its grant" —
# and it matches what TLC's RegisterAtomicBug now reports, which is the cross-check working.
SPIN_NEG := \
  "reentry|-DSERIALIZED|safety|invalid end state" \
  "reentry|-DNOATOMICFRAME|safety|assertion violated !(interleaved)" \
  "conn|-DNOENFORCE|safety|assertion violated (tokensIssued<=1)" \
  "conn|-DDROPFRAME|ltl|acceptance cycle" \
  "store|-DNOSERIALIZE|safety|assertion violated (writers<=1)" \
  "store|-DNOADMIT|safety|assertion violated (pending<=2)" \
  "store|-DNOSYNCREFS|safety|(live[k]==0)&&(truth[k]>0)" \
  "store|-DSILENTDROP|ltl|acceptance cycle" \
  "revoke|-DNOHONOR|safety|!(revObserved[0])||" \
  "revoke|-DLEAKL1|safety|(t[0]!=t[1])||" \
  "revoke|-DDELTABLIND|safety|(t[0]!=t[1])||(revObserved[0]!=revObserved[1])" \
  "revoke|-DNOCONVERGE|ltl|acceptance cycle" \
  "emit|-DEMITFIRE|safety|(sEvt==hashNew)&&(tEvt==changed)" \
  "emit|-DEMITMARKER|safety|!(tEvt)||(etype==" \
  "emit|-DEMITSTALL|ltl|acceptance cycle" \
  "register|-DNOATOMIC|safety|!(disp[0])||(tree[0]==5)" \
  "register|-DNOSYSGUARD|safety|assertion violated (tree[1]==0)" \
  "register|-DWEDGE|ltl|acceptance cycle" \
  "authority|-DOPTALLOW|safety|(kind[d]==2)&& !(hasGrant[d])" \
  "authority|-DOPTDENY|safety|(kind[d]==1)&&((res[d]==0)" \
  "authority|-DNOSUBCHECK|safety|(outcome[d]==1)&&(res[d]!=0)" \
  "authority|-DINHERITRES|safety|res[(parent[d]-1)]" \
  "bounds|-DEQUALMAG|safety|assertion violated (halt!=2)" \
  "bounds|-DRATIOBOUND|safety|assertion violated (halt!=2)" \
  "bounds|-DDOUBLECOUNT|safety|assertion violated (spent==dispatches)" \
  "bounds|-DSHARECODE|safety|(halt==1)&&(code!=1)" \
  "core|-DSERIALIZED|safety|invalid end state" \
  "core|-DNOATOMICFRAME|safety|assertion violated !(interleaved)" \
  "core|-DNOESTABGATE|safety|assertion violated established[p]" \
  "core|-DNOREVGATE|safety|assertion violated !(servedRevoked)" \
  "reentry|-DNPEERS=3 -DSERIALIZED|safety|invalid end state" \
  "reentry|-DNPEERS=3 -DNOATOMICFRAME|safety|assertion violated !(interleaved)" \
  "core|-DNPEERS=3 -DSERIALIZED|safety|invalid end state" \
  "conncodes|-DCOLLAPSE|safety|nc1!=nc2" \
  "conncodes|-DWRONGSTATUS|safety|statOf[i]!=want" \
  "conncodes|-DSEQREADING|safety|fired[3]&&(codeOf[3]!=1)" \
  "conncodes|-DAUTHFIRST|safety|fired[7]&&((codeOf[7]!=4)||(statOf[7]!=400))" \
  "conncodes|-DDROP|safety|refused[x]&&(wire==2)" \
  "conncodes|-DBARECLOSE|safety|refused[x]&&(wire==1)" \
  "conncodes|-DECFFRAMING|safety|refused[3]&&(rcodeOf[3]==8)" \
  "bootstrap|-DEARLYINDEX|safety|inIndex[i]&&(facets[i]!=2)" \
  "bootstrap|-DGATEONE|safety|registered&&(facets[j]!=2)" \
  "bootstrap|-DNOCONNGATE|safety|established&&(facets[2]!=2)"

.PHONY: green neg
# Each negative control MUST fail. Inverted exit status: a clean run is the failure.
neg:
	@for row in $(SPIN_NEG); do \
	  m=$$(echo "$$row" | cut -d'|' -f1); d=$$(echo "$$row" | cut -d'|' -f2); \
	  mode=$$(echo "$$row" | cut -d'|' -f3); want=$$(echo "$$row" | cut -d'|' -f4); \
	  echo "== Spin neg control $$m $$d ($$mode, MUST fail: $$want) =="; \
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
	  errline=$$(echo "$$out" | tr -s ' ' | grep -oE 'pan:[0-9]+: .*' | head -1); \
	  if ! echo "$$errline" | grep -qF "$$want"; then \
	    echo "FAIL: $$m $$d failed, but NOT for the reason it exists to demonstrate."; \
	    echo "      expected: $$want"; \
	    echo "      got:      $${errline:-<no pan: error line at all>}"; \
	    echo "      pan reports a positive error count for an assertion, a DEADLOCK (invalid"; \
	    echo "      end state) and a broken liveness claim alike; without this check a control"; \
	    echo "      whose model merely blocks scores exactly as one that catches its defect."; \
	    exit 1; \
	  fi; \
	  echo "   ok (failed as required: $$want)"; \
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
	@for row in $(SPIN_GREEN_N3); do \
	  m=$$(echo "$$row" | cut -d'|' -f1); d=$$(echo "$$row" | cut -d'|' -f2); \
	  lf=$$(echo "$$row" | cut -d'|' -f3); \
	  echo "== Spin $$m $$d (safety) =="; \
	  $(RUN) spin -a $$d $$m.pml || exit 1; \
	  out=$$($(RUN) sh -c "gcc -O2 -DNOCLAIM -o pan pan.c && ./pan" 2>&1); echo "$$out"; \
	  echo "$$out" | grep -q "errors: 0" || { echo "FAIL: $$m $$d safety did not report errors: 0"; exit 1; }; \
	  echo "== Spin $$m $$d (liveness/LTL) =="; \
	  $(RUN) spin -a $$d $$m.pml || exit 1; \
	  out=$$($(RUN) sh -c "gcc -O2 $$lf -o pan pan.c && ./pan -a -f" 2>&1); echo "$$out"; \
	  echo "$$out" | grep -q "errors: 0" || { echo "FAIL: $$m $$d liveness did not report errors: 0"; exit 1; }; \
	done
	@for m in $(SPIN_GREEN_SAFETY); do \
	  echo "== Spin $$m (safety; no LTL claim) =="; \
	  $(RUN) spin -a $$m.pml || exit 1; \
	  out=$$($(RUN) sh -c "gcc -O2 -DNOCLAIM -o pan pan.c && ./pan" 2>&1); echo "$$out"; \
	  echo "$$out" | grep -q "errors: 0" || { echo "FAIL: $$m safety did not report errors: 0"; exit 1; }; \
	done

clean:
	rm -f pan pan.* *.trail _spin_nvr.tmp 2>/dev/null || true
