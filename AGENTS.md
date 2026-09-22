# entity-core-formalization

Read **AGENTS-STANDARD.md** first. This file adds entity-core-formalization specifics.

## Overview

Formal design assurance for the Entity Core Protocol — machine-checked verification of
the *protocol design at the pin* on the two layers Lean cannot structurally reach: **TLA+**
(distributed correctness under concurrency, safety + liveness — TLC, with **Apalache**
for inductive/unbounded invariants and **Spin** as an independent cross-check) and
**Tamarin / ProVerif** (active-attacker / Dolev-Yao security: capability unforgeability,
no escalation, no replay/reflection/confused-deputy). Models the current core; **all three extension
protocols — `attestation`, `quorum`, `identity` — are vendored, pinned and modeled too.**

## Proof tracks — know which protocol your claim is about

**`TRACKS.toml` is the registry and `make trackcheck` is its gate.** **4 proof tracks** —
**4 modeled** (`core`, `attestation`, `quorum`, `identity`), **0 scoped**. Every model file
belongs to exactly one; an unregistered file, a declared-but-missing file, or a file claimed
by two tracks fails the build. **Unless a statement names a track, it is about `core`.**
**Vendored is not pinned** — a track's `vendored` snapshot and its `pin_file` are separate
fields. All four are now both, and each track pins independently: core is held at `v0.8.2`
pending keystone, which has no bearing on the three extension pins.

**With `identity` promoted, the `scoped` gate has no subject.** It fired as designed twice —
`quorum` on 2026-09-07 and `identity` the same day, each forced to write its `MODELING-PIN-*`
before a model file could be declared — and it now asserts nothing about the live registry,
because there is nothing left in that state. Its teeth-test lives in `tools/trackcheck.py`'s
own test path, not in `TRACKS.toml`. **A gate whose input set has gone empty is a gate that has
stopped asserting**, which is the D15 mechanism (the input set is the claim) arriving by
subtraction rather than by a glob. Recorded here rather than found later.

Two things to internalize before writing an extension model. **The `§N.M` citation pattern
behind the coverage number is document-blind**, so `EXTENSION-ATTESTATION §5.7` and core `§5.7`
are the same token and core already has that row — extension citations would have been absorbed
into a *core* claim with `make coverage` green. Hence: a bare `§N.M` means a section of **your
own track's** `primary_spec`; a cross-track reference writes the sigil first (**`§CORE:6.2`**
inside an attestation model) and is excluded from every track's coverage set. *The sigil-first
order is a bug fix, not a style call: the draft form `CORE §6.2` matched 23 lines of ordinary
prose (`WHAT §6.9 SAYS`, `LIVENESS §4.1`) and silently dropped those citations.* And
**the file globs were non-recursive** (`tla/*.tla`), so
moving models into `tla/attestation/` would have hidden them from `coverage` and `specdrift`
while both stayed green — `trackcheck` walks recursively and cross-checks against git.
Subdirectories per track are a later step, deliberately taken *after* the gate exists.

`scoped` is gated, not decorative: a scoped track must have no models and no pin, so adding a
model file fails until the track is promoted **with** a pin. That promotion is where someone
says which snapshot the results are about, and it is not skippable by adding a file.

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
  rather than skipped inside it, and its 6 runs are counted separately from the 277. Maude 3.4 — Tamarin's required rewriting backend — is pinned via
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
is the learning on-ramp; `docs/PROPERTIES.md` is the PROVEN/MODELED scorecard, and
**`docs/CORROBORATION.md` is the per-subject engine ledger** — read it before quoting any
single result, because it is the file that says which claims rest on one engine.

- `spec-data/` — vendored, SHA-pinned, byte-for-byte spec snapshots. Currently `v0.8.0/`
  and `v0.8.2/`; **`spec-data/MODELING-PIN` names the one the models actually transcribe**
  (`v0.8.2`) and therefore the one every published result is about. Do not restate it
  here — read the file. `make specdrift` reports the distance from that pin to the live spec.
- `tla/`, `spin/`, `tamarin/` — per-engine workspaces and reports.
- Per-spike deliverable: a `FORMALIZATION-REPORT`-style note (properties proved /
  counterexamples / scope boundaries / on-ramp pain / go-no-go).

**Attestation track, 2026-09-07 — three modules, and several of its rows are FINDINGS.**
`tla/AttestIndex.tla` (§5.7 indexes) and `tla/AttestLive.tla` (§4.3 liveness, §5.2/§5.3 walks).
The second one refutes the spec rather than transcribing it: **`§5.3 find_live_head` cannot
traverse a chain of three** — it filters successors by the full liveness predicate, which is
false for any attestation that has a live descendant, so the link leading to the head is never
"live" and the walk returns null where a head exists. Corollary, green and more interesting
than the bug: **§5.1's head-resolution step is an identity map**, which is *why the cross-impl
vectors cannot catch it* — the composite is right because the liveness filter already did the
work. T4's lesson on a different composition. Routed
(`docs/status/ROUTING-2026-09-07-ATTESTATION-CHAIN-WALKS.md`) with the cohort measured first:
all three implementations diverge from the pseudocode identically, and `entity-core-rust`'s
`SPEC-AMBIGUITIES.md` ATT-1 asked for a ruling on the neighbouring half in v1.0 — **v1.1
adopted one of its two interim changes**, and this defect is the residue of the other.
`tla/AttestRevoke.tla` closes the self-revocation abstraction `AttestLive` had declared, and
finds that **§4.3's `is_self_revoked` is used in normative pseudocode and defined nowhere** —
the class v1.0 Amendment 1 already fixed twice in that same function. The two natural readings
give `is_attestation_live` different answers, so it is not editorial. **The transferable piece:
a declared abstraction is a to-do list, not an absolution** — O9 exists because someone read a
D11 inventory-boundary note back as work rather than as disclosure, and that was cheaper than
finding a new section to model.

**SECOND ENGINE ON THIS TRACK, 2026-09-08 — ALL THREE modules, and read the arithmetic.**
`tla/AttestIndexApalache.tla`, `tla/AttestLiveApalache.tla` and `tla/AttestRevokeApalache.tla`.
**Both other tracks have a second engine on ONE of three modules** — `tla/QuorumKofNApalache.tla`
(§4.1, the K-of-N validator) and `tla/IdentityCertChainApalache.tla` (§3.6 topology dispatch,
where every identity K-of-N verdict is decided). `tla/QuorumSignerSetApalache.tla` and
`tla/IdentityRecoveryApalache.tla` (§9.4 compromise recovery) followed on 2026-09-09, and
`tla/IdentityProcessApalache.tla` (§6.3 the arrival path) the same day — so **the identity track
has no single-engine subject left** and `quorumtrust` is the only one anywhere on the extensions.
So **9 of 9** extension subjects rest on two engines and **none rests on one**;
**no** extension subject has a third engine, and none of the nine has a prover. Do not let "the
attestation track has two engines" become "the extension tracks are corroborated." **That
sentence is now derived rather than recalled** — `docs/CORROBORATION.md` is the per-subject
ledger and `make enginecount` fails when this line disagrees with the green tables, because the
figure it replaced was written by hand one day and was stale the next.

**F1 is now confirmed by two structurally different methods** — TLC enumerates the graph space,
Apalache answers one SMT query over it — and §5.7's index contract is now proved *inductive*
rather than bounded. **What a second engine does NOT buy is independence from the
transcription:** these files are the same author's reading of the same spec text, so a shared
misreading survives both. Engines do not move the 5th wall, and the routed findings still rest
on a human reading of the pinned text.

**WHAT IT DID BUY, ON THE THIRD MODULE, WAS A FINDING THE FIRST ENGINE COULD NOT SEE — AND IT
REFUTED THE READING IT WAS PORTED TO CONFIRM.** F5 said §4.3 defends one of its two recursions
against cycles, and inferred that termination rests on the **revocation** graph being acyclic.
`AttestRevoke.tla` could not check that: its `Init` restricts *both* pointers to lower indices,
so the assumption it needed was hard-coded in the only file that could have measured it.
`AttestRevokeApalache.tla` splits the restriction into two constants and lifts them one at a
time. Result: **per-relation acyclicity is not the assumption.** With the supersedes order
lifted and the revocation order kept, §4.3's equation has no unique solution on a configuration
where **both graphs are acyclic** — the dependency `4 --supersedes-reach--> 1 --revoked-by--> 4`
closes a loop across the *composition*, and §4.3's `visited` set is scoped to one hop of a
recursion that alternates between the two relations. What the section needs is a **common order
over both**, which content addressing supplies and no sentence states.
**The transferable piece: an assumption hard-coded into a model is invisible to that model, and
a second engine is worth most where you point it at the first one's `Init` rather than at its
invariants.** O6's shape again, and the third time a written-down pre-model hypothesis has been
right about *where* to look and wrong about *what is there*.

