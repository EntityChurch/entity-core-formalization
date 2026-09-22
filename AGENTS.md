# entity-core-formalization

Read **AGENTS-STANDARD.md** first. This file adds entity-core-formalization specifics.

## Overview

Formal design assurance for the Entity Core Protocol — machine-checked verification of
the *protocol design at the pin* on the two layers Lean cannot structurally reach: **TLA+**
(distributed correctness under concurrency, safety + liveness — TLC, with **Apalache**
for inductive/unbounded invariants and **Spin** as an independent cross-check) and
**Tamarin / ProVerif** (active-attacker / Dolev-Yao security: capability unforgeability,
no escalation, no replay/reflection/confused-deputy). Models the current core; may
extend to extension protocols once they are vendored.

## How we work here — tier **AUTHORING**

This repo runs the entity-OS methodology at the **Authoring** tier — the framework is
`METHODOLOGY.md` (injected, identical everywhere; read it once). Formal methods are this
repo's primary gate, but they gate *the model*, not *the modelling process*: a proof is only
as good as the correspondence between the model and the system it claims to describe, and
nothing in TLA+ or Tamarin checks that correspondence.

So what binds here is the honesty half of the framework:

- **D8 and D12** (`METHODOLOGY.md` §4) verbatim — read the spec *against* the model, never as
  the model; cite canonical sources with `(symbol, path, commit)`; never paraphrase a spec
  claim from a summary into a modelling assumption. **A model that encodes a paraphrase proves
  a theorem about the paraphrase.**
- **D11 inventory-boundary declaration** — every proof states what is in the model **and what
  is abstracted away**. An unstated abstraction is how a green proof coexists with a live
  attack.
- **The Audit Doctrine A0–A12** (§7.2) — including for *"the model and the spec have drifted."*
- **The ratchet** (§2) and the **promotion ladder** (§3).

## Setup / environment · Build & test

- **make + podman only — no host installs.** Toolchains are baked into podman images
  (`tla/Containerfile` → `entity-tla`, `tamarin/Containerfile` → `entity-tamarin`) and
  invoked through `make`; never run `java`/`curl`/`opam`/`stack` on the host even though
  Java is present. This pins the toolchain into the reproducibility envelope alongside
  the `spec-data/` SHA-pin. Bind mounts use `:Z` (SELinux/Fedora host).
