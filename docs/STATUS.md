# entity-core-formalization — status

_Updated: 2026-08-27 · public: v0.8.0 (master)_

> **The pin has gone stale — read this before taking any result as current.**
> Every model in this repo is written against the SHA-pinned snapshot in
> `spec-data/v0.8.0/`, which is the Entity Core Protocol at spec version **0.8.0**.
> The protocol has since advanced to **0.8.2**, and **13 of the 26 spec sections the
> models cite have changed** (`docs/SPEC-DRIFT-ASSESSMENT.md`; `make specdrift`). The results below are
> reproducible and remain true **of the 0.8.0 design**; they are *not* a current
> statement about the protocol as it stands today. Re-vendoring `spec-data/` and
> re-validating the affected §-citations is now the first substantive work, not an
> optional leftover.

## Where it is

The **formal design-assurance layer** of the Entity Core Protocol. It machine-checks
*models of the v0.8.0 (V8) protocol design* on the two layers the Lean authority proof
(in the keystone peer) structurally cannot reach:

- **Distributed correctness + liveness under concurrency** — TLA+/TLC, with **Apalache**
  (SMT/Z3) lifting key safety invariants to *unbounded* inductive proofs and **Spin**
  (Promela) as an independent re-encoding cross-check.
- **Active-attacker protocol security** — **Tamarin / ProVerif** over the Dolev-Yao
  symbolic model (capability unforgeability, no escalation, no replay/reflection/
  confused-deputy).

It is additive assurance and a research **demonstrator**, deliberately **off the release
critical path**: it verifies the *design*, not any implementation, never edits the spec,
and routes any model-surfaced design finding to the sibling architecture repo as a
proposal/review note. Every model cites the V7 § it transcribes and every secure result
has a negative control that reproduces a *named, real* bug class.

Maturity: **complete and paused clean** at a tagged public release (`v0.8.0`). A bare host
with **only `make` + `podman`** runs everything — all five toolchains (`entity-tla`,
`entity-apalache`, `entity-spin`, `entity-proverif`, `entity-tamarin`) are containerized,
each under a hard memory cap so a runaway check is OOM-killed cleanly instead of thrashing
the host. `make build` → `make smoke` → `make check` (the green-matrix gate) → `make clean`.

## Where we left off

The verification work is fully landed and captured in the capstone
(`docs/FINAL-ASSURANCE-SUMMARY.md`) and the honesty scorecard (`docs/PROPERTIES.md`).
What is proved, at demonstrator altitude against the SHA-pinned `spec-data/v0.8.0/`:

- **TLA+ track.** All 6 Core-Protocol concurrency modules (reentry, conn, store, revoke,
  emit, register) plus a composed 2-peer `Core` model — safety **and** liveness. Apalache
  proves **8 key safety invariants across 5 modules** *inductive (unbounded)*; liveness
  stays bounded-exhaustive in TLC + Spin by nature.
- **Cross-check.** Spin **independently re-encodes all 6 modules** from the spec
  (reproducing the marquee Class-G reentry deadlock); both Spin and Apalache agree with
  TLC on every green result and every negative control (`docs/CROSSCHECK-RESULTS.md`).
- **Prover track.** Tamarin + ProVerif close **12 lemmas in lockstep** (unforgeability,
  no-escalation, binding/no-replay, caveats, depth-bound, deep-chain frame integrity,
  expiry, K-of-N multisig, revocation, persistent re-check); ProVerif additionally proves
  `BindingReplay`.
- **Re-verification.** The full **76-run model matrix** was re-run from the pinned images
  and each result graded against its expected verdict (25 TLC + 26 ProVerif + 25 Tamarin),
  plus **50 cross-check runs** (28 Spin + 22 Apalache). All behave exactly as designed.

The models and their results are stable at the v0.8.0 research-preview line; no model
changes are in flight. **The condition that kept the verification surface paused has now
been met** — the spec advanced to 0.8.2 while this repo was paused (see *Waiting on*), so
the re-vendor-and-re-check cycle, not the Phase 3 extension models, is the next
substantive work.

## Backlog

Optional verification leftovers only — **none gate anything**, all stay off the release
critical path and route findings to architecture, never spec edits. Ranked by value:

