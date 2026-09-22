# Spec-drift assessment — the pin vs the live spec

> **LIVE — the pin is behind again, and this document is the measurement.** The models are
> pinned at `spec-data/v0.8.2/`; the live protocol is **0.8.2.21**, and `make specdrift`
> reports **14 of 31 cited sections moved**. §1 below is that measurement, taken 2026-09-06
> and re-derived **four times since** — twice on 2026-09-09, again on 2026-09-10, and again on
> 2026-09-12, because the upstream repo committed **0.8.2.15 through 0.8.2.21** across that
> window — **six separate
> commits, two of them while this document was being edited.** §1a classifies the two sections
> 0.8.2.16 added; **§1b classifies the two that 0.8.2.20/21 added — §5.4 and §6.8 — and it is
> the section to read, because both had been recorded in this document as `unchanged` inside
> arguments that leaned on their being unchanged.** 0.8.2.19 added a twelfth, **§5.8**, whose entire delta is **one backtick**: it is
> the sharpest example on record of this document's own standing limit — *a section-touch count is
> not a semantic delta* — and it is left in the count rather than filtered out, because the moment
> this measurement starts deciding which movements are "real" it stops being reproducible.
> §0 is the **per-track** table, new on 2026-09-09 and the reason
> this document had been telling one quarter of the truth. §2 onward is the previous cycle's
> — 0.8.0 vs 0.8.2, since resolved — kept because the method is the reusable part and because
> a repo that deletes its last drift record has no way to show the pattern is normal rather
> than alarming.

---

# 0. All four tracks — the measurement that did not exist until 2026-09-09

**`make specdrift` measured `core` and only `core` for the life of the tool.** It had no
`--track` flag: `spec-data/MODELING-PIN` and `track_models(root, "core")` were hard-wired.
When three extension tracks were promoted on 2026-09-07 it silently became a **one-of-four**
gate, and by 2026-09-09 **all three extension pins had drifted from live with every gate in
this repo green.** That is the `runcount` two-group-regex failure in a second tool — a
per-track gate that does not name every track is a per-SOME-tracks gate — and it is the reason
`measured_tracks()` now *derives* the list from `TRACKS.toml` and fails on a modeled track it
does not read.

| Track | Pin | Live tree | Files | Cited § moved |
|---|---|---|---|---|
| `core` | `spec-data/v0.8.2` | `entity-core-protocol/specs` | 3 differ | `make specdrift` reports **14 of 31 cited sections moved** |
| `attestation` | `spec-data/ext-attestation-v1.3` | `entity-system-architecture/specs/extensions` | 1 differs | `make specdrift` reports **`attestation` no drift** |
| `quorum` | `spec-data/ext-quorum-v1.2` | `entity-system-architecture/specs/extensions` | 1 differs | `make specdrift` reports **`quorum` no drift** |
| `identity` | `spec-data/ext-identity-v3.10` | `entity-system-architecture/specs/extensions` | 1 differs | `make specdrift` reports **`identity` no drift** |

**All three extension files DIFFER and no cited section moved, and both halves matter.** Each
diff is a single additive front-matter "dependency contract" block — a derived summary of the
spec's own sections, written per `GUIDE-EXTENSION-DEVELOPMENT.md` §3.3 — inserted *before*
`## 1. Overview`. **Zero lines removed, zero numbered section bodies touched**, all three at
the same declared version. So no model's transcription is affected and no routed finding
changes. The file-level `DIFFERS` is the honest report and the section-level `no drift` is the
one that answers "is any result here stale."

*Worth keeping for the next person who reads a clean number: the FIRST attempt at this
re-measurement returned "all three MISSING from live tree" on a wrong relative path, and would
have been read as "the extension specs have been deleted."* Run a term you know is present
before believing a zero (D15, ninth shape).

---

# 1. Live measurement — 0.8.2 pin vs 0.8.2.21 live

**Measured 2026-09-06; re-derived twice on 2026-09-09, again on 2026-09-10, and again on
2026-09-12.** Reproduce with `make specdrift`; the
prose sites that state the status are gated by `make driftclaim`.

| | |
|---|---|
| Modeling pin (`spec-data/MODELING-PIN`) | `spec-data/v0.8.2/` — Entity Core Protocol **0.8.2** |
| Live (`entity-core-protocol/specs`) | **0.8.2.21** · CBOR encoding 1.5 → 1.6 · type system also differs |
| **Sections the models cite that moved** | **14 of 31** |
| Sections whose movement contradicts a model | **1** (§4.7) |
| Sections whose movement lands on the **Lean seam** rather than on a model | **2** (§5.2, §5.6 — §1a) |
| Sections that moved where **every citation of them is an abstraction disclaimer** | **1** (§5.4 — §1b) |
| Green matrix against the pin | unaffected — every result is quoted against `v0.8.2` |

