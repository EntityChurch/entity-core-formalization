# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**This version number is the repository's, not the protocol's.** Which spec version the
models verify is a property of the SHA pin in `spec-data/` — see `spec-data/*/MANIFEST.md`,
the single authoritative statement. The two happened to coincide at 0.8.0 and have since
diverged, which is why they are stated separately.

## [0.8.1] — 2026-08-27

Documentation and honesty release. No model, spec or toolchain changes; the green matrix
is unchanged and re-verified against the same pin.

### Added

- **A stale-pin disclosure across the live assurance surface.** The models are pinned at
  Entity Core Protocol **0.8.0**; the protocol has advanced to **0.8.2**. Measured
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

  What is real: new normative surface no model covers — §6.11 frame-write atomicity, §4.8
  an unsynchronized refcount decrement named as a use-after-free, §5.6 malformed temporal
  ingest — plus the fact that a two-revision-old pin cannot speak to the current spec
  regardless.

- **A named limit on the dispatch-gate abstraction.** Spec §5.2 at 0.8.2 makes the
  dispatch authority three-valued (SELF / GRANT / ABSENT-must-deny). `tla/Reentry.tla`
  abstracts the verdict to a constant, so the denial case is inexpressible there.
  Recorded rather than quietly carried — and scoped honestly: the underlying
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
  is a deliberately separate fact from which snapshots have been vendored. It reads
  `v0.8.0` and does **not** move on a file copy; it moves only once the models have been
  re-validated, as the last step of that work. Without the split, vendoring would silently
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

[0.8.1]: https://github.com/EntityChurch/entity-core-formalization/releases/tag/v0.8.1
[0.8.0]: https://github.com/EntityChurch/entity-core-formalization/releases/tag/v0.8.0
