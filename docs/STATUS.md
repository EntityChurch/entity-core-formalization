# entity-core-formalization — status

_Updated: 2026-08-30 · this line: 0.8.2_

> **The models track the live spec.** Every model in this repo is written against the
> SHA-pinned snapshot in `spec-data/v0.8.2/`, which is the Entity Core Protocol at spec
> version **0.8.2** — the current published line, and what peers are building to.
> `make specdrift` reports **no drift**: the pin matches the live spec byte-for-byte across
> all three normative files. The results below are a statement about the protocol as it
> stands today.

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
  independently by TLC, Apalache and Spin — and **already divergent in the wild**: four
  distinct behaviours across the 46-peer keystone cohort and the three ground-up impls, with
  no `validate-peer` probe for the input. Routed to `entity-core-protocol`; full statement in
  `docs/PROPERTIES.md` §D.1, routing packet in
  `docs/status/ROUTING-2026-08-30-PREHELLO-AUTHENTICATE.md`.
- **The full matrix is 238 runs** and `make matrix` is the gate: **green** (does every
  property hold?) + **negative controls** (could it have failed?) + **witnesses** (does the
  model do anything?). Green alone answers only the first question, which is why `make
  check` now says so out loud. `make coverage` runs first and checks the coverage *claim*
  against the models' own citations.
- **Nothing is deferred.** The composed whole-protocol Apalache conjunction — carried as
  "consciously deferred" since Phase 1 — was proved in the 0.8.2 audit, the four modules
  that had single-tool coverage now have all three, and the last two single-engine *section*
  rows turned out to be phantoms and are now real modules on all three engines.

| slice | runs |
|---|---|
| TLC green (11 modules + Store liveness slice) | 12 |
| TLC negative controls | 36 |
| TLC non-vacuity witnesses | 11 |
| Apalache inductive (23 invariants × base+step) | 46 |
| Apalache negative controls | 21 |
| Spin green (7 × safety+LTL, 4 safety-only) | 18 |
| Spin negative controls | 35 |
| ProVerif (15 green + 15 controls) | 30 |
| Tamarin (14 green + 15 controls) | 29 |
| **total** | **238** |

**Section-by-section coverage, per-engine, with every limit stated:
`docs/COVERAGE-MATRIX.md`** — the document to send a new reader to. Headline: **28 of 85
numbered sections (33%)**, which by area is **§4 70% · §5 90% · §6 62%** — the three surfaces
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

### Two thin positives addressed, and one still open

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
- **Still open.** `Register`'s correct-model atomicity remains near-tautological; it has
  teeth on the control side only. Sequenced-write `Register` is still backlog.
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

   **Impact, and why this is worth an architecture slot now.** The divergence is shipped: a
   source read of the 46 keystone peers plus `entity-core-{go,rust,py}` (2026-08-30) finds
   **four** behaviours — 401 `invalid_nonce` (29), 400 `connection_sequence_error` (6),
   409 `connection_sequence_error` (go — a status in no clause), 400 `handshake_failed`
   (rust — a code absent from the spec). It survived because `validate-peer` has **no probe
   that sends `authenticate` before `hello`** and cites §4.7 nowhere in `connectivity`: ten
   MUST-emit rows, roughly one gated. No keystone conformance number moves (nothing tests it),
   but the fix touches ~8 trees and is far cheaper **before** the v0.8.2 cohort regeneration
   than after. Suggested resolution in `docs/PROPERTIES.md` §D.1 (narrow row 10's parenthetical
   alone — four words). Full packet, per-peer census and hand-off checklist:
   `docs/status/ROUTING-2026-08-30-PREHELLO-AUTHENTICATE.md`.
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
- Concurrent toolchain runs can hit a transient SELinux `:Z` bind-mount relabel race
  ("file not found"); run the three engines **serially**. Reclaim a hung container with
  `podman kill` (a `timeout`-wrapped `podman run` only kills the client).
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
   against them by `make coverage` — they reach **28 of the 85 numbered sections** of the core
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

   **Still open, in order:**
   - **~~Route `hframed` upstream.~~ Drafted — and the ask changed.**
     `docs/status/PROPOSAL-DRAFT-2026-08-30-KEYSTONE-HFRAMED.md`. Not "discharge `hframed`"
     (which would be asking keystone to prove something untrue) but three separable asks:
     prove the relative half from a syntactic side-condition, add the companion theorem for
     the absolute form, and correct the source comment calling `hframed` "mechanical stdlib
     plumbing" — true of the relative branch, impossible for the absolute one. **No ask on the
     ProVerif/Tamarin side; nothing was wrong with it.** Awaiting hand-off to keystone.
   - **Differential trace checking** — replay Apalache `.itf.json` counterexamples through the
     Lean executable model (or a reference peer) and assert the abstract predicate's value
     matches. The ledger is a human reading of two texts and `make leanseam` only detects that
     one of them moved; this is the only item that would put a **machine** on the Lean-facing
     half of the 5th wall. The ledger was built first precisely to tell us whether this is
     worth it — 21 of 23 rows are CLOSED and the two open ones (L1, L7) are both §5.5a
     granter-framing, so *route the findings first, then reassess* still looks right.
     **But note what the L7 correction says about this item's premise:** the ledger's open
     rows were re-read once and one of them was materially wrong. A human reading of two texts
     degrades exactly this way, which is the argument *for* the machine check, not against it.
   - **A local Lean tree here was considered and rejected.** The value of the seam is that
     Lean's theorems are about the same executable code the conformance suite runs; a fork
     would make them statements about our copy, which nothing gates. Cite, pin, and check.