*The `Sections the models cite that moved` row read **11 of 31** until 2026-09-12, while the
banner above it and eight other sites read 12 and `make driftclaim` was green over all of them.
`CLAIM_RE` matches the sentence form ``​`make specdrift` reports **N of 31 cited sections
moved**``; this row states the same fact as a **table cell in a different notation**, so the
gate has never read it — the D15 thirteenth shape (a second copy of a gated fact the parser does
not see) in the very table whose two other stale facets are the reason that shape was written
down. Fixed by deriving, and left recorded rather than quietly corrected. It is not newly
gated: a third notation would go stale the same way, and the honest note is cheaper than a
regex that pretends otherwise.*

*The line-delta row that used to sit here (`+152 added, −33 removed`) has been **removed
rather than updated**, and that is the point of this note. It was a hand-derived figure
about the live tree with no gate behind it, sitting in the same table as two gated ones —
`driftclaim` reads the section pair and the version string and has never read it. It was
correct for 0.8.2.15 and silently wrong for 0.8.2.16 within the day. Rather than re-derive a
number nothing will re-check, the table now carries only figures a gate reads or a reader can
reproduce with `make specdrift`. Third facet of this same paragraph to go stale unread; the
other two are the version and the section pair, both now gated.*

*The denominator was **30** until 2026-09-09 and the row above said so in words the drift gate
does not read — the fourth time in this repo a stale figure has hidden in a paraphrase of a
gated claim.* It moved for a real reason: `section_block` required whitespace directly after a
section number, and every top-level heading in every spec here is written `## 4. Connections`,
so a model citing **`§4`** — which `tla/Conn.tla` and `tla/Core.tla` both do, about the §4
dispatch rules — resolved to nothing and was dropped from the denominator **silently**. The
same bug hid `EXTENSION-QUORUM` §1, §2, §7 and §8, and §8 is the `tree:put` clause Q5's whole
amendment turns on. Unresolvable citations are now a **build failure** rather than a silent
subtraction, which is also how eight `COVERAGE-MATRIX` document references were found sitting
inside the citation set wearing a `§` sigil they had no right to.

**The pin is not being moved yet, and that is a decision rather than a backlog item.** The
sibling `entity-core-keystone` has not upgraded to 0.8.2.19; re-vendoring and re-targeting
the models before the peer that ships has moved would put this repo's assumption ledger and
the peer's Lean proofs on two different spec texts, which is the one configuration that makes
`docs/LEAN-SEAM.md` unreadable. Re-vendor is sequenced *after* the sign-off, per
`spec-data/<pin>/MANIFEST.md` §"Re-vendor discipline".

## What moved, and what each movement costs

Classified by hand, because a section-touch count is not a semantic delta — the mistake §3
below records an earlier draft of this document making.

| § | model files | what changed | impact |
|---|---|---|---|
| §5.9 | 3 | **−152B** — a removed provenance citation (the three-impl measurement note) | **none.** The normative text is byte-identical |
| §3.3 | 1 | +4.9KB — per-status default `code` values, the default-code force, satisfaction mode | **none.** `Reentry.tla` cites §3.3 for the **wire frame**, not the status table |
| §3.6 | 4 | +488B — `peers` reachability note; the id-scope consequence sentence reworded | **none.** The four `Multisig*` theories cite §3.6 for `system/capability/multi-granter` threshold structure; no model encodes id-scope matching |
| §6.2 | 12 | +4.3KB — the default self-grant shape (0.8.2.3); 404/501 scope clarifications | **none.** `requested_scope`, `internal_scope` and `grant_scope` occur in **zero** model files; `Register`/`Bootstrap` cite §6.2 for the five-write lifecycle |
| §4.2 | 6 | +1.4KB — pre-hello `authenticate` → **401 `invalid_nonce`**; connect pre-authorized in *any* state | **confirms us.** The first half is this repo's own finding, landed. The second half is new unmodeled surface |
| §5.2a | 1 | +1.4KB — connect-time row widened to "nonce absent, or `authenticate` before `hello`"; new pre-dispatch row | **confirms us**, in a second site |
| §4.6 | 6 | +784B — the step numbering is a normative order; lowest-numbered failing step wins | new modelable surface, no contradiction |
| §6.5 | 6 | +891B — step 3 is a **gate**, not an ordering preference; names a foreign-namespace privilege escalation | new modelable surface. Models cite §6.5 for the verdict gate and dispatch-after-establishment, not step 3 |
| **§5.2** | **17** | **0.8.2.16** — `matches_scope` pseudocode now **dispatches on the scope's type**; new `scope_value_matches` helper | **none for any model here** — see §1a. Lands on the Lean seam |
| **§5.6** | **14** | **0.8.2.16** — `scope_subset` likewise dispatches; new `pattern_covers` helper; a type mismatch between child and parent is now a malformed grant | **none for any model here** — see §1a. Lands on the Lean seam, and this is the half with a routed finding behind it |
| §5.8 | 4 | **0.8.2.19** — **one backtick**, removed from a cross-reference table row (`` `EXTENSION-CONTINUATION.md` `` → `EXTENSION-CONTINUATION.md`) | **none, and it is the cleanest illustration this table has of its own limit.** One character, zero semantic content; the four `ChainTopology.*` theories cite §5.8 for chain-inclusion topology, not for that row |
| **§5.4** | **9** | **0.8.2.20** — `canonicalize` is now **total**: the two `error(...)` returns become a `NEVER_MATCH = "/never-match"` sentinel, `matches_pattern` gains a first arm refusing it in either operand, and every `validate_absolute_path` call site is ruled MUST-consume | **none — and for a reason no other row here has.** All **nine** citations are **abstraction disclaimers** (*"the §5.4 path matcher stays abstract"*, *"is Lean's / abstracted here"*). See §1b |
| **§6.8** | **10** | **0.8.2.20/21** — **+3.8KB**: the caller-specified-path check goes **act-neutral** (reads as well as writes) and MUST rather than voluntary; a new "the subject is the effective set" rule; and a new MUST selecting **which authority** the handler-level check runs against — *by who named the path, never by who initiated the chain* | **none.** The clause all ten citing models use — *"a revoked capability never passes a check"* — is **byte-identical**. The rest is new surface, and it lands inside `tla/Authority.tla`'s own abstraction. See §1b |
| **§4.7** | **3** | **+7.0KB** | **the one contradiction — see below** |

