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

## [Unreleased]

### Fixed — two sections the coverage grid said were verified, and nothing modeled

`docs/COVERAGE-MATRIX.md` listed **§4.7** and **§6.9** as real single-tool results. Neither
was a result. Matrix A is *derived* from the models' own `§`-citations precisely so the
number cannot be one someone chose — but the extractor counts **mentions**, and a mention is
not a claim:

- **§4.7** — the only §4.7 mention in the entire repo was the far end of a section *range* in
  one header comment, written with a sigil on both ends so the endpoint scanned as a
  citation. Five other files write the same range without it. The row read "Apalache-only"
  because of one file's punctuation — and §4.7 is not "connection teardown" as the grid's
  label said, it is the **connection error-code table**.
- **§6.9** — both of its mentions were **disclaimers** in `Register.tla`'s header saying
  bootstrap handlers bypass registration and *are not modeled*. An out-of-scope declaration
  counted as coverage.

Both are now genuinely modeled, on all three TLA+-track engines, in modules of their own:
`ConnCodes` / `ConnCodesApalache` / `conncodes.pml` (§4.7) and `Bootstrap` /
`BootstrapApalache` / `bootstrap.pml` (§6.9), each with its negative controls and a
non-vacuity witness. The published coverage figure was 28 and the true one was 26; it is 28
again now, and checked.

### Added — the first genuine defect this repo has found in the spec text

Modeling §4.7 surfaced a **normative contradiction**. An `authenticate` frame arriving before
any hello nonce has been issued is named explicitly by two clauses that disagree on the
reason code **and** the status class:

- **§4.6 step 1**: "A mismatch — or an `authenticate` received before any hello nonce was
  issued — MUST be rejected with status **401 `invalid_nonce`**."
- **§4.7 table row 10**: "Out-of-order operation (e.g., **authenticate before hello**)" →
  **`connection_sequence_error`**, **400**.

Both are MUSTs, and §4.7's own preamble — "an impl that collapses several of these to one
code, **or returns a different status**, is non-conformant" — makes each reading
non-conformant by the other's lights. The disagreement lands on `result.data.code`, the field
§4.7 exists to fix across implementations, so two conformant peers can hand a client
different instructions for the same failure.

The models check **both** readings rather than picking one: the row assignment for a
pre-hello `authenticate` is a constant, and the §4.7 reading violates §4.6 step 1 transcribed
as an invariant. Exhibited independently by TLC, Apalache and Spin — the only control in the
repo whose "defect" is a conformant reading of the spec. Routed to `entity-core-protocol` as
a proposal, with a suggested resolution; full statement in `docs/PROPERTIES.md` §D.1.

### Added — the assumption ledger, and a gate on it

`docs/LEAN-SEAM.md`. `docs/ASSURANCE-MAP.md` divides labour in prose — the Lean authority
proof owns the authority-logic interior, TLA+ and Tamarin abstract it away — and a division
of labour is sound only if the property each model **assumes** of the abstraction is the
property Lean **proves**. Nothing wrote that correspondence down. The ledger now states it
per abstraction: the proposition relied on, the discharging theorem cited by
`(name, file, sha256)`, any residual hypothesis, and a verdict of CLOSED / CLOSED-MODULO-H /
OPEN / BY-DESIGN — 21 Lean theorems, one explicitly **rejected** correspondence pinned as
such, plus intra-repo rows (a TLA+ model assuming what a prover proves) and rows nothing
owns. `make leanseam` fails when the cited Lean text moves.

Writing it produced two results a spot-check had not:

- **The chain verdict is not peer-independent.** `verifyChain` takes `localPeer` as an
  argument and §5.5a's granter frame threads it through the walk, so `Revoke.tla` holding its
  structural verdict equal at both peers is sound only where the two peers' frames agree — a
  restriction the model does not state.