1. **Apalache `Core` conjunction (deferred, lowest value).** The composed whole-protocol
   inductive invariant — all modules' invariants at once. The Class-G deadlock it would
   corroborate is already reproduced by Spin and each invariant is already proven
   separately, so it is the one consciously-deferred cross-check item.
2. **Phase 3 — extension-protocol attacker models (hard-gated on vendoring).** Phase 2
   modeled only the §6.8 core re-check property that governs async flows; the protocols
   themselves (continuation dispatch, INSTALL/installation-grant chains incl. the §5.8
   three-slot transferred-closure confused deputy, subscription notification flows) are
   **not in `spec-data/`**. Architecture must vendor them SHA-pinned first — modeling from
   changelog mentions would violate the model-against-vendored-spec discipline.
3. **Widen the TLA+ bounds + harden the two thin positives.** Named in
   `tla/PHASE1-FORMALIZATION-REPORT.md`: 3-peer / churned-store bounds to exercise resource
   leak + recovery at scale; multi-key `Store` (retire the vacuous store-cardinality
   conjunct) and sequenced-write `Register` (retire the near-tautological atomicity);
   model gate *denials* so the dispatch gate is load-bearing; add per-request deadlines
   (§6.11(c)), the time-domain backstop that makes Class-G a liveness bug, not a crash.
4. **Tie models to conformance vectors.** Only the Class-G deadlock is currently grounded
   against a reference impl; where a sibling conformance vector exists for a modeled
   property, cite it to turn "spec says" into "spec says *and* a passing test exercises it."
5. **Optional native relational treatment (Alloy) of `Register`'s index↔tree-walk
   coherence.** Spin already corroborates this via the cache bi-implication; Alloy would
   model the relation directly. Not prepped (no image).

## Waiting on