### §4.7 — the one section where the live text contradicts a model

`tla/ConnCodes.tla` and `spin/conncodes.pml` transcribe §4.7's status table. Four things
moved under them:

1. **`connection_sequence_error` moved 400 → 409.** `ConnCodes.tla`'s `NormativeStatus`
   maps it to 400 (via the `OTHER` arm, line 128). Against 0.8.2.19 that constant is wrong,
   and `StatusMatchesCode` would be transcribing a status the spec no longer fixes.
2. **`incompatible_key_type` is retired** — MUST NOT be emitted. Not modeled (the module
   declares the negotiation codes out of scope), so no impact beyond the transcription note.
3. **A new row**: unknown connect operation → `400 invalid_request`, in any state.
   Reachable in this module's phase machine, and currently unmodeled.
4. **A new half-open rule**: an unauthenticated `ping` after `hello` but before
   `authenticate` is `409 connection_sequence_error`. Also a phase-machine claim.

**The contested cell is resolved, in our favour.** `ConnCodes.tla`'s header documents
`ConnCodesSeqReadingBug.cfg` as *"not a bug we injected — it is a conformant reading of the
spec, and that is the point."* At 0.8.2.19 that reading is **no longer conformant**: row 10's
parenthetical was narrowed exactly as this repo argued (`docs/PROPERTIES.md` §D.1). So when
the pin does move, the model gets **simpler** — the contested-cell constant collapses and the
control demotes from "a conformant reading" to an ordinary injected defect. That is the whole
finding being banked, and it is worth noting the direction: **the drift here is a repo's own
argument coming back to it as spec text.**

## 1a. §5.2 and §5.6 — the two newest movements, and why the count is the wrong thing to read

These are the **two most-cited sections in the repository** — 17 and 14 model files. A reader
who stops at the count will conclude the drift just got much worse. It did not, and the
reason is worth stating precisely, because the same reasoning is what routes the finding.

**What actually changed is pseudocode, not prose.** Both sections carried a scope matcher
written as *uniform across grant dimensions*:

```
matches_scope(value, scope, local_peer_id):        ; §5.2, at the pin
  ; Uniform scope check for all grant dimensions.
    if matches_pattern(canonicalize(value, local_peer_id),
                       canonicalize(pattern, local_peer_id)):
```

At 0.8.2.16 both dispatch on the scope's declared type:

| scope type | dimensions | matcher |
|---|---|---|
| `system/capability/path-scope` | `handlers`, `resources` | canonicalize both sides, then §5.4 pattern match |
| `system/capability/id-scope` | `operations`, `peers` | **literal**; exactly two wildcard forms (`*`, trailing `/*`); **no §5.4 path transforms** |

This is **0.8.1 F40 finally reaching the pseudocode** — the upstream commit says so in its
subject (*"the id-scope pin never reached the pseudocode"*). F40 fixed the *prose* rule in
§3.6 two revisions earlier; §5.2's and §5.6's worked algorithms kept the uniform form, so the
document specified one thing in prose and a contradicting thing in the code a reader
transcribes. §5.6's new comment states the stakes in the spec's own words: *"Canonicalizing an
id dimension here widens authority **down a delegation chain**, which is where nobody
re-checks."*

**Why no model here is affected — and this is an argument, not a reassurance.** Every model in
this repo abstracts the matcher rather than transcribing it. The only dimension any engine
frames concretely is **`resources`** — the §5.5a granter-frame work in `tamarin/ChainTopology.*`,
`tamarin/DeepChain*`, whose `canon`/`covok` symbols are exactly the path-scope arm. `resources`
is path-scope at the pin **and** at 0.8.2.16, matched by canonicalization in both, so that
transcription is untouched. Checked the complement directly: the strings `matches_scope`,
`scope_subset`, `id-scope` and `id_scope` occur in **zero** model files across `tla/`, `spin/`
and `tamarin/`. No model encodes the uniform rule, so nothing here transcribed the sentence
that moved.