- **Two engines, one shared undischarged assumption.** §5.5a namespace isolation is "covered"
  by ProVerif/Tamarin *and* by Lean, and **both** rest on the same unproved proposition: that
  canonicalization roots a relative pattern at the granter's namespace. Lean takes it as the
  hypothesis `hframed` and says in the source that it declines to prove it; ProVerif asserts
  it as a rewrite rule. Redundancy counted by *engine* cannot see this — the audit that
  "closed every single-tool coverage gap" was right about engines and blind to it.

A local Lean tree in this repo was considered and rejected: the value of the seam is that
Lean's theorems are about the same executable code the conformance suite runs, and a fork
would make them statements about our copy, which nothing gates.

### Added — `make coverage`, and D15

A discipline with no enforcement point does not count. `tools/coverage-check.py` asserts that
the cited `§N.M` set equals Matrix A's rows **in both directions**, that the stated numerator
and denominator match the models and the pinned spec, and that neither citation-hygiene
tripwire fires. It states in the file what it does *not* assert — the engine columns — rather
than letting a reader assume the whole grid is machine-checked. In `check` and `matrix`; five
failure modes teeth-tested.

It earned its keep immediately: the two new modules written to close §4.7 and §6.9 shipped
three fresh phantoms of exactly the same kind (`§1.2`, `§1.5`, `§2.11`, all inside scope
notes), taking the count 28 → 31 while genuine coverage went 26 → 28. Knowing the rule and
violating it in the same session is the normal case, which is the argument for the gate.

**AGENTS.md D15** — *a derived number is a claim; derive it from claims, and gate it.* D13
asked of a metric rather than a grader.

### Fixed — Spin's negative controls were graded by a criterion a deadlock satisfies

`spin/neg` graded on `errors: [1-9]`. pan reports a positive error count for a caught
assertion, an **invalid end state** (deadlock) and a broken liveness claim alike, so a
control whose model merely *blocks* scored exactly as one that catches its defect. Found
live, not by inspection: `bootstrap.pml`'s registration precondition was first written as a
two-stage guard, which commits to the do-option and then blocks, and two brand-new controls
"passed" without ever reaching their assertions.

Every one of the 35 rows now declares its **pan failure signature**, matched against the
`pan:N:` error line only. All 29 pre-existing rows were audited at the same time (D14):
every one was in fact failing for its stated reason, so the gate was blind rather than
wrong — including the two `-DSERIALIZED` rows that legitimately expect `invalid end state`,
because the Class-G reentry defect *is* a deadlock.

The first draft of this check matched the signature against pan's whole output, where
`invalid end state` appears in the **search-options header of every run** — so those two rows
asserted nothing. Reading the code did not catch it; deliberately breaking a control did.

### Fixed — three negative controls that took their own witness down with them

`DeepChainBug`, `DeepChainNBug` and `ChainTopologyBug` each falsified its target security
lemma **and** its own `exists-trace` non-vacuity lemma, because re-framing the bare-`*` leaf
moved the grantee's namespace out of reach as a side effect. Faithful to the defect, and
still a bad control: falsifying both at once means the run cannot show *which* broke, and
both report the same word.

All three narrowed together (D14 — the class, not the instance). §5.5a gives two pattern
forms and only the peer-relative one has a frame to get wrong: an absolute `/{p}/` + wildcard
canonicalizes to itself in every frame. Each theory now carries an absolute-form leaf
alongside its bare-`*` one — **byte-identical in the green twin and the control**, so each
control still differs from its green by exactly the injected defect — and the honest path
survives it. All three now report their reachability lemma `verified` and falsify their
target alone.

### Changed — the matrix is 238 runs

11 TLA+ modules (was 9), 23 Apalache inductive invariants across all 11 (was 18 across 9),
11 Spin re-encodings, 92 negative controls and 11 non-vacuity witnesses, plus the unchanged
15 ProVerif / 14 Tamarin attacker theories. `make matrix`: exit 0, zero failures.
`make specdrift`: no drift. `make leanseam`, `make coverage`: clean.

### Fixed — the *rest* of the gates now check what they claimed to check

