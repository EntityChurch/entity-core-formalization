# Gates, and the numbers they do and do not read

**Symptom that brings you here:** a claim-checking gate is green and you want to know
what it actually asserts; a published figure went stale with every gate green; or you are
about to write a new gate.

The discipline behind all of this is `docs/DISCIPLINE-CHARTER.md` — **D13** (a gate must
assert its outcome), **D15** (a derived number is a claim) and **D20** (a matcher must not
depend on the value it checks). This file is the record of the individual sentences that
went stale and how.

## The matrix paragraph — four numbers, one sentence, one of them gated

⛔ **Four numbers, one sentence, ONE of them gated — and THREE of the four have now gone stale
here, each in its own way.** `make runcount` declares this paragraph a site and reads **the run
total** and nothing else.
- *The prover pair* said `15 / 14` until 2026-09-16, when the `resolution` subject made it
  17 / 16 — derivable from `PV_GREEN`/`TM_GREEN`, corrected, and wrong for as long as it took
  to notice.
- *"all 11 … modules checked by TLC + Apalache + Spin"* was a **bare universal quantifier over
  our own artifacts**, and adding a twelfth module on two engines made it false in the way
  D14's sixth instance describes — the set grew underneath the sentence. The repair is not a
  bigger number: it is naming the module that does **not** satisfy the quantifier, because
  `AuthoritySelect` has no Spin encoding and *"12 modules on three engines"* would have been a
  cleanly-incremented lie.
- *"100 negative controls and 13 non-vacuity witnesses"* were hand-maintained, correspond to no
  table this repo derives, and were **knowingly** left uncorrected here with that fact stated.
  That was defensible while nobody had touched them. This session added 8 controls and 4
  witnesses, so continuing to print `100` would have been publishing a figure known to be
  wrong — **the values are deleted and the SUBJECT named instead**, which is D15's fifth-shape
  repair (*state the subject, let the gate own the value*) applied the moment the disclosure
  stopped being true rather than at the next audit.
This is the unread-facet shape (D15, thirteenth) inside the paragraph that announces the gate,
and D20 is its sibling: ask of a gated sentence which of its claims the gate reads.

## The assumption ledger, and the facet a gate does not read

Two things are new and change how you read the rest. **`docs/LEAN-SEAM.md`** is the
assumption ledger — per abstraction in the models, the proposition relied on and the Lean
theorem (or sibling engine, or nothing) that discharges it, cited by content digest and
gated by **two** targets: `make leanseam` (has the cited *text* moved?) and `make leanproof`
(do the cited *proofs* still hold? — §7, 6 runs, needs the keystone sibling). It is where
the complementarity claim stops being prose. **It paid out on 2026-09-06:** the §5.5a
residual it found was adopted by the keystone peer, §5.5a now has a theorem per pattern form,
and both gates caught the movement — `leanseam` on the digests, `leanproof` on three new
theorems **by name**, refusing to accept a re-declare without a re-read. **Do not trust a
count of the ledger's rows that you did not derive:** it is 43 rows / 13 Class L, **16 OPEN**,
and a recalled figure has been published wrong here **five** times. Run **`make ledgercount`**
— it parses the ledger and fails when a declared prose site disagrees. *Note what this line
used to say and why it was wrong: "`leanseam` and `leanproof` print the live numbers." They do
not. They derive THEOREM counts and say nothing about rows or verdicts, which is exactly why
none of the four errors was reachable by a gate until `ledgercount` existed.*

***And the fifth was THIS SENTENCE, found 2026-09-09.*** It read **14 OPEN** while the ledger
held 13, with `make ledgercount` green over it — because this site declared **two** of the three
facets its own sentence states. `rows` was gated, `Class L` was gated, and `OPEN`, sitting between
them in the same clause, was declared nowhere. **A gate that reads SOME facets of a claim asserts
nothing about the rest, and the unchecked facet is the one that moves.** Exactly the shape found
the same afternoon in `spec-drift`, where the section COUNT was anchored and the live spec VERSION
beside it went from 0.8.2.11 to 0.8.2.15 with `driftclaim` green. The facet is declared now.
**Ask of any gated sentence which of its claims the gate actually reads** — a warning against
recalling a number is not a substitute for deriving the number, even when the warning is the
sentence carrying it.
**Row T4 closed 2026-09-06 by being refuted** — the composed `Core` model carries **one** of
six component invariants; the other five are manufactured by the refinement mapping
(`tla/RefMap.tla`, `tla/CoreMapFree.tla`). "The composed model is checked and the components
are checked" does not mean the composition is verified, and now there is a measurement of by
how much.
**`make coverage`** checks the coverage *claim* against the models' own `§`-citations,
because two rows of the grid turned out to be phantoms, and **`make runcount`** derives the
matrix run total from the gate tables and fails when a published site disagrees, because
that number went stale three times in one week. **The one protocol finding — §4.6 step 1 vs
§4.7's table, `docs/PROPERTIES.md` §D.1 — has been adopted and ruled** in
`entity-core-protocol` (401 `invalid_nonce`, the direction we argued). Read §D.1 before citing
it: the ruling came with two corrections to what we published, one from review of the text and
one from a wire measurement of the cohort, and **both are things this repo could not have found
from inside it.** Our source census was upheld exactly; our *remedy* and our *impact argument*
were not.
`docs/COVERAGE-MATRIX.md` is the section×engine map and the limits; `docs/STATUS.md` §Next is
the work-list; `docs/FINAL-ASSURANCE-SUMMARY.md` is the capstone.

**The failure mode this repo actually has is in the verification, not the protocol** — every
defect found by the last four audits was one, and they have earned three ratified
disciplines. The fourth (`docs/archive/status/AUDIT-2026-08-30-LEAN-TIER.md`) added no discipline and
is the more useful for it: five hypotheses, five confirmed, every one an instance of D13,
D14 or D15 — applied to work built the same session **under their own banner**. (The one exception is now `docs/PROPERTIES.md` §D.1 — a real contradiction in
the spec text, surfaced by modeling a section the coverage grid wrongly claimed was covered.)
