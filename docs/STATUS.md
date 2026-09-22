# entity-core-formalization — status

_Updated: 2026-09-06 · this line: 0.8.2_

> **The models are pinned at 0.8.2; the live spec is 0.8.2.11.** Every model in this repo is
> written against the SHA-pinned snapshot in `spec-data/v0.8.2/`, which is the Entity Core
> Protocol at spec version **0.8.2**. `make specdrift` reports **9 of 30 cited sections
> moved**, so the results below are a statement about **0.8.2** and not about the protocol as
> it stands today.
>
> This paragraph said *"the models track the live spec … byte-for-byte across all three
> normative files"* until 2026-09-06, in this file and seven others, while all three files
> differed. It was true when written and went false without a commit in this repo — see
> §Next item 14 for why that is a different failure mode from every previous stale claim
> here, and `docs/SPEC-DRIFT-ASSESSMENT.md` for what the drift actually costs.

## Proof tracks

**4 proof tracks** — **4 modeled**, **0 scoped** — declared in `TRACKS.toml`, gated by
`make trackcheck`. **Every number below is a statement about `core` unless it says
otherwise**; the `attestation` and `quorum` tracks are days old and are reported separately.

| Track | Subject | Status |
|---|---|---|
| `core` | Entity Core Protocol | **modeled** — 95 model files, 277 runs, pinned at `spec-data/v0.8.2` |
| `attestation` | signed-edge substrate; four mandatory indexes; supersedes chain | **modeled** — 3 modules, 23 runs, TLC only, pinned at `spec-data/ext-attestation-v1.3` |
| `quorum` | K-of-N rosters; `quorum-update`/`quorum-publish`; `current_signer_set(as_of)` | **modeled** — 3 modules, 28 runs, TLC only, pinned at `spec-data/ext-quorum-v1.2` |
| `identity` | cert chains; rotation by handoff and by recovery; retirement | **modeled** — 3 modules, 33 runs, TLC only, pinned at `spec-data/ext-identity-v3.10` |

