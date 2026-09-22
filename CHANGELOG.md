# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**This repository versions alongside the Entity Core Protocol it tracks.** `0.8.2` here
accompanies protocol `0.8.2`, so the two line up when read side by side.

Which spec text the models actually transcribe — and therefore what every result in this
repository is a statement *about* — is named by `spec-data/MODELING-PIN`, which reads
**`v0.8.2`**. As of this release the two coincide: the models transcribe the same 0.8.2 text
the version number names, and `make specdrift` reports **no drift** against the live spec.
That has not always been true and the distinction is kept deliberately visible — the pin
moves only as the last step of re-validating the models, never on a file copy.

## [0.8.2] — 2026-08-28

**The models now verify protocol 0.8.2.** `spec-data/MODELING-PIN` moved from `v0.8.0` to
`v0.8.2` as the last step of re-validating every model against the new snapshot and modeling
the normative surface 0.8.1/0.8.2 added. `make specdrift` reports no drift against the live
spec. The full matrix is **156 runs** — green, negative controls, and, new here, non-vacuity
witnesses — and `make matrix` is the gate.

### Added — 0.8.2 normative surface, modeled

Five pieces of new normative surface, each with a §-citation, a negative control that
reproduces the *named* defect, and cross-engine corroboration where the surface allows.

- **§6.11 (a′) frame-write atomicity** (0.8.1 RT-13b) in `tla/Reentry.tla` and
  independently re-encoded in `spin/reentry.pml`. (a) forbids holding the connection lock
  across send+recv and (a′) requires holding it for one frame's bytes, so the interesting
  claim is the spec's own: that they are **jointly satisfiable** by a lock whose hold
  duration is exactly one frame. The green config asserts both at once; `ReentryFrameBug`
  (interleaved frames, **no** deadlock) and `ReentryBug` (Class-G deadlock, **no**
  interleaving) each break exactly one, which is why the two clauses are separate.

- **§4.8 refcount use-after-free** (0.8.1 RT-13a) in `tla/Store.tla`,
  `tla/StoreApalache.tla` and `spin/store.pml`. `NoUseAfterFree` is proven **inductive
  (unbounded)** by Apalache — the 9th such invariant. The control (`SyncRefs = FALSE`,
  a split read-modify-write) reproduces the defect the §7b concurrency gate observed on two
  generated peers: TLC's counterexample is a **stale decrement racing a fresh acquire**,
  freeing a shared entity under a live referrer.

- **§5.6 CAP-6a malformed temporal ingest** in the new `tamarin/Malformed.pv` and
  `Malformed.spthy`, in prover lockstep. Kept as a separate theory from `Expiry`, whose
  green result is about a *well-formed* token: the attacker's lever here is not "my cap
  expired" but "my cap's expiry cannot be read, so read it as nothing." The control shows
  the fail-open grants an immortal capability **while the §5.5 temporal lemma still passes**
  — the defect is invisible to every property the v0.8.0 models checked.

- **§5.2 dispatch authority** in the new `tla/Authority.tla`. §5.2's three-valued rule is a
  claim that *no* two-valued encoding is correct, so it is checked as such: `option-allow`
  satisfies entry dispatch and authorizes every grantless sub-dispatch; `option-deny`
  refuses the grantless sub-dispatch and breaks entry dispatch; each was run separately to
  confirm it holds the property the other breaks. Only the three-valued encoding satisfies
  both. Also models "the condition is the field, not the door" and the no-resource-
  inheritance rule. **This retires the known thin positive** that `tla/Reentry.tla`'s
  `Gate(p) == TRUE` made denial inexpressible — denial is now a reachable outcome and the
  gate is load-bearing.

- **§5.9 / §4.10(b) bounds** in the new `tla/Bounds.tla`: TTL and continuation
  `chain_depth` as distinct magnitudes, TTL decremented once per dispatch, and the two
  brakes' reason strings kept distinct. Controls reproduce the "9-vs-64" equal-magnitudes
  divergence, the double-count, and the shared reason string.

- **§5.10 revocation-propagation bound** (0.8.1 W7 Knob 2) in `tla/Revoke.tla`, on a
  propagation clock deliberately separate from the per-verdict evaluation timestamp `t`.
  `BoundHonored` and `ExposureBounded` make "the exposure window is a reason-about-able
  quantity" checkable; the control shows it is unbounded without a declared bound.

- **§5.8 conformance topology** in the new `tamarin/ChainTopology.pv` / `.spthy` — a
  verifier that constructed **no link** in the chain, with root, granter, grantee and
  verifier as four distinct peers.

### Added — non-vacuity witnesses (TLA+)

