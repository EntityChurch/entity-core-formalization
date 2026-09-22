# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**This repository versions alongside the Entity Core Protocol it tracks.** `0.8.2` here
accompanies protocol `0.8.2`, so the two line up when read side by side.

Which spec text the models actually transcribe — and therefore what every result in this
repository is a statement *about* — is named by `spec-data/MODELING-PIN`, which reads
**`v0.8.2`**. The live protocol has since advanced to **0.8.2.32** and `make specdrift`
reports **15 of 29 cited sections moved**. That gap is deliberate and visible rather than
hidden: the pin moves only as the last step of re-validating the models, never on a file
copy, so between a spec release and a re-validation this repository is *behind on purpose*.
`docs/SPEC-DRIFT-ASSESSMENT.md` measures the distance section by section.

## [Unreleased]

### Changed — the documentation is reorganised so that what a newcomer needs is separable from what a session accumulated (2026-09-17)

**No model, no result and no published claim changes.** Every edit to a model file in this
change is inside a comment.

The repository's agent-facing guidance had grown to a single 158 KB file that mixed four
different kinds of thing: how to build and run the gates, the disciplines this project has
earned, the per-subsystem knowledge behind them, and the current status. Those are now four
artifacts with four lifecycles.

- **`docs/DISCIPLINE-CHARTER.md` is new** and is the interesting one for an outside reader: the
  eight disciplines this project earned, each with the defect that earned it and the gate that
  enforces it. Every one came from a failure in the **verification**, not in the protocol.
- **`docs/agents/memory/` is new** — eight topic files entered through `INDEX.md` and opened by
  symptom rather than read through: what the SMT backend will and will not accept, which
  container failures present as model failures, what each extension track refuted, and which
  published sentences went stale and by what mechanism.
- **`AGENTS.md` is 16,887 bytes**, down from 158,868, by moving rather than deleting.
- Routing packets moved to `docs/outbox/`; aged dated snapshots to `docs/archive/status/` with
  an index. Neither directory publishes.

**One thing worth recording because it is a result rather than a rearrangement.** The
retraction tripwire — which greps every live document for claims this project has publicly
withdrawn — excluded the status directory wholesale, and its own header had recorded, and
declined to fix, the consequence: an outbound routing packet is not dated history, and a
withdrawn claim sitting in one was unreachable. Moving packets to their own directory closed
that without touching the tool. The header predicted every packet would fire; four of
twenty-three did, all four quoting a withdrawn claim in order to correct it, **and none
asserting one**.

**And one correction to this repository's own published text.** `README.md` stated that every
model file belonged to the `core` track. That was true when written and false from the day the
first extension track was promoted — through three further promotions and nine extension
modules, in the most-read file here. A model file's track is a property of `TRACKS.toml`, which
`make trackcheck` enforces; the sentence is replaced by that statement rather than by a
corrected count.

### Added — §6.8's authority-selection MUST is modeled, and the ceiling turns out to be what makes a discriminator error fail-closed (2026-09-16)

A new `core` subject, **`authority-select`** — `tla/AuthoritySelect.tla` and
`tla/AuthoritySelectApalache.tla` — in `make matrix` (641 → **687 runs**): 1 green sweep over 8
invariants, 8 negative controls, **2 finding rows**, 4 non-vacuity witnesses, and all 8 invariants
proved **inductive** on Apalache with the strengthening's closure checked.

**It is `model_pins`-targeted at `spec-data/v0.8.2.25`, because the rule does not exist at the
core pin.** At `v0.8.2` §6.8 carries one direction of the selection — the confused-deputy
prohibition — and calls the caller-specified-path check one a handler performs *"voluntarily"*.
The three-row table, the `[MUST]`, the discriminator, its 0.8.2.22 correction and row 1's ceiling
all arrive after the pin. A **new subject** rather than an addition to `authority`, whose three
engines are statements about §5.2 **at the pin**: three engines over two texts is one reading per
snapshot presented as agreement.

**Why a model and not a vector.** §6.8 says of its own defect, in the document, that it is
**wire-invisible** — *"both readings produce a well-formed response and differ only in which
authority was consulted"* — so no conformance probe can grade it.
`PROPOSAL-THE-REFUSAL-…` §11 says the same thing from the other side: *"`N5` is the only item in
this round that cannot be checked by anything that exists."* `WitnessSilentSubstitution` exhibits
precisely that state — correct reading and propagated-field reading both ALLOW, different
authorities consulted.

**Two findings routed** (`docs/outbox/ROUTING-2026-09-16-f-…`, `P-9`/`P-10`):

- **`P-9`** — row 1 is a `[MUST]` over **two** authorities and §6.3's
  `check_path_permission(operation, path, authority, …)` takes **one**; `filter_listing`, whose own
  prose states the two-authority rule, calls it **once**. The pin shows this is a **residue**: at
  `v0.8.2` the listing filter read *"checked against the request's capability"*, singular, and the
  signature matched exactly. The rule gained a conjunct; the arity did not move.
- **`P-10`** — with the ceiling present, a discriminator error is **fail-closed** (row 1 demands
  strictly more than row 2, so a misclassification can only refuse). Remove the ceiling and the
  same misreading is a **confused-deputy escalation**. ⛔ **Neither half alone does it** — both
  "holds" halves were run, not reasoned — and the shortest counterexample is one hop with a live
  caller, no continuation and no stale token.

**The `N5` cohort census moved**: `entity-core-py` has built the ceiling (two checks, citing
0.8.2.24 N5 by name) where the proposal recorded *"unbuilt at all three"*; go and rust have not,
and **rust's listing-filter doc comment quotes the pin-era singular sentence verbatim**.

**A fourth shape for `tla/Makefile:TLC_FINDING`: a COMPOSITION row**, whose two flipped constants
are of different kinds (one finding, one control) and which is violated under neither alone.

### Changed — three published quantifiers and two hand-maintained figures, each corrected at the site

- *"Every `core` module is covered by all three engines of its family"*
  (`docs/COVERAGE-MATRIX.md` §4) went **false** the moment this subject was declared — a core
  module on TLC + Apalache with no Spin — with `make enginecount` **green throughout**, correctly,
  because it reads the declared per-subject engine sets and never reads that sentence. D14's sixth
  instance. Repaired at three sites by **naming the module that fails the quantifier** rather than
  incrementing a count.
- `AGENTS.md`'s matrix paragraph lost two hand-maintained figures (*"100 negative controls and 13
  non-vacuity witnesses"*) to the same rule that retired *"the 277"*: the values are **deleted and
  the subject named**, because this change made a knowingly-uncorrected figure a knowingly-wrong
  one.
- *"none of the fourteen now contradicts a model"* — a spelled-out second copy of a gated count,
  invisible to `make driftclaim`, which was green over the sentence containing it.

### Fixed — four documents said a spec section contradicted a model two days after it stopped doing so (2026-09-17)

`README.md`, `docs/ASSURANCE-MAP.md`, `docs/FINAL-ASSURANCE-SUMMARY.md` and
**`docs/SPEC-DRIFT-ASSESSMENT.md`'s own summary table** still asserted that **§4.7's movement
contradicts a model**. It stopped being true on **2026-09-15**, when `tla/ConnCodes.tla`, its
Apalache port and `spin/conncodes.pml` were retargeted to `spec-data/v0.8.2.25/` under
`[track.core.model_pins]` — §4.7 is now measured against its own snapshot and no capstone here
makes a §4.7 claim to contradict. The correction reached two documents that day and stopped at
four others; the drift assessment's summary table disagreed with its **own §4.7 subsection**
(`✅ CLOSED 2026-09-15`) inside one file.

**Each of the four states the count in its own words and at its own vintage** — *"eleven of the
twelve"* in `README.md`, *"fifteen of the sixteen"* in the two capstones, a table cell in the
third — which is why the gate anchored on the canonical phrasing `N of 29 cited sections moved` saw
none of them. ⛔ **And three were found before the fourth: the first sweep matched the newer
paraphrase and missed the README's older one**, which is the most-read published file here. *When a
figure is restated in prose, each restatement ages independently — grep the OLD VALUES, plural, not
the current sentence.* All four repaired by **deleting the value and naming the subject**.

### Changed — the live protocol advanced to **0.8.2.32**, and the count did not move