5. **The bound nobody has attacked: `Peers = {A,B}`. Scoped 2026-08-30 — it is three different
   problems, and the first version of this item pointed at the wrong one.**
   `docs/status/SCOPING-2026-08-30-PEERS-BOUND.md`. Apalache's results are unbounded in *steps*,
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
   **Revised order:** restructure `Reentry` for a peer-indexed request target (N stays a
   `CONSTANT`; N=2 must reproduce today's results byte-for-byte — that equivalence is the
   regression test, and the step most likely to fail silently) → run N=3 → *then* reassess
   **Ivy** / `mypyvy` / TLAPS for unbounded N, informed by whether N=3 found anything and by an
   inductive invariant we will have had to write regardless. Adopting the parameterized tool
   first would answer at the expensive end a question not yet asked at the cheap one.
   **Still the largest single upgrade available, and still the one with the least defence.**
6. **Liveness is bounded everywhere and cannot be lifted by the current toolchain.** Apalache
   does safety/induction by construction. **TLAPS** machine-checks liveness proofs (fairness,
   well-founded ordering); deadlock-freedom for `Core` proved rather than model-checked would
   be the headline result this repo does not yet have.
7. **Other techniques not yet used.** A **refinement proof** that the composed `Core` model
   actually refines the individual modules (the standard TLA+ move; today they are checked
   separately and the composition is asserted, not proved — recorded as ledger row **T4**,
   the one OPEN row in Class T). Alloy for `Register`'s index↔tree-walk coherence.
   CryptoVerif for computational-model results. §6.11(c) per-request deadlines, which are
   what would make Class-G a liveness bug rather than a crash.
8. **Widen the TLA+ bounds** — 3-peer / churned-store, and sequenced-write `Register` to
   retire the last near-tautological positive.
9. **~~Nothing checks a number in prose.~~ Partly closed.** `make coverage` now derives the
   section set and count from the models and fails on any disagreement with
   `COVERAGE-MATRIX.md`, including the denominator against the pinned spec. What it still does
   **not** check: the **engine columns** of Matrix A (a citation says a model is *about* a
   section, not which engine verifies what), and the **run counts** quoted in prose — the 238
   in this file and the capstone is still hand-derived from the gate tables. Deriving the run
   total the same way is the remaining half.
10. **Model the §5.10 skew tolerance `δ`.** Found while writing the seam ledger (row **O4**):
    §5.10's cross-clock temporal model makes `δ` a declared Layer-1 input *alongside* `t`, and
    states the determinism argument in terms of both. `Revoke.tla` models `t` and not `δ`. The
    shape is already there — two peers with different declared `δ` may permissibly differ,
    exactly as with different `t` — so the extension is small.
11. **Tie models to conformance vectors.** Only the Class-G deadlock is currently grounded
    against a reference impl; where a sibling conformance vector exists for a modeled
    property, cite it to turn "spec says" into "spec says *and* a passing test exercises it."
    Overlaps item 4 — a conformance vector and a replayed counterexample are the same move
    from opposite ends.
12. **Phase 3 extension-protocol attacker models** stay gated on vendoring `EXTENSION-*`,
    which is still not in `spec-data/`. Note that §5.8's registry rows and §5.9's continuation
    depth brake are now modeled at the *core* level, so the gate is narrower than it was.
13. **Vacuity, the last of it.** `Register`'s correct-model atomicity is still
    near-tautological — teeth on the control side only — and sequenced-write `Register` is
    what would retire it. This is the one thin positive left standing; see item 8 and
    `docs/PROPERTIES.md` §C.4.