**Where it does land is `docs/LEAN-SEAM.md`.** The seam's Class-L rows face a Lean development
whose `matchesScope` (the §5.2 dispatch check) *is* typed by scope kind and whose `scopeSubset`
(the §5.6 attenuation check) is **not** — so the F40 fix reached one of the two sites in that
file and not the other, which is the same asymmetry the spec has just closed. Rows L1, L5 and
L6 all touch it. Routed as **K1**, machine-checked and with the cohort census, in
`docs/status/ROUTING-2026-09-09-KEYSTONE-SCOPE-SUBSET-TYPING.md`.

**And here the drift framing has to be corrected, in the document whose whole job is that
framing.** It is tempting — this section's first draft did it — to say *"0.8.2.16 moved and a
sibling now diverges."* **The divergence predates the movement.** §3.6's id-scope pattern
grammar is **normative in our own pin** (0.8.1, F40) and in keystone's v0.8.2.11 target;
0.8.2.16 repaired the §5.2/§5.6 *pseudocode that had been contradicting it* since 0.8.1. So the
drift measurement did not detect a new divergence — **it forced a re-read that surfaced an old
one.** Worth stating precisely, because the two are graded differently: a movement that breaks
something is a cost of being behind, and a movement that makes you look at something is a
benefit of measuring at all. This one is the second.

**The transferable piece, and it is a new shape for this document.** Every prior entry in the
table above answers *"does this movement contradict a model?"* Both of these answer **no** and
are still the most consequential movements measured here, because what they bear on is a
**sibling's proof artifact that our ledger cites** — an object `make specdrift` cannot see and
`make leanseam` reads only as a digest. *A drift measurement scoped to models under-reports
exposure in a repo whose published claims also rest on someone else's proofs.* That gap is now
named; it is not yet gated, and §5 of the ledger says why.

## 1b. §5.4 and §6.8 — the two that this document had already called `unchanged`

**Measured 2026-09-12, against live 0.8.2.21.** These are the movements 0.8.2.20 and 0.8.2.21
added, and the reason they get their own section is not their size. It is that **both were
recorded in this document as `unchanged`, in two sentences that used their stability as a
premise:**

- §1a's argument closes *"and §5.4 itself is unchanged"* — load-bearing, because §1a's whole
  claim is that the §5.2/§5.6 matcher movement costs no model, and one leg of that is the
  matcher §5.4 defines not having moved underneath it.
- §4's reading of the confused-deputy property says the door it lives behind is *"§6.8, **which
  did not move** and is cited by 8 model files … The property was modeled against stable text."*

Both sentences were **true when written**. Both are now **false in their premise**, and every
gate in this repository was green the whole time. That is the `driftclaim` class exactly — a
claim whose input lives in a sibling tree cannot be caught by anything that runs on our diffs —
but it is the first time it has landed on **a load-bearing clause of one of our own arguments**
rather than on a count or a version string. *The count going stale is an embarrassment; a
premise going stale is a different failure, and only re-reading found it.*

**Neither contradicts a model. The two reasons are different in kind, and the difference is the
part worth carrying.**

### §5.4 — the section moved in the one place nothing here models

0.8.2.20 makes `canonicalize` **total**. Its two `error(...)` returns become a sentinel,
`NEVER_MATCH = "/never-match"`; `matches_pattern` gains a **first** arm returning false for that
value in either operand; `validate_absolute_path` is named as the designed destination for the
diagnostic `canonicalize` can no longer raise, and **every one of its call sites is ruled
MUST-consume-the-return** (both call sites in that document had invoked it for effect and
discarded the result, one of them under a comment reading `; MUST — reject malformed peer_id
segment`). 0.8.2.21 then rules the **other** direction: *an unmatchable exclude excludes
everything*, because a "matches nothing" value is fail-**closed** in an include and
fail-**open** in an exclude.

**This is R11 folded** — this repository's own routed finding — and it lands in `§5.4`'s
pseudocode. So the interesting question is not whether it contradicts a model. It is that
**§5.4 is cited by 9 model files and all nine citations are ABSTRACTION DISCLAIMERS:**

| file | what the citation says |
|---|---|
| `tamarin/ChainTopology.{spthy,pv}`, `tamarin/ChainTopologyBug.{spthy,pv}` | *"the §5.4 path matcher stays abstract (the Canon/Cov fact tables)"* |
| `tamarin/DeepChain.pv`, `tamarin/DeepChainN.pv`, `tamarin/DeepChainBug.pv` | *"The §5.4 path-segment matcher is Lean's / abstracted; we model the FRAME the canonicalization uses — the §5.5a load-bearing bit"* |
| `tamarin/NoEscalation.pv`, `tamarin/NoEscalationBug.pv` | *"The §5.4 pattern-match arithmetic … is Lean's / abstracted here (verdict-interior wall); we model the order RELATION the verifier checks per link (§5.6 `is_attenuated`)"* |

Verified at the source, not from the comments: `NoEscalation.pv` gives `scope` a **two-point
abstract order** (`scopeAdmin`, `narrow(scopeAdmin)`) with `fun narrow(scope)` and no path
structure at all; `DeepChain.pv` declares `fun canon(bitstring, pkey)` with **three** rewrite
equations and an opaque `covok`, which models §5.5a's *frame* and not §5.4's *matching*. Nothing
in either could express `NEVER_MATCH`, a total `canonicalize`, or an arm order.