`0.8.2.31` and `0.8.2.32` changed **§9.1 and nothing else** — 10 lines between them, the version
header included — and **no model here cites §9.1**, so the measurement is **15 of 29 cited sections
moved** before and after. `make driftclaim` went red anyway, on the **live-version** facet, which is
gated only because nine sites once read `0.8.2.11` while it was `0.8.2.15` with the count unchanged
and the gate green.

⭐ **`0.8.2.31` corrected the §9.1 conformance floor to the rule this release models.** That row had
published *"the handler-level check's authority is selected by **who named the path**"* — the
discriminator §6.8 corrected at `0.8.2.22` — for **eight revisions**, in the MUST-implement list an
implementer builds from. It now carries §6.8's discriminator and states row 1's conjunction in as
many words: *"the caller's verified capability **AND** the executing handler's own grant, and
**BOTH MUST pass**."* The finding this release routed against that rule is **unaffected and better
evidenced**: §6.3's `check_path_permission` still takes **one** `authority` and §6.3 is
byte-identical, so the floor gained the conjunction and the arity did not.

**§6.3 and §6.8 are byte-identical between `spec-data/v0.8.2.25/` and live `0.8.2.32`**, compared by
section span rather than inferred from the unchanged count.

### Changed — the drift measurement, re-derived: 14 → **15 of 29**, live 0.8.2.25 → **0.8.2.30**

The fifteenth is **§7.3** (0.8.2.26), which makes that section *"the single normative home for the
signature message"* — the target's `content_hash` **in full**, format code as domain separator. It
is cited by **26** model files and contradicts none of them: every citation is the **crypto wall**,
so *which bytes the message is* is exactly what those theories abstract. ⚠ One adjacency is
recorded rather than waved past — the clause's own argument is a **cross-format** confusion, and
`tamarin/Resolution*` models a single hash constructor.

⛔ **And the §6.8 row of `docs/SPEC-DRIFT-ASSESSMENT.md` stated the discriminator in the refuted
0.8.2.21 wording** (*"by who named the path"*), the same defect `docs/STATUS.md` §Next carried, in
a second document. Corrected — and the correction is now **measured**: the superseded reading is a
negative control and a witness exhibits an access on which the two readings disagree, so the
.21 → .22 change is semantic rather than editorial.


### Added — the adversary now gets the ADDRESS as well as the term, and the forgery is exhibited (2026-09-16)

Four new prover theories and two new engines' worth of runs: `tamarin/Resolution.{pv,spthy}`
and `tamarin/ResolutionDiscard.{pv,spthy}` with a negative control each, on ProVerif and
Tamarin, in `make matrix` (633 → **641 runs**).

**Why they are the first of their kind here.** Every other theory in this repository takes
capabilities, signatures and identities as *terms* the verifier receives — so *"resolve an
entity by its address"* had no representation, and there was no address to forge. §5.2 and §5.5
do not receive entities; they **resolve** them, by key, out of a wire-supplied map. That
unstated abstraction is why a green active-attacker result could coexist with a live capability
forgery, which `entity-core-protocol` closed at `0.8.2.23` on text that was inside this
repository's own modelling pin.

These theories carry the indirection. The forgery is **exhibited**: remove one of five key
bindings and an observer of any capability chain mints a leaf off it, with every address in the
envelope honest, every address-level check in §5.5 passing, and the granter's key never used.
Both of the conformant mechanisms the specification offers close it.

**And the new result is about the choice between those mechanisms.** The specification warns
that its second mechanism *"depends on this item running at every ingress"*. That warning is now
measured: a peer running it at four ingresses out of five is falsified by the same attack, one
level down, and is **indistinguishable on the wire** from a conformant peer — the envelopes that
separate them are exactly the ones an honest peer never sends. The first mechanism is one check
at one site and cannot be half-adopted; the second is a check at N sites and N−1 looks like N.

### Fixed — two claim gates were green over numbers they could no longer see (2026-09-16)

`make enginecount` validated every `N of M` whose denominator was one of its own derived
figures. Adding a subject moved the total, so four live sites stating the *previous* pair had a
denominator that was no longer recognised and were skipped — and a second, still-correct pair in
the same sentence satisfied the "does it state a pair at all" check. `make runcount` failed in
the opposite direction on the same afternoon, reporting that a site had *stopped making its
claim* when the site was merely stale, because its pattern was anchored on a neighbouring number
that had also moved.

Both are the same root cause and it is now a named discipline: **a gate recognises a claim
through a matcher, and the matcher must not depend on the claim's own value.** Matchers classify
by an invariant token now. The teeth-testing checklist gained a third input — a wrong
*denominator* — which had never been run against any gate here.

### Fixed — the obligation gate credited models that transcribe a different snapshot (2026-09-16)

`make coverage` holds a pin-overridden model's citations out of the pin's coverage claim;
`make obligations` did not, so obligations inside a section only an off-pin model cites went on
counting as examined. The two share the partition now, the split is printed beside the headline,
and the published figure moved from **120 to 122 of 365 core obligations unexamined** — the hole
getting bigger because the measurement got honest.

### Added — a model may now pin to a different snapshot than its track, and it is a gate rather than a sentence (2026-09-15)

`tla/ConnCodes.tla`, `tla/ConnCodesApalache.tla` and `spin/conncodes.pml` now transcribe
`spec-data/v0.8.2.25` instead of the core pin `v0.8.2`, because **§4.11 does not exist at the
pin at all** and §4.7's out-of-order row carries a different status there.

**The mechanism is the durable part.** `spec-data/MODELING-PIN` says every published result is a
statement about that snapshot *"and no other"*, and the obvious way to retarget one module is a
paragraph in its header saying so. That is a disclaimer, and this project's own rule is that a
self-aware caveat is where a stale figure survives longest. So the override is machine-read:
`[track.core.model_pins]` in `TRACKS.toml`, a `MODELING-PIN-OVERRIDE:` marker in each file, and
`make trackcheck` checks **both directions** — a declared row with no marker fails, a marker with
no row fails, a redundant override fails, a missing snapshot fails. `make specdrift` then measures
those files against their own snapshot and `make coverage` holds their citations out of the
track's coverage pair.

**The published coverage number went DOWN as a result, from 29 to 27 of 91, and that is the gate
working rather than a regression.** §4.7 and §5.2a left the grid because no pin-targeting model
cites either — so nothing in this repository now verifies those two sections *as the pin states
them*. A header-sentence override would have left 29 standing and made it false.

### Fixed — the one place the live spec contradicted a model (2026-09-15)

`connection_sequence_error` moved 400 → 409 at protocol `0.8.2.4` while `ConnCodes` transcribed
400. With the retarget above, `make specdrift` measures those three files against `.25` and finds
**none of their 11 cited sections has moved**. *(Phrased without the canonical drift wording on
purpose: `make driftclaim` expects exactly one drift claim in this file — the versioning preamble
— and it caught this paragraph's first draft stating a second one. One claim per declared site is
the rule; a file with two is a file where one of them can go stale unnoticed.)* Also newly modeled, all reachable by the connect phase machine: the
unknown-connect-operation row (`invalid_request` 400, split out of the out-of-order row), the
half-open state rule, and `0.8.2.6`'s *address is evaluated before authentication* — the last of
which is a phase-**independence** claim and so the one property here a phase machine can really
test.

**§4.11 is modeled as its cause → code table plus its emission obligation**, with **dropping the
frame** and **closing without a coded frame** as two separate controls breaking two separate
invariants, because §4.11 states they *"are distinct failures rather than one"* and a single
conformant/not boolean could not express that. ⛔ **§4.11's multiplexed arm (f) is NOT modeled**
and `ConnCodes` cannot model it — it is a phase machine with one connection and no admitted
requests. That is written into the coverage grid rather than left to be inferred from a citation.

The matrix is **633 runs** (from 609): 24 added across TLC, Apalache and Spin.

### Changed — a finding this repository routed was adopted upstream, and closing it exposed a filing error (2026-09-15)

Protocol `0.8.2.1` (FM-1) narrowed §4.7 row 10's parenthetical exactly as argued in
`docs/PROPERTIES.md` §D.1, so a pre-hello `authenticate` is unambiguously `401 invalid_nonce`.
The model's contested-cell constant is gone and `ConnCodesSeqReadingBug` demotes from *"a
conformant reading of the spec"* to an ordinary injected defect.