**A FOURTH ENCODER FACT, AND IT REPLACES THE FIRST ONE'S REMEDY.** Unrolling into a ladder of
nested operator definitions is the obvious port and it does not survive a *mutual* recursion:
`~HasLiveDesc` and `~SelfRevFull` are negated existentials, so they become universals, and
Apalache expands a universal over a fixed range into a conjunction — branching |Nodes|^2 per
level, |Nodes|^(2k) leaves at depth k. Four levels at N = 4 is 65536 copies of the base and the
cap dies. **Build the ladder as a chain of STATE VARIABLES instead**, one application of the
equation each (`lT1 = StepFrom(Base, TRUE)`, `lT2 = StepFrom(lT1, TRUE)`, …): linear, and the
whole module then checks in three seconds. Three sharp edges come with it — write the level as
a *function constructor* (`v = [x \in Nodes |-> …]`), because Apalache's assignment solver does
not recognise the equivalent pointwise `\A x : v[x] = …` and fails with *"v' is used before it
is assigned"*; `\E f \in [S -> BOOLEAN]` inside an invariant is rejected outright (*"Trying to
expand a set of functions"*) while the universal form is accepted, because the negation is
skolemized; and **the obligation changes shape**. A ladder must justify its DEPTH; a fixed point
must justify its EXISTENCE AND UNIQUENESS, and neither failure prints anything — a short ladder
computes a wrong Boolean silently and a second solution is chosen silently. Hence
`LadderIsFixedPoint*` (deep enough *and* a solution exists, in one query) and `FixedPointUnique*`
(so the ladder's answer is *the* answer), both in the green table.

Three encoder facts worth having before writing the next one, all learned by OOM-killing the
2 GB cap rather than by reading documentation. **Apalache does not support `RECURSIVE`**, so
fuel-bounded recursion has to be unrolled into a ladder — and *every ladder depth is then a
claim*, so `UnrollDeep`, `MaxOfExact` and `SpecWalkNeverExhausts` exist to check the depths
rather than assert them in a comment. **`InlinePass` expands the whole module before the
"leaving only relevant operators" pruning takes effect on term size**, so one expensive operator
kills *every* invariant in the file, including ones already measured green — which is exactly
how the `IF`-ladder `MaxOf` was found. And **the natural TLA+ is often the wrong encoding**:
`CHOOSE` compiles to an oracle per occurrence, `S \cup UNION {f(p) : p \in S}` nested is a
combinatorial blow-up, `<=>` duplicates both sides, and `SUBSET S` over a symbolically-sized `S`
is unbounded. Each has a cheap equivalent; each rewrite is a place a transcription can drift, so
each one is commented at its site with what it replaced and why.

**Quorum track, 2026-09-07 — promoted `scoped`→`modeled`, three modules, 28 runs, SEVEN
findings.** `tla/QuorumSignerSet.tla` (§4.2 the resolver, with the clock), `tla/QuorumTrust.tla`
(§4.2/§4.2.1 the arrival-time trust model), `tla/QuorumKofN.tla` (§4.1 the validator). Routed
in `docs/status/ROUTING-2026-09-07-QUORUM.md`, indexed with attestation's in
`docs/status/FINDINGS-INDEX.md`. Four things to carry forward.

**A pre-model hypothesis is worth writing down PRECISELY SO you can find out how it was wrong.**
`TRACKS.toml`'s quorum note carried two, written before a line was modeled. One was right and
paid (*"model `not_before` and the clock explicitly from the start"* — with the clock in,
§ATTEST:4.3's undefined `not_expired` splits into two readings that disagree about whether a
**scheduled** membership change destroys the signer set). The other was right about the
assumption and **wrong about its status**: the closure is not *unstated*, it is *asserted* by
§4.2's cold-start posture and *falsified* by §4.2.1 non-trigger 1 and §8, three sentences in one
document. Both notes are left in `TRACKS.toml` unrewritten, which is the O6 discipline.

**The headline defect needs no attacker, and that is what makes it worth routing first.** On a
plain chain of three `quorum-update`s — nothing expired, nothing scheduled, nothing revoked —
§4.2 returns the roster the quorum was **created** with, because §ATTEST:5.3 returns null from
the oldest element and §4.2's fall-through is silent. A `quorum-update` that removed a
compromised signer is undone by the resolver that exists to apply it.

**A FINDING ROW CAN FLIP A CONSTANT *TOWARD* THE SPEC, AND THE GATE CANNOT TELL.** On this
track nothing is green under the spec's own constants, so the green sweep runs what the three
implementations actually do and the finding rows restore the spec's reading. That is the exact
inverse of a negative control, graded identically ("must fail, on this named invariant").
`tla/Makefile:TLC_FINDING`'s header now names the four rows this applies to and says the
distinction lives in each cfg's first line. **If you add a track where the spec-as-written is
not green, expect this shape and declare it; do not let the constants be the only record.**

**Measure the cohort, then measure it again for the next claim.** Three separate unanimous
results — none of the three implementations uses `updates[0]`; all three read `not_expired` as
full temporal validity; all three reject `threshold = 0` at `:create` when only §6.2 requires
it, and Go's comment credits that rule to a §3.1 that does not contain it. Three authors
deriving the same unwritten rule is the argument for writing it down. The exception is worth
as much: on the trust-closure finding the cohort follows the text **faithfully** and the text
is wrong, so "the impls work around it" is not a general law here either.

**Read O6 before repeating its reasoning:** the written-down hypothesis ("both walks lack a
bound, both rest on unstated acyclicity") was half right and *backwards on the interesting
half*. Modelling it, not re-reading it, is what separated the two.

**THIRD ENGINE-PORT ON THIS TRACK, 2026-09-09 — `tla/QuorumTrustApalache.tla`, AND IT CORRECTED A
CLAIM RATHER THAN FINDING A DEFECT.** §4.2.1's cache-invalidation contract has **three**
invalidation triggers. `tla/QuorumTrust.tla` has an action for two — trigger 3, *authority-
revocation arrival*, is in no action, no constant and no invariant — and
`ROUTING-2026-09-07-QUORUM.md` published *"the §4.2.1 contract is exactly sufficient"* naming
those same two. **A sufficiency claim over an incomplete rule set is a claim about a different
contract.** The correction is measured and comes out in the spec's favour: with the revocation
action added, `CacheMatchesValidated` is green and inductive over all three triggers. The
falsification of the old two-trigger form is a required-violation row (`OnlyAcceptInvalidates`),
not a paragraph. **The transferable piece is D13's cheaper half, arriving through a domain rather
than through a grading criterion: a green whose subject is a RULE SET is only as complete as the
model's ACTION SET, and nothing about it looks incomplete from inside** — every row passed, every
control had teeth, and the missing trigger produced no failure to investigate.

**AND Q5's REMEDY WAS THE WRONG CLOSURE.** Q5 said §4.2.1's "the cache reflects validated quorum
state" is false of §4.2's algorithm; the remedy that made everything green was a **read-side**
closure (only validated entries are readable). §8 permits `tree:put` to these paths, and
`tree:put(path, null)` is an unbind — which `QuorumTrust.tla`'s monotone tree could not represent.
With unbinds admitted the read-side closure holds and the cache still goes stale, because
non-trigger 2 forbids invalidating on the write that removed the entry. **What §4.2 needs is
write-side: the readable set changes only through validate-accept.** Routed as an amendment to Q5
rather than a new number (`ROUTING-2026-09-09-QUORUM-CACHE-WRITE-CLOSURE.md`); LEAN-SEAM **O11**
restated and still OPEN. Its cohort census for the two new directions is **declared not taken** in
that note — naming a census is not taking one.

**Identity track, 2026-09-07 — promoted `scoped`→`modeled`, three modules, 33 runs, NINE
findings, and the LAST scoped track.** `tla/IdentityProcess.tla` (§6.3 the arrival convergence
point), `tla/IdentityRecovery.tla` (§9.4 compromise-recovery validation), `tla/IdentityCertChain.tla`
(§3.6 topology dispatch, §9.2 key confinement). Routed in
`docs/status/ROUTING-2026-09-07-IDENTITY.md`, indexed with the other two in
`docs/status/FINDINGS-INDEX.md` (26 findings across five notes, 24 machine-checked). Five things
to carry forward.

**SECOND ENGINE ON §9.4, 2026-09-09 — AND THE TWO FINDINGS IT ADDED WERE ON A SUBJECT ALREADY
ROUTED.** `tla/IdentityRecoveryApalache.tla`. The corroboration half is unremarkable and worth
one sentence: every claim `IdentityRecovery.tla` makes reproduces, and §9.4's prohibition is now
proved *inductive*, so it covers unbounded replay where `MaxDeliveries == 2` covered two.
**The other half is D18's first payment.** The restrictions that mattered were not in `Init` —
they were a **cache variable with no key**, an **action the model did not have**, and a
**bounded counter**. §5.1 writes the §9.4 anchor at `contacts/{published_handle_hex}/…` and §9.4
reads it at `contacts/{old_handle_hex}/…`; a one-slot cache assumes those are the same handle,
and two ordinary events make them differ. **N1: a routine privacy rotation (section 13.3, dual-sig,
"the quorum doesn't sign this") moves the handle §9.4 will look up, produces no `quorum-publish`,
and no section requires a re-key or a re-publish — so the preventive rotation the spec recommends
removes the only compromise-recovery path, on all three implementations identically (C2).
N2: §6.3's `update_handle_cache_to` is named in a normative dispatch table and defined in no
section, and its two readings each satisfy ONE of two properties the spec states** — Go moves the
entry and breaks §6.3's idempotent semantic, Rust and Python retain it and make §9.4 usable once
per published handle, Python not implementing the handler at all (C3). The reading that satisfies
both is **measured green**, not proposed. Routed:
`docs/status/ROUTING-2026-09-09-IDENTITY-HANDLE-CACHE-KEY.md`.

**SECOND ENGINE ON §6.3 THE SAME DAY — THE LAST SINGLE-ENGINE SUBJECT ON THIS TRACK, AND THE
FOURTH CONSECUTIVE TIME A LIFTED DOMAIN PAID.** `tla/IdentityProcessApalache.tla`, 40 runs, and
it closes **O22**. `IdentityProcess.tla` has three variables and `Next == UNCHANGED vars`: it is
**one arrival**. But §6.3 phase 2 dispatches handlers that WRITE state and §3.6 steps 2 and 3
READ THE TREE that phase 2a DELETES from, so the arrival path is a **loop that writes what it
later reads** and one arrival cannot represent either half of it. Every ported claim reproduces.
Two new findings, both compositions of two arrivals:
**N3 — a revocation deleted on arrival leaves the cert it names permanently valid.** I2 already
said the revocation is unbound; §3.6 step 3 looks revocations up *in the tree*, so the revoked
cert is then admitted on every later arrival. Section 6.4 reasons about exactly this exposure and
**bounds it by convergence latency** ("a peer that has not yet observed it will cascade when the
revocation arrives via sync"); the revocation arrives and the window never closes, and that
section's own MAY-level mitigation re-reads the same deleted entry. Rust and Python exposed (C2),
Go not (C3). **The green under `ConstInitOK` is half the finding** — it names which repair closes
it. **N4 — an `identity-retirement` is undone by the retired cert arriving again**, because phase
2 dispatches on `(kind, function)` and consults no state, and phase 1 readmits the cert (§4.5 says
nothing about liveness; §ATTEST:4.3 liveness is supersedes plus revocation). **It is violated
under `ConstInitOK`, which on this track is the UNION of all three implementations' repairs** — so
no cohort workaround touches it. Both candidate repairs are measured green. Routed:
`docs/status/ROUTING-2026-09-09-IDENTITY-ARRIVAL-PATH-STATE.md`.

**AND THE HANDLER CENSUS N2 DID NOT TAKE (D14 — enumerate the class, do not fix the instance).**
N2 said `update_handle_cache_to` is "named in a normative dispatch table and defined in no
section." **All SEVEN handler names in §6.3's table occur exactly once in the whole document — in
the table.** None is defined anywhere. That is why N4's two candidate repairs are both statements
about text that does not exist, and it is the reason the finding is against the silence rather
than against an implementation.

**A PORTED INVARIANT CAN CARRY THE OLD DOMAIN IN ITS ANTECEDENT, AND ONLY THE CHECKER FINDS IT.**
`UnbindOnlyOnRejection` reads `Unbound => ~Step1Admits` in the TLC module — correct there, because
step 1 was the only way to fail phase 1. `SeedRowReachable` reads `DispatchRow => ReachesPhase2`,
and ported verbatim it **FAILED the inductive step** on a cert that legitimately does not dispatch
because step 3 revoked it. The claim was always about the KIND GATE; the single-arrival domain
made the missing antecedent invisible. We predicted the first widening and not the second. Sixth
consecutive session in which running, not reading, is what caught something.

**"WRITE THE WITNESS BEFORE THE PROHIBITION" PAID, AND THE PRE-MODEL NOTE WAS RIGHT AND
UNDER-SPECIFIC.** `TRACKS.toml` and the scoping doc both flagged §9.4 before a line was modeled:
a negative-reachability claim is the highest vacuity risk there is, *a peer that does nothing
satisfies it*. Followed literally. `RecoveryFailClosed` — the prohibition — is **GREEN**;
`RecoveryAttainable` — the witness, written as a positive claim so a machine can check it — is
**VIOLATED on the same constants**. The risk the note named was a MODEL with no paths. What it
found is a **SPEC with no paths**: §6.3 phase 1 rejects `quorum-publish`, so §6.3's own phase-2
row `(quorum-publish, *) → seed_contacts_cache` never runs, so §9.4's trust anchor is never
stored, so cross-peer compromise recovery — §9.6's only remedy for a stolen key — cannot
complete. **A conformance vector that checks only the fail-closed rejection passes on a peer
that can never recover.**

**A FINDING ROW'S CONSTANTS NAME THE SUBJECT ON TRIAL, AND THE SUBJECT IS NOT ALWAYS THE SPEC'S
WORDS — SOMETIMES IT IS THEIR ABSENCE.** The quorum track added the second shape (a constant
flipped *toward* the spec). This track adds a third: two rows flip toward **one implementation**,
because on their question the spec says nothing and the three impls answer three different ways.
`tla/Makefile:TLC_FINDING`'s header now carries all three shapes and names the rows. Also new
there: **one invariant is the target of both a finding and a control**
(`AcceptedRecoveryIsQuorumSigned`), which is a good sign about the property and a trap for anyone
reading the table without the cfg headers.

**WHEN A TRACK CONSUMES ANOTHER TRACK'S KNOWN-DEFECTIVE OUTPUT, MAKE THE ASSUMPTION A CONSTANT
WITH A NEGATIVE CONTROL AND OPEN A LEDGER ROW.** Identity calls `§QUORUM:4.2 current_signer_set`,
which this repo has already measured and refuted (Q1). Transcribing it would have re-derived
Q1–Q7 wearing identity section numbers and routed them twice; assuming it silently would have
made the choice invisible afterwards, which the prior checkpoint predicted. Neither:
`SignerSetIsSound` is a constant, TRUE in the green sweep and FALSE in
`IdentityCertChainSubstrateBug`, whose job is to exhibit what every identity K-of-N verdict rests
on. **LEAN-SEAM O16 is a new SHAPE of Class-O row** — not "no tool here reaches this" but "we
measured this input, found it defective, and assumed it anyway, on purpose, visibly."

**THE COHORT CAN DISAGREE WITH ITSELF, AND THAT INVERTS THE ARGUMENT THE LAST TWO TRACKS RESTED
ON.** On quorum, three authors independently derived the same unwritten rule three times and the
unanimity was the argument for writing it down. Here all three added a kind branch before §6.3
phase 1 that the spec does not have, and **no two did the same thing** — Go no-ops and caches
nothing, Rust caches unvalidated, Python validates and caches both quorum kinds, and only Go
admits `revocation`. §9.4 keys its fail-closed rule on exactly that cache, so **the peers do not
interoperate on compromise recovery.** "The impls work around it" is not a mitigation available
here; measure the cohort for *each* claim, and expect the census to sometimes be the finding.

**TWO GATES BEHAVED AS THEIR OWN FIX PROMISED, AND ONE STILL DOES WORK THE DISCIPLINE HAS TO DO.**
`make runcount`'s per-track widening (written the same day, on the quorum track) **failed
immediately** on a fourth track with *"track(s) identity have runs but no group in
TRACK_PROSE_SITES"* — the first evidence that fix was a fix and not a restatement. The `scoped`
gate forced a `MODELING-PIN-*` before a model file could be declared, for the second time.
**But `make coverage`'s tripwires did not catch what a human had to:** the first citation pass
cited **30** sections and nine were background, impact or "the property this exists to provide"
mentions. The scope-disclaimer tripwire passed all thirty — it matches *disclaimers*, not
*background* — so the audit down to **22** was discipline, not gate. `docs/COVERAGE-MATRIX.md`
§3e states which nine and why two of the same shape were kept.

**Where findings are tracked, 2026-09-08 — FOUR categories, and three of them had no home until
this date.** `docs/status/FINDINGS-INDEX.md` is the single index; read it before any handoff.
It covers: **spec defects** (26 across three extension protocols, 24 machine-checked, in five
routing notes — three per-track plus TWO that second engines added to a track already routed,
`ROUTING-2026-09-09-IDENTITY-HANDLE-CACHE-KEY.md` and
`ROUTING-2026-09-09-IDENTITY-ARRIVAL-PATH-STATE.md`); **validation-surface defects** (V1–V3, new, in
`ROUTING-2026-09-08-VALIDATION-SURFACE.md`); **implementation divergences** (D1–D19 in
`docs/status/CONFORMANCE-DIVERGENCE-REGISTER.md`); and **our own open work** (the ledger's OPEN
rows and the one subject with no second engine).

**The divergence register is the one to understand, because the gap it closes was invisible.**
Every spec finding here was written with a census of what `entity-core-{go,rust,py}` do — this
repo's own rule is census before impact claim (`docs/PROPERTIES.md` §D.1). **Those censuses were
evidence for spec findings and were tracked nowhere as observations in their own right.** An
implementation divergence is not a bug report about an implementation; it is a **measurement of
where the specification failed to converge three independent authors**, and it belongs in the
packet. Classified C1–C5 — and the classes matter more than the rows: **C2 is where the cohort
follows the text faithfully and nothing protects the field**, and **C3 is where the three
disagree with each other**, which crosses a peer boundary. Writing the register is what surfaced
V1–V3; none of them is visible from any single finding.

**Neither the register nor the V-rows is gated, and that is stated in both files.** Their inputs
are three sibling repos, so they go stale with our tree untouched — the `driftclaim` class
exactly (D15). Re-read the source before quoting a row.

**Status:** pinned at `v0.8.2`; the live spec is **0.8.2.14** and `make specdrift` reports
**9 of 31 cited sections moved**. Eight of the nine are additive clarification no model
contradicts; **§4.7 is the exception** — `connection_sequence_error` moved 400 → 409 and
`tla/ConnCodes.tla` transcribes 400. Re-vendoring is deliberately **not** the next move
(keystone has not upgraded yet); `docs/SPEC-DRIFT-ASSESSMENT.md` is the live measurement and
`make driftclaim` gates every prose site that states the status.
**All four pins are measured as of 2026-09-09, and until that date only one was.** `specdrift`
is per-track now: the track list is derived from `TRACKS.toml`, each track's pin comes from its
own `pin_file` and each track's live tree from its own `source_repo_path`, and a modeled track
no declared site states a status for is a build failure. The three extension files all **DIFFER**
from live and **no cited section moved** — one additive front-matter block each, before §1, zero
sections touched — so no finding changes. Read both halves: the file-level answer and the
section-level answer are different questions and this repo publishes the second one.
Phase 0 spikes, Phase 1 (TLA+ all-Core concurrency +
Tamarin/ProVerif active-attacker) and Phase 2 (prover surface-closure) are done. The full
**609-run** `make matrix` is the gate: all 11 concurrency/structural modules checked by TLC +
Apalache (23 inductive invariants) + Spin, both provers running every attacker theory
(15 ProVerif / 14 Tamarin lemmas), 100 negative controls and 13 non-vacuity witnesses.
No inductive invariant is deferred; no control is known-weak.

Two things are new and change how you read the rest. **`docs/LEAN-SEAM.md`** is the
assumption ledger — per abstraction in the models, the proposition relied on and the Lean
theorem (or sibling engine, or nothing) that discharges it, cited by content digest and
gated by **two** targets: `make leanseam` (has the cited *text* moved?) and `make leanproof`
(do the cited *proofs* still hold? — §7, 6 runs, needs the keystone sibling). It is where
the complementarity claim stops being prose. **It paid out on 2026-09-06:** the §5.5a
residual it found was adopted by the keystone peer, §5.5a now has a theorem per pattern form,
and both gates caught the movement — `leanseam` on the digests, `leanproof` on three new
theorems **by name**, refusing to accept a re-declare without a re-read. **Do not trust a
count of the ledger's rows that you did not derive:** it is 40 rows / 13 Class L, **14 OPEN**,
and a recalled figure has been published wrong here **four** times. Run **`make ledgercount`**
— it parses the ledger and fails when a declared prose site disagrees. *Note what this line
used to say and why it was wrong: "`leanseam` and `leanproof` print the live numbers." They do
not. They derive THEOREM counts and say nothing about rows or verdicts, which is exactly why
none of the four errors was reachable by a gate until `ledgercount` existed.*
**Row T4 closed 2026-09-06 by being refuted** — the composed `Core` model carries **one** of
six component invariants; the other five are manufactured by the refinement mapping
(`tla/RefMap.tla`, `tla/CoreMapFree.tla`). "The composed model is checked and the components
are checked" does not mean the composition is verified, and now there is a measurement of by
how much.
**`make coverage`** checks the coverage *claim* against the models' own `§`-citations,
because two rows of the grid turned out to be phantoms, and **`make runcount`** derives the
matrix run total from the gate tables and fails when a published site disagrees, because
that number went stale three times in one week. **The one protocol finding — §4.6 step 1 vs
§4.7's table, `docs/PROPERTIES.md` §D.1 — has been adopted and ruled** in
`entity-core-protocol` (401 `invalid_nonce`, the direction we argued). Read §D.1 before citing
it: the ruling came with two corrections to what we published, one from review of the text and
one from a wire measurement of the cohort, and **both are things this repo could not have found
from inside it.** Our source census was upheld exactly; our *remedy* and our *impact argument*
were not.
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
was also false.* Ten rows of `docs/LEAN-SEAM.md` rested on named Lean theorems in the
keystone peer (Class L was eleven rows; nine CLOSED, two CLOSED-MODULO-H, and L2 closed
by construction with no theorem to run — **the state on 2026-08-30; it is 13 rows and 12
CLOSED now**, and the counts in this paragraph are deliberately left at what they were when
the finding was made). `lake build EntityCoreProofs` is called "the proof check — a `sorry` or
failed proof fails the build" in five places in that peer — the lakefile, the proof-library
root, `profile.toml`'s testing contract and two status docs — and **is invoked by no
Makefile, script or workflow in that tree**, which has no CI directory at all. Asked D13's
question of it and answered by building all three cases: **a `sorry` is a *warning* in Lean,
so lake prints `Build completed successfully` and exits 0**; a hand-written `axiom`
replacing a proof exits 0 with no warning at all; only a proof that fails to type-check
exits non-zero. Exit status catches one failure mode in three, and misses the two a proof
check exists for. `make leanproof` grades the **axiom set** of all 40 `#print axioms` gates
against `lean/proof-gate.expect` in both directions, ties them to the ledger's own pin
block, and fails on any undeclared warning. Two transferable pieces: **a gate a sibling repo
says it has is a gate you have not checked**, and *a `sorry` reported as a warning* is the
same shape as ProVerif exiting 0 on a false query — the tool is telling you, quietly, in a
channel the grader does not read.

*The both-directions half is what earned its keep, 2026-09-06.* Keystone adopted the routed
packet and added three theorems. A gate asserting "37 declarations, all on the standard axiom
set" would have gone **green** on 40 — the new ones are standard-axiom proofs, so nothing
about them is anomalous except that **nobody here had read them**. Instead they arrived as
three `UNDECLARED_GATE` failures naming each declaration, and the grader printed its own
refusal: re-declaring the new axiom set is how this gate would come to assert nothing. **A
proof arriving is a diff, exactly as a proof breaking is** — the asymmetry is easy to build in
by accident, because only one of the two feels like a failure.

*Seventh instance, 2026-09-08 — asked of A SIBLING REPO'S VALIDATION SURFACE, and both halves
of D13 fired.* The fourth instance's transferable line was **"a gate a sibling repo says it has
is a gate you have not checked."** Applied it to the cross-impl test vectors the three extension
specs are conformance-tested against, and found two things.

**(a) The validation surface is STRANDED, not absent — and the first draft of this paragraph got
it wrong.** `VALIDATION-MATRIX-IDENTITY-FOUNDATIONS.md` is cited **20 times across 13 documents**
in `entity-system-architecture` — seven of them normative specs, one citation inside
`EXTENSION-ATTESTATION` §9's **conformance clause** — and `git log --all --diff-filter=AD` on the
path is empty in that repo. **From which this repo concluded, and published in five places, that
the file "has never existed." It exists**, in the archived pre-split architecture tree,
under the v7.0 core-revision reviews,
377 lines and **136 TV IDs** — including every vector we said was "defined nowhere," and
helper-level rows (`TV-F5`, `TV-F6`) calling `find_live_head` directly. Corrected 2026-09-08; see
the D15 note below, which is where the process lesson lives.

**What survives the correction is larger than what it replaces.** Architecture had already found
this (`REVIEW-2026-08-11-identity-pre-rotation-first-pass.md` §3) and **ruled** it
(`ROUTING-2026-08-11-c` §2); it is their named **cited-but-absent** class, whose first instance —
`system/peer/published-root`, definition stranded in the same archive — was routed and folded in
August; and their designed remedy, the **Q4 corpus-scoped linter that fails legacy-tree hits**, is
unbuilt. What this repo can add is the **cost**, which nobody had measured: `TV-IF19` is §9.2's
controller-confinement vector and **no implementation enforces §9.2**; `TV-IF13` is quorum-publish
caching and is exactly where the cohort split three ways. And **`PROPOSAL-IDENTITY-V3.2-MIGRATION-
FIXES.md`** — the ratification record Rust cites by name for its conformance posture — is likewise
in the archive, **uncited by the active corpus**, and is the common origin of F1's residue (SI-2),
F4/Q4's two undefined helpers, and F3's `as_of` MUST. **A stranded derivation keeps producing
defects in the corpus that survived it.**

**(b) The vector that DOES exist asserts a symptom.** Asked D13's own question — *what does this
assert, and what else satisfies it?* — of `ATTEST` TV-A4 (`A → A' → A''`, all live, expect
`A''`). It passes, and our routed F1 says `find_live_head` **cannot traverse a chain of three**.
Both are true: §5.1's head-resolution step is an identity map, so the vector exercises the
composite and the composite is correct because the liveness filter already did the work. **What
else satisfies TV-A4: a broken component whose defect is cancelled by its caller.** **Where a spec
defines a helper as a named normative algorithm, a vector over the composite that consumes it
asserts nothing about the helper.** Routed in
`docs/status/ROUTING-2026-09-08-VALIDATION-SURFACE.md`.

*Also corrected 2026-09-08:* this paragraph claimed TV-A4 "shaped three divergent walk
implementations" and left it there. **`TV-A4a`–`TV-A4d` exist, are behavioral, and pass in all
three peers** — Go drives all four over the wire (`cmd/internal/validate/behavioral_v33.go`),
Rust tests them at `extensions/attestation/src/tests.rs`. The cohort did the work. The divergence
is in *how* they walk, not in whether the transitive case is covered, and the helper-level rows
that would pin it were written and stranded rather than never designed.

The transferable piece, and it is why this is D13 rather than a bug report: **a test vector is a
grader, and every question this discipline asks of our own graders applies to someone else's.**
We had been reading TV rows as ground truth for three tracks.

*Eighth instance, 2026-09-08 — asked of THE INDUCTIVE PROOF ITSELF, and the answer was "less
than it says".* `apalache-green` checks two things per row: `Init => Inv`, and
`IndInit /\ Next => Inv'`. Where `IndInit` is just `Inv` those two ARE the inductive proof.
Where `IndInit` is `TypeOK /\ <strengthening> /\ Inv` — **20 of 26 rows** — they are not:
preservation of `Inv` *from strengthened states* establishes nothing unless the strengthening is
itself preserved, and **nothing checked that.** `docs/PROPERTIES.md` names the strengthenings
(`RefcountSound`, `DecisionSound`) and never asserts their closure. The published claim was
"proved **inductive**"; what was checked was weaker.

Answered it by RUNNING rather than reasoning — the D15 corollary, sixth consecutive session —
and **all 26 rows CLOSE.** Nothing was wrong. That is the point worth keeping: *this is the
cheaper half of D13 and the half that goes unnoticed, because the result of checking is that
nothing changes.* A gate that under-asserts produces no failure to investigate, so only asking
the question finds it. `make apalache-closure` (`APALACHE_CLOSURE`, 26 rows, in `green` and
`matrix`) now checks `IndInit /\ Next => IndInit'`, and its failure message says exactly what a
break would mean rather than "assertion failed".

*Sixth instance, 2026-09-07 — and it is about a gate table meaning TWO things.* The
attestation chain-walk model produces rows that **must be violated on a model where nothing is
weakened**: the transcribed spec algorithm fails a contract the spec itself writes. That grades
identically to a negative control, so the mechanical argument was to add three `TLC_NEG` rows.
Asked D13's question of the TABLE rather than the row — what does this table assert? — and
`TLC_NEG`'s own header answers: *"every row MUST fail — a green here means the property has no
teeth."* **That sentence is false of a finding row**, where a green would mean the defect had
been fixed upstream and the row should be RETIRED, not repaired. Two opposite meanings behind
one exit code, distinguishable only by prose nobody reads at failure time. Hence `TLC_FINDING`,
with its retirement condition written into the target's own failure message. `TLC_NEG` already
carried one such exception (`CoreMapFreeCarried`) explained in a paragraph; **a second
exception is a table.** Teeth-tested both ways before use — a row that goes green, and a row
naming an operator that does not exist.

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

***And for the WITHDRAWN-CLAIM half specifically, "grep the retracted words" is now a program:
`make retractcheck` (`tools/retractcheck.py`, `docs/RETRACTIONS.toml`), in `check` and
`matrix`.*** Nine rows, each with the phrasing, the date, why it was withdrawn — and a
**`witness`**, a document that must still contain the words, because a mistyped tripwire reports
a clean pass forever. It found one on its first run: **`tla/AttestRevoke.tla`'s header still
asserted F5's withdrawn conclusion** ("termination rests on the revocation graph being acyclic"),
in the model that is the subject of the correction, a day after the Apalache port refuted it.
D14's fifth instance again — *a corrected defect survives longest somewhere that does not look
like prose.*

**The row it CANNOT carry is the more useful half, and it is D13's question asked of the new
gate.** The §QUORUM:4.2.1 sufficiency retraction has no row and cannot: the withdrawn claim is
*"the §4.2.1 contract is exactly sufficient"* over **two** triggers and the corrected claim is
the same eight words over **three**. What was retracted is the SCOPE, and a phrasing tripwire
cannot see a scope. Stated in `docs/RETRACTIONS.toml` rather than papered over with a brittle
lookahead. **Two gates, two blind spots, and they are complements:** a derived-number gate
(`enginecount`) cannot see a paraphrase, and a phrasing gate cannot see a claim whose words
survive their own correction. Where neither reaches, the discipline is all there is.

*Fifth instance, 2026-09-06 — and it names the site class that gets missed.* The `:Z`→`:z`
bind-mount fix (2026-08-30) reached the two `MOUNT` lines and this file, and left the
**retracted reason** — "run the engines serially because concurrent `:Z` relabels race" —
standing in **five** places: `COVERAGE-MATRIX.md` §7 and `STATUS.md` as live guidance (the
latter under *"Known, documented non-issues (not bugs)"*, where it named as a platform quirk
what was our own defect); `FINAL-ASSURANCE-SUMMARY.md` as history with no resolution;
`tla/Makefile`'s own **header**, contradicting the `MOUNT` line twenty lines below it that the
same fix had corrected; and worst, **`CROSSCHECK-RESULTS.md`'s copy-pasteable reproduce
command**, which handed a reader `-v "$PWD":/work:Z` on the exact directory and image the bug
involved. **Add to the grep list: a corrected defect survives longest in a command a reader
runs**, because a code fix feels finished and a documented invocation does not look like code.
Grepping the withdrawn phrasing (`:Z`, "relabel", "race") found all five; grepping the subject
would not have.

*Sixth instance, 2026-09-07, and the mechanism is a QUANTIFIER whose set grew underneath it.*
`docs/COVERAGE-MATRIX.md` §4 opened with **"Every module is covered by all three engines of its
family"** — true when written, when `core` was the only track, and false from the day the
attestation track landed. It stayed false through two more track promotions and **nine TLC-only
modules**. Nothing was mis-derived: Matrix B has no row for an extension module and is accurate
line by line, and each extension grid says "one engine" plainly. The defect is entirely in a
summary sentence that quantifies over a set someone else grew. Grepping the *subject* (Apalache,
Spin, corroboration) finds hundreds of lines; grepping the **quantifier phrasing** — "every
module", "all three engines" — found the class in one pass: **four sites**
(`COVERAGE-MATRIX.md` §4, `README.md` §"What is verified", `FINAL-ASSURANCE-SUMMARY.md`, and
`CROSSCHECK-RESULTS.md`'s historical blockquote, which is left as written with a dated scope
note beside it because it is accurate history). **Add to the grep list: a bare universal
quantifier over your own artifacts.** `every`, `all`, `no module`, `nothing is` — each one is a
claim about an input set, and this repo's input sets have grown four times in two days. No gate
reads prose like this, which is why it survived three promotions.

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

*The input set a number is derived over is itself a claim — 2026-09-06, twice in one session.*
D15 says derive the figure from the artifacts and gate it. It does not say what defines
*which artifacts*, and in every tool here that was a **glob**, written once and never
re-asked. Two failures, same mechanism, opposite directions:
- **Too many.** `spec-drift`'s per-engine exposure line published **"15/1169 model files"** for
  a release. `tla/*.tla` matches the hundreds of gitignored `_TTrace_` specs TLC drops beside
  the real ones, so the denominator was mostly build artifacts. Nobody looked at it because it
  is not the headline number — and a derived figure nobody reads is exactly where this hides.
  It is 15/24.
- **Too few, and latent.** The same globs are **non-recursive**, so the first per-track
  reorganization (`tla/attestation/`) would have removed those files from `coverage` and
  `specdrift` **while both stayed green** — a gate silently narrowing its own subject.

Both are D15's mechanism one level down: *what does this number assert, and what else
produces it?* asked of the **file set** rather than the arithmetic. **`make trackcheck`
(`tools/trackcheck.py`) is the fourth enforcement point**: `TRACKS.toml` declares every model
file's proof track, the walk is recursive, and it is cross-checked against git — because
`make matrix` reads the engine Makefiles rather than git and can therefore *run* a file that
no claim-checking gate can see. Not promoted to its own discipline: it is the same mechanism
as D15, earned in a second medium. **If it bites in a third shape, give it a number.**

*And its own tripwire failed the same way, in the same hour.* The cross-track citation form
was drafted as `CORE §6.2` — prefix, space, sigil — which matched **23 lines of ordinary
prose** (`WHAT §6.9 SAYS`, `LIVENESS §4.1`, `THE §5.8`, every Spin `-D` macro name) and then
excluded each from that line's citation set: a guard against citations being *miscredited*
that silently **dropped** them. The published 28 survived only because every affected section
is cited on some other line too. The notation is `§CORE:6.2` now — sigil first, which cannot
collide with `§`+digit. Reading the regex did not catch it; running it did. **That is now four
consecutive sessions in which a new gate's first draft was wrong and only running it found
out.** Budget for it: writing the gate is half the work, breaking it is the other half.

*The letter suffix, 2026-09-07 — and this one bit the DENOMINATOR, which nobody had asked the
question of.* Writing the second attestation model produced a `§5.6a` citation.
`coverage-check.py` matched `§(\d+\.\d+)` and yielded `5.6` — but `§5.6` and `§5.6a` are
**sibling `###` sections** of that spec, so the citation would have been credited to a section
the model says nothing about. The §4.7 range-endpoint miscredit, through a different door.
Then the same question asked of the denominator: `SPEC_HEADING` excluded lettered headings
entirely, so **six normative core sections had never been in it** (`1.2a`, `1.5a`, `4.5a`,
`5.2a`, `6.9a`, `9.5a`). `28 of 85` was a fraction over a silently narrowed section set — and
so were the by-area figures published next to it. It is **29 of 91**.
**Two lessons worth more than the fix.** First: `tools/spec-drift.py` had `[a-z]?` in both its
patterns and had been right all along, which is exactly why it reports **30** cited sections
where `coverage` reported **28** — *two gates over one artifact, disagreeing by two, both
numbers published in the same documents, and nobody had reconciled them.* When two tools
derive a number from the same input, **make them disagree out loud or make them share the
definition**; a quiet two-unit gap is a gate telling you something nobody is listening to.
Second: `make coverage` checked the coverage pair at **one** site — the line inside the grid it
derives from — while three more published it. All three were found by grep. Declared prose
sites now, `runcount`-style. *(Still not its own discipline: same mechanism as D15, fourth
medium. The rule stands — if it bites where the mechanism is genuinely different, number it.)*

*Fifth medium, 2026-09-07, and BOTH instances were found by WIDENING a gate rather than by
breaking one.* Promoting a third proof track did not fail anything, and that was the problem.
- **A per-track gate that does not name every track is a per-SOME-tracks gate.** `runcount`'s
  split patterns captured exactly two groups, `core` and `attestation`. With `quorum` modeled
  the sentences still matched, both captured numbers were still right, and `make runcount` went
  **green while asserting nothing whatever about 28 runs**. Same mechanism as the non-recursive
  globs, one artifact over: the input set a gate checks, silently narrowed by an addition
  elsewhere. It now derives the tuple from the modeled set and **fails on a modeled track it
  does not read**, so a fourth track cannot repeat it.
- **A stale number hides best in a sentence that states it in DIFFERENT WORDS.**
  `make coverage` declared three prose sites; there was a fourth — `docs/STATUS.md` §Next
  item 1, `"they reach **28 of the 85** numbered sections"`, the pre-letter-suffix pair. It
  survived the grep that corrected the other three because that grep searched the canonical
  phrasing (`Coverage: N of M`) and this site does not use it. **Add to D14's grep list from
  the other end:** grep the retracted phrasing to find a withdrawn claim, and grep the *number*
  to find a stale one, because a paraphrase of a live claim is invisible to both a search for
  the subject and a search for the canonical words.
Neither is numbered: this is D15's mechanism in a fifth and sixth shape, not a new one. The
standing rule holds — if it bites where the mechanism is genuinely different, give it a number.

*Eleventh shape, 2026-09-09 — **A DISCLAIMER IS NOT A GATE**, and it is worse than nothing
because it reads as though the risk was handled.* `docs/status/FINDINGS-INDEX.md`'s open-work
table carries the sentence **"Do not quote these from here. Run `make ledgercount`, `make
runcount`, `make coverage`, `make specdrift`."** Both figures in it were wrong when the sentence
was read: the ledger row said **14 of 38** (it is 13 of 40) and the engine row said **5 of 9**
while naming four TLC-only modules, two of which had gained a second engine the previous
afternoon. Neither was a *declared site* of the gate that derives it, so the disclaimer was the
only thing standing between a reader and a stale number — and a disclaimer stops nobody, least of
all the author of the next session, who re-derived every other number in the repo and walked past
this table because its header said the numbers were not authoritative.
**The shape: a self-aware caveat is where a stale figure survives longest**, because it looks
like a site that has already been thought about. Grep for the caveat, not only for the number:
"do not quote", "derived by", "run `make`" next to a literal. Both rows are declared sites now
and both were teeth-tested three ways (wrong number, wrong pair, claim deleted). *Not numbered:
D15's mechanism — what is the input set of the gate — in an eleventh medium, and the standing
rule holds.*

*Twelfth shape, 2026-09-09 — **THE GATE FOR THE `driftclaim` CLASS WAS ITSELF IN THE
`driftclaim` CLASS**, and three things came out of one afternoon.* `make specdrift` had no
`--track` flag: pin, models and live tree were all hard-wired to `core`. Three tracks were
promoted on 2026-09-07, the tool did not notice, and by 2026-09-09 **all three extension pins had
drifted from live with every gate in this repo green** — found by hand, not by anything that runs.
D15 written about the tool that exists to ask D15's question of somebody else's tree. Fixed the
`runcount` way: `measured_tracks()` derives the list from `TRACKS.toml` and a modeled track no
declared site states a status for fails the build.

**Two more input-set defects fell out of the same read, and both had been SUBTRACTING silently
for the life of the tool.** `section_block` required whitespace directly after the section
number, and every top-level heading in every spec here is `## 4. Connections` — so a model citing
**`§4`** (`tla/Conn.tla`, `tla/Core.tla`, about the §4 dispatch rules) resolved to nothing and left
the denominator without a word. Same for `EXTENSION-QUORUM` §1, §2, §7, §8 — and §8 is the
`tree:put` clause Q5's amendment turns on. And **an unresolvable citation was DROPPED rather than
reported**, which is how eight `COVERAGE-MATRIX` document references (`§3b` meaning *that
document's* §3b) sat inside the citation set: they cancelled out by failing to resolve, so the
noise and the real omission hid each other. Both fixed — the published core pair is **9 of 31**,
unresolvable citations are a build failure, and a bare `§` in a model file now means what
`TRACKS.toml` says it means, in 31 lines across 23 files.

**And a fourth, which is the one to remember: the LIVE VERSION was never gated at all.** Nine
sites said *"the live spec is 0.8.2.11"* while it was **0.8.2.14**, `driftclaim` green throughout
— because the gate anchored the section COUNT and the count happened to still be 9. *Two facts in
one sentence, one of them checked, and the unchecked one is the one that moved.* Ask of a gated
sentence what ELSE it asserts. `check_live_version` now covers it.

*The teeth-test that mattered was the one expected to pass.* Four break tests fired correctly;
the RESTORE test then showed `make driftclaim` exiting non-zero on a correct tree, because the
rewrite had let the drift exit status leak into the claim exit status. A gate that fails whenever
drift exists — which here is every day — gets muted within a week. **Run the restored state too,
not just the broken ones.**

*Seventh and eighth shapes, 2026-09-07, and the seventh is D15 arriving by SUBTRACTION.*
Promoting `identity` emptied the `scoped` state: `TRACKS.toml` now has four modeled tracks and
none scoped, so the gate that refuses a model file on a scoped track **has no subject in the live
registry and asserts nothing about it**. Every prior instance of this mechanism was an input set
silently NARROWED — non-recursive globs, a two-group regex, a glob matching build artifacts.
This one went to **zero**, by an ordinary and correct addition elsewhere, and nothing failed.
**Ask of a gate not only "what is in its input set" but "can that set become empty, and would
anything say so."** Recorded in the §Proof-tracks section and in
`spec-data/MODELING-PIN-IDENTITY`, so the next person to scope a fifth track knows the gate has
been untested since.

The eighth is the counterpart, and it is about a tripwire's REACH rather than its input. The
identity models' first citation pass cited **30** sections; `make coverage`'s scope-disclaimer
tripwire passed all thirty; a human audit removed **nine** — background, impact and "the property
this section exists to provide" mentions, none of which is a *disclaimer*. The published pair is
**22 of 73**. **A tripwire that matches one phantom idiom does not cover the class**, and the two
that were kept (§6.0b, §6.0c) look like the same shape and are not — the claim "no operation
validates this" is modeled as a constant there. `docs/COVERAGE-MATRIX.md` §3e names all eleven
and says which way each went. The gate is worth having and the discipline still does work the
gate does not; do not let a green `coverage` stand in for reading your own citations.

*Ninth shape, 2026-09-08 — the input set of a PROVEN NEGATIVE, and it is the most expensive one
yet because the claim was published as a finding.* `AGENTS-STANDARD.md` says *"prove a negative
before you claim it — run an exhaustive named search and `git log --since`."* V1 did exactly that:
name search, `*MATRIX*` search, `git ls-files`, `git log --all --diff-filter=AD`, all clean, and
published **"the file has never existed"** in five places. **Every command was correct and the
input set was one repository.** The file is in the pre-split archive of that repository's
architecture tree, with 136 TV IDs — *including the three vector IDs the note asserted were
"defined nowhere."*

Three things make this worth the space. **The pointer was in hand and read backwards:**
`docs/LEGACY-ARCHIVE-INDEX.md` was cited by the note as evidence of absence ("indexes it as an
existing document"), and that file is a **title index OF the archive** whose own header says to
grep it before writing *"this is new to us."* A hit in an archive index is a location, not a
symptom. **The class was already known upstream and ruled** — same corpus, same month, same
`cited-but-absent` name — so the finding was not new, and *"has this already been found"* is part
of proving a negative about someone else's tree. And **the same bug recurred inside the
correction**: the first re-audit pass searched the archive with a wrong relative path, returned
zero hits for six terms, and would have "confirmed" our findings had a control not been run. **Run
a term you KNOW is present before believing a zero.**

*Enforcement, such as it is:* no gate — the input lives in two trees outside this repo, the
`driftclaim` class. What is enforceable is the checklist, and it is written here rather than in a
tool: a negative about the ecosystem's design corpus is not proven until the **pre-split archive**
has been searched full-text, `docs/LEGACY-ARCHIVE-INDEX.md` has been grepped, the owning repo's
own `docs/status/` and `reviews/` have been searched for a prior ruling, and a **positive control
term** has been run against every tree searched. Not numbered: this is D15's mechanism — *what is
the input set, and what else produces this result* — in a ninth medium, and the standing rule
holds. Full correction and the reframed ask: `docs/status/ROUTING-2026-09-08-VALIDATION-SURFACE.md`.

*Tenth shape, 2026-09-08 — **A MODEL'S OWN `Init` IS AN INPUT SET**, and this is the one that
has actually cost a published claim.* Every prior shape was a tool's input set: a glob, a regex,
a denominator, a gate whose state went empty. This one is the domain a model checks over, and it
differs from the others in a way that makes it worse rather than better: **it was disclosed.**
`tla/AttestRevoke.tla`'s header says, in plain terms, that `Init` restricts both the supersedes
and the revocation pointer to lower-numbered nodes and that every recursion terminates because
of that restriction rather than because of the algorithm. Nothing was hidden. And F5 — the
finding *about* that assumption — was then reasoned out in prose, published as "termination
rests on the revocation graph being acyclic", and was **wrong**: lifting the two restrictions
independently in `tla/AttestRevokeApalache.tla` shows §4.3's equation has no unique solution on
a configuration where *both graphs are acyclic*, because the recursion alternates between the
two relations and the real requirement is a **joint order over both**. The model that discloses
an assumption is the model that cannot measure it, and a disclosure reads as a conclusion.

**The candidate rule stated here on 2026-09-08 was PROMOTED on 2026-09-09** — it bit a second
time in a genuinely different shape, which is §3's ladder criterion, and the second bite is
recorded below. It is now **D18**, and the sentence it was promoted with is wider than the
sentence it was written with:

> **A model's domain restriction is a claim, and `Init` is only one place it lives.** An action
> guard that admits an event once, a data structure with a dimension collapsed out, a bounded
> counter, an action the model simply does not have — each excludes legal states exactly as an
> `Init` conjunct does. Make it a **CONSTANT with a control or finding row**, or book it as an
> **OPEN Class-O row** in `docs/LEAN-SEAM.md` naming what it excludes.

The remedy was already invented here independently, which is the argument for the rule rather
than against it: **O16** made identity's substrate assumption a constant (`SignerSetIsSound`)
with a negative control precisely so the choice would be "visible in the gate table instead of
invisible afterwards". `AttestRevoke` did the opposite with the same kind of assumption, and
paid.

*The class, enumerated 2026-09-08 across all nine extension models' `Init` — and the last row is
why the rule got promoted, because that enumeration's own input set was too narrow:*

| Site | Shape | Disposition |
|---|---|---|
| `AttestRevoke.tla` — `sup[x] < x` **and** `revt[x] < x` | unconditional, disclosed in prose | **FIXED 2026-09-08** — two constants (`SupOrdered`, `RevOrdered`) in the Apalache port, five finding rows, O10 closed and its statement corrected |
| `QuorumSignerSet.tla` — `sup[x] = NULL \/ sup[x] < x` | unconditional, **no constant, no control** | **OPEN, and now visible.** Same shape as the one that just bit, on the module carrying Q1. `docs/LEAN-SEAM.md` **O20** |
| `QuorumSignerSet.tla` — `WellFormedChain` as the *antecedent* of both cohort greens | invariant guard rather than `Init` | **OPEN**, already booked as O13 — a second shape of the same mechanism, disclosed and unmeasured |
| `AttestLive.tla` — `AllowCycles` | constant, with a control | done right |
| `QuorumKofN.tla` — `CreateValidates => k >= 1` | constant, with a finding row | done right |
| `IdentityCertChain.tla` — `HandoffIdentityEnforced` | constant, with a finding row | done right |
| `IdentityCertChain.tla` — `SignerSetIsSound` | constant, with a control | done right (O16, the precedent) |
| `AttestIndex`, `QuorumTrust`, `IdentityProcess`, `IdentityRecovery` | `Init` is a concrete start state, not a domain restriction | ~~not in the class~~ **TRUE OF `Init` AND WRONG ABOUT THE MODEL** — see below |

### D18 — a model's domain is a claim, and it is not only in `Init`

*The second bite, 2026-09-09, and it came through the table above.* `IdentityRecovery` is in that
last row, and the row is **accurate about `Init` and wrong about the model**: its `Init` really is
a concrete start state. Its domain restrictions were somewhere the enumeration never looked —
a **cache variable with no key** (§IDENT:5.1 writes the anchor under `published_handle`, §9.4
reads it under `old_handle`, and one slot assumes those are the same handle), an **action that
does not exist** (no §4.3 rotation, so the handle can never move), and a **bounded counter**
(`MaxDeliveries == 2`). Lifting all three in `tla/IdentityRecoveryApalache.tla` produced two
findings — N1 and N2, `docs/status/ROUTING-2026-09-09-IDENTITY-HANDLE-CACHE-KEY.md` — on a
subject nine other findings had already been routed from.

**That is D15's own mechanism applied to a rule about D15's mechanism:** the enumeration asked
"what does each `Init` restrict?" when the question is "what legal state can this model not
represent?", and grepping for the narrower question is how the wider class stayed invisible.
Same shape as the non-recursive globs, the two-group regex, and `runcount` not reading a gate
table added the same day (fixed in `tools/runcount.py` this session — it now fails on any gate
table in an engine Makefile that no row of `DERIVATION` counts).

*The widened sweep, run on promotion (D14 — enumerate the class, do not fix the instance):*

| Site | Restriction, and where it lives | Disposition |
|---|---|---|
| `IdentityRecovery.tla` — keyless cache, no rotation action, `MaxDeliveries == 2` | variable shape · absent action · counter | **FIXED 2026-09-09** — all three lifted in the Apalache port as `RotationsEnabled` / a keyed `anchor` / unbounded delivery; four finding rows, three greens on the repairs. `docs/LEAN-SEAM.md` **O21** |
| `IdentityProcess.tla` — three variables (`kind`, `src`, `hfail`), so **one arrival per run** | absent history | **FIXED 2026-09-09** — `tla/IdentityProcessApalache.tla` makes arrivals an unbounded sequence, with phase 2's handlers and phase 2a's unbind writing state the next arrival's phase 1 reads. Two findings (N3, N4), 9 greens, 4 controls, 6 witnesses; **O22 closed — ASSUMPTION FALSE**. The row's proposition was right and its PRICE was wrong: "nothing accumulated across arrivals is in reach" reads as a coverage gap, and the accumulation is where §IDENT:3.6 steps 2 and 3 get their INPUT |
| `AttestIndex.tla` — three fixed entities | bounded universe | disclosed and priced: "unbounded in STEPS, not in ENTITIES" (`docs/PROPERTIES.md`), and the third entity exists to make I1/I5's conditional half checkable |
| `AttestLive` / `AttestRevoke` / `QuorumSignerSet` Apalache ladders — unrolling depth | bounded recursion | done right: every depth is a ROW (`UnrollDeep`, `ConstInitLadderShort`), so a short ladder fails loudly instead of computing a wrong Boolean |
| `QuorumTrust.tla` — `~cached[q]` on `Walk` | action guard | ~~not in the class~~ **RIGHT ABOUT THAT GUARD AND THE WRONG QUESTION.** §4.2.1's "recompute on next call" IS a cache-miss guard, so that one really is the algorithm. But the sweep asked *which guards look suspicious* where D18 asks *what legal state can this model not represent*, cleared the guard it examined, and stopped. Three restrictions were elsewhere: **§4.2.1 TRIGGER 3 had no action at all**, the tree was **monotone** (`~tree[a]` on every write, and §8 permits `tree:put(path, null)`), and an attestation **arrived once**. All three lifted in `tla/QuorumTrustApalache.tla` 2026-09-09; O11 restated, Q5 amended, and a published sufficiency claim corrected. **FIXED** |
| `QuorumKofN.tla`, `IdentityCertChain.tla` | constants with control/finding rows | done right (O16 is the precedent) |

*Enforcement point, per §3's "a discipline with no enforcement point does not count":* the
`docs/LEAN-SEAM.md` Class-O column, plus the second engine's cinit table. A restriction with no
constant must carry a Class-O row naming what it excludes — O20 was the first added under the
candidate, O21 and O22 the first under the promoted rule. **The question to ask of a new model,
in these words: *what legal state can this model not represent, and which row says so?***

*And the corollary held for a fifth consecutive session, twice in one module.*
`IdentityRecovery`'s `RecoveryIdempotent` first read "two deliveries, one verdict" and the GREEN
cfg violated it immediately — on a behaviour that is entirely correct (fail-closed before the
anchor arrives, accept after). And `IdentityProcess`'s green sweep was VACUOUS on its first
draft: under the union of the cohort's repairs every kind was either admitted or pre-routed, so
the phase-2a unbind path was dead and two greens were true of a model that never unbinds
anything. **Both were found by running, not by reading** — the second by a witness coming back
clean, which is the whole reason witnesses exist. Budget for it: writing the model is half the
work, breaking it is the other half.

*Third and fourth enforcement points, 2026-09-06 — and the third one changes what "gate" has
to mean here.* `make driftclaim` (`tools/spec-drift.py --check-claims`) and `make ledgercount`
(`tools/ledgercount.py`). Both are the `runcount` shape applied one artifact over. What is new
is the failure mode behind `driftclaim`: **eight canonical documents said "`make specdrift`
reports no drift" while all three pinned spec files differed from live**, two of them in the
strongest available form ("byte-for-byte across all three normative files"). Every one was
true when written. **It went stale when a SIBLING REPO COMMITTED — our tree untouched, every
existing gate green, no diff for a change-triggered gate to fire on.** Every previous
stale-claim finding here went stale because *we* edited and missed a site. So:

**A claim whose input lives outside this repo cannot be gated by anything that runs only on
our diffs.** That is a difference in kind, not in thoroughness. `driftclaim` is therefore
deliberately **excluded from `check` and `matrix`** and says in its own output that it must be
run at a release boundary and on a schedule; `ledgercount`, whose input is our own file, is in
both. Two compounding causes worth remembering: `make specdrift` is wired `|| true` so running
it *cannot* fail (correct — drift is information), and `make specdrift-gate`, which can, **was
invoked by no target for nine days**. A target nothing calls is not a gate.

*And both first drafts failed the same way, which is now a standing note for this family.*
`driftclaim`'s matched raw text and failed six of nine sites on **markdown line-wrapping**;
`ledgercount`'s anchored row counts only and **would have gone green on all four historical
errors**, because every one was a *verdict* error and three had the row total right. Neither
was caught by reading the code. Both were caught by breaking the thing on purpose — D15's
corollary, again, at a rate of two per session.

### D16 — two structurally different engines, minimum; one engine is a hypothesis with a machine behind it

**A result this repo publishes as a property of the protocol is carried by at least two engines
that answer the question in structurally different ways. A result carried by one is allowed and
must SAY SO — in `docs/CORROBORATION.md`, by name, with the reason and what it would take.**
Absence of a second engine is never disclosed by the absence of a row.

*Why this is a discipline and not a preference.* **Five times now** the second engine has found
what the first structurally could not, and three of the five **refuted or corrected something this
repo had published**:

- **`AttestRevokeApalache` (2026-09-08).** F5 was reasoned out from an assumption
  `AttestRevoke.tla` hard-codes in its own `Init` — so the model that disclosed the assumption
  was the only model that could have measured it, and could not. Lifting the two restrictions
  independently showed §ATTEST:4.3's equation has no unique solution where **both graphs are
  acyclic**; what it needs is a joint order over both, which is stronger than what we published.
- **`QuorumSignerSetApalache` (2026-09-09).** The same experiment one track over, on the module
  carrying Q1. Four of §QUORUM:4.2's five checked properties are unaffected by the lifted order;
  one is not, and `CohortNeverSilentlyRevertsWhenAcyclic` says which weaker property was actually
  load-bearing. **The greens are half the result** — without them this is "removing an assumption
  broke something", which is not a measurement.

- **`IdentityRecoveryApalache` (2026-09-09).** The restrictions were **not in `Init` at all** — a
  keyless cache, an absent action, a bounded counter — which is what promoted the candidate rule
  to **D18**. N1 and N2, on a subject nine findings had already been routed from.
- **`IdentityProcessApalache` (2026-09-09).** The restriction was the model's **shape**: three
  variables and `Next == UNCHANGED vars`, so one arrival. §6.3's arrival path writes state its own
  §3.6 validator later reads, so the domain excluded the loop rather than a class of properties.
  N3 and N4. **This one refuted nothing we had published and widened two things we had** — I2's
  data-loss claim becomes an authorization claim, and O22's own ledger row turned out to be true
  and mis-priced.
- **`QuorumTrustApalache` (2026-09-09).** The fifth, and the only one whose target was a
  restriction the D18 sweep had **examined and cleared**. §4.2.1 has three invalidation triggers;
  that model has an action for two, so **a sufficiency claim this repo published was over a
  different contract than the one it named**. The correction came out in the spec's favour — the
  rules are exactly sufficient over all three — and the falsification of the two-trigger form is
  a required-violation gate row rather than a paragraph. It also amended Q5: the closure we named
  as the remedy is read-side, §8 permits unbinds as well as writes, and the closure §4.2 needs is
  **write-side**.

The generalization worth carrying: **point the second engine at the first one's `Init`, not at
its invariants.** An invariant re-checked is a second opinion on a question already asked; a
domain restriction lifted is a question the first model could not pose. That is D15's tenth
shape and D16 is how it gets funded.

*And the counter-clause, which is part of the discipline rather than a caveat on it.*
**A second engine does not buy independence from the transcription.** Two models of one section,
written by one author from one reading, share the reading; a misreading survives both. It does
not buy a different *question* either: TLC and Apalache are both model checkers over the same
`.tla` text, so `§QUORUM:4.1` now has two engines and **neither can express unforgeability**.
The things that move the 5th wall are a second *reader*, the cross-implementation census, and a
prover — and no extension track has one (`docs/LEAN-SEAM.md` O5, O14, O19). Never let "two
engines" be quoted as "corroborated" without the sentence that says what it corroborates.

*Enforcement:* **`make enginecount`** (`tools/enginecount.py`), in `check` and `matrix`.
`docs/CORROBORATION.md` declares subject → files → engines; the gate derives the engine set from
the **green** tables in the three engine Makefiles and fails on any disagreement, on a model file
in no subject, on a single-engine subject with no written reason, on a stale exemption, and on a
prose site whose corroboration pair has drifted. It is **33 of 35** subjects overall and **9 of 9**
on the extension tracks; do not quote either number without running it.

*It earned its keep in the hour it was written, on the derivation rather than the arithmetic.*
The first draft counted an engine as present when a FILE with that engine's extension existed.
`tamarin/BindingReplayBug.spthy` is on disk and there is no `BindingReplay.spthy` — so the draft
credited Tamarin with the replay result **on the strength of a file whose entire job is to
fail**. An engine now counts only where its green table names one of the subject's files, and
`tamarin/Makefile` already carried the explanation four lines from the bug: no-replay lives
inside `Binding.spthy`'s `no_replay` lemma. **A control is not corroboration**, and neither is a
witness or a finding row: they are claims about what breaks.

*Three more defects in the same tool, all found by breaking it and none by reading it, and the
last two are the interesting ones because they are D15's mechanism INSIDE a D15 gate.*
A green table the tool did not read (`TLC_GREEN_PAIRS`) made `CoreMapFree` look unverified — an
input set narrowed by omission. **The prose-site markers were written at each SITE, and the tool
reads only the ledger, so six of seven sites were parsed by nothing** and the gate went green
while asserting one line of one document; they are declared in `docs/CORROBORATION.md` now, which
also catches a site that deletes its claim. And **the site check asked whether SOME pair in the
window matched**, which a paragraph stating both pairs satisfies with one of them broken — it now
requires every `N of M` whose denominator is ours to be right. Sixth consecutive session in which
a new gate's first draft was wrong and only running it found out; budget for it, because writing
the gate is half the work and breaking it is the other half.

### D17 — an unenforced obligation is a defect, and so is a spec that lets two implementations disagree

**When a spec states a MUST, name the operation that enforces it and the vector that exercises
that operation. Where either is missing, that absence IS the finding — of the same weight as a
contradiction in the text, and reported the same way.** A specification's job is not only to be
consistent; it is to make independent implementations converge. **Where three ground-up
implementations could answer differently and nothing rejects either answer, the specification
has failed at its job whether or not any sentence in it is wrong.**

*Earned on this repo's own results, in three different shapes.*

- **The obligation with no enforcing operation.** Nine of the twenty-one routed spec findings
  share one shape (`docs/status/SEVERITY-2026-09-08-FINDINGS-TRIAGE.md` §4): a normative
  obligation stated in one place whose enforcement is assumed to happen somewhere that does not
  do it. §ATTEST:TV-A8 delegates to a step that does not exist; §QUORUM:4.2 rests on a closure
  §4.2.1 denies; §QUORUM:6.1 rests on an invariant §3.1 does not have; §IDENT:9.4 keys on a cache
  filled by a §6.3 phase-2 row §6.3 phase 1 makes unreachable. **Three of the nine could not have
  been written under this rule.**
- **The vector that asserts a symptom.** §ATTEST:TV-A4 passes on a peer whose `find_live_head`
  cannot traverse a chain of three, because §5.1's head-resolution step is an identity map and
  the vector exercises the composite. **Where a spec defines a helper as a named normative
  algorithm, a vector over the composite that consumes it asserts nothing about the helper**
  (D13's seventh instance, and the reason that instance is D13 rather than a bug report: *a test
  vector is a grader*). Its helper-level rows were written — and stranded in the pre-split
  archive, uncited by the active corpus (V1).
- **The cohort as the measurement.** On quorum, three authors independently derived the same
  unwritten rule three times, and the unanimity is the argument for writing it down. On identity,
  all three added a kind branch §6.3 does not have and **no two did the same thing**, so the peers
  do not interoperate on compromise recovery — a defect visible in **no single implementation and
  in no single sentence**, only in the census. That is `docs/status/CONFORMANCE-DIVERGENCE-REGISTER.md`'s
  reason to exist: an implementation divergence is not a bug report about an implementation, it is
  **a measurement of where the specification failed to converge three independent authors**, and
  its classes carry the weight — **C2** (the cohort follows the text faithfully and nothing
  protects the field) and **C3** (the three disagree, which crosses a peer boundary).

*The corollary that keeps this from becoming a licence to file everything.* A divergence is
routed as a **spec** finding when nothing in the text decides it, and as a **divergence-register
row** when the text decides it and an implementation went elsewhere. Deciding which is a reading,
and the reading is stated in the row.

*Enforcement:* `docs/status/FINDINGS-INDEX.md` is the register of record, and a routed finding
is not complete until its note carries three things by name — **the cohort census** (what
`entity-core-{go,rust,py}` each do, read from source, `docs/PROPERTIES.md` §D.1's rule), **the
operation the spec names as enforcing the obligation** (or "none", which is then the finding),
and **the vector that exercises that operation** (or "none", likewise). Grep for a routing note
with no census: it is not ready to file. **This is a documentary enforcement point and it is
weaker than a gate, deliberately** — its inputs are three sibling repos and the ecosystem's
design corpus, so it is the `driftclaim` class (D15): nothing that runs on our diffs can see it
go stale, and re-reading the source before quoting a row is the whole procedure. `V1` is what
happens when that is skipped.

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
  **Vendor each spec from the repo that owns it.** `entity-core-protocol/specs/` owns the
  three core specs. **The extension specs are owned by `entity-system-architecture`** — all
  26, including `EXTENSION-IDENTITY.md` and `EXTENSION-ATTESTATION.md`, in
  `../entity-system-architecture/specs/extensions/`. That is the ecosystem's ordinary layout
  and vendoring from both is the ordinary thing to do; the sentence above previously named
  only the core repo, so following it to vendor an extension finds nothing and the absence
  reads as *"the spec is not written yet"* when it is written and landed.
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