- `make` is the door: the root `Makefile` carries `smoke` / `check`
  (= `check-tla` + `check-spin` + `check-provers`) / `crosscheck` / `caps` / `clean`; each
  per-engine dir (`tla/`, `spin/`, `tamarin/`) has its own `image` (build the podman image)
  + `green` (green-sweep). Maude 3.4 — Tamarin's required rewriting backend — is pinned via
  a Tamarin-blessed prebuilt binary in `tamarin/Containerfile.tamarin` (apt's 3.2 is too old).
- Resource caps live in `caps.mk` (included by root + sub-Makefiles); `CAP_MEM=2g`,
  no swap (`CAP_SWAP == CAP_MEM` → the container is OOM-killed cleanly at the cap instead of
  dragging the host into swap-thrash). `caps.local.mk` is gitignored (per-host overrides).
- Run the three toolchains **serially** — concurrent `:Z` relabel races cause transient
  "file not found." `RevokeMech.spthy` is genuinely non-terminating (excluded from the
  matrix by design); run it standalone or skip it, and reclaim hung containers with
  `podman kill` (a `timeout podman run` only kills the client, not the detached container).

## Project structure

Read in order: `README.md` → `docs/ASSURANCE-MAP.md` → `docs/SCOPING-AND-SPIKE-PLAN.md`
→ your spike workspace README. Resuming? Start at `docs/FINAL-ASSURANCE-SUMMARY.md`
(capstone) → `docs/CROSSCHECK-RESULTS.md`. `docs/PRIOR-ART.md`
is the learning on-ramp; `docs/PROPERTIES.md` is the PROVEN/MODELED scorecard.

- `spec-data/` — vendored, SHA-pinned, byte-for-byte spec snapshots. Currently `v0.8.0/`
  and `v0.8.2/`; **`spec-data/MODELING-PIN` names the one the models actually transcribe**
  (`v0.8.2`) and therefore the one every published result is about. Do not restate it
  here — read the file. `make specdrift` reports the distance from that pin to the live spec.
- `tla/`, `spin/`, `tamarin/` — per-engine workspaces and reports.
- Per-spike deliverable: a `FORMALIZATION-REPORT`-style note (properties proved /
  counterexamples / scope boundaries / on-ramp pain / go-no-go).

**Status:** pinned at `v0.8.2` and `make specdrift` reports **no drift** — the models
transcribe the live spec. Phase 0 spikes, Phase 1 (TLA+ all-Core concurrency +
Tamarin/ProVerif active-attacker) and Phase 2 (prover surface-closure) are done. The full
**238-run** `make matrix` is the gate: all 11 concurrency/structural modules checked by TLC +
Apalache (23 inductive invariants) + Spin, both provers running every attacker theory
(15 ProVerif / 14 Tamarin lemmas), 92 negative controls and 11 non-vacuity witnesses.
No inductive invariant is deferred; no control is known-weak.

Two things are new and change how you read the rest. **`docs/LEAN-SEAM.md`** is the
assumption ledger — per abstraction in the models, the proposition relied on and the Lean
theorem (or sibling engine, or nothing) that discharges it, cited by content digest and
gated by `make leanseam`. It is where the complementarity claim stops being prose.
**`make coverage`** checks the coverage *claim* against the models' own `§`-citations,
because two rows of the grid turned out to be phantoms. **One protocol finding is open** —
§4.6 step 1 vs §4.7's table, `docs/PROPERTIES.md` §D.1 — routed to `entity-core-protocol`.
`docs/COVERAGE-MATRIX.md` is the section×engine map and the limits; `docs/STATUS.md` §Next is
the work-list; `docs/FINAL-ASSURANCE-SUMMARY.md` is the capstone.

**The failure mode this repo actually has is in the verification, not the protocol** — every
defect found by the last three audits was one, and they have earned three ratified
disciplines. (The one exception is now `docs/PROPERTIES.md` §D.1 — a real contradiction in
the spec text, surfaced by modeling a section the coverage grid wrongly claimed was covered.)

### D13 — a gate must assert the outcome it claims, not merely a symptom of it

For every grading target, answer in the file: **what does this assert, and what else
satisfies it?** Exit status is almost never the answer. Demonstrated repeatedly here:
ProVerif exits `0` with a *false* query; TLC exits non-zero for an undefined invariant exactly
as for a violation; Apalache exits `255` for a config error and `12` for a counterexample;
Spin prints `errors: 0` for a compile failure **and a positive `errors: N` for a deadlock,
a broken liveness claim and a caught assertion alike**; Tamarin exits `0` while printing "the
analysis results might be wrong"; and "some RESULT is false" is how a *passing* non-vacuity
query reports, so a secure theory satisfied its own negative control's criterion. A control
must fail **for its stated reason**, a green must **positively** report success, and a tool
warning is a build failure.

*Enforcement:* every row of `TLC_NEG`, `TLC_WITNESS`, `PV_EXPECT`, `PV_NEG_EXPECT`,
`TM_EXPECT`, `TM_NEG_EXPECT`, **`SPIN_NEG`** carries its expected verdict; `apalache-neg`
requires `EXITCODE: ERROR (12)`; `spin/neg` requires the declared **pan failure signature**
(matched against the `pan:N:` error line only — the search-options header contains
`invalid end state` in every run) and `spin/green` an explicit `errors: 0`. Adding a run
without adding its expected verdict fails the build — the graders reject a theory that
declares nothing.

### D14 — a finding is not closed until it is applied to every instance of its shape

Do not fix the instance you found. Enumerate the class, then fix all of it in the same
session, and say in the commit how many instances there were. Twice now the cost has been
real: `StoreBounded` was *disclosed* as vacuous in two releases before anyone removed it; and
the audit that hardened `tlc-neg`, Spin and Tamarin against exit-status grading left
`apalache-neg`, `tlc-witness` and **both** ProVerif targets untouched — **62 of 203 runs**,
found only because a later pass re-asked the question of every target rather than the one that
had failed.

Twice more since: `spin/neg` was hardened against compile failure and exit status by the
first audit and left grading on `errors: [1-9]`, which a *deadlocking* control satisfies —
found when two brand-new controls did exactly that; and the three Tamarin controls that
falsified their own reachability lemma were **disclosed** rather than fixed, then all three
narrowed together once the move was found for one.

*Enforcement:* a fix whose finding names a mechanism (a grading criterion, an idiom, a
tool behaviour) must list every site of that mechanism and its disposition in
`docs/PROPERTIES.md` §C or `docs/STATUS.md`. `grep -n 'dev/null' */Makefile` is the specific
tripwire for this family: discarded output is the tell.

### D15 — a derived number is a claim; derive it from claims, and gate it

D13 applies to **metrics**, not only to graders. Ask of any number this repo publishes: *what
does it assert, and what else produces it?* Deriving a figure from the artifacts instead of
choosing it by hand feels like it settles the question and does not: the derivation is only
as honest as what it counts, and it is written into prose that nothing re-reads.

Earned on the coverage grid, in two different shapes and then a third. Matrix A is derived
from the models' own `§`-citations precisely so the number cannot be hand-picked — and a `§`
mention is not a claim of coverage. **§4.7** was counted because a header comment wrote a
section *range* with a sigil on both ends, so the endpoint scanned as a citation; **§6.9**
because both of its mentions were out-of-scope **disclaimers** saying bootstrap is not
modeled. Two rows of the published grid described work that did not exist, through a
release. Then, within the hour of writing the rule down, the two new modules closing those
gaps shipped three fresh phantoms of the same kind (`§1.2`, `§1.5`, `§2.11`, all inside
scope notes) — which is the argument for the gate over the discipline alone.

*Enforcement:* `make coverage` (`tools/coverage-check.py`), in `check` and `matrix`. It
asserts the cited `§N.M` set equals Matrix A's rows **in both directions**, that the stated
numerator and denominator match, and that neither citation-hygiene tripwire fires. It states
in the file what it does **not** assert — the engine columns — rather than letting a reader
assume the whole grid is machine-checked. The residue is named in `docs/STATUS.md` §Next
item 9: the run-count totals quoted in prose are still hand-derived from the gate tables.

*Corollary, learned by getting it wrong twice in one session:* **teeth-test a gate rather
than reasoning about it.** The first draft of the Spin failure-signature check matched
`invalid end state` against pan's whole output — where that string appears in the
*search-options header of every run* — so the two rows that legitimately expect a deadlock
asserted nothing. Reading the code did not catch it; deliberately breaking a control did.

## Boundaries — do NOT modify

- **An existing `spec-data/vX/` snapshot is frozen** — vendored, SHA-pinned. Model against
  it, never against a live checkout, and **never edit a snapshot in place**: a pin whose
  bytes can change is not a pin, and every result here is quoted against one.
  **Adding a new snapshot is not editing one.** When the spec advances, vendor a new
  `spec-data/vX.Y.Z/` beside the old — this repo does that itself, because the source is
  the public `entity-core-protocol` `specs/` and the operation is mechanical and
  hash-verifiable (copy byte-for-byte, recompute SHA-256, record provenance and what
  moved). Prior snapshots stay in place as point-in-time pins. Procedure:
  `spec-data/<pin>/MANIFEST.md` §"Re-vendor discipline".
  *(This rule previously said "the architecture repo re-vendors." That named
  `entity-core-architecture`, which no longer exists — the same stale reference corrected
  elsewhere in this file. There is no external owner to wait on.)*
- **`spec-data/MODELING-PIN` names the snapshot the models actually transcribe** — the one
  every published result is a statement about. Vendoring a newer snapshot does **not**
  move it. It moves only when the models have been re-validated against the new text, and
  moving it is the last step of that work, not the first. `make specdrift` reads it.
- **Ratified / superseded phase reports are historical record.** The phase outcomes are
  lineage; `docs/FINAL-ASSURANCE-SUMMARY.md` is the single live capstone pointer — don't
  rewrite closed reports to look current.
- **Don't change the spec here.** A model that surfaces a design defect is a **finding
  routed to the sibling `entity-core-protocol` repo** (a proposal in *their*
  `docs/proposals/`), never a spec edit here. Don't re-model what Lean proved —
  cap-chain-verify is an abstract predicate (TLA+) / function symbol (Tamarin); the
  attenuation logic is Lean's, done.

## Scope discipline

- **A model verifies a *model*, not the code and not the prose.** State the fidelity wall
  (the spec↔model 5th wall, `ASSURANCE-MAP.md`) in every report: the result is only as
  good as the model faithfully transcribing the spec. Cite spec section numbers in model
  comments so a reviewer can check the transcription. Never let scope hide.
- **This repo is additive assurance, off the release critical path** — a research
  demonstrator that must not pull effort off shipping work. A tag is a release cut at
  freeze, not on push.
- Model fidelity is checked against the pinned `spec-data/` plus the sibling repos
  (`entity-core-go` transport, `entity-core-keystone` Lean report + concurrency gate,
  `entity-core-protocol` live specs + `docs/proposals/`), present locally as siblings of
  this repo — read the source, not memory.