The pass below hardened three of the repo's ten grading targets and closed the finding. A
subsequent audit asked the same question of the other seven and found **62 of the 203 runs**
still graded by a criterion blind to the outcome claimed. Same shape, same session's lesson,
not applied to its own class — which is what earned **AGENTS.md D14**.

- **`proverif-green` had no verdict gate at all** (15 runs). It ran `proverif $t.pv || exit 1`,
  grading on the exit status — while **ProVerif exits 0 even when a query is false**, a fact
  written in the comment on the target directly below it. Confirmed: `UnforgeBug.pv` prints
  `RESULT … is false.` and exits `0`. An attack found against any of the 15 secure theories
  would have been reported as green.
- **`proverif-neg`'s criterion was satisfied by the secure theory** (15 runs). It required "at
  least one `RESULT … is false`" — but ProVerif reports a *reachable* event as a **falsified**
  `not event(…)` query, which is exactly how a passing non-vacuity witness reports, and 13 of
  the 15 secure theories carry one. Secure `Revoke.pv` passes the criterion its own negative
  control was graded by.
- **`apalache-neg` and `tlc-witness` graded on exit status with output discarded** (15 + 9
  runs) — verbatim the `tlc-neg` defect, in the two targets the earlier pass never opened.
  Apalache exits `255` on a configuration error and `12` on a counterexample; TLC exits `151`
  on an undefined invariant. Both scored as "the control caught its defect". Confirmed by
  pointing one of each at a nonexistent operator: both passed. That `tlc-witness` was among
  them is the sharpest form of it — the witnesses exist to rule out vacuity and were graded by
  a criterion a broken config satisfies.
- **Both provers are now graded against declared verdict tables** — `PV_EXPECT`,
  `PV_NEG_EXPECT`, `TM_EXPECT`, `TM_NEG_EXPECT`. Every query and every lemma of every theory
  declares the verdict it must produce, and a run must produce **exactly that set**, so a
  query silently added or dropped also fails. The green-versus-control distinction now lives
  entirely in the declared verdicts. `apalache-neg` requires `EXITCODE: ERROR (12)`;
  `tlc-witness` requires its own witness invariant named in the violation. All four hardened
  targets were teeth-tested by breaking them deliberately.

### Fixed — a green lemma with no control running (matrix 203 → 204)

- **`BindingReplayBug.spthy` was on disk but in no gate list.** `Binding.spthy`'s `no_replay`
  lemma — counted in the green slice and quoted in the reports — therefore had **no negative
  control running anywhere in `make matrix`**. The control was never broken; it was simply
  never listed in `TM_NEG`. Run now: wellformedness clean, `binding` still verified (the
  defect is replay-specific, which is what a well-isolated control looks like), `no_replay`
  falsified, reachability intact. Added, with its declared lemma verdicts.
- Clarified in `docs/PROPERTIES.md` §B1 and `docs/COVERAGE-MATRIX.md` §4 what the "15 ProVerif
  / 14 Tamarin" split actually is: **both provers prove no-replay**, Tamarin inside
  `Binding.spthy` and ProVerif in a separate `BindingReplay.pv` because its tables are not
  atomic under replication. It is a packaging difference, not a coverage gap. `RevokeMech` is
  the one genuine tool asymmetry — and its ProVerif column refers to `Revoke.pv`; there is no
  `RevokeMech.pv`.

### Fixed — two vacuity gaps the new tables exposed

- **`Unforge.pv` and `Binding.pv` had no non-vacuity query**, while their Tamarin twins both
  carry an `accepted_reachable` `exists-trace` lemma. Both are pure correspondence lemmas
  ("accepted ⇒ issued"), which a model that can never accept satisfies **vacuously** — so the
  flagship unforgeability result was the un-witnessed one. Queries added; both fire.
- **Three Tamarin controls falsify their own reachability lemma**, which `grep -q falsified`
  could not distinguish from the security lemma breaking. `ChainTopologyBug`'s is the injected
  defect's expected consequence; `DeepChainBug`/`DeepChainNBug` lose the honest chain at
  **2 steps**, making them the weakest controls in the prover matrix. Now declared in
  `TM_NEG_EXPECT` rather than absorbed. Narrowing the latter two is open.