Added 2026-09-06, **before** any extension model exists, and that order is the point. The
coverage number is derived from a *document-blind* `§N.M` pattern, so an
`EXTENSION-ATTESTATION §5.7` citation is indistinguishable from core `§5.7` — which already
has a grid row. The first extension model would have had its citations absorbed into a **core**
coverage claim with `make coverage` reporting OK: a phantom row arriving *through* the gate
built to stop phantom rows (§3b's failure, one spec body over). The second half was quieter —
`coverage-check.py` and `spec-drift.py` globbed `tla/*.tla` **non-recursively**, so the obvious
first reorganization (models into `tla/attestation/`) would have made them invisible to both
gates, which would then stay green while asserting nothing. `trackcheck` walks recursively and
cross-checks the walk against git for exactly that reason.

`scoped` is a **gated state, not a note**: a scoped track must carry no models and no pin, so
assigning a model file to one fails the build until it is promoted *with* a spec pin — the step
where someone states which snapshot the results are about. Physical subdirectories per track
are a deliberate follow-up, and are safe to do once a file that falls out of the gate's view is
a build failure rather than a silent green.

## Where it is

The **formal design-assurance layer** of the Entity Core Protocol. It machine-checks
*models of the protocol design at the pin* on the two layers the Lean authority proof
(in the keystone peer) structurally cannot reach:

- **Distributed correctness + liveness under concurrency** — TLA+/TLC, with **Apalache**
  (SMT/Z3) lifting key safety invariants to *unbounded* inductive proofs and **Spin**
  (Promela) as an independent re-encoding cross-check.
- **Active-attacker protocol security** — **Tamarin / ProVerif** over the Dolev-Yao
  symbolic model (capability unforgeability, no escalation, no replay/reflection/
  confused-deputy).

It is additive assurance and a research **demonstrator**, deliberately **off the release
critical path**: it verifies the *design*, not any implementation, never edits the spec,
and routes any model-surfaced design finding to the sibling `entity-core-protocol` repo as
a proposal. Every model cites the § it transcribes, every secure result has a negative
control that reproduces a *named, real* bug class, and — new at 0.8.2 — every TLA+ module
carries a **non-vacuity witness** proving it reaches an interesting state at all.

A bare host with **only `make` + `podman`** runs everything — all five toolchains
(`entity-tla`, `entity-apalache`, `entity-spin`, `entity-proverif`, `entity-tamarin`) are
containerized, each under a hard memory cap so a runaway check is OOM-killed cleanly
instead of thrashing the host. `make build` → `make smoke` → `make matrix` → `make clean`.

A sixth image, `entity-lean`, serves the **Lean seam tier** (`make lean`) and is built
separately by `make lean-image`: that tier checks the sibling keystone peer's proofs, which
a bare clone does not have, so it is excluded from `make matrix` rather than skipped inside
it. See §Next item 4 and `docs/LEAN-SEAM.md` §7.

## Where we left off

The 0.8.2 re-target is **complete**: the models were re-read against the new snapshot, the
normative surface 0.8.1/0.8.2 added was modeled, and `spec-data/MODELING-PIN` moved to
`v0.8.2` as the **last** step of that work. What is proved, at demonstrator altitude:

- **TLA+ track.** **11 modules** bounded-exhaustive in TLC — the 6 Core-Protocol concurrency
  modules (reentry, conn, store, revoke, emit, register), the composed 2-peer `Core` model,
  the two added at 0.8.2 (`Authority`, `Bounds`), and the two added by the second gate audit
  (`ConnCodes` §4.7, `Bootstrap` §6.9) — safety **and** liveness. Apalache proves **23 safety
  invariants across all 11 modules** *inductive (unbounded in steps)*; liveness stays
  bounded-exhaustive in TLC + Spin by nature.
- **Cross-check.** Spin **independently re-encodes all 11 modules** from the spec (reproducing
  the marquee Class-G reentry deadlock); both Spin and Apalache agree with TLC on every
  green result and every negative control (`docs/CROSSCHECK-RESULTS.md`).
- **Prover track.** Tamarin + ProVerif close **14 lemmas in lockstep** (unforgeability,
  no-escalation, binding/no-replay, caveats, depth-bound, deep-chain frame integrity,
  expiry, malformed-temporal ingest, third-party chain topology, K-of-N multisig,
  revocation, persistent re-check). No-replay is proved by **both**, in different theories:
  Tamarin inside `Binding.spthy` (a linear consumed-nonce fact), ProVerif in a separate
  `BindingReplay.pv` (injective correspondence over a challenge-response handshake, because
  ProVerif's tables are not atomic under replication). The 15-vs-14 count is that packaging
  difference, not a coverage gap; the one real tool asymmetry is `RevokeMech`.
- **One protocol finding**, the repo's first that is a defect in the spec text rather than a
  boundary worth stating: **§4.7's error-code table gives two contradictory normative answers**
  for an `authenticate` arriving before any hello nonce was issued — 401 `invalid_nonce` by
  its row 6 (and §4.6 step 1), 400 `connection_sequence_error` by its row 10, both MUSTs, in
  one table, on the very field §4.7 tells clients to key error handling off. Exhibited
  independently by TLC, Apalache and Spin — and **already divergent in the wild**: **six**
  distinct behaviours across the 46-peer keystone cohort and the three ground-up impls, with
  no `validate-peer` probe for the input. **Adopted and ruled 401 `invalid_nonce`** in
  `entity-core-protocol`; the census has since been *measured* by `entity-core-keystone` rather
  than read, which upheld ours and corrected two things we published. Full statement, both
  corrections, and why our four-word remedy was incomplete: `docs/PROPERTIES.md` §D.1.
- **The full matrix is 361 runs** and `make matrix` is the gate: **green** (does every
  property hold?) + **negative controls** (could it have failed?) + **witnesses** (does the
  model do anything?). Green alone answers only the first question, which is why `make
  check` now says so out loud. `make coverage` runs first and checks the coverage *claim*
  against the models' own citations.
- **Nothing is deferred.** The composed whole-protocol Apalache conjunction — carried as
  "consciously deferred" since Phase 1 — was proved in the 0.8.2 audit, the four modules
  that had single-tool coverage now have all three, and the last two single-engine *section*
  rows turned out to be phantoms and are now real modules on all three engines.

- **The Lean seam now has a second gate, and finding out why it needed one is the result.**
  `make leanseam` checks that the Lean *text* our assumption ledger cites has not moved. It
  cannot check that the text still *proves* what the ledger says — and nothing did.
  `lake build EntityCoreProofs` is called "the proof check" in five places in the keystone
  peer — the lakefile, the proof-library root, the peer's `profile.toml` testing contract and
  two status docs — and **is invoked by no Makefile, script or workflow in that tree** (which
  has no CI directory at all); ten ledger rows rest on named Lean theorems and every one of
  them rested on a build nobody ran.
  Worse, the claim is wrong as written: **a `sorry` is a warning in Lean, so `lake build` exits 0 and prints "Build
  completed successfully"**, and so does a hand-written `axiom` standing in for a proof —
  each built and observed, not reasoned about. Exit status catches one failure mode in
  three. `make leanproof` therefore grades the **axiom sets**: 40 declared `#print axioms`
  gates, exact set per declaration in both directions, tied to the ledger's own pin block,
  with five controls (`neg-sorry`, `neg-axiom`, `neg-ungate`, `neg-dropfile`, `neg-broken`)
  each required to fail for its own reason on the declarations it names. **6 runs, separate
  from the 277** — they need the sibling
  checkout, and every published number here is reproducible from a bare clone.
  `docs/LEAN-SEAM.md` §7.
- **The tier was then audited before it was committed, and the audit found five things.**
  Framing: *we just built a gate whose whole
  subject is gates that assert less than they claim; does this one?* Five hypotheses, five
  confirmed. The sharpest: **the green gate met D13 and its own controls did not** — each
  declared a reason-code *count*, which any three contaminated declarations satisfy, in a
  table written the same day it cited the three Tamarin controls that made exactly that
  mistake. All controls now declare **which** declarations must carry each code. Also: a
  fifth control for the file-level case, a misdiagnosed missing-image error, the "eleven
  CLOSED rows" miscount above, and `runcount`'s own first draft failing D13. **No new
  discipline** — every finding is an instance of D13/D14/D15, which is the useful part.

| slice | runs |
|---|---|
| TLC green (20 modules + Store liveness slice + `Reentry3` + `Core3` + `RevokeDeltaZero` + `CoreRefines` + 6 T4 classifier rows) | 31 |
| TLC negative controls | 65 |
| TLC non-vacuity witnesses | 42 |
| TLC findings (must be violated; `tla/Makefile:TLC_FINDING`, whose header states which rows weaken nothing, which read toward the spec, and which read toward an implementation because the spec is silent) | 25 |
| Apalache inductive (24 invariants × base+step, + 2 at N=3) | 52 |
| Apalache negative controls | 24 |
| Spin green (7 × safety+LTL, 4 safety-only, 3 × safety+LTL variant rows) | 24 |
| Spin negative controls | 39 |
| ProVerif (15 green + 15 controls) | 30 |
| Tamarin (14 green + 15 controls) | 29 |
| **total** | **361** |

Split by proof track, derived by `make runcount` rather than stated by hand: **277 runs** on
`core`, **23** on `attestation`, **28** on `quorum` and **33** on `identity`. Attestation:
`AttestIndex` — 1 green, 3 controls, 3 witnesses; `AttestLive` — 1 green, 2 controls,
3 witnesses, 2 findings; `AttestRevoke` — 1 green, 2 controls, 3 witnesses, 2 findings. Quorum:
`QuorumSignerSet` — 1 green, 2 controls, 3 witnesses, 5 findings; `QuorumTrust` — 1 green,
3 controls, 3 witnesses, 2 findings; `QuorumKofN` — 1 green, 2 controls, 3 witnesses, 2 findings.
Identity: `IdentityProcess` — 1 green, 4 controls, 3 witnesses, 3 findings; `IdentityRecovery` —
1 green, 2 controls, 3 witnesses, 5 findings; `IdentityCertChain` — 1 green, 3 controls,
3 witnesses, 4 findings.
The four are different protocols against different spec pins, so the total is a fact about the
gate rather than about any one subject; the per-track figures are the ones to quote. The
derivation also fails if any gate-table row names a module no track declares — a run whose
track cannot be determined is not silently counted as core.

Plus **6 runs in the Lean seam tier** (`make lean`: 1 green + 5 negative controls), counted
separately and deliberately: they require an `entity-core-keystone` checkout, so they are not
reproducible from a bare clone and must not inflate a number that is.

**Section-by-section coverage, per-engine, with every limit stated:
`docs/COVERAGE-MATRIX.md`** — the document to send a new reader to. Headline: **29 of 91
numbered sections (32%)**, which by area is **§4 64% · §5 91% · §6 57%** — the three surfaces
this repo owns — with §2/§3/§7–§9 deliberately out of scope rather than missed.

### What 0.8.2 added, and where it now lives

0.8.1/0.8.2 were largely conformance findings written down as normative clarification. The
structure was completely stable — no section added, removed or renumbered, and all 35 model
`§`-citations still resolved — so the work was **new territory to model**, not contradicted
results. Five pieces of new normative surface, each with a negative control that reproduces
the named defect:

| § | requirement | now modeled in |
|---|---|---|
| **§6.11 (a′)** | frame-write atomicity (0.8.1 RT-13b) — two frames' bytes MUST NOT interleave on a pooled connection | `Reentry.tla`/`ReentryApalache.tla` + `reentry.pml`, and under composition in `Core.tla`/`CoreApalache.tla` + `core.pml` |
| **§4.8** | an unsynchronized content-store refcount decrement is a use-after-free (0.8.1 RT-13a) | `Store.tla`, `StoreApalache.tla`, `store.pml` |
| **§5.6 CAP-6a** | an unrepresentable temporal field is malformed and MUST NOT read as absent | `Malformed.pv` + `Malformed.spthy` |
| **§5.2** | the dispatch authority is three-valued (SELF/GRANT/ABSENT-must-deny); the resource check binds sub-dispatches; no resource inheritance | `Authority.tla` *(new)* |
| **§5.9 / §4.10(b)** | TTL and continuation `chain_depth` are distinct magnitudes; TTL decremented once per dispatch; distinct reason strings | `Bounds.tla` *(new)* |
| **§5.10** | a finite, declared, honored `revocation_propagation_bound` (0.8.1 W7 Knob 2) | `Revoke.tla` |
| **§5.8** | cross-peer provenance verified by a party that constructed **no link** in the chain | `ChainTopology.pv` + `.spthy` *(new)* |

Two of these are sharper than "add a property":

- **§6.11 (a′) and (a) pull in opposite directions** — (a) forbids holding the connection
  lock across send+recv, (a′) requires holding it for a frame's bytes — and the spec asserts
  they are jointly satisfiable by a lock whose hold duration is exactly one frame. The green
  config asserts **both at once**, and the two controls each break exactly one: dropping (a′)
  costs byte integrity and *not* liveness; dropping (a) costs liveness and *not* byte
  integrity. That joint satisfiability is the theorem.
- **§5.2's three-valued rule is a claim that no two-valued encoding is correct.** `Authority`
  checks it as such: `option-allow` satisfies entry dispatch and authorizes every grantless
  sub-dispatch; `option-deny` refuses the grantless sub-dispatch and breaks entry dispatch;
  each was run separately to confirm it holds the property the other breaks. Only the
  three-valued encoding satisfies both.

### The verification's own defects — where this repo actually gets bitten

Every defect the last two audits found was in the **verification**, not the protocol, and they
share one shape: **a green that means less than it appears.** They are listed here rather than
buried because the pattern is the thing worth carrying forward.

| What | Why it read as green | Now |
|---|---|---|
| Spin `-DNOESTABGATE` compiled out the establishment gate **and** its detector | `errors: 0` — indistinguishable from a pass | detector no longer variant-conditional |
| An Apalache control too **short** to reach its defect | `NoError` — textually identical to "the invariant holds" | lengths carry margin, trap documented in `tla/Makefile` |
| Four Tamarin theories failed Tamarin's own **wellformedness** checks | Tamarin exits **0** when lemmas verify, printing *"the analysis results might be wrong"* on the way out | a wellformedness failure is a **build failure** in both prover targets |
| `DeepChainN`'s `DelegateB` had a **free variable in its rule conclusion** | the delegatee was bound by no premise, so the backward search could instantiate it at will | `In(gC)` premise added, as its sibling rule already had |
| `Malformed` used `Repr` at **two arities** | an arity-0 action label colliding with the arity-1 fact carrying the whole §5.6 encoding | action renamed `ReprSeeded()` |
| `Reentry`/`Core` `StoreBounded`, and `core.pml`'s clamped store write | a conjunct that could not fail; in Spin, an assertion **enforced by the statement three lines above it** | removed as a structural exclusion; `Store` owns the real bound |
| `tlc-neg` graded on **exit status** with output discarded | TLC exits non-zero for a parse error exactly as for a caught defect | all 30 rows declare the verdict line they must produce |
| **`proverif-green` had no verdict gate at all** (15 runs) | graded on the exit status — and **ProVerif exits 0 with a FALSE query**, the fact already written on the target below it | graded against `PV_EXPECT`: every query declares its verdict |
| **`proverif-neg`'s criterion was met by the SECURE theory** (15 runs) | required "some `RESULT … is false`" — which is also how a passing *non-vacuity* query reports, and 13 of 15 secure theories carry one | graded against `PV_NEG_EXPECT`, per query |
| **`apalache-neg` + `tlc-witness` graded on exit status, output discarded** (15 + 9 runs) | the `tlc-neg` defect, in the two targets that pass never opened: Apalache `255` (config error) vs `12` (counterexample); TLC `151` (undefined invariant) | `EXITCODE: ERROR (12)` required; each witness must name its own invariant |
| Three Tamarin controls falsify their own **reachability** lemma | `grep -q falsified` matched `falsified - no trace found` — the honest path dying reads the same as the property breaking | declared per lemma in `TM_NEG_EXPECT`, then **all three narrowed**: each carries a §5.5a absolute-form leaf (frame-independent, so the defect cannot reach it), so the honest path survives and the control falsifies its target alone |
| **Spin's `neg` target graded on `errors: [1-9]`** (29 runs) | pan reports a positive error count for an assertion, a **deadlock** and a broken liveness claim alike — a control whose model merely blocks scores as one that catches its defect | every row declares its pan failure signature. Found live: `bootstrap.pml`'s two-stage guard made two new controls "fail" without reaching their assertion. All 29 pre-existing rows audited — every one was failing for its stated reason, so the gate was blind, not wrong |
| **The coverage number counted `§` mentions, not claims** (2 phantom rows) | Matrix A is *derived* from the models' own citations so it cannot be hand-chosen — but a range endpoint (`§4.1-§4.7`) and an out-of-scope disclaimer ("§6.9 … not modeled") both scan as citations. §4.7 and §6.9 were listed as covered while nothing modeled either | `make coverage` checks the cited set against the grid in both directions, plus the count, the denominator and two citation-hygiene tripwires. Both sections are now genuinely modeled on all three engines |
| `Unforge.pv` / `Binding.pv` carried **no non-vacuity query** | pure correspondence lemmas go green on a model that can never accept; their Tamarin twins both had an `exists-trace` lemma | queries added; both fire |

The pattern is the enforcement point for the rest: a control that fails for the wrong reason,
or a run that fails to run at all, is no longer distinguishable from teeth by accident. Note
what the second audit found: **fixing three of the five graders left the other two, plus both
ProVerif targets, exactly as they were** — 62 of the 203 runs. The lesson is not "check the
controls", which was already the rule; it is **apply a finding to every instance of its shape
before closing it**. No verdict moved in either pass; all 203 were re-derived by hand and match
what the reports claim.

And the third pass found the same shape again in two places the first two never looked:
**Spin's `neg` target**, which the first audit had hardened against compile failures but not
against *failing by the wrong error kind*; and **the coverage number itself**, which is a
derived metric rather than a gate and had never been asked D13's question. That is what
earned **D15**: a number computed from the artifacts is a claim, and it is only as honest as
what the computation counts. Both now have gates, and both gates were teeth-tested by
breaking them — which is how the coverage gate's first draft was caught matching
`invalid end state` against pan's *search-options header* rather than its error line.

### All three thin positives retired

- **Retired.** `Store`'s store-cardinality conjunct was **vacuous** — a single key against a
  bound of 2, so it could not fail (disclosed in `PROPERTIES.md` since Phase 1, never
  fixed). The store is now multi-key, the bound is falsifiable, and what discharges it is
  refcount correctness — the composition §4.8 actually asserts.
- **Retired.** The TLA+ track had **no non-vacuity assertions at all**, unlike ProVerif's
  reachability queries: a trivially-inert model would have reported the same green as a
  working one. Every TLC module now has a witness config that must be violated, and
  `make -C tla tlc-witness` fails loudly if a witnessed state becomes unreachable.
- **Retired.** `Reentry`'s and `Core`'s `StoreBounded` were vacuous conjuncts — one literal
  key written once against a bound ≥ 1 — and `Core`'s was carried into the composed Apalache
  conjunction. Removed as a structural exclusion rather than patched: the bound has no content
  in models whose servers serve once, so giving it teeth would mean duplicating `Store`.
  Disclosed as vacuous twice before being fixed, which is twice too many.
- **~~Still open.~~ Retired 2026-09-06.** `Register`'s correct-model atomicity was
  near-tautological; sequenced writes fixed it. The four non-committing §6.2 facets land one
  per transition, the fifth plus the §6.6 index publish are one atomic commit, and
  `RegisterSeqWitness` asserts the **pre-0.8.3** invariant and requires it to be violated —
  which is what distinguishes real sequencing from sequencing-shaped source. Apalache
  additionally proves `RegisterAllOrNothing` inductive, with its own control.
- **Still open (new).** `DeepChainBug` / `DeepChainNBug` falsify their target lemma in a
  variant where the *honest* chain no longer runs (`legit_reachable`: `falsified - no trace
  found` at 2 steps). A defect that breaks the model demonstrates less than one that breaks
  only the property. Declared in `TM_NEG_EXPECT` rather than absorbed by a `grep`; narrowing
  them is work not yet done.

## Findings routed to `entity-core-protocol`

Never spec edits here — proposals in the sibling repo.

1. **§4.7's table contradicts itself — and §4.6 step 1 — on the same input. The first genuine
   defect in the spec text this repo has found.** An `authenticate` arriving before any hello
   nonce was issued: §4.6 step 1 says it "MUST be rejected with status **401
   `invalid_nonce`**"; §4.7 **row 6** restates exactly that, "pre-hello" and the §4.6 citation
   included; §4.7 **row 10**, four rows later in the same table, puts "authenticate before
   hello" under **400 `connection_sequence_error`**. All are normative MUSTs, they disagree on
   the code *and* the status class, and §4.7's preamble makes each reading non-conformant by
   the other's lights — on `result.data.code`, the field §4.7 exists to fix across
   implementations. So "follow §4.7" is not a well-defined position. Exhibited by all three
   TLA+-track engines; reproduce with `ConnCodesSeqReadingBug.cfg`.

   **Impact.** The divergence is shipped, across **six** behaviours: 401 `invalid_nonce` (38),
   400 `connection_sequence_error` (6), 401 `authentication_failed` (1), plus one apiece from
   `entity-core-go` (409 `connection_sequence_error`, a status in no clause), `entity-core-rust`
   (400 `handshake_failed`, a code absent from the corpus) and `entity-core-py` (400
   `bad_request`, a code in no §4.7 row). It survived because `validate-peer` has **no probe
   that sends `authenticate` before `hello`** and cites §4.7 nowhere in `connectivity`: ten
   MUST-emit rows, roughly one gated. No keystone conformance number moves (nothing tests it),
   but the fix touches ~8 trees and is far cheaper **before** the v0.8.2 cohort regeneration
   than after — a sequencing ask both siblings have honoured.

   **Disposition, 2026-08-31 — closed on our side, live on theirs, and it corrected us twice.**
   `entity-core-protocol` adopted the draft and **ruled 401 `invalid_nonce`**, adding four
   normative sites we had not carried (§4.2, §6.12, §9.1, and a stale copy of the table in
   `ENTITY-CORE-MACHINE-SPEC` §6.4) and finding that our "four words" remedy was incomplete:
   §4.2's bare ordering MUST is what leads an implementer into row 10, so narrowing row 10
   alone would leave §4.2 pointing at no row at all. `entity-core-keystone` built the probe our
   packet said did not exist and **measured** 45 of 46 peers — upholding our source read with
   zero disagreements on the 34 we committed to, resolving all 11 we could not, and surfacing
   both a sixth behaviour and the fact that **39 peers answer identically pre- and post-hello**,
   which makes the cohort argument we published much weaker than it looked. Both corrections
   are absorbed in `docs/PROPERTIES.md` §D.1 rather than quietly dropped. The per-peer census
   and hand-off checklist remain internal working notes.
2. **§5.9's recommended 8× TTL/`chain_depth` ratio has zero margin at worst-case fan-out.**
   The property needs `ceiling × worst_case_fanout` **strictly less than** the TTL seed; at
   exact equality the last causal level spends the last of the TTL and the backstop fires on
   the step the deterministic brake would have. §5.9 puts the ratio choice on the deployment,
   so this is a boundary worth stating where operators read it, not a defect in the default.
   Reproduce: `BoundsRatioBug.cfg`.
3. **§5.8's conformance topology is load-bearing for this repo's own prior results.** The
   pre-0.8.2 `DeepChain`/`DeepChainN` models seat the verifier as the root issuer — exactly
   the same-peer topology §5.8 says cannot witness a cross-peer seam. They remain sound for
   the §5.5a property they claim, but the new `ChainTopology` control shows a defect that
   canonicalizes against the root frame leaves their lemma **still true** while falsifying the
   one only a third-party verifier can state. Recorded as a note on modeling practice.

## Known, documented non-issues (not bugs)

- **`RevokeMech` (Tamarin) does not terminate** — mechanistic linear-token revocation loops
  Tamarin's backward search on a regenerated `Valid` fact. It stays ProVerif's lane; Tamarin
  uses a terminating trace-restriction idiom. An irreducible tool-capability finding,
  **excluded from `make check`** — run it standalone with a kill switch.
- Run the three engines **serially** — each runs under the `caps.mk` memory ceiling and three
  concurrent sweeps contend for it. Reclaim a hung container with `podman kill` (a
  `timeout`-wrapped `podman run` only kills the client).

  *(This bullet read "concurrent toolchain runs can hit a transient SELinux `:Z` bind-mount
  relabel race (file not found)" until 2026-09-06, and it did not belong in a **non-issues**
  list: that race was a **bug in this repo**, fixed 2026-08-30. `tla/` and `tamarin/` are each
  mounted by two images, and uppercase `:Z` relabels a volume private to one container, so the
  second image's relabel invalidated the first's — Apalache died mid-sweep with a
  directory error that read like a model failure. Both dropped to lowercase `:z`; `spin/` is
  owned by one image and correctly stays `:Z`. **The fix reached the mount flags and
  `AGENTS.md` and stopped there**, leaving the retracted reason standing here, in
  `COVERAGE-MATRIX.md` §7 and in `tla/Makefile`'s own header — which contradicted its own
  `MOUNT` line. D14 applied to a retraction, the L7 shape again: what finds these is grepping
  the withdrawn **phrasing** (`:Z`, "relabel", "race"), not the subject.)*
- **Observed once, 2026-09-07, and NOT diagnosed — an Apalache directory error that looks
  exactly like the fixed `:Z` bug.** A `make matrix` run died at `apalache-green` /
  `StoreApalache` with `Configuration error: Could not find or create directory:
  /work/_apalache-out/StoreApalache.tla` (`EXITCODE: ERROR (255)`). An immediate re-run of
  `make -C tla apalache-green` succeeded, and a full `make matrix` re-run passed end to end.
  Two runs of the same matrix earlier the same day had also passed.

  What was actually measured, since the tempting move is to call it the known bug and move on:
  `tla/Makefile` and `tamarin/Makefile` correctly use lowercase `:z`, `spin/Makefile`
  correctly uses `:Z`, and a `spin` container run relabels **only** `spin/`. But **the
  repository ROOT** — `.`, `docs/`, `tools/`, `spec-data/`, `README.md` — carries
  `container_file_t:s0:c255,c930`, a *private* MCS category pair, and `tla/` inherits it.
  Only a `:Z` mount of the whole repo produces that, and **no Makefile here does one**. So
  something outside this repo's build has privately relabelled the tree, which is a standing
  trap for precisely this failure: a container holding different categories then cannot write
  into `tla/`.

  **Root cause not determined, and this is deliberately not written up as solved.** What is
  known: the flag discipline inside this repo is correct, the failure is transient, and the
  repo-root label is anomalous. What is not known: what set it. Do not relabel the tree to
  make this go away without finding the writer first — the label is the evidence.

  **Recurred 2026-09-07 during the identity track's matrix run, at `apalache-green` /
  `RegisterApalache`, same message and same `EXITCODE: ERROR (255)`. One new measurement, and
  it is the useful one: THE CATEGORY PAIR HAD CHANGED.** It was `c255,c930` when the bullet
  above was written and `c360,c625` when this run failed — the whole repo root again, uniformly,
  every file. So the relabel is **not a one-time event that predates the build**; something
  re-applies a *fresh* private pair repeatedly. That is what makes it transient rather than
  permanent, and it means a `:z` mount (which relabels to shared `s0` on each run) can be
  undone **while a run is in progress** — which is a race, in the shape the retracted
  "concurrent `:Z` relabel" explanation guessed at while being wrong about the cause. The
  writer is still outside this repo: no Makefile here mounts the root, and every mount that
  touches `tla/` is `:z`. Still not written up as solved, and still: **do not relabel the tree
  to make it go away.** The next person to see it should record the pair, because a third
  distinct pair confirms the periodicity and a repeat of `c360,c625` refutes it.
- TLC's liveness graph exhausts the 2 GB cap at `Store`'s safety bound of `NReq = 4`, so
  `Store` runs safety at 4 and liveness at 3 in two configs rather than one config that
  silently drops a property. Stated in both cfg headers.

## The deepest open assumption

The **5th wall — spec↔model fidelity**. Every result is a property of a *model*. The
two-paradigm agreement (Spin independent encoding + Apalache unbounded matching TLC;
ProVerif + Tamarin lockstep) **narrows** it but cannot close it — the engines could share a
misreading. **Human review of the models against `spec-data/v0.8.2/` owns it**
(`docs/PROPERTIES.md` §C, `docs/ASSURANCE-MAP.md`).

This is not hypothetical. During the 0.8.2 work the ProVerif/Tamarin lockstep caught a real
defect in a hand-written Tamarin lemma — a variable never bound to the verifier it named, so
the lemma asserted far less than it appeared to. The two provers disagreed, and the
disagreement was the signal. The cross-check earned its keep on the modeller, which is the
failure mode it exists for.

**A second wall was named this session and is now an artifact rather than prose: the
model↔model seam.** Where one tool abstracts something because another owns it, the division
is sound only if the property assumed is the property proved. `docs/LEAN-SEAM.md` states that
per abstraction and `make leanseam` fails when the cited Lean text moves — but it is still a
human reading of two texts, and the gate detects only that one of them changed. See §Next
item 4.

## Next

1. **Coverage breadth.** Measured by the `§`-citations the models carry — and now *checked*
   against them by `make coverage` — they reach **29 of 91 numbered sections** of the core
   spec. By area that is **§4 · §5 · §6**, the three surfaces this repo owns. Near-zero
   coverage of §2, §3, §7, §8 and §9 is deliberate scope: registries, encoding, trusted crypto
   and the conformance profiles belong to other layers of the assurance map. The remaining
   third of §4/§5/§6 is the real backlog: §4.3–4.5, §5.3, §6.3/6.4/6.7, §6.12/6.13. Which
   uncovered section is *scope* and which is *backlog* is set out in
   `docs/COVERAGE-MATRIX.md` §5 — keep that split sharp; it is the difference between an
   honest coverage number and a bad one.
2. **~~Close the two single-engine section rows.~~ Done, and they were not what they looked
   like.** §4.7 and §6.9 were listed as real single-tool results; neither was modeled at all.
   Both are now genuine modules on all three engines (`ConnCodes`/`conncodes.pml`,
   `Bootstrap`/`bootstrap.pml`), and `make coverage` makes the class of mistake that hid them
   a build failure. Modeling §4.7 produced the spec finding in `PROPERTIES.md` §D.1. §3.3
   remains single-engine and is honestly disclosed as subject-not-property.
3. **~~Narrow the two weak controls.~~ Done — three, not two.** `DeepChainBug`,
   `DeepChainNBug` **and** `ChainTopologyBug` all falsified their own reachability lemma
   alongside their target. Each now carries a §5.5a **absolute-form** leaf (`/{p}/` +
   wildcard), which is frame-independent by definition and so cannot be reached by a
   canonicalization-frame defect; the honest path survives and each control falsifies its
   target alone. The absolute-leaf rules are byte-identical in each green twin, so every
   control still differs from its green by exactly the injected defect.
4. **~~The Lean seam is asserted, not checked.~~ Written down: `docs/LEAN-SEAM.md`,
   gated by `make leanseam`.** The ledger states, per abstraction, the proposition the model
   relies on and what discharges it — 21 Lean theorems cited by `(name, file, sha256)`, one
   rejected correspondence pinned as such, plus the intra-repo (Class T) and unowned
   (Class O) rows. Two results a spot-check would not have produced:
   - **L1 — the chain verdict is not peer-independent.** `verifyChain` takes `localPeer` as an
     argument and the §5.5a granter frame threads it through the walk, so `Revoke.tla`'s
     `ChainValid == TRUE` at both peers is sound only where the two peers' frames agree — a
     restriction the model does not state. CLOSED-MODULO-H.
   - **L7 — Lean's §5.5a isolation theorem covers one of three pattern forms.**
     *(Corrected 2026-08-30. This item previously read "two engines, one shared undischarged
     assumption" and claimed ProVerif asserts `hframed` by rewrite. **Both halves were wrong**
     — the error and its shape are recorded in `docs/LEAN-SEAM.md` §4.1, which is rewritten in
     place rather than amended.)* `hframed` is not an unproved lemma, it is **false in
     general**: `canonSegs` frames only the *relative* branch, so `canonSegs "P" "/Q/*"` heads
     at `Q`. That is correct behaviour — §5.5a line 2729 makes the absolute form the required
     way to express cross-peer authority — which means `hframed` **scopes** the theorem to the
     peer-relative fragment. Our symbolic models carry all three §5.5a forms as three `canon`
     equations, one of which is the *negation* of `hframed`; the first pass quoted one of the
     three and inferred a shared assumption that does not exist. **The real residual:** the
     absolute named form (`/{q}/…` reaches exactly `q`) has no Lean theorem. CLOSED-MODULO-H,
     with H now named precisely.

     **And the correction itself reached two sites out of five** — found 2026-08-30 while
     wiring the Lean tier. `LEAN-SEAM.md` and this file were fixed; `ASSURANCE-MAP.md`,
     `FINAL-ASSURANCE-SUMMARY.md` and the `CHANGELOG` entry were still telling a reader that
     two engines rest on **one shared undischarged assumption** and that ProVerif asserts
     `hframed` by rewrite — a claim about a sibling repo's proofs, on the published surface,
     that we had already established was wrong in both halves. All three corrected. This is
     **D14 applied to a retraction rather than to a defect**: a finding is not closed until
     it reaches every instance of its shape, and a *withdrawn* claim has a shape too. What
     found them was grepping the superseded **phrasing**, not the row name.

   **~~The ledger checks the text and nothing checks the proofs.~~ Closed 2026-08-30 —
   `make leanproof`, and the reason it was needed is the finding.** `lake build
   EntityCoreProofs` is called "the proof check" in five places in keystone — the lakefile, the
   proof-library root, `profile.toml`'s `[testing]` contract and two status docs — and
   **nothing in that repo invokes it** (exhaustive search over
   every Makefile, `*.mk`, `*.sh`, `*.yml`, `*.py` and Containerfile; the only `lake build`
   anywhere is `run-s4.sh`'s `lake build host`). Ten rows above cite Lean theorems by name —
   nine of the eleven Class-L rows are CLOSED, two CLOSED-MODULO-H, and L2 is closed by
   construction with no theorem — and all ten rested on it.
   - **The claim it makes is also false.** A `sorry` is a **warning** in Lean: `lake build`
     prints `Build completed successfully` and exits **0**. So does a hand-written `axiom`
     replacing a proof, with no warning at all. Only a proof that fails to type-check exits
     non-zero. Demonstrated by building all three, per the D15 corollary.
   - **So the gate grades axiom sets, not exit status.** 40 declared `#print axioms` gates in
     `lean/proof-gate.expect`, exact axiom set per declaration in both directions, every
     ledger-pinned theorem required to be among them, warnings failing unless declared with an
     owner, and the image's Lean version required to equal keystone's own `lean-toolchain`
     pin. Four controls, each failing for its own declared reason — including `neg-ungate`,
     which deletes a `#print axioms` line and would score green against any grader built on
     grepping the build log for `sorryAx`.
   - **One thing to route, found by running it:** the shipping peer's
     `src/EntityCore/Capability.lean` — text this ledger pins by digest — calls the
     deprecated `String.dropRight`, whose replacement returns a different type. Declared in
     `proof-gate.expect` with an owner rather than ignored, and routed to
     `entity-core-keystone`.
   - **The arrangement is unchanged and was re-examined, not assumed:** keystone owns the Lean
     artifact, this repo owns the claims about it. No fork, no vendored copy — a fork would
     make the ledger a statement about our copy, which nothing gates. What moved is only that
     the *checking* of the peer's own honesty gates now happens somewhere.

   **~~Both packets routed to keystone.~~ Answered 2026-09-06 — six of seven asks adopted,
   one declined with a measurement, and the decline corrects us.** `entity-core-keystone`
   `8156792`. What came back, and what it did to this repo:
   - **`hframed`'s residual is discharged.** `absolutePattern_names_one_peer` is the companion
     theorem for §5.5a's absolute named form, and keystone added **two we did not ask for** —
     `canonSegs_absolute_frame_independent` (frame-independence, which needs no `splitOn`
     reasoning at all) and `wildcardPattern_peer_agnostic` (the third pattern form). Each
     witness-checked for non-vacuity. **All three §5.5a forms now carry a theorem apiece,
     matching the three `canon` equations our symbolic theories carry one for one.** L7 is
     CLOSED; L12 and L13 are new rows. They re-derived our counterexample by evaluation rather
     than accepting it.
   - **The ask we got wrong, and they measured it.** We asked them to discharge `hframed` from
     a syntactic side-condition, on our own written claim that the relative half was *"genuinely
     mechanical"*. **Declined, correctly:** the pinned mathlib-free toolchain ships
     `String.splitOn`/`splitOnAux` and *zero theorems about either*, and `splitOnAux` is
     `@[irreducible]` over raw byte positions with `extract` under a UTF-8 validity proof. We
     criticised their comment for being wrong about `hframed`'s scope and then repeated its
     error about `hframed`'s cost — an estimate published without measuring it. The ask
     survives only as the mathlib question below.
   - **The proof-gate packet is closed** — their ask-1 target landed 2026-09-03 and the
     remaining claim sites are corrected. `String.dropRight` → `dropEnd` is fixed, so the one
     declared warning in `proof-gate.expect` is **deleted and the build is warning-clean**; our
     "the `String.Slice` return type is not a rename" caveat read as a blocker and was not one.
     They measured the replacement over 21 inputs including multi-byte prefixes rather than
     stopping at typechecking. Two further deprecations disclosed in `Host.lean`, outside our
     pinned files and deliberately unbundled so their re-measurement stayed unambiguous.
   - **Our own gate is what caught the movement**, which is the part worth keeping: the three
     new theorems arrived as `UNDECLARED_GATE` failures by name, and the grader printed its
     refusal to accept a re-declare without a re-read. A gate that counted declarations would
     have absorbed three unread theorems silently.

   **Still open, in order:**
   - **~~Answer keystone's three questions.~~ Answered same-day, 2026-09-06.** Two are "no".
     - **Set-valued code slot — the shape is right, Lean is the wrong tool.** The property is
       about a peer's *emit sites*, not the authority interior their proofs cover, and a
       theorem about the one modeled peer would have missed **five of the six** §4.7
       behaviours — they live in peers with no formal model. Their own `37/46` miscount is the
       argument: it came from grepping a literal that appears in each peer's generated
       conformance report, the oracle's vocabulary quoted back — a source-read artifact, which
       is the failure mode a wire probe does not have. Routed to `validate-peer` as a vector.
       **One narrow theorem we did say yes to:** make the code a closed sum type whose
       inhabitants are exactly the §4.7 rows, so an unregistered spelling is
       *unrepresentable*. That is about a definition, it is cheap, our tier can gate it today,
       and it would have made `handshake_failed` and `bad_request` impossible to write.
     - **Host contract: H1 in scope in shape, H3 out.** H1 is the same form as our `Register` /
       `Authority` / `Bootstrap` dispatch invariants — but **land and pin the spec before
       modeling it**, because modeling against a text being drafted couples the model to the
       spec, which is exactly what the `spec-data/` SHA-pin exists to prevent. H3 is their
       packaging boundary, which Class O declares unowned. The transferable half we did route:
       **a negative reachability claim is the highest vacuity risk there is** — "nothing may
       reach X" is trivially true in a model with no paths — so the spec should **name the
       required witness alongside the prohibition**, or a peer that does nothing conforms.
       That is `StoreBounded`, the pre-0.8.2 witness gap, and the three self-falsifying Tamarin
       controls, all in one shape.
     - **No mathlib.** The only ask it served is moot: it existed to discharge `hframed`
       syntactically, and `hframed`'s reason for mattering was that §5.5a's absolute form had
       no theorem. It has one. Nothing in the ledger now needs `hframed` universal. A
       mathlib-free proofs target is also an assurance property in its own right — our gate
       grades exact axiom sets, and that review stays hand-checkable only while the trusted
       base is small. Revisit if a row ever needs real mathematics rather than string plumbing.

     Packet: `docs/status/ROUTING-2026-09-06-KEYSTONE-THREE-ANSWERS.md`. It also carries three
     corrections **to us** that they earned: the declined ask was built on our own unmeasured
     "genuinely mechanical" claim, our `String.Slice` blocker note was wrong, and our L1 row
     described their code incorrectly in a published document.
   - **Keystone should run this gate too, and the packet says so.** Our gate covers our
     ledger's rows; it does not put a check in the repo where a `sorry` would be *written*.
   - **~~The ledger's own counts are ungated.~~ CLOSED 2026-09-06 — `make ledgercount`,
     built because the count could not be stated safely without it.** Closing T4 changed a
     verdict, and the correct new breakdown could not be written down without either
     hand-counting (the mechanism that had failed four times) or a tool. So the tool.

     It parses `docs/LEAN-SEAM.md` itself — Class L from its `### L<n>` sections and their
     `**Verdict:**` lines, Classes T and O from their tables — and checks the row counts,
     the verdict counts and the **row structure** (contiguous ids per class, so a silently
     deleted row fails rather than yielding a smaller number that still looks tidy) against
     every declared prose site. Correction to what this bullet used to say: **`leanseam` and
     `leanproof` do not derive these numbers.** They derive *theorem* counts and say nothing
     about rows or verdicts, which is precisely why none of the four errors was ever
     reachable by an existing gate. It is in `check` and `matrix` — unlike `driftclaim`, it
     depends on nothing outside this repo, so a change-triggered gate is sufficient in kind.

     **Its first draft anchored row counts only — and would have gone green on all four
     historical errors**, because every one of them was a *verdict* error and three had the
     row total right. Found by flipping a verdict and watching it pass, not by review.
     Teeth-tested three ways (flipped verdict, deleted verdict line, deleted row → id gap),
     each failing for its own stated reason. It asserts the counts and the structure; it does
     **not** assert that any verdict is correct.
   - **Differential trace checking** — replay Apalache `.itf.json` counterexamples through the
     Lean executable model (or a reference peer) and assert the abstract predicate's value
     matches. The ledger is a human reading of two texts and `make leanseam` only detects that
     one of them moved; this is the only item that would put a **machine** on the Lean-facing
     half of the 5th wall. The ledger was built first precisely to tell us whether this is
     worth it, and the answer has moved: **L7 is now closed by a real theorem, so the only
     Lean-facing residual left is L1** — and L1's H is not a framing question at all (it is
     the `localPeer` frame on handlers/operations plus the `peers` default; `LEAN-SEAM.md` L1).
     *Route the findings first, then reassess* has now paid out once, which is the argument
     for finishing the routing before building the machine.

     *(This bullet read **"21 of 23 rows are CLOSED and the two open ones (L1, L7) are both
     §5.5a granter-framing"** until 2026-09-06. Every number in it was wrong and so was the
     attribution. Derived now, **by `make ledgercount` rather than by hand**: the ledger is
     **37 rows** — 13 Class L, 5 Class T, 19 Class O — of which **15 CLOSED**, 1 CLOSED —
     ASSUMPTION FALSE (T4), 1 CLOSED — ASSUMPTION ISOLATED (O6), 1 CLOSED-MODULO-H (L1),
     2 N/A-device, 3 BY-DESIGN, and **14 OPEN** (O5, O7–O10 from the attestation track,
     O11–O15 from quorum and O16–O19 from identity, all added 2026-09-07 with those tracks'
     first nine modules).
     All three extension tracks are entirely TLC, so O5, O14 and O19 — the three Dolev-Yao rows
     — are the same undischarged gap counted three times, and every green on any of them assumes
     signatures work. **O16 is a shape none of the others has**: it is not "no tool reaches
     this" but "this repo already measured this input and found it defective (Q1), and the
     identity models assume it works anyway" — held visible as a constant with its own negative
     control rather than as a fidelity note. *(This same sentence has now been wrong twice more than the bullet it
     corrects: it read "14 CLOSED … 2 OPEN (T4, O4)" until O4 closed two hours later, then
     "15 CLOSED … 1 OPEN (T4)" until T4 closed on 2026-09-06. Both were true when written.
     **That is four ungated ledger counts published wrong, and the fifth was only avoided
     because the gate now exists** — it was built in the same session precisely because the
     count could not be stated safely without it.)* The two rows that were genuinely **OPEN**
     were never L1 and L7 — those were CLOSED-MODULO-H, a different verdict — they were T4,
     the unproved composition, and O4, the unmodeled `δ`. **This is the third time a recalled
     ledger count has been published here**, after "eleven CLOSED rows" in five files and the
     Class-L verdicts in the audit. `leanseam` and `leanproof` derive *theorem* counts and say
     nothing about rows or verdicts, which is why they never caught any of this;
     `make ledgercount` is what now ties the prose to the derivation.)*
     **But note what the L7 correction says about this item's premise:** the ledger's open
     rows were re-read once and one of them was materially wrong. A human reading of two texts
     degrades exactly this way, which is the argument *for* the machine check, not against it.
   - **A local Lean tree here was considered and rejected.** The value of the seam is that
     Lean's theorems are about the same executable code the conformance suite runs; a fork
     would make them statements about our copy, which nothing gates. Cite, pin, and check.
5. **The bound nobody has attacked: `Peers = {A,B}`. Scoped 2026-08-30 — it is three different
   problems, and the first version of this item pointed at the wrong one.**
   Apalache's results are unbounded in *steps*,
   never in *peers*, and this is still the first question a reviewer asks of a multi-peer
   protocol. What reading the models changed:
   - **`Revoke` / `RevokeApalache` are already N-generic** — `\A p \in Peers` throughout, no
     binary idiom; one line pins them. **But widening them would assert nothing.** Both
     properties are per-peer local or N-independent *by construction*: `Observe(p)` is
     independent per-peer nondeterminism with no topology, so extra peers are extra coin
     flips. The gap there is a **missing propagation mechanism**, not a small N — separate
     work, separately justified. *(This item previously named revocation propagation as a
     place N>2 "could plausibly matter." In reality, not until the model has a network.)*
   - **Cross-peer chain topology is already at N=3** — `ChainTopology.{pv,spthy}` runs three
     distinct principals (root `P`, granter `A`, verifier `W`), built deliberately because
     `DeepChain`'s two collapsed the frames. *(Also previously named here as an N>2 target; it
     is banked.)*
   - **`Core` / `Reentry` are binary structurally, not by bound** — `Other(p) == IF p = "A"
     THEN "B" ELSE "A"`. Under it the wait-for graph has two nodes, so the only expressible
     deadlock is the mutual 2-cycle — which is the Class-G shape already re-derived. **A
     3-cycle is a deadlock class two peers cannot make**, and whether §4.8's per-connection
     invariant composes around a cycle of connections is a question the models cannot
     currently ask. **That is the real prize, and it is reachable at N=3 with no new tool.**
   **~~Revised order: restructure `Reentry` → run N=3.~~ DONE 2026-08-30.** `Reentry.tla` now
   takes `CONSTANT N`, dispatches on a directed ring (`Succ`/`Pred`), and `Other(p)` is gone.
   The regression held: at N=2 both full-exploration configs reproduce the old numbers exactly
   (green 106/62, witness 105/62); the two counterexample configs abort at first error so they
   differ only in how much was explored before it, with identical verdicts.
   - **Green holds at N=3** — 1229 states, 488 distinct, `NoDispatchWithoutGate` +
     `FramesNotInterleaved` + the `EventuallyResolved` liveness property, no error.
   - **And it is not vacuous.** `ReentryBug3` (the `Serialized` defect at N=3) reaches
     `wlock = <<"client","client","client">>` with all three clients in `CRecv` and all three
     servers blocked at `SFrame1` — **a three-node wait-for cycle**, a state the previous model
     could not represent. The state space does reach 3-cycles; the fix forbids them.
   - **`Other` was not hiding a bound, it was hiding a conflation.** The response target read
     `resp[Other(Pof(self))]` — "answer the other peer" — which silently identifies the peer
     this one *dispatches to* with the peer whose request it is *answering*. Those are the same
     peer iff N=2. The binary assumption was load-bearing in the response routing, where it
     read as an obvious truth, not in the peer set where it was visible.
   - **No new bug.** `ReentryBug3` exhibits the *same* defect as `ReentryBug`. What is new is
     the claim: §6.11's contract is deadlock-free against a 3-cycle, a shape two peers cannot
     form. Before this the honest position was "we did not look."
   - 4 new gated runs (green + 2 controls + witness), matrix 238 → 242.

   **~~Cross-check the N=3 result.~~ DONE, same day — all three engines now agree at N=3.**
   `Other(p)` is gone from every model that had it: `Reentry.tla`, `Core.tla`,
   `ReentryApalache.tla`, `CoreApalache.tla`, `spin/reentry.pml`, `spin/core.pml`. Each takes
   a peer count (`CONSTANT N` / `-DNPEERS`) and runs the same directed ring.
   - **TLC** — `Core3` green (composed model, 3 peers), `CoreBug3` deadlocks, `CoreWitness3`
     fires. At N=2, `Core` reproduces its pre-change count **exactly**: 331 distinct states,
     verified by re-running the stashed tree rather than by assuming.
   - **Apalache** — `FramesNotInterleaved` (Reentry) and the composed `InvComposed` (Core) are
     both proven **inductive at N=3**: no execution of any length interleaves two frames' bytes
     on a 3-ring, and the composed invariant holds unboundedly in steps there. Two new controls
     confirm the N=3 configurations still have teeth.
   - **Spin** — `reentry` and `core` re-encoded with `-DNPEERS`, safety **and** LTL green at 3,
     three new controls firing. `core` at N=3 runs 11 processes and pan's weak-fairness
     construction caps at `NFAIR=3` → 10, so it *aborts* rather than mis-reporting; the bound
     is carried per-row in `SPIN_GREEN_N3` instead of being rediscovered.
   - Matrix 242 → **258**.

   **Still open, and now the honest frontier:**
   - **The ring is one topology, not all of them** (`Reentry.tla` §TOPOLOGY BOUNDARY). One
     outbound request per peer, one predecessor. Arbitrary dispatch graphs — a peer with
     several counterparties, or several concurrent outbound requests — are a strictly larger
     question and are **not** modeled. This is now the *only* structural limit left on the
     multi-peer claim, and it is the one a reviewer should press.
   - **N=3, not all N.** Three is the smallest number that exhibits a cycle two peers cannot
     form; it is not a proof for arbitrary N. **Ivy** / `mypyvy` / TLAPS remain the answer for
     that, and are now better informed: N=3 found no new defect on any of the three engines,
     which is evidence about how much is left to find rather than a reason to stop.
   - **`pan`'s generated C emits gcc bounds warnings** (`writing 1 byte into a region of size
     0`) on the array-indexed models. Pre-existing and *reduced* by this work — 41 on the old
     `core.pml` at N=2, 26 on the new one — and the `spin` gate greps `errors:` and does not
     read gcc's output at all. D13 says a tool warning is a build failure; that rule was
     written about verification-tool warnings, and whether it should reach the generated-C
     compile is an open question, named here rather than quietly answered "no".
6. **Liveness is bounded everywhere and cannot be lifted by the current toolchain.** Apalache
   does safety/induction by construction. **TLAPS** machine-checks liveness proofs (fairness,
   well-founded ordering); deadlock-freedom for `Core` proved rather than model-checked would
   be the headline result this repo does not yet have.
7. **~~A refinement proof relating `Core` to its components.~~ DONE 2026-09-06 — and it is a
   REFUTATION, which is the more useful result.** Ledger row **T4**, the last OPEN row, is
   closed as **CLOSED — ASSUMPTION FALSE**.

   **`Core` does not refine `Conn` or `Store`, for a structural reason worth keeping.** Core
   collapses §4.6's handshake into one step (`conn[p] := "established"`); `Conn` runs
   new → hello_done → established as two. A refinement mapping lets the *abstract* spec
   stutter while the concrete one moves — it does not let one concrete step perform two
   abstract ones. So no mapping satisfies `Conn`'s next-state relation. For `Store` it is
   starker: `Core` has no counterpart for the refcount, referrer set, write critical section
   or admission state at all. The scoping checkpoint predicted exactly this shape for
   `Revoke` and it generalized.

   **So the weaker claim was run: invariant implication under an explicit mapping**
   (`tla/RefMap.tla`), with the component modules `INSTANCE`d so what is asserted is their
   **own invariant text** rather than a transcription. *Implication and refinement are not
   the same claim and the row does not blur them.*

   **The contribution is the classifier, not the implication.** A mapping that sends a
   component variable to a constant makes that component's invariant a tautology, and TLC
   reports the identical green for "Core enforces this" and "the mapping asserts it" — the
   `StoreBounded` vacuity reproduced *inside the fix for the composition gap*.
   `tla/CoreMapFree.tla` runs each mapped invariant over **every type-correct valuation**
   instead of the reachable ones, one graded cfg per verdict:
   **1 CARRIED (§4.2's dispatch gate), 5 MANUFACTURED.**

   Two things fell out that are worth more than the result itself:
   - **The first draft asserted all seven mapped invariants and went green.** Six could not
     have failed. Catching that needed the classifier, not review.
   - **TLC's own vacuity warning caught 2 of the 6.** It flags "constant-level formula …
     evaluates to TRUE" — but only where the formula mentions no variable. The other four
     read a `Core` variable *through the mapping* and are still unfalsifiable;
     `NoUseAfterFree` reads `store` yet cannot fail because the referrer set is constant.
     **A syntactic vacuity check catches vacuity visible in the formula, not vacuity
     manufactured by a mapping.** "The tool would have told us" was false.

   +9 runs (268 → 277). **Scope stated rather than assumed:** TLA+-only (Spin has no
   instantiation mechanism to state it with, so the composition claim is unexamined there),
   and `Reentry`/`Revoke` are deliberately not mapped — `Revoke`'s `Verdict1` is a function
   of three inputs `Core` abstracts to `~revoked`, so its invariants would be manufactured
   for the same reason `Store`'s are. *That last part is a judgement, not a measurement, and
   it is the one claim here that was not run.*

   **Still not used:** Alloy for `Register`'s index↔tree-walk coherence. CryptoVerif for
   computational-model results. §6.11(c) per-request deadlines, which are what would make
   Class-G a liveness bug rather than a crash. **TLAPS** for liveness (item 6).
8. **Widen the TLA+ bounds** — 3-peer / churned-store. *(The other half of this item,
   ~~sequenced-write `Register`~~, is done — see item 13.)*
9. **~~Nothing checks a number in prose.~~ CLOSED 2026-08-30 — `make coverage` **and**
   `make runcount`.** The remaining half named below is now gated: `tools/runcount.py` derives
   the per-target run counts from `TLC_*`/`APALACHE_*`/`SPIN_*`/`PV_*`/`TM_*` in the three
   engine Makefiles, checks the total against every declared prose site **and** against the
   per-slice table above row by row, and fails if a site stops making the claim at all. The
   derivation was cross-checked against a live `make matrix`: 258 both ways, and the
   per-engine breakdown (Apalache 73, TLC 66, Spin 60, ProVerif 30, Tamarin 29) matches
   run-for-run. Teeth-tested four ways by breaking it. **Its own first draft failed D13** —
   it matched any three-digit number near "runs", so it flagged three files whose 203/204/238
   are *true statements about the past*; a gate that makes you delete accurate history to go
   green is worse than none. The live claim is now declared per site by anchor. What it still
   does not assert: that a run exists at all if it is in no gate table — the hole that hid
   `BindingReplayBug` for a release, stated in the tool rather than left to be assumed away.

   **The history, kept because it is the argument for the gate.** `make coverage` closed the
   first half: it derives the section set and count from the models and fails on any
   disagreement with `COVERAGE-MATRIX.md`, including the denominator against the pinned spec.
   It still does **not** check the **engine columns** of Matrix A — a citation says a model is
   *about* a section, not which engine verifies what — **and that half remains open.** The run
   counts were the other half, hand-derived from the gate tables into six files. *(It moved 238 → 242 → 258
   across two commits on 2026-08-30 as the N=3 rows landed, and all four sites had to be
   hand-edited each time — which is the argument, restated as a chore, twice.)*

   **And the third time it bit, in the same session the rule was written.** Two sites were
   *missed* by those hand-edits and were found while wiring the Lean tier: `PROPERTIES.md`
   §C's grader inventory still read **"Ten targets decide the 238 runs"** with 238-era
   per-target counts, and `CANONICAL-DOCS.toml`'s blurb for the capstone still advertised a
   **203-run** matrix — a stale number on the one file that decides what a public reader
   sees. Both corrected, and the per-target counts re-derived mechanically from the gate
   tables in `tla/`, `spin/` and `tamarin/Makefile` rather than copied forward:
   14 + 39 + 13 + 50 + 23 + 22 + 38 + 15 + 15 + 14 + 15 = **258**. That the derivation is
   easy to run by hand and was not run is the whole of item 9.
10. **~~Model the §5.10 skew tolerance `δ`.~~ DONE 2026-09-06, on all three engines — and the
    reason it mattered is sharper than "an unmodeled input".** Found while writing the seam
    ledger (row **O4**, now CLOSED). §5.10's cross-clock temporal model (0.8.1, W7 Knob 3)
    makes `δ` a declared Layer-1 input *alongside* `t` and states the determinism argument in
    terms of both. `Revoke.tla` modeled `t` and not `δ` — which means its `VerdictFnOfLayer1`
    was **an accidentally-true statement about a model that could not express the case the
    invariant was guarding**. That is the same shape as a vacuous invariant, arriving through
    a missing variable rather than a missing state.

    `δ` is now a per-peer declared tolerance in `tla/Revoke.tla`, `tla/RevokeApalache.tla` and
    `spin/revoke.pml`; the temporal check is the clause's two DENY rules negated; and the
    determinism antecedent carries `delta["A"] = delta["B"]` because §5.10 puts it there.
    **Apalache proves the strengthened invariant inductive**, so the result is unbounded in
    steps, not bounded-exhaustive. +6 runs (264 total).

    Three runs, each answering a different question — and one of them was wrong first:
    - **`RevokeDeltaBlindBug`** (control, TLC + Spin `-DDELTABLIND`) — the pre-0.8.3
      antecedent, blind to `δ`. The defect it names is a verifier that *applies* a tolerance
      without *declaring* it, which is the sole condition §5.10 attaches to `δ`: "it introduces
      no concealed state."
    - **`RevokeDeltaWitness`** (non-vacuity) — `δ` decides a verdict with every other Layer-1
      input equal. **Its first draft omitted the `revObserved` conjunct**, and TLC satisfied it
      immediately with a state where the two peers differed on *observed revocation* and `δ`
      differed only incidentally. It fired, looked like success, and supported nothing. Caught
      by reading the counterexample trace rather than the exit status. **A witness that fires
      for the wrong reason is worse than a control that does, because firing is what a witness
      is supposed to do** — there is no red to investigate.
    - **`RevokeDeltaZero`** (green, TLC + Spin `-DDELTAZERO`) — the clause says *"`δ = 0`
      reproduces today's exact behavior"*, which is an equivalence about any implementation of
      it, so we run it instead of reading it. A sign error, a one-sided tolerance, or the
      tolerance on the wrong operand all pass the default green — which admits `δ = 1` and
      therefore *expects* a wider window — and fail here. **D13 asked of a green row:** "the
      invariants hold" is satisfied by a model with the wrong validity window.
11. **Tie models to conformance vectors.** Only the Class-G deadlock is currently grounded
    against a reference impl; where a sibling conformance vector exists for a modeled
    property, cite it to turn "spec says" into "spec says *and* a passing test exercises it."
    Overlaps item 4 — a conformance vector and a replayed counterexample are the same move
    from opposite ends.
12. **Phase 3 extension-protocol attacker models.** *(Header rewritten 2026-09-07: the original
    read "stay gated on vendoring `EXTENSION-*`, which is still not in `spec-data/`". All three
    are vendored, pinned and modeled now, so the gate that item named is gone and what remains is
    narrower and sharper — **there is no prover theory on any extension track**. The original
    text and its 2026-09-06 correction are kept below because the way the blocker was
    misdescribed is the reusable part.)* Structural models exist on all three tracks; the
    Dolev-Yao layer exists on none, which is `docs/LEAN-SEAM.md` O5, O14 and O19 — one
    undischarged row per track, deliberately not merged so the growth is visible.

    *Original text:* stay gated on vendoring `EXTENSION-*`,
    which is still not in `spec-data/`. Note that §5.8's registry rows and §5.9's continuation
    depth brake are now modeled at the *core* level, so the gate is narrower than it was.

    **The blocker is narrower again, and this item has been misleading — corrected
    2026-09-06.** As written it reads as though the extension specs do not exist yet. **They
    do: all 26**, including `EXTENSION-IDENTITY.md` and `EXTENSION-ATTESTATION.md`, in
    `../entity-system-architecture/specs/extensions/`. The reason nobody here had noticed is
    that `AGENTS.md` named `entity-core-protocol/specs/` as *the* re-vendor source — true for
    the three core specs, and there are no `EXTENSION-*` files there at all, so following the
    rule finds nothing and the absence reads as authorship rather than location. `AGENTS.md`
    is corrected.

    So nothing is blocked on anyone writing anything: the specs are landed, and vendoring
    each spec from the repo that owns it — core from `entity-core-protocol`, extensions from
    `entity-system-architecture` — is the ordinary operation this repo already performs.
    Nothing has been vendored yet only because **`spec-data/` is being held at `v0.8.2`
    until keystone converges**; the extension snapshot rides along with that same
    re-vendoring pass. The mechanical work is `spec-data/<pin>/MANIFEST.md`
    §"Re-vendor discipline", unchanged.

    *(An earlier draft of this item called it "a decision about whether to pin from a second
    upstream". There is no such decision — extension specs live in the architecture repo,
    which is simply where they live. Struck rather than left, because a manufactured
    architectural question is a worse artifact than the stale sentence it replaced.)*

    **Structured 2026-09-06 — `TRACKS.toml` + `make trackcheck`, and the reason it had to
    come first is the finding.** Before any extension model exists, two of this repo's own
    gates were shaped so that the first one would have been *absorbed* rather than rejected:

    - **The coverage number is derived from a document-blind pattern.** `§(\d+\.\d+)` yields
      the same token for `EXTENSION-ATTESTATION §5.7` (attestation's index invariants) and
      core `§5.7` (delegation caveats) — and core **already has a `5.7` row**. The first
      attestation citation would have been credited to core's grid and `make coverage` would
      have reported OK. That is a phantom row arriving **through** the gate whose entire
      purpose is to prevent phantom rows: §4.7/§6.9 again, one spec body over. Citations are
      extracted per track now, and a cross-track reference is written sigil-first
      (`§CORE:6.2`) and excluded from every track's coverage set.
    - **And the file globs were non-recursive.** `coverage-check.py` and `spec-drift.py` both
      globbed `tla/*.tla`, so the obvious first reorganization — models into
      `tla/attestation/` — would have made them **invisible to both gates, which would then
      stay green while asserting nothing**. Both read the registry now; `trackcheck` walks
      recursively and cross-checks the walk against git, because `make matrix` reads the
      engine Makefiles rather than git and can therefore *run* a file no claim-gate can see.

    **Two things fell out of building it, and both are the usual shape.** The cross-track
    notation's first draft was `CORE §6.2` — prefix, space, sigil — which matched **23 lines
    of ordinary prose** across 12 files (`WHAT §6.9 SAYS`, `LIVENESS §4.1`, `THE §5.8`, every
    Spin `-D` macro name) and then *excluded* each match from that line's citation set: a
    tripwire against miscrediting citations that silently **dropped** them instead. The count
    held at 28 only because every affected section is cited on some other line too. And
    `spec-drift`'s per-engine exposure line had been reporting **"15/1169 model files"** — the
    denominator was the flat glob counting hundreds of gitignored TLC `_TTrace_` artifacts as
    models. It is 15/24. Neither was found by reading the code.

    `scoped` is a **gated state**: a scoped track must carry no models and no pin, so adding a
    model file fails the build until the track is promoted *with* a pin — the step where
    someone states which snapshot the results are about. Per-track subdirectories are the
    deliberate next step, and are now safe: a file that falls out of a gate's view is a build
    failure rather than a silent green.

    **STARTED 2026-09-07 — all three extension specs vendored, and the attestation track has
    its first module.** `spec-data/ext-attestation-v1.3`, `ext-quorum-v1.2`,
    `ext-identity-v3.10`, each a frozen snapshot with a generated MANIFEST, produced and
    verified by `tools/vendor-spec.py`. **This was never blocked on keystone and the belief
    that it was is worth recording as an error of ours:** all three specs declare
    `Depends: ENTITY-CORE-PROTOCOL.md (v7.40+)`, a FLOOR, and the pin we already hold carries
    v7.62–v7.76 clause tags. The item above said the extension snapshot "rides along with that
    same re-vendoring pass" — an inference nobody checked. Core's pin stays parked on keystone;
    the extension tracks pin independently, which is what per-track `pin_file` is for.

    **`tla/AttestIndex.tla` — attestation §5.7, index invariants I1–I5.** 7 runs (1 green,
    3 controls, 3 witnesses). What makes it more than a transcription: **two of the four
    mandatory indexes are conditional** — `supersedes` only when the field is non-null, `kind`
    only when the key is present (§3.2 makes `kind` a recommendation, not a field) — so *"the
    entity is in all four indexes"* is FALSE for an ordinary kind-less attestation. Entity `a3`
    exists to be that attestation, and `AttestIndexEligWitness` is asserted-to-be-violated
    precisely so the two readings are distinguishable on this model; without it the wrong one
    passes. The `Register` vacuity trap was avoided by construction and then **demonstrated**:
    with the index publishes collapsed into one assignment the state space drops 1485 → 216,
    the sequencing witness goes silent, and `IndexAllOrNothing` goes green as a tautology.

    **Honest scope: TLC only.** No Apalache, no Spin, no prover model — so the corroboration
    argument this repo rests on does **not** cover these rows, and `docs/COVERAGE-MATRIX.md`
    §3c says so rather than leaving it to be inferred. Three new ledger rows, all **OPEN**: O5
    (no prover model exists on this track at all, so attestation signature validity is
    discharged by nobody), O6 (below), O7 (the model encodes a *reading* of I2, and nothing in
    this repo could check it).

    **`tla/AttestLive.tla` — §4.3 liveness and the §5.2/§5.3 chain walks. The next target was
    O6, and modelling it found something bigger, in the direction the hypothesis was wrong.**
    8 runs (1 green, 2 controls, 3 witnesses, **2 findings**). Coverage on this track is now
    **7 of 25**.

    The hypothesis written above was: `§5.2` and `§5.3` both lack a depth bound, so both rest
    on unstated acyclicity. Half of that survived contact with a model.

    - **§5.2 does rest on it, exactly** — `BackWalkBoundedWhenAcyclic` green over every graph
      on three nodes including cyclic ones, `BackWalkBoundedAlways` violated. The assumption is
      now *isolated* rather than suspected, which is what closes O6: not "it terminates" but
      "here is precisely what its termination is, and nobody here owns the discharge."
    - **§5.3 does not, and the reason is the defect.** `SpecWalkNeverExhausts` is green: the
      `while True` cannot iterate twice, because stepping to a live successor proves that
      successor has no live successor of its own. But that same fact means the walk **cannot
      traverse a chain of three at all** — the link leading to the head is never itself "live"
      under §4.3's ratified transitive semantics, so `find_live_head` started at the oldest
      link returns **null** where the head is the third link. A missing bound was the guess;
      a wrong answer was the defect. **Reading found the smell and got the mechanism
      backwards.** Only running it separated the two — which is the argument for modelling a
      suspicion rather than writing it down.

    **And the corollary is worth more than the bug: §5.1's head-resolution step is an identity
    map.** `default_find_authorizing` filters candidates to live ones and then resolves each
    through `find_live_head` — but a live attestation has no live descendant, so every
    resolution returns its own input. `HeadResolutionIsIdentity` is **green, and the green is
    the finding**. That is also *why the conformance vectors cannot catch the bug*: TV-A4 gets
    the right answer because the liveness filter already did the chain resolution, and the
    broken component is invisible from outside the composite. **T4's lesson on a different
    composition** — "the composed thing is checked and the components are checked" does not
    mean the composition is verified.

    Routed to `entity-system-architecture`:
    `docs/status/ROUTING-2026-09-07-ATTESTATION-CHAIN-WALKS.md`. Three findings — the §5.3
    traversal defect, a §5.2 type error against §4.0's own accessor contract (a hash passed to
    the path-keyed getter), and `EXTENSION-QUORUM` §4's normative MUST resting on an `as_of`
    parameter §5.3 does not define. **The cohort was measured before any of it was written**:
    all three implementations diverge from §5.3's pseudocode in the same direction, Go's
    comment names the exact cause, and `entity-core-rust`'s `SPEC-AMBIGUITIES.md` **ATT-1**
    raised the neighbouring half against v1.0 and asked for a ruling. v1.1 adopted **one of
    ATT-1's two interim changes**, and F1 is the residue of the half that was not adopted — the
    amendment that fixed §4.3 is what made §5.3 worse. Rust and Go disagree on `as_of`, which
    is a live interop split.

    **A new gate-table kind: `TLC_FINDING`** (`make -C tla tlc-finding`, in `matrix`). Rows
    that MUST be violated on a model where **nothing is weakened**. It grades identically to
    `TLC_NEG` and means the opposite — `TLC_NEG`'s header says "a green here means the property
    has no teeth", which is false of these rows, where a green would mean the spec defect had
    been *fixed upstream* and the row should be retired rather than repaired. Two opposite
    meanings behind one exit code is the D13 shape; `TLC_NEG` already carried one such
    exception in a paragraph, and a second is a table. Teeth-tested both ways before use (a row
    that goes green; a row naming a nonexistent operator).

    **`tla/AttestRevoke.tla` — §4.3's OTHER recursion, found by going back to close a declared
    abstraction rather than by moving on.** 8 runs (1 green, 2 controls, 3 witnesses, 2
    findings). Coverage 7 of 25 -> **9 of 25**.

    `AttestLive` abstracted self-revocation to a per-node flag and said so in a D11
    inventory-boundary note. Closing that boundary is what surfaced this: **`is_self_revoked`
    is used in §4.3's normative pseudocode and defined nowhere in the document** — one
    occurrence in the whole file, and it is the use. `not_expired` likewise. And this is a
    class the document has already fixed twice: v1.0 Amendment 1's history entry records adding
    definitions for two helpers *"referenced from §4.3 … but never specified"*. Two were found;
    two more in the same function were not.

    **It is not editorial, because the readings disagree.** The main path spells self-revocation
    out recursively (`is_attestation_live(rev, …)`); the descendant path calls the undefined
    helper. Modelled both ways side by side: `SelfRevReadingsAgree` is violated by an *expired*
    revocation (recursively it does not revoke, structurally it does — an expired revocation
    that goes on revoking), and `LiveReadingsAgree` shows it changes `is_attestation_live`'s
    answer, which is the predicate every consumer's authorization decision runs through. The
    counterexample is the documented predecessor-revival semantics being switched on and off by
    an undefined term: node 3 supersedes node 1, node 4 revokes node 3, node 4 is expired —
    recursively node 1 is dead, structurally node 1 is alive.

    **The cohort was measured and it is more interesting than "they diverge".** Python and Rust
    both pick the recursive reading; Go computes the descendant check a third way (any *fully
    live* descendant, walking past dead links, with the comment *"the rescuing-grandchild case
    the spec's literal pseudocode mishandles"*). That looked like a real interop divergence.
    **It is not, and `DescReadingsCoincide` is the green that says so** — the two predicates
    coincide on every acyclic graph. Run rather than argued, because §D.1 is the record of this
    repo reasoning its way to a cohort claim and being wrong.

    **Second finding, recorded as a reading rather than a measurement.**
    `has_live_transitive_descendant` carries a `visited` set and says it is cycle-safe; the
    revocation recursion four lines above it has **neither a visited set nor a depth bound**.
    The one place §4.3 defends against cycles defends one of its two recursions. All three
    implementations built a guard or a rationale for it — Python threads an `in_progress` set
    through the whole mutual recursion, Rust's comment says the recursion is *"fine because
    revocations don't normally form chains"*. `AttestRevoke` cannot check this: its `Init`
    restricts both relations to be acyclic by construction and every recursion in it terminates
    because of that restriction rather than because of the algorithm. The module header says so.
    Ledger O10.

    **The transferable piece: a declared abstraction is a to-do list, not an absolution.** O9
    exists because someone went back and read a D11 boundary note as work rather than as
    disclosure. That is the first time in this repo that reading one back has paid, and it is
    cheaper than finding a new section to model.

    **And modelling this section found a defect in `make coverage` — D15's mechanism in a
    fourth shape, the letter suffix.** `AttestLive`'s first draft cited `§5.6a`
    (`find_attestations_with_supersedes`). `coverage-check.py`'s citation pattern was
    `§(\d+\.\d+)`, so it produced the token `5.6` — and in this spec `§5.6`
    (`find_revocations_for`) and `§5.6a` are **sibling `###` sections**, not a section and its
    subsection. The citation would have been credited to a section the model says nothing
    about. Same miscredit as `§4.7`'s range endpoint, arriving through a different door.

    Asking the same question of the **denominator** was worse: `SPEC_HEADING` excluded lettered
    headings outright, so **six normative core sections had been missing from it all along**
    (`1.2a`, `1.5a`, `4.5a`, `5.2a`, `6.9a`, `9.5a`) plus two in attestation. `28 of 85` was a
    fraction over a section set that dropped sections for no stated reason, and the by-area
    figures published beside it (`§4 70% · §5 90% · §6 62%`) were computed the same way. It is
    **29 of 91** — `§4 64% · §5 91% · §6 57%` — and `§5.2a` is now its own Matrix A row rather
    than being folded into `§5.2`, which is a different section 320 lines away.

    **`tools/spec-drift.py` had it right the whole time** (`[a-z]?` in both its heading and
    citation patterns). *That* is why it reports **30** cited sections where `coverage` reported
    **28** — a two-tool disagreement over one artifact, both numbers published in the same
    documents, and nobody had reconciled them. Two gates, two definitions of "a section",
    neither aware of the other. The convention is spec-drift's now, in both.

    **Third piece: `make coverage` checked one prose site and there were four.** It verified the
    `Coverage: N of M` line *inside the grid it derives from* — and `README.md`'s headline,
    `docs/STATUS.md`'s pointer and `COVERAGE-MATRIX` §5's complement ("N of M sections are not
    cited by any model") all stated the old pair and were found **by grep**. `runcount`'s
    declared-prose-site discipline now applies to the coverage pair too, teeth-tested both ways
    (a stale number; a site that stops making the claim).

    **Scoped 2026-09-06: `docs/status/SCOPING-2026-09-06-IDENTITY-ATTESTATION.md`.** Identity
    + attestation + quorum is the next phase, and it is a better target than core was: a
    signed graph with **mutable membership, cached trust, and a temporal query**. Four shapes
    map onto machinery this repo already has — K-of-N onto `MultisigKN`, chain-walk
    termination onto `DeepChain`/`Bounds`, the attestation index invariant **I2** onto
    `Register`'s sequenced writes (*"partial-index states are NOT permitted"* is
    `RegisterAllOrNothing` with four indexes instead of five facets), and
    `current_signer_set(as_of)` onto `Revoke`'s verdict determinism over a declared temporal
    input — **the exact shape where §5.10's `δ` turned out to be missing from the model.**

    Two explicitly stated closure assumptions are already visible in the spec text and are
    the sharpest targets: quorum's **cached trust** (a validated `quorum-update` is trusted on
    every subsequent read, with no end-to-end re-validation and none required at cold start —
    so the whole live signer set rests on *every* write path running arrival-time validation),
    and the **"previous quorum" pinning rule**, which names its own wrong answer and is
    therefore a negative control already written for us. Start at `EXTENSION-ATTESTATION`'s
    substrate, not at identity's 1,617 lines. **"Recovery cluster" is the pre-v3.3 name for an
    identity quorum** (`SYSTEM-IDENTITY-COMPOSITION.md` §7).
    **QUORUM TRACK — promoted and modeled 2026-09-07, three modules, 28 runs, SEVEN findings.**
    `spec-data/MODELING-PIN-QUORUM` -> `ext-quorum-v1.2` (byte-identical to live when checked).
    The `scoped` gate worked exactly as designed: the three model files could not be declared
    in `TRACKS.toml` until the pin file existed, so promotion happened in the intended order
    rather than being worked around. Routed:
    `docs/status/ROUTING-2026-09-07-QUORUM.md`; indexed with the attestation note in
    `docs/status/FINDINGS-INDEX.md`, which is the per-track index the previous checkpoint
    deferred until there was more than one note to index.

    **The two questions `TRACKS.toml` wrote down before any model existed were both answered,
    and one of them was answered wrong by the note.** That is the interesting half.

    - *"The whole live signer set rests on every write path running arrival-time validation,
      and nothing states that every path does."* — right about the assumption, **wrong that it
      is unstated.** §4.2's cold-start posture asserts it outright ("tree-bound only on
      validation success"), and two sentences in the same document falsify it: §4.2.1
      non-trigger 1 ("may sit in the tree at a structurally-valid path without being
      authoritative") and §8's permitted raw `tree:put`. `tla/QuorumTrust.tla` exhibits it in
      **two steps with §8 switched off** — a K-of-N failure is tree-bound, the next read walks
      the index and caches it as authoritative. Ledger O11.
      **And the green is the more useful result:** given the closure, §4.2.1's trigger and
      non-trigger set is *exactly sufficient* across every interleaving. The invalidation rules
      are not the problem; the closure they silently require is.
    - *"Model `not_before` and the clock explicitly from the start."* — the right call, and it
      paid immediately. With the clock in, `EXTENSION-ATTESTATION §4.3`'s undefined
      `not_expired` separates into two readings that disagree about whether a **scheduled**
      membership change destroys the current signer set. Ledger O12.

    **The finding worth reading first is Q1**, and it needs no attacker, no expiry and no
    malformed input: on a plain chain of three `quorum-update`s, §4.2 returns the roster the
    quorum was **created** with. §5.3's walk returns null from the oldest element (the routed
    F1), and §4.2's fall-through is silent — `signers` still holds `quorum.data.signers`.
    TLC's counterexample is `sup = <<0,1,2>>` with no `not_before` and no `expires_at`.

    **The cohort was measured before any impact claim, and it is unanimous three times.** None
    of `entity-core-{go,rust,py}` implements §4.2's `find_live_head(updates[0], ...)` — all
    three probe more than one candidate. All three read `not_expired` as full temporal
    validity. All three reject `threshold = 0` at `:create`, which only §6.2 requires — and
    Go's comment attributes that rule to "the §3.1 invariants", where §3.1 states no such
    invariant. Three authors deriving the same unwritten rule is the argument for writing it
    down. The one exception is Q5, where the cohort follows the text faithfully and the text is
    wrong.

    **O15, and it is the row that could not be seen from one track.** `AttestRevoke` models
    revocation with the clock collapsed to a flag; `QuorumSignerSet` models the clock with
    revocation omitted. Both disclosures are honest and neither model is wrong. But
    `DescReadingsCoincide` — AttestRevoke's cohort green — is scoped to a model in which
    `not_before` does not exist, and O12 shows the two descendant readings separate precisely
    when it does. **The green is true and its scope is narrower than it reads.** No model covers
    both dimensions; that composition is now the cheapest open item on either extension track.
    O9's lesson arriving from a direction nobody was watching.

    **Two gates were found asserting less than they claimed, both by widening, not by breaking.**
    (a) `runcount`'s per-track split captured exactly two groups, core and attestation.
    Promoting a third track did **not** fail it — the sentence still matched, both numbers were
    still right, and it went green while asserting nothing whatever about 28 quorum runs. It now
    derives the tuple from the modeled set and **errors on a modeled track it does not read**;
    teeth-tested both ways. (b) `coverage`'s prose-site table listed three sites and there was a
    fourth: §Next item 1 above said "they reach **28 of the 85** numbered sections", the
    pre-letter-suffix pair, stale since 2026-09-07. It survived the grep that fixed the other
    three **because it states the pair in different words** — "they reach", not "Coverage:".
    That is the shape worth keeping: a stale number hides best in a sentence that says it
    differently from the canonical one, since every search for the staleness searches for the
    canonical phrasing.

    **Still TLC only, and this now spans two tracks.** No Apalache, no Spin, no prover. §4.1 is
    a K-of-N *signature* validator — §2 calls it "the only mechanism that distinguishes quorum
    from a regular peer node" — and its unforgeability is discharged by nothing here (O5, O14).
    Read both extension tracks as defect reports, not as assurance.

    **IDENTITY TRACK — promoted and modeled 2026-09-07, three modules, 33 runs, NINE findings,
    and the LAST scoped track.** `spec-data/MODELING-PIN-IDENTITY` -> `ext-identity-v3.10`
    (byte-identical to live when checked). The `scoped` gate forced the pin before the model
    files could be declared, for the second time in one day — and with this promotion **no
    scoped track remains**, so that half of the gate now has no subject in the live registry.
    Routed: `docs/status/ROUTING-2026-09-07-IDENTITY.md`; indexed in
    `docs/status/FINDINGS-INDEX.md`, now 21 findings across three notes, 18 machine-checked.

    **The finding worth reading first is I2, and its shape is a green.** §9.4's fail-closed rule
    for compromise recovery is a NEGATIVE REACHABILITY claim, and `TRACKS.toml` plus
    `docs/status/SCOPING-2026-09-06-IDENTITY-ATTESTATION.md` §3.3 both said so before a line was
    modeled: *"a peer that does nothing satisfies it ... write the witness before the
    prohibition."* Followed literally. `RecoveryFailClosed` — the prohibition — is **GREEN**.
    `RecoveryAttainable` — the witness, stated as a positive claim so a machine can check it —
    is **VIOLATED on the same constants**:

    > a compromise-recovery signed K-of-N by the identity's real quorum, delivered to a contact
    > that has already received that identity's genuine `quorum-publish`, is REJECTED.

    The cause is §6.3: phase 1 is unconditional `identity_verify_cert`, whose §3.6 step 1 admits
    four kinds, and the phase-2 dispatch table's seventh row names `quorum-publish`. So the row
    that fills §9.4's trust anchor is unreachable and the arrival is unbound on the way past.
    §9.6 names compromise-recovery as the only remedy for a stolen controller key. **A
    conformance vector that checks only the fail-closed rejection passes on a peer that can
    never recover.** The pre-model note was right and *under-specific*: the risk it named was a
    MODEL with no paths; what turned up is a SPEC with no paths.

    **The same mechanism deletes two other kinds on arrival**, neither of them a row of that
    table, so both had to be looked for: a `revocation` (§4.6 gives identity authority rules over
    it, §5.1 stores it at synced paths, §3.6 step 3 reads it back out of the tree) and a
    `quorum-update` (§5.1's path, §3.3's "identity does not define this kind"). The second
    composes with Q1: the roster cannot change because the updates do not survive to be walked.

    **THE COHORT DOES NOT AGREE WITH ITSELF, AND THAT INVERTS THE ARGUMENT THE PREVIOUS TWO
    TRACKS RESTED ON.** All three implementations added a kind branch before §6.3 phase 1 that
    the spec does not have — the unanimity is the finding — and **no two did the same thing.**
    Go no-ops every non-identity kind and caches nothing; Rust caches `quorum-publish` without
    validating it; Python validates and caches both quorum kinds; only Go admits `revocation`,
    and it needed two spec-absent additions to do so. §9.4 keys its fail-closed rule on exactly
    that cache, so **a Go contact rejects a recovery a Rust contact accepts**. "Three authors
    deriving the same unwritten rule" was the quorum track's argument for writing it down; here
    they derived three different rules and the peers do not interoperate.

    **One cross-spec finding exists only in a PAIR of documents.** `EXTENSION-ATTESTATION`'s
    TV-A8 constructs an invalid-signature attestation written by raw `tree:put` and justifies
    returning it: *"consumers layer signature validation per topology — identity's
    `identity_verify_cert` rejects A at topology-dispatch step."* §3.6 rejects every
    `kind="revocation"` at step 1, before topology dispatch, and `identity_topology_for` has no
    revocation arm. **The rejection point TV-A8 delegates to does not exist for the kind TV-A8
    is about.** Neither document is wrong read alone. On the pinned text an unsigned revocation
    naming the quorum marks any cert rooted there `authority_revoked` — denial of authority, no
    signature required.

    **§9.2's MUST and §4.2's valid-modes table cannot both be satisfied.** §4.2 gives `agent`
    "any of the four" modes; §4.2a and §5.1 put mode=public at `public/cert/`; §2.3 makes the
    signer the controller in the three-key default; §9.2 requires rejecting anything under
    `public/` carrying a live controller's signature. The four-key shape is unaffected, which
    is the tell. **No implementation enforces §9.2 at all** — that absence is the census datum.

    **O16 is a NEW SHAPE of ledger row and the transferable piece.** Identity consumes
    `§QUORUM:4.2 current_signer_set`, which this repo has already measured and refuted (Q1).
    Transcribing it would have re-derived Q1-Q7 wearing identity section numbers and routed them
    twice; assuming it silently would have made the choice invisible afterwards, which the prior
    checkpoint predicted. Neither: `SignerSetIsSound` is a model **constant**, TRUE in the green
    sweep and FALSE in a negative control whose only job is to exhibit what every identity K-of-N
    verdict rests on. **When a track consumes another track's known-defective output, make the
    assumption a constant, control it, and open the row.**

    **Still TLC only, and this now spans three tracks.** O5, O14 and O19 are one undischarged
    Dolev-Yao gap counted once per track — deliberately not merged, so its growth is visible.
    Read all three extension tracks as defect reports, not as assurance.

13. **~~Vacuity, the last of it.~~ DONE 2026-09-06 — no thin positive remains.**
    `Register`'s correct-model atomicity was near-tautological because the five §6.2 writes
    landed in **one assignment**: `tree[h] \in {{}, FACETS}` restated the assignment and could
    not fail, so every tooth was on the control side.

    The four non-committing facets now land **one per transition, in any order**, with the
    fifth write and the §6.6 index publish as a single atomic **commit point**; the teardown
    mirrors it, because the stale-*positive* hazard runs the other way. `RegisterAllOrNothing`
    and `IndexMatchesTree` now hold by a **discipline** rather than by the absence of any other
    state, and Apalache proves `RegisterAllOrNothing` **inductive** — not worth doing while it
    was a tautology — with its own negative control, since an inductive invariant with no
    control is the same trap one level up.

    **The evidence is a run, not a rewrite.** `RegisterSeqWitness` asserts the **pre-0.8.3**
    invariant and requires it to be **violated**: the old positive is now false (the tree
    reaches `{"manifest"}`) while the properties that matter still hold. That is the sharpest
    form the claim could take, and it is what rules out the failure mode that would otherwise
    replace the old one — **a "sequenced" model whose sequence is never reached is the same
    vacuity in new source code.** Adding write-loop labels does not prove the loop is entered.

    Two consequences, stated rather than absorbed:
    - `NoPartialResidue` is now scoped to **settled** handlers. A partial tree in flight is the
      model working; a partial tree at rest is the defect, and that is what §6.2 forbids.
    - `RegisterAtomicBug` now fails on `RegisterAllOrNothing` — **in TLC and in Spin, agreeing**
      — which is the defect its own header names. The old verdict was an incidental side effect
      of the collapsed-write shape, so this is a control that went from failing for a
      neighbouring reason to failing for its stated one.
14. **~~"`make specdrift` reports no drift" was published in eight canonical documents while
    all three pinned files differed from live.~~ CLOSED 2026-09-06 — `make driftclaim`. The
    finding is the mechanism, not the stale sentence.**

    The live spec had reached **0.8.2.11** with the pin at **0.8.2** and **9 of 30 cited
    sections moved**. Two sites stated it in the strongest available form — *"the pin matches
    the live spec **byte-for-byte across all three normative files**"* (`README.md`,
    `docs/STATUS.md`). Every one of the eight was true when written.

    **Three failures compounded, and the third is the one worth keeping:**
    - `make specdrift` is wired **`|| true`** — running it cannot fail, by design, because
      drift is information rather than a build break. That design is still right.
    - `make specdrift-gate`, which *does* fail on drift, is invoked by **no target** — not
      `check`, not `matrix`, nothing. It has existed unreferenced since 2026-08-28.
    - The prose was tied to **no derivation at all**. That is precisely the hole `make
      runcount` closes for the matrix total and `make coverage` closes for the section set,
      one artifact over — the third instance of D15's residue, found the same way.

    **Why this one is not like the other two, which is the transferable part.** Every previous
    stale-claim finding here went stale because *we* edited our own tree and missed a site: the
    run total across two commits, the ledger counts across seven. This claim went stale
    **when a sibling repo committed** — our tree untouched, every existing gate green, no diff
    for a change-triggered gate to fire on. **A gate that runs only on our own diffs cannot
    reach a claim whose input is outside the repo, in principle and not by oversight.** So
    `driftclaim` is deliberately *not* in `check` or `matrix` (it also needs the sibling, the
    `leanseam` constraint) and its own output says it must run at a release boundary and on a
    schedule. Making it a pre-commit gate would have been the intuitive fix and the wrong one.

    D13 asked of it: it asserts every declared site states the derived status, **and that every
    site still states one at all** — silence fails, because deleting the sentence is otherwise
    the cheapest way to green. Teeth-tested four ways by breaking it, including the direction
    that does not feel like a failure (**a document claiming drift that does not exist**, the
    `leanproof` both-directions lesson). Its first draft matched raw text and failed six of
    nine sites on **markdown line-wrapping alone** — a gate whose green depends on where an
    author's editor broke a line asserts the line breaks, not the claim; it matches a
    normalized copy now.

    What it does **not** assert, stated in the tool: that the prose *around* the anchor
    describes the drift correctly, and that no undeclared site says otherwise. Same
    acknowledged hole as `runcount`'s.