**So the movement is free, and the finding is what being free reveals.** §5.4 is a row of
`docs/COVERAGE-MATRIX.md` Matrix A — `| 5.4 | pattern matching | no escalation via attenuation |
| | | ● | ● |` — crediting **ProVerif and Tamarin** for a section every citing file declares out
of scope, for a property (*no escalation via attenuation*) that is **§5.6's order relation**, and
which **§5.6's own row already credits to the same two engines**. This is the §6.9 / §4.7 phantom
shape that D15 was written about, in the dimension `make coverage` says in its own output it does
**not** assert (*"the engine columns are still hand-maintained — a citation says a model is ABOUT
a section, not which engine verifies what"*). The disclaimer was accurate and the row still went
unread for the life of the grid.

**Not fixed by deleting the row**, and that is worth saying because it was the first instinct:
`make coverage` asserts the cited set equals the grid rows **in both directions**, so as long as
nine files cite §5.4 the row must exist. What is wrong is the two dots and the property label,
which are hand-maintained. Recorded here and in `docs/COVERAGE-MATRIX.md`; the numerator does
not move.

### §6.8 — 3.8 KB around a byte-identical clause

§6.8 grew by **+3.8 KB** across 0.8.2.20 and 0.8.2.21:

- the **caller-specified-path** rule goes **act-neutral** — *reads or writes* — and the check is
  promoted from voluntary to `[MUST]`. 0.8.2.20's own note says the measured harm was a `get`;
  0.8.2.21 rules the read carve-out **closed** and names the region it searched;
- a new **"the subject is the effective set"** rule: a handler MUST NOT act on a target
  `effective_targets` (§5.2) excluded, and MUST NOT widen the set;
- and the sharp one: **which authority the handler-level check runs against is selected by WHO
  NAMED THE PATH, never by who initiated the chain `[MUST]`**, with a three-row table —
  caller-named path → the caller's verified capability; handler-**derived** path → the executing
  handler's own grant; peer-root dispatch → **no check**.

**Every model citing §6.8 cites the "Capability validity" paragraph, and that paragraph is
byte-identical.** `spin/core.pml` and `tla/Core.tla` cite it as `NoServeWhenRevoked`,
`tla/Revoke.tla` and `tla/RevokeApalache.tla` as `RevokedNeverPasses`,
`tamarin/PersistentRecheck.*` quotes it verbatim (*"A revoked capability never passes a check,
even if the same capability passed a check earlier in the same operation"*). Ten files, one
clause, unmoved.

`tla/Authority.tla` is the one exception and it is the interesting one: it cites §6.8 only as the
**source** of the grant (*"does the handler executing this sub-dispatch hold a §6.8 grant?"*) —
its properties are §5.2's three rules, and §5.2's movement was already classified in §1a.

**So: no contradiction, and the largest piece of new modelable surface this document has
recorded.** It is new surface that lands *inside an abstraction this repo has already built*.
`Authority.tla`'s header states its own subject as *"the rules under test are about WHICH
authority is consulted and WHETHER it is consulted, never about what a grant contains"*, and its
`Covers` makes the SELF and GRANT authorities **deliberately disjoint** *"so that consulting the
wrong authority is observable"*. 0.8.2.21's new rule is a normative claim about exactly that:
which authority, selected by a property of the path. The machinery to falsify it exists here.

And the spec says the defect is **wire-invisible** — *"both readings produce a well-formed
response and differ only in which authority was consulted"* — which is the strongest possible
argument for a structural model over a conformance vector, and the D13/D17 shape: an obligation
no oracle can grade. Booked in `docs/STATUS.md` §Next, not modeled here; the pin is 0.8.2 and
this text is 0.8.2.21, so modeling it requires a re-vendor, which is a separate decision.

## What this measurement does not assert

- **Not that the models would pass at 0.8.2.21.** Nothing has been re-run against the new
  text and nothing can be, because the models transcribe 0.8.2. Only a re-vendor and
  re-validation can speak to the current spec, and that is the point of keeping the two
  statements apart.
- **Not that additive text is harmless.** "Additive" means it contradicts nothing modeled;
  §4.6's step-ordering rule and §6.5's step-3 gate are both new *obligations* a peer must
  meet, and neither has a model. They are backlog, not absolution.
- **Not that the 31 cited sections are the right 31.** Coverage is bounded by what the
  models chose to cite — the standing limit of this method, §3 below.

---

# 2. Previous cycle — 0.8.0 pin vs 0.8.2 live (RESOLVED)

> **Historical record.** This measured the drift that existed while the models were pinned at
> 0.8.0 and the protocol had advanced to 0.8.2. That gap was closed: the models were
> re-validated against `spec-data/v0.8.2/`, the normative surface 0.8.1/0.8.2 added was
> modeled, and `MODELING-PIN` moved to `v0.8.2` as the last step. Kept because it is what
> scoped that re-target, and because the method — derive the dependency set from the
> `§`-citations the models carry, not from a prose summary — is the reusable part.

**Measured 2026-08-27.** Reproduce with `make specdrift`.

Every result in this repository is a statement about the SHA-pinned snapshot in
`spec-data/`, not about the protocol as it stands today. That is the 5th wall
(`ASSURANCE-MAP.md`) restated as a practical matter: fidelity is to a *pinned text*, and
a pin ages. This document measures how far it has aged, by what method, and what that
does and does not mean.

It exists because the alternative — a reader assuming a formal-methods repository speaks
about the current protocol — is the exact overclaim this project was built not to make.

## Summary

| | |
|---|---|
| Modeling pin (`spec-data/MODELING-PIN`) | `spec-data/v0.8.2/` — Entity Core Protocol **0.8.2** *(moved 2026-08-28; this assessment records the drift that existed before the move)* |
| Vendored, not yet modeled | `spec-data/v0.8.2/` — hash-verified 2026-08-27 |
| Live (published `master`) | **0.8.2** |
| Core spec delta | 197 changed lines; 25 of 85 numbered sections |
| **Sections the models cite that moved** | **13 of 26** |
| Green matrix against the pin | still fully green (re-run 2026-08-27) |

Nothing previously published is falsified. The results remain reproducible statements
about the 0.8.0 design. What changed is that they are no longer *current*, and this
document is what makes the difference visible instead of implicit.

## Method

Deliberately dumb, because a subtle method is one we could be subtly wrong about.

A section counts as **unchanged** if and only if its pinned text — from its heading up to
the next heading of any level — occurs **verbatim** in the live file. No diff heuristics,
no fuzzy matching, no section-parsing applied to the live side at all. A section that
moved position but kept its bytes reads as unchanged, which is correct: models cite
content, not line numbers.

**The denominator is the models, not prose.** An early pass of this analysis took its
section list from `spec-data/v0.8.0/MANIFEST.md`, which names the sections the spikes
"care about." That list is a human summary and it undercounted: it gave 8 of 14 where the
models' own citations give 13 of 26. Every model in this repository is required to carry
the `§` it transcribes, so those citations are the dependency set the models *declare*.
That is the honest denominator, and it is the one used below.

### Negative controls

A drift detector that always reports drift is worthless, so the tool is controlled the
same way every model in this repo is:

| control | expected | observed |
|---|---|---|
| pin compared against itself | no drift, exit 0 | no drift, exit 0 |
| pin against itself, one 12-character edit injected inside §6.11 | exactly §6.11 flagged | exactly §6.11 flagged, 1 of 26, no false positives on the other 25 |

### What this method does not do

- It does not judge **significance**. A section flagged as moved may have changed by one
  word or been rewritten; the tool cannot tell you which. That is why the magnitude and
  classification below are done by hand — a section count on its own overstates the change,
  which is a mistake an earlier draft of this document made.
- It does not detect a change that is **semantically** relevant but lands in a section no
  model cites. Coverage is bounded by what the models chose to cite.
- It does not cover the extension protocols. Three of them (`attestation`, `quorum`,
  `identity`) **are** vendored as of 2026-09-07 and `attestation` is pinned and modeled, but
  `make specdrift` measures the `core` track's pin against the live core spec and nothing
  else. **The attestation pin has no drift measurement at all** — its upstream lives in
  `entity-system-architecture`, so the claim "our snapshot matches live" is one a sibling
  repo's commit can falsify with our tree untouched. That is the `make driftclaim` failure
  mode exactly, one spec body over, and it is open.

## What moved

Of the 26 core-protocol sections cited by the models:

| § | model files citing it | |
|---|---|---|
| §5.1 verification | 11 | **moved** |
| §5.5a granter-frame canonicalization | 10 | **moved** |
| §5.6 attenuation | 10 | **moved** |
| §6.2 system handlers | 10 | **moved** |
| §4.8 store-safety | 7 | **moved** |
| §5.2 verification algorithm | 7 | **moved** |
| §5.10 verdict determinism | 6 | **moved** |
| §3.6 capability types | 4 | **moved** |
| §4.2 pre-authorization rules | 4 | **moved** |
| §4.6 authenticate signature | 3 | **moved** |
| §4.10 resource bounds | 3 | **moved** |
| §6.1 registration | 3 | **moved** |
| §6.11 transport reentry | 3 | **moved** |
| §5.5 chain verification | **33** | unchanged |
| §7.3 signatures | **22** | unchanged |
| §5.7 | 9 | unchanged |
| §6.8 handler-grant gate | 8 | unchanged |
| §4.9 resilience | 6 | unchanged |
| §5.4 pattern matching | 5 | unchanged |
| §4.1 · §6.5 · §6.10 · §1.7 · §6.6 · §6.9 · §4.7 | 1–4 each | unchanged |

### Exposure by track

| track | model files | cited § | moved | files touching a moved § |
|---|---|---|---|---|
| TLA+ / Apalache | 13 | 21 | 11 (52%) | 11 / 13 |
| Spin | 7 | 17 | 10 (59%) | 5 / 7 |
| Tamarin / ProVerif | 52 | 13 | 7 (54%) | 35 / 52 |

**The drift is even across all three tracks.** An earlier draft of this assessment said it
"concentrates in the TLA+ track." That was wrong — 52%, 59% and 54% are the same number
for practical purposes — and it is corrected here rather than quietly dropped.

The real asymmetry is **depth, not breadth**: the two most-depended-on sections in the
repository, §5.5 chain verification (33 files) and §7.3 signatures (22 files), are both
unchanged, as are §5.4 pattern matching and §6.8. So the deepest and most widely shared
foundations are stable. What "moved" means in practice — and it is much less than the
count suggests — is measured in the next section.

> **Dated scope note, 2026-09-12 — accurate history, no longer a live claim.** This paragraph
> is about the **0.8.0 → 0.8.2** comparison and is left as written. In the *current* cycle
> (0.8.2 → 0.8.2.21) **§5.4 and §6.8 have both moved**, so the sentence *"the deepest and most
> widely shared foundations are stable"* must not be quoted forward — it is a measurement of a
> resolved cycle, not a property of this repository's dependencies. §1b has the live reading.
> Recorded here because a summary sentence that quantifies over a set someone else grows is
> D14's sixth instance, and this is the second document it has happened in.

## How much actually changed — magnitude, not just section count

**A section-touch count is not a semantic delta, and reporting it as one is misleading.**
An earlier draft of this document led with "roughly half the cited surface has moved,"
which is true of the section count and gives entirely the wrong impression of the change.
The measurement below is what that count is actually made of.

Across all 13 moved sections that the models cite:

| | lines |
|---|---|
| pre-existing text **removed or altered** | **16** |
| new text **added** | **105** |

Per section, the share of pre-existing text that changed is between 0% and 10%, and for
most sections it is 1–4%. §5.2, §5.10 and §6.11 — three of the sections that sound most
alarming — changed **0%** of their existing text; they are pure additions.

**The spec did not get different. It got more precise.** 0.8.1 and 0.8.2 are largely the
absorption of conformance findings — the `F32`, `F40`, `F48`, `CAP-1`…`CAP-7`, `RT-6`…`RT-14`
and `W7` tags running through the new text are implementation bugs and ambiguities being
written down as normative clarification. That is what a spec should look like two patch
revisions after a release.

### The 16 altered lines, classified

- **Status-code discrimination (§4.2, §5.1).** A blanket `403` became a discriminated
  `401` for authentication failure versus `403` for authorization failure. Before and
  after, **the request is rejected either way**. The models model accept/reject, not
  status codes.
- **Appended clarification (§4.6, §4.8, §4.10, §5.5a, §5.6, §6.2).** The original sentence
  is retained and extended — an added list item, an added ordering constraint, an added
  ceiling. Additive hardening, not reversal.
- **Two genuine semantic changes**, and both were checked against the models:

  | change | what it alters | do the models depend on it? |
  |---|---|---|
  | §3.6 `F40` — `id-scope` (`operations`, `peers`) is matched as a **literal string**, no longer via the §5.4 path `matches_pattern` | a real ALLOW bug class | **No.** The four models citing §3.6 (`Multisig*`) cite it for `system/capability/multi-granter` threshold structure. No model encodes id-scope matching at all, and §5.4 itself is unchanged. **⚠ 2026-09-12 — the last clause is now FALSE and is left standing as the record: §5.4 moved at 0.8.2.20 (`canonicalize` made total, `NEVER_MATCH`), which is this row's own premise going stale in a sibling tree with every gate here green. The row's verdict is unaffected — all nine §5.4 citations are abstraction disclaimers — but the argument now rests on §1b rather than on this clause.** |
  | §6.1 `CAP-1` — a handler grant must be "present and **§6.8-valid**" rather than "present and **non-empty**" | empty `grants` is now a legitimate handler class | **No.** The models citing §6.1 (`Register*`, `register.pml`) cite it as the tree/index source of truth for handler facets. No model encodes grant emptiness. |

**No property this repository proved has been contradicted by 0.8.0 → 0.8.2.** Not one of
the 16 altered lines weakens a modeled invariant — not revocation-never-passes, not
no-escalation, not deadlock-freedom, not unforgeability.

### So what is the actual finding?

Not "the proofs are stale and possibly wrong." It is narrower and it is still worth acting
on:

1. **New normative surface exists that no model covers** — §6.11 frame-write atomicity,
   §4.8 the unsynchronized-refcount use-after-free, §5.6 malformed temporal-field ingest.
   These are new territory to model, not contradictions of old results.
2. **The pin is two revisions behind**, so nothing here can *speak* to the current spec
   regardless of whether anything broke — and that distinction was previously implicit.
3. **The `§`-citations should be re-validated** against the new text, which is cheap now
   that the moved list is known.

## Reading the changes that matter

Section-level flags are not severity. These are the ones worth a human's attention first,
with the reasoning stated so it can be argued with.

**§6.11 transport reentry** — the spike-A modeling target. 0.8.2 adds a new MUST: frame
writes on a shared/pooled connection must be atomic with respect to each other. The
existing models do not encode frame-level write atomicity at all; they model the mutex
discipline around send+recv. This is new modelable surface, not a contradiction.

**§4.8 store-safety** — 0.8.2 names an unsynchronized reference-count decrement under
concurrent dispatch as a use-after-free and therefore a §4.9 no-crash violation. The store
model abstracts refcounts away. Again new surface, and squarely in the class this track exists for.

**§5.6 attenuation** — the `MIN_DEFINED` portability rules and, more sharply, a named
fail-open: a capability whose temporal field is unrepresentable is *malformed*, and a
verifier must not read it as absent, because absent means no expiry. `Expiry.pv` /
`Expiry.spthy` model expiry validity but not malformed-field ingest.

**§5.2 verification algorithm — and an honest correction.** 0.8.2 adds two normative
rules absent from the pin (verified: the strings `THREE-VALUED`, `is_sub_dispatch` and
`THE CONDITION IS THE FIELD` occur zero times in the pin and are present at 0.8.2). The
first requires the dispatch authority to be three-valued — SELF, GRANT, and an ABSENT case
that must deny — and states that collapsing it to a two-valued optional has no correct
default.

An earlier draft of this assessment claimed that `tla/Reentry.tla`'s `Gate(p) == TRUE` is
"the spelling the spec now names as the defect." **That overstated it and is withdrawn.**
Three things temper it:

1. §5.2's rule is addressed to *implementations* representing an authority value. A
   declared modeling abstraction is a different kind of object; `Reentry.tla` says
   plainly that the verdict is Lean's and is not modeled.
2. The underlying security property — gate on the handler's own grant, never on the
   propagated caller capability, which is the confused-deputy door — lives in **§6.8,
   which did not move** and is cited by 8 model files. 0.8.2's new §5.2 text explicitly
   defers to §6.8 for it. The property was modeled against stable text.
   **⚠ 2026-09-12 — "which did not move" is now FALSE, and this is the clause §1b was written
   about.** §6.8 grew +3.8 KB at 0.8.2.20/21 and is cited by **10** model files, not 8. The
   conclusion survives and the reason has to be restated rather than recalled: the clause those
   models actually consume — *"a revoked capability never passes a check"* — **is** byte-identical,
   so the property really was modeled against stable text. But *"the section did not move"* and
   *"the sentence we model did not move"* are different claims, and only the second one was ever
   true of the future. The new text also adds the MUST that decides **which** authority a
   handler-level check consults; see §1b.
3. `tla/Core.tla` does model gate denials (`GateEstablished`, `GateRevocation` are
   controls that can be false), so the track is not uniformly blind to a denying gate.

What survives, and is worth acting on: `Reentry.tla`'s gate is a **constant**, so
`NoDispatchWithoutGate` cannot fail there and the denial case is inexpressible in that
module. That was already a known backlog item ("model gate denials so the dispatch gate is
load-bearing"). 0.8.2 does not create the gap; it raises its value, because the denial
case now carries an explicit normative rule with a named ALLOW-bug lineage behind it.

## What this does not change

The green matrix was re-run against the pin during this assessment and is unchanged:

| engine | result |
|---|---|
| TLC | 7 modules, "No error has been found" ×7, zero violations |
| Apalache | 8 invariants × {base, step} = 16 runs, checker-clean |
| Spin | 6 modules × {safety, liveness} = 12 runs, `errors: 0` |
| Tamarin | 12 theories, 26 lemma verdicts, all `verified`, 0 falsified |
| ProVerif | 13 secure theories; security lemmas true with non-vacuity reachable |

That the matrix is green says the models still hold **against the pin**. It says nothing
about 0.8.2, and no re-run of the current models can, because they transcribe 0.8.0 text.
Only a re-vendor and a re-transcription can speak to the current spec. Keeping those two
statements apart is the whole point of this document.

## What happens next

**The snapshot is vendored.** `spec-data/v0.8.2/` is in the tree, copied byte-for-byte from
`entity-core-protocol`'s published `master` and hash-verified per file. An earlier version
of this section said the re-vendor was owned by that repo and this one could not do it;
that was wrong, and it traced to an `AGENTS.md` rule naming "the architecture repo" —
`entity-core-architecture`, which no longer exists. The rule is corrected. The source is
public, the copy is mechanical, and every byte is checkable by digest.

**The pin has not moved, and that is the point.** `spec-data/MODELING-PIN` still reads
`v0.8.0` because that is the text the models transcribe. Vendoring changes no result. If
the pin advanced on a file copy it would silently convert *"we vendored the new spec"* into
*"we verified the new spec"* — two claims separated by roughly the entire cost of this
project. `make specdrift` reads that file, so it keeps reporting the full distance and
notes that a newer snapshot exists but is unmodeled.

**The citation structure re-validated cleanly** against the new snapshot: no section added,
removed or renumbered, all inline sub-labels intact, and **0 of 35 model `§`-citations
broken**. The one structural addition is §6.11 (a′). So the new text is a clean target —
the work is modeling, not repair.

What remains is enumerated in `spec-data/v0.8.2/MANIFEST.md` §"What DOES need modeling
work" and sequenced in `STATUS.md` §Next: model the three genuinely new normative
requirements (§6.11 (a′) frame-write atomicity, §4.8 refcount use-after-free, §5.6
malformed temporal ingest), re-read the 13 moved sections against their transcriptions,
promote the gate-denial backlog item — and only then move the pin.
