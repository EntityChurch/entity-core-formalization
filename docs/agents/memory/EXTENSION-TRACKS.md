# Extension tracks — attestation, quorum, identity

**Symptom that brings you here:** you are about to model, re-model, or quote a result on
one of the three extension protocols, or you are about to repeat a census or a hypothesis
one of these tracks already took.

Each track is a different protocol with its own spec pin and its own denominator
(`TRACKS.toml`). Findings are indexed and sent on to the repository that owns the text;
this file is the *why it went that way*, not the register. Where a finding below is
described as *routed*, what was sent is the model, the section it contradicts, and the
run that shows it — the note carrying it is internal and is not part of what this
repository publishes.

---

## Attestation track (2026-09-07 onward)

**Attestation track, 2026-09-07 — three modules, and several of its rows are FINDINGS.**
`tla/AttestIndex.tla` (§5.7 indexes) and `tla/AttestLive.tla` (§4.3 liveness, §5.2/§5.3 walks).
The second one refutes the spec rather than transcribing it: **`§5.3 find_live_head` cannot
traverse a chain of three** — it filters successors by the full liveness predicate, which is
false for any attestation that has a live descendant, so the link leading to the head is never
"live" and the walk returns null where a head exists. Corollary, green and more interesting
than the bug: **§5.1's head-resolution step is an identity map**, which is *why the cross-impl
vectors cannot catch it* — the composite is right because the liveness filter already did the
work. T4's lesson on a different composition. Routed, with the cohort measured first:
all three implementations diverge from the pseudocode identically, and `entity-core-rust`'s
`SPEC-AMBIGUITIES.md` ATT-1 asked for a ruling on the neighbouring half in v1.0 — **v1.1
adopted one of its two interim changes**, and this defect is the residue of the other.
`tla/AttestRevoke.tla` closes the self-revocation abstraction `AttestLive` had declared, and
finds that **§4.3's `is_self_revoked` is used in normative pseudocode and defined nowhere** —
the class v1.0 Amendment 1 already fixed twice in that same function. The two natural readings
give `is_attestation_live` different answers, so it is not editorial. **The transferable piece:
a declared abstraction is a to-do list, not an absolution** — O9 exists because someone read a
D11 inventory-boundary note back as work rather than as disclosure, and that was cheaper than
finding a new section to model.

**SECOND ENGINE ON THIS TRACK, 2026-09-08 — ALL THREE modules, and read the arithmetic.**
`tla/AttestIndexApalache.tla`, `tla/AttestLiveApalache.tla` and `tla/AttestRevokeApalache.tla`.
**Both other tracks have a second engine on ONE of three modules** — `tla/QuorumKofNApalache.tla`
(§4.1, the K-of-N validator) and `tla/IdentityCertChainApalache.tla` (§3.6 topology dispatch,
where every identity K-of-N verdict is decided). `tla/QuorumSignerSetApalache.tla` and
`tla/IdentityRecoveryApalache.tla` (§9.4 compromise recovery) followed on 2026-09-09, and
`tla/IdentityProcessApalache.tla` (§6.3 the arrival path) the same day — so **the identity track
has no single-engine subject left** and `quorumtrust` is the only one anywhere on the extensions.
So **9 of 9** extension subjects rest on two engines and **none rests on one**;
**no** extension subject has a third engine, and none of the nine has a prover. Do not let "the
attestation track has two engines" become "the extension tracks are corroborated." **That
sentence is now derived rather than recalled** — `docs/CORROBORATION.md` is the per-subject
ledger and `make enginecount` fails when this line disagrees with the green tables, because the
figure it replaced was written by hand one day and was stale the next.

**F1 is now confirmed by two structurally different methods** — TLC enumerates the graph space,
Apalache answers one SMT query over it — and §5.7's index contract is now proved *inductive*
rather than bounded. **What a second engine does NOT buy is independence from the
transcription:** these files are the same author's reading of the same spec text, so a shared
misreading survives both. Engines do not move the 5th wall, and the routed findings still rest
on a human reading of the pinned text.