**On the way out it surfaced a defect in this repository's own gate tables.** A *finding* row and
a *negative control* grade identically and mean opposite things when green — a green control has
no teeth; a green finding means the defect was fixed upstream and the row should be retired.
`TLC_FINDING` was created to separate the two; **this row, which is the shape that table was
written for and predates it, was never moved into it** and sat in `TLC_NEG` under a header whose
sentence was false of it. It is correctly filed now without being moved, because the spec moved
instead. A row that is misfiled and then made correct by an upstream fix is the hardest kind to
notice: nothing was ever red.

### Fixed — a capability forgery was closed upstream in text that was in our pin, and no gate here was red (2026-09-14)

`entity-core-protocol` `0.8.2.23` closed a **capability and identity forgery**: every authority
lookup resolved an entity by a wire-supplied `envelope.included` map key that nothing verified,
so an observer of any capability chain could mint a leaf off it up to the parent's scope
**without the grantee's key**. Three things about that are this repository's to answer, and all
three are now recorded rather than argued:

**The enabling obligation was in our pin.** `spec-data/v0.8.2` §3.1 — *"The content_hash MUST
match the map key"* — with no enforcing operation and no vector anywhere in the pinned text, and
named in the pin's own §9.1 *MUST Implement* index. That absence is the exact trigger of this
repository's **D17**, which had only ever been applied to the three extension tracks. D17's scope
now says so in the discipline itself.

**No model here represents the mechanism.** The active-attacker theories take capabilities and
chain links as terms, so there is no address to forge; `content_hash` occurs **0** times across
the 60 files in `tamarin/`. The abstraction was **undeclared** — not a disclosed limit — and is
now `docs/LEAN-SEAM.md` **O23**, OPEN, with every active-attacker result in `docs/PROPERTIES.md`
stated as conditional on it.

**Two canonical documents published a no-forgery claim** that was true and that a reader could
not scope: *"…admits no forgery … under an active attacker, **at the modeled bound**."* Both are
corrected at the site, with the original kept beside the correction; the assertion form is
retracted as **R13** so it cannot silently return.

### Added — `make obligations`, the one gate here whose denominator is not ours

Every existing gate divides by an artifact of this repository: `coverage` by the sections our
models cite, `runcount` by our gate tables, `enginecount` by our green tables, `ledgercount` by
our ledger. `coverage` is the near miss and the instructive one — it does divide by the pin's
section count, and **a section is not an obligation**: §5.2 carries engine dots with nine MUSTs
inside it, while §3.1, which carries the forgery's, is not a row at all.

`tools/obligations.py` + `docs/OBLIGATIONS.toml` count each track's obligations from **its own
pin** and require a written disposition — `modeled-elsewhere` / `out-of-scope` with a reason /
`UNEXAMINED` — for every obligation-bearing section no model cites. The headline is the
UNEXAMINED count, so what a reader sees is the size of the hole:

| track | obligations | inside cited sections | outside | UNEXAMINED |
|---|---|---|---|---|
| `core` | 365 | 237 | 128 | **120** |
| `attestation` | 37 | 16 | **21** | 5 |
| `identity` | 86 | 59 | 27 | 27 |
| `quorum` | 60 | 23 | **37** | 11 |

On `quorum` and `attestation` more normative surface sits outside the models than inside — and
those are the tracks this repository originated findings on. Catalogued as an anti-pattern: *the
productive track reads as the covered one.*

Ratified as **candidate D19** only. It has bitten once; the promotion ladder says one bite is a
candidate, and the promotion condition is written down. Nine teeth tests including the restore.

### Added — `spec-data/v0.8.2.24/`, and the pin did not move

The three normative files vendored byte-for-byte and digest-verified, `0.8.2.24` / CBOR `1.7` /
type system `4.2.1`. **No structural movement at all**: no section added, removed or renumbered,
the coverage denominator unchanged at 91, and every model `§`-citation still resolves.
`spec-data/MODELING-PIN` still reads `v0.8.2` and every published result remains a statement
about it. `docs/SPEC-DRIFT-ASSESSMENT.md` **§1c** classifies the fifteenth moved section — §5.5,
the most-cited section in this repository, moved because a defect was closed rather than because
surface was added, which is a distinction this document previously had no column for.

### Added — the frame-canonicalization equivalence is measured (arch `KS-9c`)

`lean/lemmas/Frame.lean`, gated by `make leanlemma`, against keystone's own definitions.
**Claim E holds: 2370 differential pairs, zero disagreements**, plus 90 round-trip and 120
id-scope pairs. Arch's items 2 (per-link chain framing), 3 (the sentinel) and 4 (the exclude
side) are clean; items 1 (multi-granter root) and 5 (identity rotation) are **not decided**,
because neither is a matcher question. The sentinel **survives minting**, so both readings refuse
exactly the same set and the difference is *where*, not *whether*. Every substantive row reports
zero, so the sweep carries a **positive control** injecting §5.5a's own
`canon-against-wrong-frame` architecture — it reports 62 and 14, which is what makes the zeros
measurements rather than silence.

### Fixed — two defects in keystone's Lean, found by re-reading it for the above

`scopeSubset` reaches neither the `0.8.2.20` sentinel rule (implemented as a wrapper that one
call site does not use) nor the `0.8.2.22` typed dispatch. Routed, split into an ask and a
heads-up by their declared pin, per D17's fourth item.

### Added — `docs/status/INBOUND.md`

All three trackers were outbound-only. Arch's `ROUTING-2026-09-12-e`, marked *"the priority
item"*, sat unopened for two days; keystone's scope-algebra cell census — an instrument
enumerating this repository's own subject — was unknown here while three other seats worked from
it. A work-list is an input set too.

### Fixed — `tools/ledgercount.py` anchored two patterns on the value they watch

Two STATUS matchers carried the literal `**40 rows**`, so when the ledger moved to 41 they
stopped matching and the gate reported *"the site went silent"* instead of *"the site is
stale"* — a true message naming the wrong defect. Never anchor a matcher on the value it checks.


### Fixed — a coverage row credited two engines for a section every model declares abstract

`docs/COVERAGE-MATRIX.md` Matrix A carried `| 5.4 | pattern matching | no escalation via
attenuation | … | ● | ● |`, crediting ProVerif and Tamarin. **All nine model files citing §5.4
cite it as an abstraction boundary, in those words**, and the property the row named is **§5.6's**
order relation — already credited to the same two engines by §5.6's own row. One property counted
twice, half of it attributed to the wrong section.

The row is **kept and corrected, not deleted**: the coverage gate asserts the cited section set
equals the grid rows in both directions, so while nine files cite §5.4 a row must exist. What was
wrong is the hand-maintained part — the engine dots and the property label — which is why **the
published coverage figure does not change** and no gate had flagged it. `docs/COVERAGE-MATRIX.md`
§3a records what was wrong, and the distinction that makes it statable: the test is not whether a
section is abstracted but **whether a row's stated property is the one its engines establish**
(§7.3 keeps two dots and says *"(as crypto wall)"* in its own label).

### Changed — the pin is further behind, and the distance was measured rather than assumed

The live protocol advanced to **0.8.2.21** while this repository's models stayed pinned at
**0.8.2**, and `make specdrift` now reports **14 of 31 cited sections moved**. Four of the
fourteen were added during this cycle — **§5.2** and **§5.6** (0.8.2.16), the two most-cited
sections here (17 and 14 model files), and **§5.4** and **§6.8** (0.8.2.20/21), cited by 9 and
10. **None contradicts any model in this repository**, and that is an argument rather than a
reassurance: every engine abstracts the scope matcher, and the one dimension any of them frames
concretely is path-scope in both texts. `docs/SPEC-DRIFT-ASSESSMENT.md` §1a and §1b state the
arguments and their limits.

**§5.4 and §6.8 had both been recorded as `unchanged` inside arguments that leaned on their
stability**, so the measurement did not merely go stale — it went stale under two load-bearing
sentences, with every gate in this repository green. The reasons they still contradict nothing
differ in kind, and the difference is the interesting part: **all nine of §5.4's citations are
abstraction disclaimers** — the section moved in the one place nothing here models — while
**§6.8 grew by 3.8 KB around a clause that is byte-identical**, and that clause is the only thing
the ten models citing it use.