- **The spec advanced; `spec-data/` must be re-vendored.** This is no longer "nothing
  blocking." Measured 2026-08-27 against `entity-core-protocol` `master` (published;
  byte-identical to their `dev`): all three vendored files differ from the pin, and
  `ENTITY-CORE-PROTOCOL.md` has moved from spec version **0.8.0 to 0.8.2** — 197 changed
  lines, 25 of 93 numbered sections.

  **Of the 26 core-protocol sections the models actually cite, 13 have moved.** The full
  per-section table, the method, its negative controls and its limits are in
  **`docs/SPEC-DRIFT-ASSESSMENT.md`** — one canonical home, not restated here. Reproduce
  any of it with `make specdrift`.

  The headline for a returning reader: the drift is **even across all three tracks**
  (52% / 59% / 54% of each track's cited sections). What is stable is *depth* — the two
  most-depended-on sections in the repo, §5.5 chain verification (33 model files) and §7.3
  signatures (22), did not move, nor did §5.4 or §6.8. So the foundations the
  unforgeability and confused-deputy results rest on are unmoved.

  **And the section count badly overstates it.** Across all 13 moved sections, only **16
  lines of pre-existing text** changed against **105 lines added** — 0–10% of any section,
  1–4% for most, and 0% for §5.2, §5.10 and §6.11, which are pure additions. Of those 16
  lines, most are status-code discrimination (a blanket 403 split into 401-auth vs
  403-authz — rejected either way, and the models model accept/reject, not status codes) or
  appended clarification. Exactly two are genuine semantic changes (§3.6 `F40` id-scope
  literal matching, §6.1 `CAP-1` empty grants) and **neither intersects anything the models
  encode** — checked, not assumed. **No property this repo proved has been contradicted.**

  The real finding is narrower: there is genuinely new normative surface no model covers —
  §6.11 frame-write atomicity (the spike-A target), §4.8 the unsynchronized-refcount
  use-after-free, §5.6 malformed temporal-field ingest. New territory to model, not
  contradictions of old results.

- **One change questions a modeling choice rather than a modeled fact.** §5.2 at 0.8.2
  requires the dispatch authority to be three-valued — SELF, GRANT, and an ABSENT case
  that MUST deny — and says collapsing it to a two-valued optional has no correct default.
  `tla/Reentry.tla` abstracts the verdict to a constant (`Gate(p) == TRUE`), so the denial
  case is inexpressible there and `NoDispatchWithoutGate` cannot fail.

  Stated carefully, because an earlier draft of this entry overstated it: 0.8.2 does
  **not** invalidate the result and does not name our abstraction as a defect. That rule
  addresses implementations representing an authority value; the model declares the
  verdict out of scope and Lean-owned. The underlying security property — gate on the
  handler grant, never on the propagated caller capability — is **§6.8, which did not
  move**, is cited by 8 model files, and is what 0.8.2's new §5.2 text defers to.
  `tla/Core.tla` does model denying gates. What survives is narrower and still worth
  acting on: the backlog item *"model gate denials so the dispatch gate is load-bearing"*
  is pre-existing, and 0.8.2 raises its value by giving the denial case an explicit
  normative rule with a named ALLOW-bug lineage.

- Re-vendoring is owned by the sibling spec repo (`entity-core-protocol`); this repo does
  not edit `spec-data/`. The re-check discipline once it lands is already written down
  under **Next**.
- The deepest open assumption is the **5th wall — spec↔model fidelity**: every result is a
  property of a *model*. The two-paradigm agreement (Spin independent encoding + Apalache
  unbounded matching TLC; ProVerif + Tamarin lockstep) **narrows** it but cannot close it —
  the engines could share a misreading. **Human review of the models against
  `spec-data/v0.8.0/` owns it** (`docs/PROPERTIES.md` §C, `docs/ASSURANCE-MAP.md`).

## Done recently

- **v0.8.0 public research-preview release tagged** (`master @ 0a04dca`). De-versioned V8
  cutover of the V7 line the proofs were built on — **wire-byte-identical**, so the proofs
  carry forward unchanged; `spec-data/` migrated to the v0.8.0 snapshot.
- **Release prep** built the `make` + `podman` door from scratch (this was the one repo
  with no prior Makefile): the green sweep lives as a `green` target beside each engine's
  specs so the parameters version with the models; resource caps in `caps.mk` were **sized
  from measurement** (`CAP_MEM=2g`, zero swap — covers the heaviest build, the ProVerif
  opam compile at ~0.92 GB, with headroom and a clean OOM kill for a runaway JVM/Z3/Haskell
  heap) and the full green matrix was re-run under that cap; and `docs/PROPERTIES.md` was
  written as the PROVEN-vs-MODELED honesty scorecard.
- **Verification arc completed earlier:** Phase 0 two go/no-go spikes (TLA+ on the §6.11
  reentry slice, ProVerif+Tamarin on capability unforgeability — both GO); Phase 1 (TLA+
  all-Core concurrency + the first 5 prover lemmas); Phase 2 (prover surface-closure, 7
  more lemmas + 1 documented non-closure); then the Spin + Apalache cross-check across
  every modeled subsystem and the full-matrix close-out re-verification.

### Known, documented non-issues (not bugs)

- **`RevokeMech` (Tamarin) does not terminate** — mechanistic linear-token revocation
  loops Tamarin's backward search on a regenerated `Valid` fact. It stays ProVerif's lane;
  Tamarin uses a terminating trace-restriction idiom. An irreducible tool-capability
  finding, **excluded from `make check`** — run it standalone with a kill switch.
- Concurrent toolchain runs can hit a transient SELinux `:Z` bind-mount relabel race
  ("file not found"); run the three engines **serially**. Reclaim a hung container with
  `podman kill` (a `timeout`-wrapped `podman run` only kills the client).

## Next

1. **Re-vendor `spec-data/` to spec 0.8.2.** Owned by `entity-core-protocol`; this repo
   does not author the snapshot. Until it lands, every result here is explicitly a
   statement about the 0.8.0 design.
2. **Then run the re-check cycle already written down here:** rebuild the engine images,
   re-run `make check` to confirm the green baseline still reproduces, then diff
   `spec-data/` and re-validate the affected §-citations **before** extending — keeping the
   lockstep + negative-control + §-citation discipline on every new increment. The eight
   moved sections in *Waiting on* are the work-list; §6.11, §4.8 and §5.9/§4.10 carry new
   normative MUSTs that the current models do not encode at all.
3. **Re-check the §5.2 three-valued-authority rule against the abstraction**, ahead of the
   rest. It is the one change that questions a modeling choice rather than a modeled fact,
   and it promotes the backlog's "model gate denials" item out of optional.
4. **Phase 3 extension-protocol attacker models** stay gated on vendoring `EXTENSION-*`,
   behind the re-vendor above.
