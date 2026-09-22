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
  the `spec-data/` SHA-pin. **Bind-mount relabel flag: `:z` where a directory is shared by two
  images (`tla/` = TLC + Apalache, `tamarin/` = ProVerif + Tamarin), `:Z` only where one image
  owns it (`spin/`).** Uppercase `:Z` relabels a volume *private to one container*, so on a
  shared directory the second image's relabel invalidates the first's — Apalache then dies
  mid-sweep with `Configuration error: Could not find or create directory`, which reads like a
  model failure and is not one. *(This line said "bind mounts use `:Z`" until 2026-08-30, and
  `tla/Makefile` carried "drop to `:z` if shared across containers" directly above a `:Z` that
  had been shared since Apalache was added.)*
- `make` is the door: the root `Makefile` carries `smoke` / `check`
  (= `check-tla` + `check-spin` + `check-provers`) / `crosscheck` / `caps` / `clean`; each
  per-engine dir (`tla/`, `spin/`, `tamarin/`) has its own `image` (build the podman image)
  + `green` (green-sweep). **`lean/` is a fourth workspace with no models in it** — it holds
  the gate that builds the *sibling keystone peer's* Lean proof track (`entity-lean` image,
  `make lean-image`) and grades its axiom sets. `make lean` = `leanseam` + `leanproof` +
  `leanproof-neg`; it needs the keystone checkout, so it is **excluded from `make matrix`**
  rather than skipped inside it, and its 6 runs are counted separately from the 258. Maude 3.4 — Tamarin's required rewriting backend — is pinned via
  a Tamarin-blessed prebuilt binary in `tamarin/Containerfile.tamarin` (apt's 3.2 is too old).
- Resource caps live in `caps.mk` (included by root + sub-Makefiles); `CAP_MEM=2g`,
  no swap (`CAP_SWAP == CAP_MEM` → the container is OOM-killed cleanly at the cap instead of
  dragging the host into swap-thrash). `caps.local.mk` is gitignored (per-host overrides).
- Run the three toolchains **serially.** *(The reason given here used to be "concurrent `:Z`
  relabel races cause transient file-not-found" — that was a symptom of the shared-mount flag
  bug above, now fixed; serial execution remains the rule for resource-cap reasons.)*
  `RevokeMech.spthy` is genuinely non-terminating (excluded from the
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
**258-run** `make matrix` is the gate: all 11 concurrency/structural modules checked by TLC +
Apalache (23 inductive invariants) + Spin, both provers running every attacker theory
(15 ProVerif / 14 Tamarin lemmas), 100 negative controls and 13 non-vacuity witnesses.
No inductive invariant is deferred; no control is known-weak.

Two things are new and change how you read the rest. **`docs/LEAN-SEAM.md`** is the
assumption ledger — per abstraction in the models, the proposition relied on and the Lean
theorem (or sibling engine, or nothing) that discharges it, cited by content digest and
gated by **two** targets: `make leanseam` (has the cited *text* moved?) and `make leanproof`
(do the cited *proofs* still hold? — §7, 6 runs, needs the keystone sibling). It is where
the complementarity claim stops being prose.
**`make coverage`** checks the coverage *claim* against the models' own `§`-citations,
because two rows of the grid turned out to be phantoms, and **`make runcount`** derives the
matrix run total from the gate tables and fails when a published site disagrees, because
that number went stale three times in one week. **One protocol finding is open** —
§4.6 step 1 vs §4.7's table, `docs/PROPERTIES.md` §D.1 — routed to `entity-core-protocol`.
`docs/COVERAGE-MATRIX.md` is the section×engine map and the limits; `docs/STATUS.md` §Next is
the work-list; `docs/FINAL-ASSURANCE-SUMMARY.md` is the capstone.

**The failure mode this repo actually has is in the verification, not the protocol** — every
defect found by the last four audits was one, and they have earned three ratified
disciplines. The fourth (`docs/status/AUDIT-2026-08-30-LEAN-TIER.md`) added no discipline and
is the more useful for it: five hypotheses, five confirmed, every one an instance of D13,
D14 or D15 — applied to work built the same session **under their own banner**. (The one exception is now `docs/PROPERTIES.md` §D.1 — a real contradiction in
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

*Fourth instance, 2026-08-30 — a grader another repo CLAIMED, that nobody ran, whose claim
was also false.* Ten rows of `docs/LEAN-SEAM.md` rest on named Lean theorems in the
keystone peer (Class L is eleven rows; nine CLOSED, two CLOSED-MODULO-H, and L2 is closed
by construction with no theorem to run). `lake build EntityCoreProofs` is called "the proof check — a `sorry` or
failed proof fails the build" in five places in that peer — the lakefile, the proof-library
root, `profile.toml`'s testing contract and two status docs — and **is invoked by no
Makefile, script or workflow in that tree**, which has no CI directory at all. Asked D13's
question of it and answered by building all three cases: **a `sorry` is a *warning* in Lean,
so lake prints `Build completed successfully` and exits 0**; a hand-written `axiom`
replacing a proof exits 0 with no warning at all; only a proof that fails to type-check
exits non-zero. Exit status catches one failure mode in three, and misses the two a proof
check exists for. `make leanproof` grades the **axiom set** of all 37 `#print axioms` gates
against `lean/proof-gate.expect` in both directions, ties them to the ledger's own pin
block, and fails on any undeclared warning. Two transferable pieces: **a gate a sibling repo
says it has is a gate you have not checked**, and *a `sorry` reported as a warning* is the
same shape as ProVerif exiting 0 on a false query — the tool is telling you, quietly, in a
channel the grader does not read.

*Fifth instance, same day, on the fix for the fourth — the new tier's GREEN gate met D13 and
its own CONTROLS did not.* Each of the four controls declared a reason-code **count**
(`SORRY_AX: 3`). Asked "what else satisfies it?" and answered by running it: any three
contaminated declarations do. That is the `TM_NEG_EXPECT` lesson — three Tamarin controls
that falsified their own reachability lemma — reproduced in a table written the same day it
was cited. **A count is a symptom of the outcome; the identities are the outcome.** All five
controls now declare which declarations must carry each code, matched one-to-one with extras
rejected, and `neg-broken` pins the file *and* the error kind. The transferable line:
**a control that passes is exactly as unexamined as a green that passes** — teeth-test the
controls in the same pass, not after they go green. `docs/status/AUDIT-2026-08-30-LEAN-TIER.md`.

*Third instance, 2026-08-30 — the TLA+ GREEN sweep was the one grader nobody had asked the
question of.* `tlc-green` ran `tlc2.TLC … || exit 1`: pure exit status, the criterion D13 was
written about, sitting in the target that produces most of the repo's positive claims. It now
requires TLC's completion line **and** — this is the part that has teeth — that the cfg
**declares at least one `INVARIANT` or `PROPERTY`**. Asked "what else satisfies it?": a cfg
declaring neither. TLC enumerates the state space, checks nothing, exits **0**, and prints
`Model checking completed. No error has been found.` verbatim. **Both** the old exit-status
grader and the first draft of the fix scored that green — demonstrated, not reasoned about,
by building such a cfg and running it (the D15 corollary). No output distinguishes "verified
everything" from "verified nothing", so the assertion has to be made against the **config**.

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

*It applies to retractions too, learned 2026-08-30.* The L7 correction — that ProVerif and
Lean do **not** share an undischarged `hframed` — was written into `LEAN-SEAM.md` and
`STATUS.md` and left standing in `ASSURANCE-MAP.md`, `FINAL-ASSURANCE-SUMMARY.md` and the
`CHANGELOG`: three canonical documents telling a public reader a claim about a sibling
repo's proofs that we had already established was wrong in both halves. **A withdrawn claim
has a shape, and the shape is its phrasing, not its subject** — grep the retracted words
("shared undischarged assumption"), because the row name appears in every site including the
corrected ones and finds nothing.

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
assume the whole grid is machine-checked.

*Second enforcement point, 2026-08-30 — `make runcount` (`tools/runcount.py`), also in
`check` and `matrix`.* The run total was the residue D15 named and it went stale three times
in one week (238 → 242 → 258, six sites hand-edited, two missed — one of them the blurb a
public reader gets). It now derives the per-target counts from the gate tables themselves and
fails if any declared prose site disagrees, or if a site stops making the claim at all.
**Its own first draft failed D13**: it matched any three-digit number near the word "runs"
and so flagged three files whose 203/204/238 are true statements about the past — a gate that
makes you delete accurate history to go green. The live claim is now declared per site by
anchor. *A number this repo publishes is checked; a number it publishes about its own past
is deliberately not, and the tool says so.*

*Corollary, learned by getting it wrong twice in one session:* **teeth-test a gate rather
than reasoning about it.** The first draft of the Spin failure-signature check matched
`invalid end state` against pan's whole output — where that string appears in the
*search-options header of every run* — so the two rows that legitimately expect a deadlock
asserted nothing. Reading the code did not catch it; deliberately breaking a control did.

*A number that justifies a gate is still a number, 2026-08-30.* The Lean tier was argued for
in five files by "eleven CLOSED rows of the ledger rested on a build nobody ran." Class L is
eleven rows: **nine CLOSED, two CLOSED-MODULO-H**, ten citing a theorem. The conclusion
survived — ten rows did rest on that build — but the figure was *recalled*, not derived, and
it was published five times before anyone counted the verdicts. Ask it of the number that
makes the case for the work, not only of the numbers in the results table.

*Second medium, same mechanism — D15 is not only about numbers.* `LEAN-SEAM.md` L7 claimed
ProVerif and Lean shared one undischarged assumption, on the strength of the single equation
`canon(star, fr) = awild(fr)` matching the shape of Lean's `hframed`. **There are three `canon`
equations, four lines apart in the same file, and the second one is `hframed`'s negation.** The
claim was assembled from a grep hit that agreed with a hypothesis already formed — the same
mechanism as counting a `§` mention as coverage, in prose instead of in a metric. Ask it of a
*claim*, not just a published number: **what does this assert, and what else produces the
evidence I read it from?** The same pass mis-read `hframed` itself as an unproved lemma when
`canonSegs`' two branches make it *false* for §5.5a's absolute form — one definition, read
once, would have shown both. **Enforcement: none exists, and that is the point.**
`make leanseam` pins the cited text by digest and states in its own output that it does **not**
assert any correspondence is correct. This is the strongest argument on record for the
`docs/STATUS.md` §Next differential-trace-checking item, which is the only proposal that would
put a machine on this half of the seam. Until then the ledger is a human reading, and its own
rows say so.

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
- **The keystone peer's Lean tree is read-only input — never vendored, never edited.**
  `lean/` builds it from a *copy* (`lean/_work/`, gitignored) with the sibling mounted
  read-only, and the negative controls mutate only that copy. A local fork would make the
  assumption ledger a claim about our copy, which nothing gates, rather than about the peer
  that ships and that the conformance suite runs — the whole value of the seam. Findings on
  the Lean side are **routed to `entity-core-keystone`**, like spec findings are routed to
  the protocol repo.
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