### Fixed — documentation that had drifted from the work

- `docs/FINAL-ASSURANCE-SUMMARY.md` §6 still said the composed `Core` conjunction "remains
  deferred", contradicting §2 and §3 of the same file, which record it as proved.
- The same file described the ProVerif green slice as graded on "security lemma `is true` +
  non-vacuity reachable" — a grading that was not implemented and, for two theories, not even
  expressible.
- `AGENTS.md` said `MODELING-PIN` reads `v0.8.0`; it reads `v0.8.2`, as the paragraph below it
  said. The restatement is removed rather than corrected.
- Stale counts in `Makefile` (9 invariants → 18; 6 Spin modules → 9) and `spin/Makefile`.
- `spec-data/v0.8.2/MANIFEST.md` said "25 of **93** numbered sections"; the count is **85**
  (`### N.M` headings, excluding letter-suffixed refinements and `####` sub-sections), which
  is the denominator `COVERAGE-MATRIX.md` uses. Numerator unchanged and correct. The three
  normative files and their SHA-256 digests are untouched and re-verified — `MANIFEST.md` is
  repo-authored provenance and is excluded from the hashed set by `tools/spec-drift.py`.
- Live docs no longer restate "V7"/"V8" in prose; the pin is the answer. Phase reports keep
  their V7 wording as historical record (0.8.0 was the wire-identical de-versioned cutover).

### Added — two ratified disciplines and one disclosed coverage gap

- **D13** (a gate must assert the outcome it claims, not a symptom of it) and **D14** (a
  finding is not closed until applied to every instance of its shape), in `AGENTS.md`, each
  with a named enforcement point. Both are earned on repeated evidence, not speculation.
- `docs/COVERAGE-MATRIX.md` §3 now names the **three single-engine section rows** the
  module-granularity coverage audit left behind: §3.3 (incidental — the subject of §6.11(a′),
  not a claim), and **§4.7 (Apalache-only)** and **§6.9 (TLC-only)**, which are real
  single-tool results and are open in `docs/STATUS.md` §Next.
- `docs/ASSURANCE-MAP.md` now states that the **Lean↔model seam is asserted, not checked**:
  the models assume properties of the abstraction Lean owns, and nothing writes that
  correspondence down. ≥9 concrete correspondences identified; an assumption ledger and
  counterexample-replay differential check are the proposed closures.
- `docs/STATUS.md` §Next now names the two structural limits no current engine reaches:
  **peers are fixed at 2 in every model** (parameterized verification — Ivy/`mypyvy`/TLAPS)
  and **liveness is bounded everywhere** (TLAPS).

### Fixed — the gates now check what they claimed to check

A follow-up pass over the verification itself, in the same vein as the coverage audit below.
Everything here is a defect **in the verification, not the protocol**, and all of it shares one
shape: *a green that means less than it appears.* The protocol results are unchanged — 203 runs,
zero failures, pin at `v0.8.2` with no drift.

- **Tamarin was reporting that its own results might be wrong, and the gate called it green.**
  `tamarin-prover --prove` exits 0 when every lemma verifies even if its wellformedness checks
  failed, printing `WARNING: N wellformedness check failed! The analysis results might be
  wrong!` on the way out. Four green theories were shipping that warning unread, and
  `tamarin-neg` captured prover output and echoed only a verdict line, so a warning from a
  *control* was invisible even in scrollback. Two of the four were substantive:
  - `DeepChainN` / `DeepChainNBug` — `DelegateB` had a **free variable in its rule conclusion**:
    the delegatee `gC` appeared in the message, the action and the output but was bound by no
    premise, so the backward search could instantiate it at will. Its sibling rule `DelegateA`
    binds its own delegatee correctly. Added the missing `In(gC)`.
  - `Malformed` / `MalformedBug` — the name `Repr` was used at **two arities**: an arity-0
    action label colliding with the arity-1 fact `!Repr(x)` that carries the entire §5.6
    representability encoding. Action renamed `ReprSeeded()`.
  - `ChainTopology`, `Expiry` (+ their controls) — `!PkA(pk(~skA))` premises binding a secret
    key derivable from nothing. Rebound to the public key, as the verifier rules already did.
  - A wellformedness failure is now a **build failure** in both `tamarin-green` and
    `tamarin-neg`.