**WHAT IT DID BUY, ON THE THIRD MODULE, WAS A FINDING THE FIRST ENGINE COULD NOT SEE — AND IT
REFUTED THE READING IT WAS PORTED TO CONFIRM.** F5 said §4.3 defends one of its two recursions
against cycles, and inferred that termination rests on the **revocation** graph being acyclic.
`AttestRevoke.tla` could not check that: its `Init` restricts *both* pointers to lower indices,
so the assumption it needed was hard-coded in the only file that could have measured it.
`AttestRevokeApalache.tla` splits the restriction into two constants and lifts them one at a
time. Result: **per-relation acyclicity is not the assumption.** With the supersedes order
lifted and the revocation order kept, §4.3's equation has no unique solution on a configuration
where **both graphs are acyclic** — the dependency `4 --supersedes-reach--> 1 --revoked-by--> 4`
closes a loop across the *composition*, and §4.3's `visited` set is scoped to one hop of a
recursion that alternates between the two relations. What the section needs is a **common order
over both**, which content addressing supplies and no sentence states.
**The transferable piece: an assumption hard-coded into a model is invisible to that model, and
a second engine is worth most where you point it at the first one's `Init` rather than at its
invariants.** O6's shape again, and the third time a written-down pre-model hypothesis has been
right about *where* to look and wrong about *what is there*.

---

## Quorum track (2026-09-07 onward)

**Quorum track, 2026-09-07 — promoted `scoped`→`modeled`, three modules, 28 runs, SEVEN
findings.** `tla/QuorumSignerSet.tla` (§4.2 the resolver, with the clock), `tla/QuorumTrust.tla`
(§4.2/§4.2.1 the arrival-time trust model), `tla/QuorumKofN.tla` (§4.1 the validator). Routed
and indexed alongside attestation's. Four things to carry forward.

**A pre-model hypothesis is worth writing down PRECISELY SO you can find out how it was wrong.**
`TRACKS.toml`'s quorum note carried two, written before a line was modeled. One was right and
paid (*"model `not_before` and the clock explicitly from the start"* — with the clock in,
§ATTEST:4.3's undefined `not_expired` splits into two readings that disagree about whether a
**scheduled** membership change destroys the signer set). The other was right about the
assumption and **wrong about its status**: the closure is not *unstated*, it is *asserted* by
§4.2's cold-start posture and *falsified* by §4.2.1 non-trigger 1 and §8, three sentences in one
document. Both notes are left in `TRACKS.toml` unrewritten, which is the O6 discipline.

**The headline defect needs no attacker, and that is what makes it worth routing first.** On a
plain chain of three `quorum-update`s — nothing expired, nothing scheduled, nothing revoked —
§4.2 returns the roster the quorum was **created** with, because §ATTEST:5.3 returns null from
the oldest element and §4.2's fall-through is silent. A `quorum-update` that removed a
compromised signer is undone by the resolver that exists to apply it.

**A FINDING ROW CAN FLIP A CONSTANT *TOWARD* THE SPEC, AND THE GATE CANNOT TELL.** On this
track nothing is green under the spec's own constants, so the green sweep runs what the three
implementations actually do and the finding rows restore the spec's reading. That is the exact
inverse of a negative control, graded identically ("must fail, on this named invariant").
`tla/Makefile:TLC_FINDING`'s header now names the four rows this applies to and says the
distinction lives in each cfg's first line. **If you add a track where the spec-as-written is
not green, expect this shape and declare it; do not let the constants be the only record.**

**Measure the cohort, then measure it again for the next claim.** Three separate unanimous
results — none of the three implementations uses `updates[0]`; all three read `not_expired` as
full temporal validity; all three reject `threshold = 0` at `:create` when only §6.2 requires
it, and Go's comment credits that rule to a §3.1 that does not contain it. Three authors
deriving the same unwritten rule is the argument for writing it down. The exception is worth
as much: on the trust-closure finding the cohort follows the text **faithfully** and the text
is wrong, so "the impls work around it" is not a general law here either.