What the movement did surface is a divergence that **predates it**: §3.6's id-scope pattern
grammar has been normative since 0.8.1, and the sibling proof development this repository's
assumption ledger cites does not implement it on the delegation-subset path. Machine-checked and
routed; `docs/LEAN-SEAM.md` L1, L5 and L6 carry scope notes and no verdict changed. **A drift
measurement scoped to models under-reports exposure in a repository whose published claims also
rest on someone else's proofs** — that gap is now named in the assessment, and it is not gated.

### Added — a third assertion in the Lean seam gate

`make leanseam` now fails on any full SHA-256 stated **outside** its machine-read pin block that
the pin block does not declare. It was added because the ledger's own prose table of pinned
digests had been wrong for three days with the gate green: the gate parses one block, the table
restates the same fact in a notation nothing reads, and **the stale copy was created by the very
commit that correctly updated the block**. A digest does not read as a claim.

### Added — the corroboration standard, and its gate

**Two engines, minimum.** A result published here as a property of the protocol is now required
to be carried by **at least two structurally different engines**, and a result carried by one
must say so by name. **`docs/CORROBORATION.md`** is the ledger — per modeled subject, which
engines have a *green* result on it, and every subject that rests on a single engine listed
individually with the reason — and **`make enginecount`** derives the whole thing from the gate
tables and fails when any published figure disagrees. It is **35 of 37** subjects on two or more
engines, **9 of 9** on the three extension protocols.

The ledger says in its own text what a second engine does **not** buy, because the number is
easy to over-read: it does not make two models of one spec section independent of the reading
that produced them, and two model checkers over one transcription cannot ask a question neither
can express. Every extension track's adversarial property is still discharged by nothing.

**A file existing is not an engine checking anything.** An engine counts for a subject only where
that engine's *green* table names one of the subject's files. Controls, witnesses and finding
rows are claims about what breaks, and the first draft of this gate credited a prover with a
result on the strength of a file whose only job is to fail.

### Added — `EXTENSION-IDENTITY` §9.4 under a second engine, and two findings from its domain

**`tla/IdentityRecoveryApalache.tla`** carries compromise-recovery validation to Apalache. The
corroboration half: every claim the first model makes reproduces, and §9.4's fail-closed rule is
now proved **inductive**, so it holds for an unbounded number of deliveries rather than the two
the first model could represent.

The other half is what the second engine was pointed at. §5.1 stores the trust anchor at
`contacts/{published_handle_hex}/quorum-publish` — keyed by the *`quorum-publish`'s* own property
— and §9.4 looks it up at `contacts/{old_handle_hex}/quorum-publish`, keyed by the *recovery's*.
The first model had one cache slot with no key, so it assumed those were the same handle.

- **A routine handle rotation disables compromise recovery.** The privacy-hygiene rotation is
  dual-signed by the two handle keys — the quorum does not sign it — produces no
  `quorum-publish`, and no section requires either a re-key of the cached entry or a fresh
  publish afterwards. The anchor is left under the previous handle, so a later recovery
  fail-closes on the one path the specification names as the remedy for a stolen key. All three
  implementations behave identically here.
- **The dispatch handler that could carry the entry across is named and never defined.** Its two
  available readings each satisfy one of two properties the specification states and neither
  satisfies both: moving the entry breaks the idempotent semantic the dispatch section asks for,
  retaining it makes the anchor usable only once per published handle. The three implementations
  answer three different ways. The reading that satisfies both is included as a checked
  configuration rather than as a recommendation.

### Added — `EXTENSION-QUORUM` §4.2 under a second engine, and what its model had assumed

**`tla/QuorumSignerSetApalache.tla`** carries the signer-set resolver to Apalache, reproducing
each of the four §4.2 findings by a second method. It exists mainly to run one experiment: the
TLC model restricts the supersedes pointer to lower-numbered entries *unconditionally*, and that
restriction is a claim nothing had measured.

Lifted, **four of §4.2's five checked properties are unaffected and one is not**. On a supersedes
cycle the resolver returns the roster the quorum was created with while a membership change is in
force — and the companion result, green on the same constants, shows the assumption the section
actually needs is **acyclicity**, weaker than the ordering its model assumed. The configuration is
not constructible where entries are content-addressed; that unstated argument is the finding.
Routed, not fixed here.

### Added — a second engine on the attestation track, and the closure half of the inductive proof

**`tla/AttestIndexApalache.tla` and `tla/AttestLiveApalache.tla`** carry two of the attestation
track's three modules to Apalache. §5.7's index contract is now proved **inductive** — true for
runs of any length rather than within a bound — and **the `find_live_head` finding is confirmed
by a second, structurally different method**: TLC enumerates the supersedes-graph space, Apalache
answers one SMT query over it, and both exhibit the counterexample on constants where nothing is
weakened.

**Read the arithmetic, not the headline. Seven of the nine extension modules still rest on one
engine**, none of the nine has a third, and none has a prover model, so the Dolev-Yao gap is
untouched. A second engine also buys no independence from the transcription: both files are one
author's reading of one spec text, and a shared misreading survives both.
*(That count was true of this entry and has since moved twice inside the same unreleased cycle;
`docs/CORROBORATION.md` is the live figure and the entry above is the one to read for it. The
third and fourth sentences are unchanged and are the durable part.)*

### Fixed — the inductive proof asserted less than it claimed

`apalache-green` checks `Init => Inv` and `IndInit /\ Next => Inv'`. Where `IndInit` carries a
strengthening — 20 of 26 rows — those two do not establish that the invariant is inductive,
because nothing showed the *strengthening* survives a step. **`make apalache-closure` now checks
it, and all 26 rows pass**: nothing was wrong, the claim was simply weaker than the words. That
is the quiet half of this repo's grading discipline — a gate that under-asserts produces no
failure to investigate, so only asking the question finds it.

The full matrix is **407 runs** (was 361).

### Added — the identity track, and with it the last extension protocol is modeled

**`tla/IdentityProcess.tla`, `tla/IdentityRecovery.tla`, `tla/IdentityCertChain.tla`** model
`EXTENSION-IDENTITY` v3.10 — 33 runs, TLC only, pinned by `spec-data/MODELING-PIN-IDENTITY`,
which had to be written *before* the model files could be declared. That is the `scoped` gate
doing its job for the second time in one day, and with `identity` promoted **no scoped track
remains**: four tracks, all modeled, each against its own frozen and separately pinned snapshot.
The consequence is recorded rather than left to be found — a gate whose input set has gone empty
asserts nothing about the live registry, and this one now has no subject in it.

