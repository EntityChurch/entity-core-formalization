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

- **TLA+ track.** **9 modules** bounded-exhaustive in TLC — the 6 Core-Protocol concurrency
  modules (reentry, conn, store, revoke, emit, register), the composed 2-peer `Core` model,
  and the two added at 0.8.2 (`Authority`, `Bounds`) — safety **and** liveness. Apalache
  proves **18 safety invariants across all 9 modules** *inductive (unbounded in steps)*;
  liveness stays bounded-exhaustive in TLC + Spin by nature.
- **Cross-check.** Spin **independently re-encodes all 9 modules** from the spec (reproducing
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
- **The full matrix is 204 runs** and `make matrix` is the gate: **green** (does every
  property hold?) + **negative controls** (could it have failed?) + **witnesses** (does the
  model do anything?). Green alone answers only the first question, which is why `make
  check` now says so out loud.
- **Nothing is deferred.** The composed whole-protocol Apalache conjunction — carried as
  "consciously deferred" since Phase 1 — was proved in the 0.8.2 audit, and the four modules
  that had single-tool coverage now have all three.

| slice | runs |
|---|---|
| TLC green (9 modules + Store liveness slice) | 10 |
| TLC negative controls | 30 |
| TLC non-vacuity witnesses | 9 |
| Apalache inductive (18 invariants × base+step) | 36 |
| Apalache negative controls | 15 |
| Spin green (7 × safety+LTL, 2 safety-only) | 16 |
| Spin negative controls | 29 |
| ProVerif (15 green + 15 controls) | 30 |
| Tamarin (14 green + 15 controls) | 29 |
| **total** | **204** |

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
| Three Tamarin controls falsify their own **reachability** lemma | `grep -q falsified` matched `falsified - no trace found` — the honest path dying reads the same as the property breaking | declared per lemma in `TM_NEG_EXPECT`; two of them still weak, open |
| `Unforge.pv` / `Binding.pv` carried **no non-vacuity query** | pure correspondence lemmas go green on a model that can never accept; their Tamarin twins both had an `exists-trace` lemma | queries added; both fire |

The pattern is the enforcement point for the rest: a control that fails for the wrong reason,
or a run that fails to run at all, is no longer distinguishable from teeth by accident. Note
what the second audit found: **fixing three of the five graders left the other two, plus both
ProVerif targets, exactly as they were** — 62 of the 203 runs. The lesson is not "check the
controls", which was already the rule; it is **apply a finding to every instance of its shape
before closing it**. No verdict moved in either pass; all 203 were re-derived by hand and match
what the reports claim.

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

1. **§5.9's recommended 8× TTL/`chain_depth` ratio has zero margin at worst-case fan-out.**
   The property needs `ceiling × worst_case_fanout` **strictly less than** the TTL seed; at
   exact equality the last causal level spends the last of the TTL and the backstop fires on
   the step the deterministic brake would have. §5.9 puts the ratio choice on the deployment,
   so this is a boundary worth stating where operators read it, not a defect in the default.
   Reproduce: `BoundsRatioBug.cfg`.
2. **§5.8's conformance topology is load-bearing for this repo's own prior results.** The
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

## Next

1. **Coverage breadth.** Measured by the `§`-citations the models carry, they now reach
   **28 of the 85 numbered sections** of the core spec. By area that is **§4 70% · §5 90% ·
   §6 62%** — the three surfaces this repo owns. Near-zero coverage of §2, §3, §7, §8 and
   §9 is deliberate scope: registries, encoding, trusted crypto and the conformance profiles
   belong to other layers of the assurance map. The remaining third of §4/§5/§6 is the real
   backlog: §4.3–4.5, §5.3, §6.3/6.4/6.7, §6.12/6.13. Which uncovered section is *scope* and
   which is *backlog* is set out in `docs/COVERAGE-MATRIX.md` §5 — keep that split sharp; it
   is the difference between an honest coverage number and a bad one.
2. **Close the two single-engine section rows.** `docs/COVERAGE-MATRIX.md` §3 now names them:
   **§4.7** connection teardown is Apalache-only, **§6.9** bootstrap handler safety is
   TLC-only. Each is one file away from a transcription error no cross-check would see.
   Cheap: a `Conn` TLC/Spin teardown property, and a `Register` Apalache port for §6.9.
3. **Narrow the two weak controls.** `DeepChainBug`/`DeepChainNBug` falsify their lemma in a
   variant whose honest path is unreachable at 2 steps. The injected defect should break the
   *property*, not the model.
4. **The Lean seam is asserted, not checked — and it is the biggest thing a reviewer would
   name.** `docs/ASSURANCE-MAP.md` row 1 says Lean owns the authority-logic interior and that
   TLA+/Tamarin "abstract it away". Nowhere is it written **what the models assume about that
   abstraction**, so nothing checks that Lean proves the same proposition. There are at least
   nine concrete correspondences — e.g. `Revoke.InvDet` (§5.10 verdict determinism) against
   Lean's `verifyChain_time_stable` / `verifyChain_time_independent`; `Authority.NoGrantlessAllow`
   against `checkPermission_no_grants_deny`; `Register.NoUserAtSystem` against
   `grantPattern_namespace_isolation`; Tamarin `Multisig`/`MultisigKN` against
   `multiSigRootOk_quorum`; `Bounds` §4.10(b) against `chainExceedsDepth_iff`; Tamarin
   `NoEscalation` against `isAttenuated_trans` + `matchesScope_excl_override`
   (`entity-core-keystone/protocol-generator/lean/proofs/EntityCoreProofs/CapabilityProofs.lean`).
   Two levels, in order of cost:
   - **An assumption ledger** — one row per abstract predicate / function symbol, stating the
     property the model relies on and citing either the discharging Lean theorem
     `(name, path, commit)`, the spec clause that asserts it, or **"unclosed"**. Turns
     complementarity from prose into a checkable artifact. This is the D11 inventory boundary
     applied to the *seam* rather than to each tool separately.
   - **Differential trace checking** — replay TLC/Apalache counterexample traces (Apalache
     emits `.itf.json`) through the Lean executable model or a reference peer, asserting the
     abstract predicate's value matches the reference verdict. The strongest achievable link
     short of an embedding, and the only thing on this list that puts a *machine check* on the
     Lean-facing half of the 5th wall.
5. **The bound nobody has attacked: `Peers = {A,B}` is fixed in every model** — TLC, Spin and
   Apalache alike. Apalache's results are unbounded in *steps*, never in *peers*, and this is
   the first question a reviewer asks of a multi-peer protocol. Parameterized verification is
   the named technique: **Ivy** (decidable EPR fragment — proves for all N given an inductive
   invariant), `mypyvy`, or TLAPS. Revocation propagation and cross-peer chain topology are
   the properties where N > 2 could plausibly matter.
6. **Liveness is bounded everywhere and cannot be lifted by the current toolchain.** Apalache
   does safety/induction by construction. **TLAPS** machine-checks liveness proofs (fairness,
   well-founded ordering); deadlock-freedom for `Core` proved rather than model-checked would
   be the headline result this repo does not yet have.
7. **Other techniques not yet used.** A **refinement proof** that the composed `Core` model
   actually refines the individual modules (the standard TLA+ move; today they are checked
   separately and the composition is asserted, not proved). Alloy for `Register`'s
   index↔tree-walk coherence. CryptoVerif for computational-model results. §6.11(c)
   per-request deadlines, which are what would make Class-G a liveness bug rather than a
   crash.
8. **Widen the TLA+ bounds** — 3-peer / churned-store, and sequenced-write `Register` to
   retire the last near-tautological positive.
9. **Nothing checks a number in prose.** Every count drift found by the last two audits — a
   stale invariant total in a Makefile comment, three different run counts across three files,
   a wrong section denominator in the pin's own manifest — was found by grep, by hand.
   `make matrix` cannot fail because a README says 156. Matrix A is already *derived* from the
   models' own `§`-citations; the run counts and invariant totals should be derived the same
   way and checked in the gate.
10. **Tie models to conformance vectors.** Only the Class-G deadlock is currently grounded
    against a reference impl; where a sibling conformance vector exists for a modeled
    property, cite it to turn "spec says" into "spec says *and* a passing test exercises it."
    Overlaps item 4's second level — a conformance vector and a replayed counterexample are
    the same move from opposite ends.
11. **Phase 3 extension-protocol attacker models** stay gated on vendoring `EXTENSION-*`,
    which is still not in `spec-data/`. Note that §5.8's registry rows and §5.9's continuation
    depth brake are now modeled at the *core* level, so the gate is narrower than it was.
12. **Vacuity, the last of it.** `Register`'s correct-model atomicity is still
    near-tautological — teeth on the control side only — and sequenced-write `Register` is
    what would retire it. This is the one thin positive left standing; see item 8 and
    `docs/PROPERTIES.md` §C.4.