**Read O6 before repeating its reasoning:** the written-down hypothesis ("both walks lack a
bound, both rest on unstated acyclicity") was half right and *backwards on the interesting
half*. Modelling it, not re-reading it, is what separated the two.

**THIRD ENGINE-PORT ON THIS TRACK, 2026-09-09 — `tla/QuorumTrustApalache.tla`, AND IT CORRECTED A
CLAIM RATHER THAN FINDING A DEFECT.** §4.2.1's cache-invalidation contract has **three**
invalidation triggers. `tla/QuorumTrust.tla` has an action for two — trigger 3, *authority-
revocation arrival*, is in no action, no constant and no invariant — and what we routed
published *"the §4.2.1 contract is exactly sufficient"* naming
those same two. **A sufficiency claim over an incomplete rule set is a claim about a different
contract.** The correction is measured and comes out in the spec's favour: with the revocation
action added, `CacheMatchesValidated` is green and inductive over all three triggers. The
falsification of the old two-trigger form is a required-violation row (`OnlyAcceptInvalidates`),
not a paragraph. **The transferable piece is D13's cheaper half, arriving through a domain rather
than through a grading criterion: a green whose subject is a RULE SET is only as complete as the
model's ACTION SET, and nothing about it looks incomplete from inside** — every row passed, every
control had teeth, and the missing trigger produced no failure to investigate.

**AND Q5's REMEDY WAS THE WRONG CLOSURE.** Q5 said §4.2.1's "the cache reflects validated quorum
state" is false of §4.2's algorithm; the remedy that made everything green was a **read-side**
closure (only validated entries are readable). §8 permits `tree:put` to these paths, and
`tree:put(path, null)` is an unbind — which `QuorumTrust.tla`'s monotone tree could not represent.
With unbinds admitted the read-side closure holds and the cache still goes stale, because
non-trigger 2 forbids invalidating on the write that removed the entry. **What §4.2 needs is
write-side: the readable set changes only through validate-accept.** Routed as an amendment to Q5
rather than a new number; LEAN-SEAM **O11**
restated and still OPEN. Its cohort census for the two new directions was **declared not taken**
in that note — naming a census is not taking one — and was **taken later the same day**, which is
the part worth carrying.

**THE CENSUS ANSWERED BOTH QUESTIONS "UNANIMOUS" AND THE INTERESTING RESULT WAS IN THE MECHANISM,
NOT THE VERDICT.** *Nobody* implements §4.2.1 **trigger 3** (D20) and *nobody* invalidates on a
raw unbind (D21) — but Go **sees the delete and deliberately returns**
(`if evt.ChangeType == store.ChangeDeleted { return nil }`, under a header citing §4.2.1), Rust
**cannot see it** (no hook wiring), and Python **filters it out** on `entity is None`. A unanimous
outcome reached three ways is not the same finding as a unanimous decision: **Go's early return is
§4.2.1 non-trigger 2 implemented exactly as written**, which is the strongest evidence that the
write-side closure §4.2 needs cannot be derived from the text by anyone. *Record how each peer
arrives at the shared answer, not just that they share it.*

**And the census found a third thing neither question asked for, which is the argument for taking
one at all.** Rust does not implement **trigger 2** either — its only invalidation points are
local ops, its own tests name a `SyncTreeHook` that is not in the tree, and `TV-QF13` passes by
exercising the invalidation API rather than the arrival path. Two peers invalidate on a synced
arrival and one does not (**D22**, C3). Neither of the two questions would have surfaced it; going
to the source did.

---

## Identity track (2026-09-07 onward)

**Identity track, 2026-09-07 — promoted `scoped`→`modeled`, three modules, 33 runs, NINE
findings, and the LAST scoped track.** `tla/IdentityProcess.tla` (§6.3 the arrival convergence
point), `tla/IdentityRecovery.tla` (§9.4 compromise-recovery validation), `tla/IdentityCertChain.tla`
(§3.6 topology dispatch, §9.2 key confinement). Routed and indexed with the other two
tracks' (26 findings across five notes, 24 machine-checked). Five things
to carry forward.

**SECOND ENGINE ON §9.4, 2026-09-09 — AND THE TWO FINDINGS IT ADDED WERE ON A SUBJECT ALREADY
ROUTED.** `tla/IdentityRecoveryApalache.tla`. The corroboration half is unremarkable and worth
one sentence: every claim `IdentityRecovery.tla` makes reproduces, and §9.4's prohibition is now
proved *inductive*, so it covers unbounded replay where `MaxDeliveries == 2` covered two.
**The other half is D18's first payment.** The restrictions that mattered were not in `Init` —
they were a **cache variable with no key**, an **action the model did not have**, and a
**bounded counter**. §5.1 writes the §9.4 anchor at `contacts/{published_handle_hex}/…` and §9.4
reads it at `contacts/{old_handle_hex}/…`; a one-slot cache assumes those are the same handle,
and two ordinary events make them differ. **N1: a routine privacy rotation (section 13.3, dual-sig,
"the quorum doesn't sign this") moves the handle §9.4 will look up, produces no `quorum-publish`,
and no section requires a re-key or a re-publish — so the preventive rotation the spec recommends
removes the only compromise-recovery path, on all three implementations identically (C2).
N2: §6.3's `update_handle_cache_to` is named in a normative dispatch table and defined in no
section, and its two readings each satisfy ONE of two properties the spec states** — Go moves the
entry and breaks §6.3's idempotent semantic, Rust and Python retain it and make §9.4 usable once
per published handle, Python not implementing the handler at all (C3). The reading that satisfies
both is **measured green**, not proposed. Routed.

**SECOND ENGINE ON §6.3 THE SAME DAY — THE LAST SINGLE-ENGINE SUBJECT ON THIS TRACK, AND THE
FOURTH CONSECUTIVE TIME A LIFTED DOMAIN PAID.** `tla/IdentityProcessApalache.tla`, 40 runs, and
it closes **O22**. `IdentityProcess.tla` has three variables and `Next == UNCHANGED vars`: it is
**one arrival**. But §6.3 phase 2 dispatches handlers that WRITE state and §3.6 steps 2 and 3
READ THE TREE that phase 2a DELETES from, so the arrival path is a **loop that writes what it
later reads** and one arrival cannot represent either half of it. Every ported claim reproduces.
Two new findings, both compositions of two arrivals:
**N3 — a revocation deleted on arrival leaves the cert it names permanently valid.** I2 already
said the revocation is unbound; §3.6 step 3 looks revocations up *in the tree*, so the revoked
cert is then admitted on every later arrival. Section 6.4 reasons about exactly this exposure and
**bounds it by convergence latency** ("a peer that has not yet observed it will cascade when the
revocation arrives via sync"); the revocation arrives and the window never closes, and that
section's own MAY-level mitigation re-reads the same deleted entry. Rust and Python exposed (C2),
Go not (C3). **The green under `ConstInitOK` is half the finding** — it names which repair closes
it. **N4 — an `identity-retirement` is undone by the retired cert arriving again**, because phase
2 dispatches on `(kind, function)` and consults no state, and phase 1 readmits the cert (§4.5 says
nothing about liveness; §ATTEST:4.3 liveness is supersedes plus revocation). **It is violated
under `ConstInitOK`, which on this track is the UNION of all three implementations' repairs** — so
no cohort workaround touches it. Both candidate repairs are measured green. Routed.

**AND THE HANDLER CENSUS N2 DID NOT TAKE (D14 — enumerate the class, do not fix the instance).**
N2 said `update_handle_cache_to` is "named in a normative dispatch table and defined in no
section." **All SEVEN handler names in §6.3's table occur exactly once in the whole document — in
the table.** None is defined anywhere. That is why N4's two candidate repairs are both statements
about text that does not exist, and it is the reason the finding is against the silence rather
than against an implementation.

**A PORTED INVARIANT CAN CARRY THE OLD DOMAIN IN ITS ANTECEDENT, AND ONLY THE CHECKER FINDS IT.**
`UnbindOnlyOnRejection` reads `Unbound => ~Step1Admits` in the TLC module — correct there, because
step 1 was the only way to fail phase 1. `SeedRowReachable` reads `DispatchRow => ReachesPhase2`,
and ported verbatim it **FAILED the inductive step** on a cert that legitimately does not dispatch
because step 3 revoked it. The claim was always about the KIND GATE; the single-arrival domain
made the missing antecedent invisible. We predicted the first widening and not the second. Sixth
consecutive session in which running, not reading, is what caught something.

**"WRITE THE WITNESS BEFORE THE PROHIBITION" PAID, AND THE PRE-MODEL NOTE WAS RIGHT AND
UNDER-SPECIFIC.** `TRACKS.toml` and the scoping doc both flagged §9.4 before a line was modeled:
a negative-reachability claim is the highest vacuity risk there is, *a peer that does nothing
satisfies it*. Followed literally. `RecoveryFailClosed` — the prohibition — is **GREEN**;
`RecoveryAttainable` — the witness, written as a positive claim so a machine can check it — is
**VIOLATED on the same constants**. The risk the note named was a MODEL with no paths. What it
found is a **SPEC with no paths**: §6.3 phase 1 rejects `quorum-publish`, so §6.3's own phase-2
row `(quorum-publish, *) → seed_contacts_cache` never runs, so §9.4's trust anchor is never
stored, so cross-peer compromise recovery — §9.6's only remedy for a stolen key — cannot
complete. **A conformance vector that checks only the fail-closed rejection passes on a peer
that can never recover.**

**A FINDING ROW'S CONSTANTS NAME THE SUBJECT ON TRIAL, AND THE SUBJECT IS NOT ALWAYS THE SPEC'S
WORDS — SOMETIMES IT IS THEIR ABSENCE.** The quorum track added the second shape (a constant
flipped *toward* the spec). This track adds a third: two rows flip toward **one implementation**,
because on their question the spec says nothing and the three impls answer three different ways.
`tla/Makefile:TLC_FINDING`'s header now carries all three shapes and names the rows. Also new
there: **one invariant is the target of both a finding and a control**
(`AcceptedRecoveryIsQuorumSigned`), which is a good sign about the property and a trap for anyone
reading the table without the cfg headers.

**WHEN A TRACK CONSUMES ANOTHER TRACK'S KNOWN-DEFECTIVE OUTPUT, MAKE THE ASSUMPTION A CONSTANT
WITH A NEGATIVE CONTROL AND OPEN A LEDGER ROW.** Identity calls `§QUORUM:4.2 current_signer_set`,
which this repo has already measured and refuted (Q1). Transcribing it would have re-derived
Q1–Q7 wearing identity section numbers and routed them twice; assuming it silently would have
made the choice invisible afterwards, which the prior checkpoint predicted. Neither:
`SignerSetIsSound` is a constant, TRUE in the green sweep and FALSE in
`IdentityCertChainSubstrateBug`, whose job is to exhibit what every identity K-of-N verdict rests
on. **LEAN-SEAM O16 is a new SHAPE of Class-O row** — not "no tool here reaches this" but "we
measured this input, found it defective, and assumed it anyway, on purpose, visibly."

**THE COHORT CAN DISAGREE WITH ITSELF, AND THAT INVERTS THE ARGUMENT THE LAST TWO TRACKS RESTED
ON.** On quorum, three authors independently derived the same unwritten rule three times and the
unanimity was the argument for writing it down. Here all three added a kind branch before §6.3
phase 1 that the spec does not have, and **no two did the same thing** — Go no-ops and caches
nothing, Rust caches unvalidated, Python validates and caches both quorum kinds, and only Go
admits `revocation`. §9.4 keys its fail-closed rule on exactly that cache, so **the peers do not
interoperate on compromise recovery.** "The impls work around it" is not a mitigation available
here; measure the cohort for *each* claim, and expect the census to sometimes be the finding.

**TWO GATES BEHAVED AS THEIR OWN FIX PROMISED, AND ONE STILL DOES WORK THE DISCIPLINE HAS TO DO.**
`make runcount`'s per-track widening (written the same day, on the quorum track) **failed
immediately** on a fourth track with *"track(s) identity have runs but no group in
TRACK_PROSE_SITES"* — the first evidence that fix was a fix and not a restatement. The `scoped`
gate forced a `MODELING-PIN-*` before a model file could be declared, for the second time.
**But `make coverage`'s tripwires did not catch what a human had to:** the first citation pass
cited **30** sections and nine were background, impact or "the property this exists to provide"
mentions. The scope-disclaimer tripwire passed all thirty — it matches *disclaimers*, not
*background* — so the audit down to **22** was discipline, not gate. `docs/COVERAGE-MATRIX.md`
§3e states which nine and why two of the same shape were kept.
