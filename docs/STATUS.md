# entity-core-formalization — status

_Updated: 2026-08-28 · this line: 0.8.2_

> **The models track the live spec.** Every model in this repo is written against the
> SHA-pinned snapshot in `spec-data/v0.8.2/`, which is the Entity Core Protocol at spec
> version **0.8.2** — the current published line, and what peers are building to.
> `make specdrift` reports **no drift**: the pin matches the live spec byte-for-byte across
> all three normative files. The results below are a statement about the protocol as it
> stands today.

## Where it is

The **formal design-assurance layer** of the Entity Core Protocol. It machine-checks
*models of the v0.8.2 (V8) protocol design* on the two layers the Lean authority proof
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
  proves **9 key safety invariants across 5 modules** *inductive (unbounded)*; liveness
  stays bounded-exhaustive in TLC + Spin by nature.
- **Cross-check.** Spin **independently re-encodes 6 modules** from the spec (reproducing
  the marquee Class-G reentry deadlock); both Spin and Apalache agree with TLC on every
  green result and every negative control (`docs/CROSSCHECK-RESULTS.md`).
- **Prover track.** Tamarin + ProVerif close **14 lemmas in lockstep** (unforgeability,
  no-escalation, binding/no-replay, caveats, depth-bound, deep-chain frame integrity,
  expiry, malformed-temporal ingest, third-party chain topology, K-of-N multisig,
  revocation, persistent re-check); ProVerif additionally proves `BindingReplay`.
- **The full matrix is 156 runs** and `make matrix` is the gate: **green** (does every
  property hold?) + **negative controls** (could it have failed?) + **witnesses** (does the
  model do anything?). Green alone answers only the first question, which is why `make
  check` now says so out loud.

| slice | runs |
|---|---|
| TLC green (9 modules + Store liveness slice) | 10 |
| TLC negative controls | 29 |
| TLC non-vacuity witnesses | 9 |
| Apalache inductive (9 invariants × base+step) | 18 |
| Apalache negative controls | 3 |
| Spin green (6 modules × safety+LTL) | 12 |
| Spin negative controls | 17 |
| ProVerif (15 green + 15 controls) | 30 |
| Tamarin (14 green + 14 controls) | 28 |
| **total** | **156** |

### What 0.8.2 added, and where it now lives

0.8.1/0.8.2 were largely conformance findings written down as normative clarification. The
structure was completely stable — no section added, removed or renumbered, and all 35 model
`§`-citations still resolved — so the work was **new territory to model**, not contradicted
results. Five pieces of new normative surface, each with a negative control that reproduces
the named defect:

| § | requirement | now modeled in |
|---|---|---|
| **§6.11 (a′)** | frame-write atomicity (0.8.1 RT-13b) — two frames' bytes MUST NOT interleave on a pooled connection | `Reentry.tla` + `reentry.pml` |
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

### Two thin positives addressed, and one still open

- **Retired.** `Store`'s store-cardinality conjunct was **vacuous** — a single key against a
  bound of 2, so it could not fail (disclosed in `PROPERTIES.md` since Phase 1, never
  fixed). The store is now multi-key, the bound is falsifiable, and what discharges it is
  refcount correctness — the composition §4.8 actually asserts.
- **Retired.** The TLA+ track had **no non-vacuity assertions at all**, unlike ProVerif's
  reachability queries: a trivially-inert model would have reported the same green as a
  working one. Every TLC module now has a witness config that must be violated, and
  `make -C tla tlc-witness` fails loudly if a witnessed state becomes unreachable.
- **Still open.** `Register`'s correct-model atomicity remains near-tautological; it has
  teeth on the control side only. Sequenced-write `Register` is still backlog.

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
   **28 of the 93 numbered sections** of the core spec. By area that is roughly two-thirds
   of §4 (connection, dispatch, resilience), §5 (capability and verdict) and §6 (handlers and
   lifecycle) — the three surfaces this repo owns. Near-zero coverage of §2, §3, §7, §8 and
   §9 is deliberate scope: registries, encoding, trusted crypto and the conformance profiles
   belong to other layers of the assurance map. The remaining third of §4/§5/§6 is the real
   backlog.
2. **Techniques not yet used.** A **refinement proof** that the composed `Core` model
   actually refines the individual modules (the standard TLA+ move; today they are checked
   separately and the composition is asserted, not proved). Alloy for `Register`'s
   index↔tree-walk coherence. CryptoVerif for computational-model results. §6.11(c)
   per-request deadlines, which are what would make Class-G a liveness bug rather than a
   crash.
3. **Widen the TLA+ bounds** — 3-peer / churned-store, and sequenced-write `Register` to
   retire the last near-tautological positive.
4. **Tie models to conformance vectors.** Only the Class-G deadlock is currently grounded
   against a reference impl; where a sibling conformance vector exists for a modeled
   property, cite it to turn "spec says" into "spec says *and* a passing test exercises it."
5. **Phase 3 extension-protocol attacker models** stay gated on vendoring `EXTENSION-*`,
   which is still not in `spec-data/`. Note that §5.8's registry rows and §5.9's continuation
   depth brake are now modeled at the *core* level, so the gate is narrower than it was.
6. **Apalache `Core` conjunction** — the composed whole-protocol inductive invariant. Still
   the one consciously-deferred cross-check item (lowest value; Spin already corroborates the
   deadlock and each invariant is proven separately).