- **Nine witness configs, one per TLC module**, plus `make -C tla tlc-witness` and a
  `matrix` target that runs green + controls + witnesses together. The TLA+ track
  previously had **no** non-vacuity assertions, unlike ProVerif's reachability queries, so
  a trivially-inert model would have reported the same green as a working one. Each witness
  is an invariant asserted in order to be **violated**; a clean run is the failure.
  `make check` now says out loud that green alone does not answer "could it have failed?"
  or "does the model do anything?".

### Fixed — vacuous and mis-stated proof obligations

- **`Store`'s store-cardinality conjunct was vacuous and is not any more.** The model held
  a single key while asserting a bound of 2, so `Cardinality(store) ≤ MaxStore` could not
  fail — the Apalache port made it explicit as `store ⊆ {"k"}`. Disclosed since Phase 1 and
  never fixed. The store is now multi-key (3 keys against a bound of 2) and what discharges
  the bound is refcount correctness, which is the composition §4.8 actually asserts.

- **A Tamarin lemma that asserted less than it appeared to.** `ChainTopology.spthy`'s
  verifier-namespace lemma quantified over a `pkW` never bound to the verifier. ProVerif and
  Tamarin disagreed on the negative control, and the disagreement was the signal. Recorded
  in `docs/PROPERTIES.md` §C.1 because it is the exact failure mode the two-prover lockstep
  exists to catch, and it caught it on the modeller rather than the protocol.

### Changed

- **`make matrix` is the honest gate**, not `make check`. Three questions, not one: do the
  properties hold, could they have failed, and does the model reach an interesting state.
- **`Core.tla` declares what it does not carry.** §6.11(a′), §4.8's refcount and §5.2's
  authority are owned by the dedicated modules; the composed model states that in its
  header rather than leaving the omission silent.
- **`Store` splits safety and liveness across two configs** (`NReq = 4` / `NReq = 3`):
  TLC's liveness graph exhausts the 2 GB cap at the safety bound. Both cfg headers say so,
  including which claim is *not* earned in the smaller config.

### Findings routed to `entity-core-protocol`

- **§5.9's recommended 8× TTL/`chain_depth` ratio has zero margin at worst-case fan-out.**
  The property needs `ceiling × worst_case_fanout` **strictly less than** the seed; at exact
  equality the backstop fires on the step the deterministic brake would have. §5.9 puts the
  choice on the deployment, so this is a boundary worth stating, not a defect in the default.
- **§5.8's topology rule bears on this repo's own prior results.** `DeepChain`/`DeepChainN`
  seat the verifier as the root issuer — the same-peer topology §5.8 says cannot witness a
  cross-peer seam. They remain sound for the §5.5a property they claim; the new control
  shows a root-frame defect leaves their lemma **true** while falsifying the one only a
  third-party verifier can state.

### Added — spec-drift tooling and disclosure (as shipped earlier in this cycle)

- **A stale-pin disclosure across the live assurance surface.** *(Shipped earlier in this
  cycle, when the models were still pinned at 0.8.0. Retained as the record of how the drift
  was measured — the measurement is what scoped the modeling work above, and the disclosure
  it drove is now discharged rather than merely reworded.)* Measured
  2026-08-27 against protocol's published `master`, **13 of the 26 spec sections the
  models cite have moved**. The measurement is derived from the `§`-citations the models
  themselves carry, not from a prose summary, and it is reproducible: `make specdrift`.
  `docs/SPEC-DRIFT-ASSESSMENT.md` is the new canonical home for the method, the
  per-section table, the tool's negative controls and its stated limits; `README.md`,
  `docs/STATUS.md`, `docs/PROPERTIES.md`, `docs/ASSURANCE-MAP.md` and
  `docs/FINAL-ASSURANCE-SUMMARY.md` state the pin and point there.

  The drift is even across all three tracks (52% / 59% / 54% of each track's cited
  sections). What is stable is depth: §5.5 chain verification (33 model files), §7.3
  signatures (22), §5.4 and §6.8 did not move, so the unforgeability and confused-deputy
  foundations are unmoved.

  **The section count overstates the change and the assessment says so.** Across the 13
  moved sections only 16 lines of pre-existing text changed, against 105 added — 0% for
  §5.2, §5.10 and §6.11, which are pure additions. Most of the 16 are status-code
  discrimination or appended clarification; exactly two are genuine semantic changes
  (§3.6 `F40`, §6.1 `CAP-1`) and neither intersects anything the models encode. **No
  property this repository proved has been contradicted by 0.8.0 → 0.8.2.** 0.8.1/0.8.2
  are largely conformance findings being written down as clarification.

  What was real: new normative surface no model covered — §6.11 frame-write atomicity, §4.8
  an unsynchronized refcount decrement named as a use-after-free, §5.6 malformed temporal
  ingest — plus the fact that a two-revision-old pin cannot speak to the current spec
  regardless. All of it is modeled above, which is what let the pin move.