- **Negative controls now assert *why* they fail.** `tlc-neg` graded on TLC's exit status with
  output sent to `/dev/null` — and TLC exits non-zero for a parse or semantic error exactly as
  it does for a caught defect. A control broken by a typo, or one that had drifted onto a
  different property than the one it targets, scored `ok (failed as required)`. All **30** rows
  of `TLC_NEG` now declare the exact verdict line they must produce (`Invariant X is violated` /
  `Deadlock reached` / `Temporal property Y was violated`) and a mismatch fails the build.
  Verified to have teeth by pointing one row at the wrong invariant and confirming it fails.

- **Spin's gates were symmetrically weak.** A control was graded on the *absence* of
  `errors: 0`, which a compile failure also produces — so a control that never ran scored as a
  control that caught something. Controls now require a positive `errors: N`; green runs now
  require an explicit `errors: 0` rather than trusting pan's exit status.

- **`StoreBounded` removed from `Reentry`, `Core`, `CoreApalache`, `reentry.pml`, `core.pml`.**
  It was vacuous — one literal key written once against a bound ≥ 1 — and `Core`'s was carried
  into `ComposedSafety`, making the composed whole-protocol conjunction look one term stronger
  than it was. `core.pml`'s was worse: a **saturating** store write that clamped at `MAXKEYS`,
  followed by `assert(store[q] <= MAXKEYS)` — an assertion enforced by the statement three
  lines above it, 30 lines below a comment warning about exactly that failure mode. Removed
  rather than given teeth: the bound has no content in models whose servers serve once, so
  making it falsifiable would mean importing `Store`'s multi-key/refcount machinery and
  duplicating an owner. Declared as a structural exclusion in each model's header.
  `Store.ResourceBounded` remains the real §4.8/§4.9(b) obligation. It had been disclosed as
  vacuous twice without being fixed.

### Fixed — documentation that contradicted the work it described

- `docs/PROPERTIES.md` §C.8 still stated that `Core` **deliberately does not** carry
  §6.11(a′) because doing so "would duplicate `Reentry` without producing an interleaving
  `Reentry` cannot already exhibit" — the exact claim the coverage audit retracted, left
  standing in the repo's load-bearing honesty document. Replaced with the measured result and
  an explicit retraction.
- `docs/CROSSCHECK-RESULTS.md` and `docs/FINAL-ASSURANCE-SUMMARY.md` both carried a lede
  saying the composed Core-conjunction was "consciously deferred" above a body saying it was
  proved. `docs/STATUS.md` §Next still listed it as the one deferred item.
- **Section-count denominator was wrong in two places.** `docs/STATUS.md` and
  `docs/SPEC-DRIFT-ASSESSMENT.md` said "of 93 numbered sections"; the core spec has **85**
  (counted from the pinned snapshot: §1×11, §2×11, §3×13, §4×10, §5×10, §6×13, §7×6, §8×5,
  §9×6). Coverage is 28/85, as `docs/COVERAGE-MATRIX.md` already said.
- Three different run counts for one matrix: `README.md` said 156, `CANONICAL-DOCS.toml` said
  76, the capstone said 203. It is **203**.
- `AGENTS.md`'s status block still described the pre-0.8.2 world (pin at `v0.8.0`, 76 runs,
  6 Spin modules, 8 invariants over 5 modules, 12 lemmas) and named the next work as something
  already done.
- `README.md` called `make check` "the gate" (it is the green-only slice; `make matrix` is the
  gate) and did not list `make matrix` at all; described the repo as "arch-owned", naming a
  repository that no longer exists; and had a sentence that lost its verb.

### Added — coverage audit: every module now checked by every engine of its family