**Nine findings, all machine-checked, routed to `entity-system-architecture`.** The one to read
is a *green*: §9.4's compromise-recovery rule is a negative-reachability claim ("fail-closed if
no `quorum-publish` is cached"), and the model that transcribes it passes — **because the
accepting path is unreachable.** §6.3 phase 1 rejects `quorum-publish` at
`not_identity_attestation`, so §6.3's own phase-2 dispatch row `(quorum-publish, *) →
seed_contacts_cache` never runs, so the trust anchor §9.4 requires is never stored, so a
compromise-recovery signed by the identity's real quorum is rejected at a contact that has
received that identity's genuine publish. §9.6 names compromise-recovery as the only remedy for
a stolen controller key.

This repo's own scoping note predicted the shape before a line was modeled — *"a peer that does
nothing satisfies it … write the witness before the prohibition"* — and the prediction was right
and under-specific: the risk it named was a model with no paths; what turned up is a **spec**
with no paths. The prohibition and its witness are now two rows that must be read together.

One finding is **cross-spec and exists only in a pair of documents**: `EXTENSION-ATTESTATION`'s
TV-A8 delegates the rejection of an invalid-signature revocation to *"identity's
`identity_verify_cert` … at topology-dispatch step"*, and `identity_verify_cert` rejects every
`kind="revocation"` before topology dispatch is reached. Neither document is wrong read alone.

**The implementation cohort does not agree with itself here, and that inverts the argument the
previous two tracks rested on.** On quorum, three independent authors derived the same unwritten
rule three times, and the unanimity was the argument for writing it down. On identity all three
added a kind branch ahead of §6.3 phase 1 that the spec does not have — that unanimity is the
finding — and no two did the same thing, so whether an arriving `quorum-publish` fills §9.4's
trust anchor is answered three different ways and the peers do not interoperate on compromise
recovery.

**Where a track consumes another track's known-defective output, the assumption is now a model
constant with a negative control rather than a footnote.** Identity calls
`EXTENSION-QUORUM §4.2 current_signer_set`, which this repo has already measured and refuted.
Transcribing it would have re-derived the quorum findings wearing identity section numbers;
assuming it silently would have hidden the choice. `SignerSetIsSound` is true in the green sweep
and false in a control whose only job is to exhibit what every identity K-of-N verdict rests on.
`docs/LEAN-SEAM.md` O16 is that row and it is a shape the other eighteen do not have.

The published coverage pair is **22 of 73 sections**, audited down from an initial 30: nine of
those citations were background, impact or "the property this section exists to provide"
mentions, and the coverage gate's scope-disclaimer tripwire passed all thirty. A tripwire that
matches one phantom idiom does not cover the class.

Matrix: **361 runs**, up from 328. Assumption ledger: **37 rows, 14 open**, up from 33 and 10.

### Added — the attestation track's first two models, and all three extension specs vendored

`tools/vendor-spec.py` (`make specfreeze`) vendors a spec byte-for-byte into a new frozen
snapshot and, separately, re-hashes **every** existing snapshot against its own MANIFEST.
The second half closes a rule that had no enforcement point: `AGENTS.md` and
`v0.8.2/MANIFEST.md` both say a snapshot is frozen because *"a pin whose bytes can change is
not a pin"*, and nothing had ever re-hashed one. Now in `check` and `matrix`. Nothing had
drifted — all six files matched — but that could only be known by checking by hand.

Vendored: `ext-attestation-v1.3`, `ext-quorum-v1.2`, `ext-identity-v3.10`. **Not blocked on
anything, contrary to what the status log said:** all three declare
`Depends: ENTITY-CORE-PROTOCOL.md (v7.40+)`, a floor the existing core pin already meets.
Core's pin is unmoved and every published core result is untouched; extension tracks pin
independently.

**`tla/AttestIndex.tla`** models `EXTENSION-ATTESTATION` §5.7's index invariants I1–I5 — 7
runs, TLC only. Two of the four mandatory indexes are **conditional**, so
the obvious invariant *"the entity is in all four indexes"* is false for a kind-less
attestation; the model asserts membership of the entity's *eligible* set instead, and carries
a witness that a bound attestation with a proper-subset eligibility actually exists — without
which the correct and incorrect readings are indistinguishable on the model. Three ledger rows
added, all OPEN, including one recording that the model encodes a *reading* of I2 that nothing
in this repo can check.

**`tla/AttestLive.tla`** models §4.3's liveness check and the §5.2 / §5.3 chain walks — 8
runs, TLC only — and **two of its rows are findings about the specification rather than
results about the protocol.**

*`§5.3 find_live_head` does not compute its own stated contract.* It filters direct successors
by the full `is_attestation_live` predicate, and v1.1's ratified transitive supersession makes
that predicate false for any attestation that *has* a live descendant. So the link leading to
the head is never itself "live", the walk cannot pass through it, and on a three-link chain the
function returns **null** where the head is the third link. Checked on a model with nothing
weakened: `SpecHeadFindsLiveHead` — §5.3's own comment, stated as an invariant — is violated
over every supersedes graph on three nodes.

*And the corollary is green:* `§5.1`'s head-resolution step is an **identity map**.
`default_find_authorizing` filters candidates to live ones and then resolves each through
`find_live_head`, but a live attestation has no live descendant, so every resolution returns
its input. That is also why the normative cross-impl vectors cannot catch the defect above —
the composite returns the right answer because the liveness filter already did the chain
resolution, and the broken component is invisible from outside it.

Routed to the owning repository with the implementation cohort measured first: all three
sibling implementations diverge from §5.3's pseudocode in the same direction, one carrying a
code comment naming the exact cause, and one repository's spec-ambiguity log had raised the
neighbouring half against v1.0 — v1.1 adopted one of its two interim changes, and this is the
residue of the other. Two further findings routed alongside: §5.2 passes a hash to the
path-keyed accessor that §4.0's own interface contract types by path, and `EXTENSION-QUORUM`'s
normative historical-state requirement rests on an `as_of` parameter §5.3 does not define.

**New gate-table kind — `TLC_FINDING`** (`make -C tla tlc-finding`, in `matrix`): rows that
must be violated on a model where nothing is weakened. It grades exactly like a negative
control and means the opposite, so it is a separate table with its own retirement condition —
a green here means the spec was fixed upstream and the row should be deleted, not repaired.

**`tla/AttestRevoke.tla`** models §4.3's other recursion — revocation — and closes an
abstraction `AttestLive` had declared rather than moving on to a new section. 8 runs; two more
findings.

*`is_self_revoked` is used in §4.3's normative pseudocode and defined nowhere in the document.*
One occurrence in the file, and it is the use site; `not_expired` likewise. The document has
fixed this exact class before — v1.0 Amendment 1 added definitions for two helpers "referenced
from §4.3 … but never specified" — and two more in the same function were left. It is not
editorial: the two natural readings give `is_attestation_live` different answers about the same
attestation, which the model shows by computing both. The counterexample is the documented
predecessor-revival semantics being switched on and off by the undefined term.

*And §4.3's cycle-safety covers one of its two recursions.* `has_live_transitive_descendant`
carries a visited set and says it is cycle-safe; the revocation recursion four lines above it
has neither a visited set nor a depth bound. Recorded as a reading rather than a measurement —
the model assumes acyclicity by construction and says so.

*A cohort divergence that turned out not to be one.* Two implementations read the undefined
helper recursively; the third computes the descendant check a different way entirely. The
green `DescReadingsCoincide` shows the two forms are the same predicate on every acyclic graph.
Run rather than argued, because §D.1 is this repository's record of reasoning its way to a
cohort claim and being wrong.

### Fixed — the coverage denominator dropped every lettered section, and two gates disagreed about it

`make coverage` matched section citations as `§(\d+\.\d+)` and counted spec headings the
same way, so a **letter suffix** was silently discarded at both ends. Two consequences, and
the second is the one that had been live for releases:

- A citation of `§5.6a` was credited to `§5.6` — **sibling sections**, not a section and its
  subsection — which is the `§4.7` phantom-row mechanism arriving through a different door.
- The **denominator** excluded lettered headings outright, so six normative core sections had
  never been counted (`1.2a`, `1.5a`, `4.5a`, `5.2a`, `6.9a`, `9.5a`). Core coverage is
  **29 of 91**, not `28 of 85`; by area **§4 64% · §5 91% · §6 57%**, not `70/90/62`. `§5.2a`
  is now its own grid row rather than folded into `§5.2`, a different section 320 lines away.

`make specdrift` had the correct convention all along, which is exactly why it reported **30**
cited sections where `make coverage` reported **28** — a two-tool disagreement over one
artifact, with both numbers published in the same documents and neither reconciled to the
other. Both tools share the convention now.

`make coverage` also checked the coverage pair at **one** site, the line inside the grid it
derives from, while three other published sites stated it; all three were stale and were found
by grep. Declared prose sites now, in both directions.

Published numbers are now **per track** — 277 runs on `core`, 15 on `attestation`, derived by
`make runcount` rather than written by hand, because one total across two protocols is the
conflation the track dimension exists to prevent.

### Added — proof tracks: which protocol a result is about is now declared and gated

This repository verifies **more than one protocol**, and until now nothing said so. Every
model file, spec pin and coverage number is assigned to exactly one **track** in the new
root-level **`TRACKS.toml`**, gated by **`make trackcheck`** (in `check` and `matrix`). Four
tracks: **`core`** — the Entity Core Protocol, the only **modeled** one, and therefore what
every published number here is about — plus **`attestation`**, **`quorum`** and
**`identity`**. *(All three extension tracks were `scoped` — spec landed, nothing vendored, no
model — when this entry was first written; `attestation` is vendored, pinned and modeled by the
end of the same release. The other two are vendored and scoped.)*

**The structure was built before the first extension model, because two existing gates would
have absorbed it rather than rejected it.** The coverage number is derived from `§(\d+\.\d+)`,
which is *document-blind*: `EXTENSION-ATTESTATION §5.7` and core `§5.7` are the same token and
core already carries a `5.7` row, so the first attestation citation would have been credited
to core's grid with `make coverage` reporting OK — a phantom row produced *by* the gate that
exists to prevent phantom rows. Separately, that gate and `spec-drift` both globbed
`tla/*.tla` **non-recursively**, so the obvious first reorganization (models into
`tla/attestation/`) would have hidden those files from both while both stayed green. Citations
are now extracted per track, a cross-track reference is written sigil-first (`§CORE:6.2`) and
excluded from every track's coverage set, and both tools read the registry instead of globbing.

`scoped` is a gated state rather than a note: a scoped track must declare no models and no
pin, so assigning a model file to one fails the build until the track is promoted **with** a
spec pin — the step where someone states which snapshot the results are about. Per-track
subdirectories are a deliberate later step, safe only now that a file falling out of a gate's
view is a build failure rather than a silent green. Ten teeth-tests on `trackcheck` and seven
on the track-aware `coverage`, each required to fail for its own stated reason.

Two defects surfaced while building it, both found by running rather than reading.
`spec-drift`'s per-engine exposure line had been publishing **"15/1169 model files"** — the
denominator was the flat glob counting gitignored TLC `_TTrace_` artifacts as models; it is
15/24. And the cross-track citation form's first draft, `CORE §6.2`, matched **23 lines of
ordinary prose** and then excluded each from that line's citation set, so a guard against
citations being miscredited was silently dropping them; the published `28 of 85` held only
because every affected section is cited elsewhere too.

### Fixed — a corrected bind-mount defect left its retracted reason in five places

The `:Z`→`:z` SELinux relabel fix reached the two `MOUNT` lines and `AGENTS.md` and stopped
there. The withdrawn justification — *"run the engines serially because concurrent `:Z`
relabels race"* — survived in `docs/COVERAGE-MATRIX.md` and `docs/STATUS.md` as live guidance,
in `docs/FINAL-ASSURANCE-SUMMARY.md` as history with no resolution, in `tla/Makefile`'s own
header contradicting the corrected line below it, and — the sharpest — in
`docs/CROSSCHECK-RESULTS.md`'s **copy-pasteable reproduce command**, which handed a reader the
removed flag on the exact directory and image the bug involved. Serial execution remains the
rule, for the `caps.mk` memory ceiling. *A corrected defect survives longest in a command a
reader runs*, and grepping the withdrawn **phrasing** rather than the subject is what found
all five.

### Fixed — eight documents claimed "no drift" while all three pinned spec files differed

The live protocol reached **0.8.2.11** with the models pinned at **0.8.2**, and `make
specdrift` measured **9 of 30 cited sections moved at this release**. Eight canonical
documents stated the opposite; `README.md` and `docs/STATUS.md` stated it as *"the pin matches
the live spec byte-for-byte across all three normative files."* All eight were true when
written. *(Phrased in the past tense deliberately: the live status is stated once, in the
sites `make driftclaim` gates, and a changelog entry is a statement about a release. The gate
flagged this paragraph's first draft for minting a second live-looking claim — which is the
`runcount` lesson, that a gate must never force you to edit accurate history to go green.)*

Three failures compounded, and the third is the one worth keeping. `make specdrift` is wired
`|| true`, so running it cannot fail — that is deliberate and still correct, because drift is
information rather than a build break. `make specdrift-gate`, which *does* fail on drift, was
invoked by no target at all. And the prose was tied to no derivation.

**`make driftclaim`** closes it: nine declared sites by anchor, each required to state the
derived status, with **silence treated as failure** because deleting the sentence is otherwise
the cheapest way to green. Teeth-tested four ways, including the direction that does not feel
like a failure — a document claiming drift that does not exist.

The transferable part is *why it is not in `check` or `matrix`*: every previous stale-claim
finding here went stale because we edited our own tree and missed a site. **This one went
stale when a sibling repo committed** — our tree untouched, every existing gate green, no diff
to fire on. A gate that runs only on our own diffs cannot reach a claim whose input lives
outside the repo. `driftclaim` says so in its own output and asks to be run at a release
boundary and on a schedule.

**Nothing proved here is falsified**, because every result is quoted against the pin.
`docs/SPEC-DRIFT-ASSESSMENT.md` is live again with the section-by-section measurement: eight
of the nine moved sections are additive, two of them this repo's own §4.7 finding landing as
spec text. **§4.7 is the one contradiction** — `connection_sequence_error` moved 400 → 409 and
`tla/ConnCodes.tla` transcribes 400. The pin is deliberately **not** being moved yet: the
keystone sibling has not upgraded, and re-targeting ahead of the peer that ships would put our
assumption ledger and their Lean proofs on two different spec texts.

### Added — the composition is checked at last, and the answer is a refutation (ledger T4)

`Core` is the composed whole-protocol model; `Conn` and `Store` are components. They were
checked independently with nothing relating them, recorded as assumption-ledger row **T4** —
the last OPEN row. It is now **CLOSED — ASSUMPTION FALSE**.

**`Core` is not a refinement of either.** It performs §4.6's two-step handshake in one step,
and a refinement mapping lets the abstract spec stutter while the concrete one moves — not one
concrete step performing two abstract ones. For `Store` it is starker: `Core` has no
counterpart for the refcount, referrer set, write critical section or admission state. So the
weaker claim was run instead — invariant implication under an explicit mapping
(`tla/RefMap.tla`), with the components `INSTANCE`d so what is asserted is **their own
invariant text** rather than a transcription. The two are not the same claim and the row does
not blur them.

**The contribution is the classifier.** A mapping that sends a component variable to a
constant makes that component's invariant a tautology, and a model checker reports the
identical green for "Core enforces this" and "the mapping asserts it" — the `StoreBounded`
vacuity reproduced inside the fix for the composition gap. `tla/CoreMapFree.tla` runs each
mapped invariant over **every type-correct valuation** instead of the reachable ones, one
graded run per verdict: **1 CARRIED — §4.2's dispatch gate — and 5 MANUFACTURED.**

Two by-products worth more than the headline. The first draft asserted all seven mapped
invariants and **went green**, six of them unable to fail. And TLC's own vacuity warning
caught **2 of the 6**: it flags a formula mentioning no variable, while the other four read a
`Core` variable *through* the mapping and are still unfalsifiable — `NoUseAfterFree` reads
`store` yet cannot fail because the referrer set is constant. A syntactic vacuity check
catches vacuity visible in the formula, not vacuity manufactured by a mapping.

Scope stated rather than assumed: **TLA+ only** (Spin has no instantiation mechanism for it,
so the composition claim is unexamined there), and `Reentry`/`Revoke` are deliberately not
mapped — a judgement, and the one claim here that was not run.

Matrix **268 → 277 runs**.

### Added — `make ledgercount`, because the count could not be stated safely without it

Closing T4 moved a verdict, and the ledger's row/verdict counts have been published **wrong
four times** ("eleven CLOSED rows" in five files; the Class-L verdicts in the tier audit;
"21 of 23 rows … the two open ones are L1 and L7", every number and the attribution wrong;
"14 CLOSED … 2 OPEN", stale within the session). Writing the new breakdown by hand meant using
the mechanism that had failed four times.

`make ledgercount` parses `docs/LEAN-SEAM.md` and checks row counts, verdict counts and **row
structure** (contiguous ids per class) against every declared prose site. It corrects a claim
this repo has been repeating: **`leanseam` and `leanproof` do not derive these numbers** — they
derive *theorem* counts, which is why none of the four errors was ever reachable by a gate.

**Its first draft anchored row counts only and would have gone green on all four** — every one
was a *verdict* error and three had the row total right. Found by flipping a verdict and
watching it pass. In `check` and `matrix`, since unlike `driftclaim` its input is our own file.

### Fixed — the N=3 work was documented in one file and stale in eleven other places

`docs/PROPERTIES.md` said *"Every Apalache result here fixes the peer/request set
(`Peers = {A,B}`)"* and *"Every model — TLC, Spin and Apalache alike — fixes the peer set at
2."* Both had been false since the N=3 work landed on 2026-08-30: `Reentry` and `Core` take
`CONSTANT N` on a directed ring and are checked at 2 **and** 3 on all three engines. Worth
noting the direction — **the stale claim made this repo look weaker than it was**, which is
the direction nobody re-reads a document to catch. Found while adding the T4 wall, by no gate:
`coverage` and `runcount` check a section set and a run total, and **nothing reads a prose
sentence about a bound.**

### Changed — `Register`'s writes are sequenced, and the last thin positive is retired

`Register`'s correct-model atomicity was **near-tautological**, disclosed as such since 0.8.2
and the only thin positive left in the repo. The five §6.2 writes landed in **one assignment**,
so `tree[h] ∈ {{}, FACETS}` restated the assignment and could not fail. Every tooth was on the
control side; the green side asserted the model's own shape back at itself.

The four non-committing facets now land **one per transition, in any order**, with the fifth
write and the §6.6 index publish as a single atomic **commit point**. The teardown mirrors it,
because the stale-*positive* hazard — dispatching a handler whose grant is already gone — runs
the other way. `RegisterAllOrNothing` and `IndexMatchesTree` now hold because of a
**discipline**, not because the model has no other state to be in.

**The evidence is a run, not a rewrite.** `RegisterSeqWitness` asserts the **pre-0.8.3**
invariant and requires it to be **violated**: the old positive is now false — the tree really
does reach `{"manifest"}` — while the properties that matter still hold. That rules out the
failure mode which would otherwise have replaced the old one: **a "sequenced" model whose
sequence is never reached is the same vacuity in new source code.** Adding write-loop labels
does not prove the loop is entered.

The property also got *stronger*, not merely honest: Apalache now proves `RegisterAllOrNothing`
**inductive (unbounded in steps)**, which was not worth doing while it was a tautology, and it
carries its own negative control — an inductive invariant with no control is the same trap one
level up. The matrix is **268 runs**.

Two consequences stated rather than absorbed:

- **`NoPartialResidue` is scoped to *settled* handlers.** A partial tree in flight is the model
  working; a partial tree at rest is the defect, and that is what §6.2 actually forbids.
- **`RegisterAtomicBug` now fails on `RegisterAllOrNothing`** — in TLC *and* in Spin, agreeing,
  which is the cross-check doing its job. That is the defect the control's own header names,
  "a half-built handler is dispatch-visible without its grant". The previous verdict was an
  incidental side effect of the collapsed-write shape, so this is a control that moved from
  failing for a neighbouring reason to failing for its stated one.

### Added — §5.10's skew tolerance `δ` is modeled, on all three engines

Ledger row **O4** was the only OPEN row facing nothing: §5.10's cross-clock temporal model
(0.8.1, W7 Knob 3) makes `δ` a declared Layer-1 input *alongside* the evaluation timestamp
`t`, and `Revoke.tla` modeled `t` and not `δ`.

The consequence was worse than "an input is missing". The module's cross-peer determinism
invariant — same Layer-1 inputs ⇒ same verdict — **could not express the case it was
guarding**, because the model had no way to make two peers differ on `δ`. It was
accidentally true: the same shape as a vacuous invariant, arriving through a missing variable
rather than a missing state.

`δ` is now a per-peer declared tolerance in `tla/Revoke.tla`, `tla/RevokeApalache.tla` and
`spin/revoke.pml`, transcribed as §5.10's two DENY rules negated (`expires_at + δ < t`,
`t + δ < not_before`), and the determinism antecedent carries `delta["A"] = delta["B"]`
because the clause puts it there: *"two peers with different declared `δ` may permissibly
differ at the boundary, the same way different `t` does."* **Apalache proves the strengthened
invariant inductive**, so this is unbounded in steps rather than bounded-exhaustive. The
matrix is **264 runs**.

Three runs, each answering a different question:

- **`RevokeDeltaBlindBug`** — the pre-0.8.3 antecedent, blind to `δ`. The defect it names is a
  verifier that *applies* a tolerance without *declaring* it, which is the only condition
  §5.10 attaches to `δ`: "it introduces no concealed state."
- **`RevokeDeltaWitness`** — `δ` decides a verdict with every other Layer-1 input held equal.
- **`RevokeDeltaZero`** — the clause states *"`δ = 0` reproduces today's exact behavior"*, so
  the equivalence is run rather than read. A sign error or a one-sided tolerance passes the
  default green, which admits `δ = 1` and therefore expects a wider window, and fails here.
  D13 applied to a green row: *"the invariants hold"* is satisfied by a model with the wrong
  validity window.

**The witness was wrong first, and that is the transferable part.** Its first draft did not
pin `revObserved`, so TLC satisfied it with a state where the two peers differed on *observed
revocation* and `δ` differed only incidentally — a witness firing for a claim it does not
support. It was caught by reading the counterexample trace, not the exit status. **A witness
that fires for the wrong reason is harder to notice than a control that does**, because
firing is the outcome a witness is supposed to produce: there is no red to investigate.

`make runcount` caught all 14 stale prose sites in one pass, including five per-slice table
rows. That is the gate doing precisely the job it was built for two entries below.

### Closed — §5.5a has a theorem per pattern form, and the seam gate caught the movement

The `hframed` finding this repo routed to `entity-core-keystone` was adopted. §5.5a admits
three pattern forms; the Lean isolation theorem covered one, which is the asymmetry the
assumption ledger was built to expose. It now covers all three —
`absolutePattern_names_one_peer` for the absolute named form (the residual we routed), plus
`canonSegs_absolute_frame_independent` and `wildcardPattern_peer_agnostic`, which keystone
proved unprompted and witness-checked for non-vacuity. **Three forms, three theorems, matching
the three canonicalization equations our symbolic theories carry one for one.** Ledger row
**L7 moves CLOSED-MODULO-H → CLOSED**; **L12** and **L13** are new rows; the ledger is 22 rows
with **one** Lean-facing residual left (L1).

**Both gates did their job on movement rather than on breakage**, which is the half that is
easy to get wrong. `leanseam` went red on the two digests and demanded the rows be re-read
before re-pinning; `leanproof` rejected the three new theorems **by name** as
`UNDECLARED_GATE`. A gate that asserted "37 declarations, all on the standard axiom set" would
have passed 40 — the new proofs are unremarkable except that nobody here had read them. A
proof arriving is a diff exactly as a proof breaking is.

**And the exchange corrected us twice.** We asked keystone to discharge `hframed` from a
syntactic side-condition, on our own written claim that the relative half was "genuinely
mechanical." They declined and measured why: the pinned mathlib-free toolchain ships
`String.splitOn`/`splitOnAux` and *zero theorems about either*, with `splitOnAux`
`@[irreducible]` over raw byte positions. We had diagnosed their comment as wrong about
`hframed`'s scope and then reproduced its error about `hframed`'s cost. Separately, re-reading
**L1** against the current definitions showed **this repo had its mechanism wrong**: `edgeOk`
derives the §5.5a granter frames from the chain, not from `localPeer`, so the resources
dimension — the one our row blamed — was never the source of the peer-dependence. It is the
`localPeer` frame on handlers/operations, plus a `peers` scope that *defaults* to the
evaluating peer. L1 stays CLOSED-MODULO-H with H correctly located.

The declared `String.dropRight` warning is **deleted** — keystone fixed it, and our note that
the replacement's `String.Slice` return type might be a blocker was wrong; they measured the
replacement over 21 inputs including multi-byte prefixes rather than stopping at typechecking.

### Added — a second gate on the Lean seam, and the reason it was needed

`docs/LEAN-SEAM.md` records which Lean theorem in the keystone peer discharges each
assumption our models make; `make leanseam` checks that the cited **text** has not moved.
Nothing checked that the text still **proves** what the ledger says it proves — and it turns
out nothing checked it anywhere. `lake build EntityCoreProofs` is called "the proof check"
in five places in that peer — the lakefile, the proof-library root, the peer profile's
testing contract and two status documents — and is invoked by no Makefile, script or
workflow in that tree, which has no CI directory at all. Ten rows of the ledger rest on named Lean
theorems — nine of the eleven Class-L rows are CLOSED, two are CLOSED-MODULO-H — and every
one of them rested on a build nobody ran.

The claim is also wrong as written, which is the more useful half. Each case was **built**,
not reasoned about:

- a `sorry` in a cited theorem → `lake` prints `Build completed successfully` and **exits 0**
  (a `sorry` is a *warning* in Lean);
- a hand-written `axiom` standing in for the proof → **exits 0**, and no warning at all;
- a proof that does not type-check → exits 1.

So an exit-status gate would have caught one failure mode in three, missing exactly the two
a proof check exists for. **`make leanproof`** therefore grades the axiom sets: all 37
`#print axioms` declarations in the peer's proof track *(40 as of the entry above — keystone
added three theorems, and the gate rejected them by name rather than absorbing them)*, exact set per declaration in both
directions against `lean/proof-gate.expect`, every ledger-pinned theorem required to be among
them, any undeclared warning a failure, and the toolchain required to be the Lean version the
peer itself pins. Five negative controls (`sorry`, substituted `axiom`, deleted gate line,
dropped proof file, broken proof), each required to fail for its own declared reason **and on
the declarations it names**, not merely by producing the right number of failures.

No Lean source is vendored here: the peer's tree is mounted read-only and built from a
scratch copy, because a fork would make the ledger a claim about our copy rather than about
the code that ships. **6 runs, counted separately from the matrix's 258** — they need a
sibling checkout, and every published number here is reproducible from a bare clone.

### Added — `make runcount`: the published run total is now derived, not transcribed

The matrix run total appeared in six places and was copied there by hand. It moved
238 → 242 → 258 in one week and two sites were missed — one of them the blurb that decides
what a public reader sees, which sat at **203**. D15 says a derived number is a claim and a
claim needs a gate; this is it. `tools/runcount.py` derives the per-target counts from the
gate tables in `tla/`, `spin/` and `tamarin/Makefile`, checks the total against every
declared prose site *and* against `docs/STATUS.md`'s per-slice table row by row, and fails if
a site stops making the claim at all. In `check` and `matrix`. The derivation was
cross-checked against a live matrix run — 258 both ways, and the per-engine breakdown matches
run-for-run.

Its own first draft failed the discipline it enforces: matching any three-digit number near
the word "runs", it flagged three files whose 203/204/238 are **true statements about the
past**. A gate that makes you delete accurate history to go green is worse than no gate in a
repo whose practice is keeping superseded claims visible. The live claim is now declared per
site by anchor, and what the gate does not assert is stated in it.

### Fixed — the Lean tier's negative controls graded on counts, not on what broke

Found by auditing the tier the same session it was built. Each control declared a
reason-code *count* —
`SORRY_AX: 3` — which any three contaminated declarations satisfy. That is the same defect as
the three Tamarin controls that once falsified their own reachability lemma alongside their
target, reproduced in a table written the same day it cited them. **A count is a symptom of
the outcome; the identities are the outcome.** All controls now declare which declarations
must carry each code, matched one-to-one with extras rejected, and `neg-broken` pins the file
*and* the error kind. Verified by re-running the mutation that count-grading accepted: now
rejected by name.

Two more from the same audit: a fifth control, `neg-dropfile`, covers a whole proof file
dropped from the library root — it builds clean, gates nothing, and produces **no**
`LEDGER_UNCOVERED`, so its signature differs from the deleted-gate case and it needed its own
row. And a missing `entity-lean` image used to be reported as a *toolchain mismatch*, telling
you to re-pin a version when the real fix is `make lean-image`.

### Fixed — "eleven CLOSED rows" was the wrong number, in five files

The Lean tier was argued for by *"eleven CLOSED rows of the ledger rested on a build nobody
ran."* Class L is eleven rows: **nine CLOSED, two CLOSED-MODULO-H**, and ten cite a Lean
theorem by name (L2 is closed by Lean's termination checker and names none). The conclusion
stands — ten rows did rest on that build — but the figure was recalled rather than derived,
and it was published five times before anyone counted the verdicts. D15 applies to the number
that makes the case for the work, not only to the numbers in the results table.

### Fixed — two run-count claims that were stale by two matrix growths

`docs/PROPERTIES.md` §C's grader inventory still read "Ten targets decide the 238 runs" with
238-era per-target counts, and `CANONICAL-DOCS.toml`'s blurb for the capstone still
advertised a **203**-run matrix. Both now say 258, with the per-target counts re-derived from
the gate tables rather than carried forward. This was the third time the chore had been
missed, which is what earned the `make runcount` gate above — the derivation is no longer a
chore anyone can skip.

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

Modeling §4.7 surfaced a **normative contradiction — inside one table**. An `authenticate`
frame arriving before any hello nonce has been issued is named explicitly by four normative
sites that disagree on the reason code **and** the status class:

- **§4.6 step 1**: "A mismatch — or an `authenticate` received before any hello nonce was
  issued — MUST be rejected with status **401 `invalid_nonce`**."
- **§4.7 table row 6**: "Nonce mismatch / absent / **pre-hello** (§4.6 step 1)" →
  **`invalid_nonce`**, **401**.
- **§4.7 table row 10**: "Out-of-order operation (e.g., **authenticate before hello**)" →
  **`connection_sequence_error`**, **400**.
- **§5.2a**: re-lists the connect-time rows, carrying only "Nonce mismatch" — the pre-hello
  case is dropped rather than answered.

Rows 6 and 10 are four rows apart in the same table, so *"follow §4.7"* is not a well-defined
position. All are MUSTs, and §4.7's own preamble — "an impl that collapses several of these to
one code, **or returns a different status**, is non-conformant" — makes each reading
non-conformant by the other's lights. The disagreement lands on `result.data.code`, the field
§4.7 exists to fix across implementations, so two conformant peers can hand a client
different instructions for the same failure.

The models check **both** readings rather than picking one: the row assignment for a
pre-hello `authenticate` is a constant, and row 10's reading violates §4.6 step 1 / row 6
transcribed as an invariant. Exhibited independently by TLC, Apalache and Spin — the only
control in the repo whose "defect" is a conformant reading of the spec.

**And the divergence is already shipped** — across **six** distinct behaviours for that one
frame: 401 `invalid_nonce` (38 peers), 400 `connection_sequence_error` (6), 401
`authentication_failed` (1), 409 `connection_sequence_error` (`entity-core-go`), 400
`handshake_failed` (`entity-core-rust` — a code that appears nowhere in the spec) and 400
`bad_request` (`entity-core-py` — a code in no §4.7 row). Nothing caught any of it: the
conformance oracle has no probe that sends `authenticate` before `hello`, and of §4.7's ten
self-declared MUST-emit rows roughly one is gated.

**Adopted and ruled 401 `invalid_nonce`** in `entity-core-protocol` — and corrected twice on
the way, by the repos that own what this one could only read. *(This entry first reported
**four** behaviours from a source read: 29 peers at 401, and `entity-core-py` as conformant.
Review of the draft found py emits 400 `bad_request` — a fifth. `entity-core-keystone` then
built the wire probe our packet said did not exist, measured 45 of 46 peers, upheld our source
read with zero disagreements across the 34 we committed to, resolved all 11 we could not, and
found a sixth behaviour. It also found that 39 of the peers answer identically pre- and
post-hello — they never model the case — so the cohort majority we cited as impact is mostly
fall-through, not agreement.)* Review likewise found four normative sites we had not carried
and showed our four-word remedy incomplete: §4.2's bare ordering MUST is what leads an
implementer into row 10. Full statement, both corrections and the disposition:
`docs/PROPERTIES.md` §D.1; the per-peer census and hand-off checklist are internal working
notes rather than part of this publication.

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
- **Two engines "covering" §5.5a, and covering different parts of it.** Namespace isolation is
  claimed by ProVerif/Tamarin *and* by Lean. §5.5a admits three pattern forms; our symbolic
  models carry all three (three `canon` equations), and Lean's isolation theorem is scoped by
  its hypothesis `hframed` to the **peer-relative** one — `hframed` is not an unproved lemma,
  it is *false* for the absolute form, which is why it scopes rather than weakens. So the
  **absolute named form**, the one §5.5a requires for cross-peer authority, has no Lean
  theorem. Redundancy counted by *engine* cannot see this — the audit that "closed every
  single-tool coverage gap" was right about engines and blind to it.
  *(This entry first read "two engines, one shared undischarged assumption", on the strength
  of one `canon` equation out of three that matched a hypothesis already formed. Both halves
  were wrong; corrected here, with the error kept on the record in `docs/LEAN-SEAM.md` §4.1.
  There is no ask on the ProVerif/Tamarin side and never was.)*

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

**docs/DISCIPLINE-CHARTER.md D15** — *a derived number is a claim; derive it from claims, and gate it.* D13
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
not applied to its own class — which is what earned **docs/DISCIPLINE-CHARTER.md D14**.

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