- **A named limit on the dispatch-gate abstraction — since resolved by `tla/Authority.tla`
  above.** Spec §5.2 at 0.8.2 makes the dispatch authority three-valued (SELF / GRANT /
  ABSENT-must-deny). `tla/Reentry.tla` abstracts the verdict to a constant, so the denial
  case is inexpressible there. Recorded rather than quietly carried — and scoped honestly: the underlying
  confused-deputy property lives in §6.8, which did **not** move and is modeled by 8
  files, so this raises the value of a pre-existing backlog item rather than exposing a
  gap 0.8.2 created.

- **`make specdrift` / `make specdrift-gate`** (`tools/spec-drift.py`) — the pin-vs-live
  measurement as a command instead of a claim in a document. Host `python3` only, no
  toolchain and no image. Controlled the way every model here is: it reports clean on a
  pin compared with itself, and catches a single 12-character edit injected into §6.11
  with no false positives on the other 25 cited sections.

### Added — the 0.8.2 snapshot, vendored

- **`spec-data/v0.8.2/`** — the three normative specs copied byte-for-byte from
  `entity-core-protocol`'s published `master`, each hash-verified against its source blob
  before acceptance. `v0.8.0/` stays in place as a point-in-time pin; a snapshot is never
  edited once written.

- **`spec-data/MODELING-PIN`** — names the snapshot the models actually transcribe, which
  is a deliberately separate fact from which snapshots have been vendored. It did **not**
  move when `v0.8.2/` was vendored; it moved later in this same cycle, as the last step of
  re-validating the models, which is the discipline the file exists to enforce. Without the split, vendoring would silently
  convert "we vendored the new spec" into "we verified the new spec" — two claims that
  differ by roughly the entire cost of the project. `make specdrift` reads it, so the drift
  report keeps its teeth after vendoring rather than falsely clearing.

- **Citation structure re-validated against the new snapshot:** no section added, removed
  or renumbered, every inline sub-label intact, and **0 of 35 model `§`-citations broken**.
  The one structural addition is §6.11 (a′). The new text is a clean modeling target.

### Fixed

- **Leaked tool-call markup removed from two published documents.** `</content>` at the
  end of `docs/FINAL-ASSURANCE-SUMMARY.md`, and `</content>` / `</invoke>` at the end of
  the rolling status log. Both were live on public `master`.

- **References to a repository that no longer exists.** `entity-core-architecture` was
  superseded by `entity-core-protocol` and `entity-system-architecture` and is not public.
  The six live-surface references — `README.md`, `AGENTS.md` (×2), `docs/PROPERTIES.md`,
  `docs/FINAL-ASSURANCE-SUMMARY.md` and the manifest intro — now name
  `entity-core-protocol`, which publishes the three specs vendored in `spec-data/v0.8.0/`
  and whose `docs/proposals/` is where a design finding actually lands. Four further
  references inside ratified phase reports are left as written: those reports are
  historical record and were accurate about the repository layout at the time they closed.

- **Protocol version numbers no longer restated in prose.** `README.md` and the manifest
  intro deferred to the pin instead of carrying their own copy, which had already drifted
  (the manifest intro still said "v7"). In-model `§`-citations are untouched and remain
  correct: section numbering is unchanged from the V7 line through 0.8.2, verified
  section-by-section.

### Changed

- **The re-vendor ownership rule in `AGENTS.md` is corrected.** It said *"the architecture
  repo re-vendors when the spec moves"* — naming `entity-core-architecture`, which no longer
  exists. There was no external owner to wait on, and treating a defunct repo as a blocker
  had left the pin two revisions stale. The rule now distinguishes the two things it had
  conflated: an existing snapshot is frozen and never edited in place, but **adding** a new
  snapshot is this repo's own mechanical, hash-verifiable work.

- **The rolling status log moved to `docs/STATUS.md`** ([ADR-0031]), leaving `docs/status/`
  for dated snapshots so the two kinds separate by path rather than by filename.
  `.release-removals` records the move against the published tree using the exact path.

- **The published document set is now declared in full.** `CANONICAL-DOCS.toml` declared
  only `README.md` at the repository root, so a release would have withdrawn `AGENTS.md`,
  `AGENTS-STANDARD.md`, `CHANGELOG.md`, `CLAUDE.md`, `CODE_OF_CONDUCT.md`,
  `CONTRIBUTING.md` and `SECURITY.md` from the public tree. All eight universal root
  documents are declared, `METHODOLOGY.md` among them for the first time.

## [0.8.0] — 2026-06-21

- Initial public research-preview release.

[0.8.2]: https://github.com/EntityChurch/entity-core-formalization/releases/tag/v0.8.2
[0.8.0]: https://github.com/EntityChurch/entity-core-formalization/releases/tag/v0.8.0