A full review of the verification itself, prompted by the question a reader will ask first:
*"who formalizes the formalization?"* The answer is the other tools — which only works if the
redundancy is real. It was not, in four places.

- **`docs/COVERAGE-MATRIX.md`** (new, canonical) — what each of the four engines can and
  cannot do; protocol section × engine; what is **not** covered, split into *out-of-scope* /
  *tool-limited* / *backlog*; and the exact bound on every claim. Matrix A is derived by
  grepping the `§`-citations in the models, not written by hand. `README.md` now leads with
  the headline grid and points here.

- **Four Apalache ports for modules that had TLC coverage only** — `Reentry` (§6.11(a′)
  frame-write atomicity), `Authority` (all four §5.2 rules), `Bounds` (§5.9/§4.10(b)) and
  `Core`. Apalache goes from 9 invariants over 5 modules to **18 over all 9**.
  - `CoreApalache.InvComposed` is **the composed whole-protocol conjunction deferred since
    Phase 1**. The old rationale — "each invariant is proven separately; Spin corroborates
    the deadlock" — does not survive: proving the conjuncts in separate modules is precisely
    what a composition invariant is *not*, and the deadlock is liveness, which Apalache
    cannot prove either way. **Nothing is deferred now.**
  - `BoundsApalache` proves the depth-brake property over **symbolic constants** constrained
    only by §5.9's ratio condition, so it holds for every conforming deployment rather than
    the one triple TLC checks. §5.9 makes the numbers non-normative and states the
    requirement as a property; this is the result shape that matches the claim.

- **Three Spin re-encodings** — `authority.pml`, `bounds.pml` and `core.pml`. The composed
  `core` model previously had **no independent encoding at all**, the worst-placed gap in the
  repo given that composition is the whole reason that module exists.

- **§6.11(a′) in `Core.tla`**, with its own control. An earlier revision declined this on the
  grounds it "would duplicate `Reentry` without producing an interleaving `Reentry` cannot
  already exhibit" — an empirical claim asserted without running the model, and not even
  structurally safe, since `Core` has revocation and a connection lifecycle that `Reentry`
  lacks. Modeled; the measured answer is corroboration, no new violation path. That reads
  differently as a measurement than as an excuse.

### Fixed — three defects in the verification, found by the redundancy

- **A writer released a lock it did not hold.** `Reentry.tla`'s client freed the connection
  write lock on receiving a response even when that peer's *own server* held it mid-frame.
  TLC found nothing and was right to: at the 2-peer bound no third writer exists to exploit
  the stolen lock. Apalache's inductive step starts from arbitrary rather than reachable
  states and caught it immediately. Fixed in `Reentry.tla`, `Core.tla` and `reentry.pml`
  (which now tracks the lock owner rather than a free bit). **This is the clearest
  demonstration in the repo of why the Apalache ports are not optional — and it only
  surfaced because the audit added a port that was missing.**
- **A negative control that could not fail.** `spin/core.pml`'s `-DNOESTABGATE` compiled out
  the establishment gate *and* the assertion detecting its absence, reporting `errors: 0`.
  Only the gate is variant-conditional now.
- **A bounded control too short to reach its defect.** `ReasonCodesDistinct` under
  `ConstInitBugCode` needs 5 steps; at 4 it reported `NoError`, textually identical to "the
  invariant holds". Lengths in `tla/Makefile` carry margin and the trap is documented there.

### Changed

- `spin/Makefile` gained `LTLFLAGS ?= -DNFAIR=3`: pan's weak-fairness process cap is 6 and
  the composed `core` model runs 8, aborting with a **tool** error that is easy to misread as
  a verification result.
- The matrix is **203 runs** (was 156), zero failures.
- Newly disclosed vacuity: `Reentry`'s and `Core`'s `StoreBounded` are inherited vacuous
  conjuncts (a single key against a bound ≥ 1). The real §4.8/§4.9(b) bound is `Store`'s,
  de-vacuumed at 0.8.2. Recorded in `docs/PROPERTIES.md` §C.4 and the coverage matrix rather
  than quietly carried.

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
