# CORROBORATION.md — how many engines carry each claim, and which claims rest on one

**This file is the declaration; `make enginecount` (`tools/enginecount.py`) is the gate, and
the GREEN gate tables in the three engine Makefiles are the evidence.** It is the enforcement
point for **AGENTS.md D16**: *a claim this repo publishes is carried by at least two
structurally different engines, and a claim that is not says so here.*

Read `docs/COVERAGE-MATRIX.md` for **which sections** are modeled and `docs/PROPERTIES.md` for
**what is claimed about them**. This file answers a third and narrower question that neither
does: **how many independent engines would have to be wrong at once for a published result to
be wrong.**

## What a row means, and the three things it does not mean

A **subject** is one modeled thing — a protocol mechanism, not a file. `revoke` is a subject;
`tla/Revoke.tla`, `tla/RevokeApalache.tla`, `spin/revoke.pml`, `tamarin/Revoke.{pv,spthy}` and
their controls are its files. Grouping is a **human declaration**, exactly as `TRACKS.toml`'s
track membership is, and the gate checks membership and completeness rather than correctness.

An engine counts for a subject **only if that engine's GREEN table has a row on one of the
subject's files.** Not if a file exists. That distinction is the first thing this gate found:
`tamarin/BindingReplayBug.spthy` is on disk with no `BindingReplay.spthy` beside it, so a
count by file extension would have published "two provers carry the replay result" on the
strength of a file **whose entire job is to fail**. (The claim *is* carried twice — Tamarin
proves no-replay as `Binding.spthy`'s `no_replay` lemma rather than in a separate theory — and
that is exactly why the two are declared as one subject below.) Controls, witnesses and
finding rows corroborate nothing: they are claims about what breaks.

**Three things a second engine does not buy, stated here because the number below is easy to
over-read.**

1. **It does not buy independence from the transcription.** Two models of one spec section,
   written by one author from one reading, share that reading. A misreading survives both.
   That is the 5th wall (`docs/ASSURANCE-MAP.md`) and no engine moves it — the only things
   that move it are a second *reader* and the cross-implementation census.
2. **It does not buy a different QUESTION.** TLC and Apalache are both model checkers over the
   same `.tla` transcription: independent *method* (enumeration vs one SMT query), same
   subject matter. Neither can express unforgeability, which is why every extension track's
   real security property is still undischarged (`docs/LEAN-SEAM.md` O5, O14, O19) with two
   engines on all nine extension subjects.
3. **It does not mean the two engines check the same PROPERTY.** `make coverage` verifies the
   two files are about the same sections; that they make the same claim about them is a human
   reading of both.

**What it demonstrably does buy** is on the record **four times**, and every time the second engine
found something the first structurally could not see: `AttestRevokeApalache` refuted F5 by
lifting an assumption `AttestRevoke.tla` had hard-coded into its own `Init`;
`QuorumSignerSetApalache` measured O20 the same way one track over; `IdentityRecoveryApalache`
found N1 and N2 by lifting three restrictions that were **not in `Init` at all**, which is what
promoted D18; and `IdentityProcessApalache` found N3 and N4 by lifting O22's single-arrival
domain. Every one is a case of pointing the new engine at the old model's **domain** rather than
at its invariants.

**EVERY extension subject now carries two engines, and that is a smaller claim than it sounds.**
All nine modules across `attestation`, `quorum` and `identity` carry TLC + Apalache. Neither
engine can express unforgeability, neither is a second *reader*, and **there is still no prover
on any of the three tracks** (`docs/LEAN-SEAM.md` O5, O14, O19) and no Spin encoding anywhere on
them. Read the column as `n`, not as a grade.

**What the five extension ports actually bought was not corroboration.** Four of the five found
something the first engine structurally could not see, every one by lifting a DOMAIN restriction
rather than by re-checking an invariant — and the fifth (`quorumtrust`, 2026-09-09) found that a
claim this repo had *published* was over two thirds of its own subject: §QUORUM:4.2.1 has three
invalidation triggers, `tla/QuorumTrust.tla` has an action for two, and the sufficiency result in
`ROUTING-2026-09-07-QUORUM.md` names two. The correction came out in the spec's favour and the
number of engines is not what produced it.

**AND THE SIXTH PORT PAID NOTHING, WHICH IS RECORDED HERE BECAUSE A LEDGER THAT LISTS ONLY THE
WINS IS A SELECTED SAMPLE.** `authority-select` (core, 2026-09-16) was ported to Apalache with
D16's own advice followed — *point the second engine at the first one's `Init`* — and there was
nothing there to point at: `tla/AuthoritySelect.tla`'s `Init` is an empty chain and every hop's
origin, provenance and path are chosen freely, which is already wider than any implementation.
Every claim reproduced and **no new finding came out of it.** What the port did buy is the thing
it was bought for and no more: the eight properties are **inductive** rather than true of chains
of three, and `MisclassificationCostsAvailabilityOnly` — which quantifies over all three readings
of §6.8's discriminator — is the row that most needed it, because as a bounded result it was a
statement about short chains and as an inductive one it is a statement about the rule.

## The standard, stated so it can be applied to a new module

> **Two structurally different engines, minimum, before a result is published as a property of
> the protocol.** One engine is a hypothesis with a machine behind it. Where a subject has one,
> it is listed under "Single-engine subjects" below with the reason and what it would take —
> never left to be inferred from the absence of a row.

A subject may sit at one engine for a while; that is a scheduling decision, not a licence to
describe it as verified. The rule the gate enforces is that **the exemption is written down**.

<!-- enginecount-site: docs/CORROBORATION.md :: Derived, not recalled -->
**Derived, not recalled: 35 of 37 subjects carry a green on two or more engines.** On the three
extension tracks it is **9 of 9**. Both numbers are re-derived by `make enginecount` from the
green tables on every run of `make check` and `make matrix`; every prose site that states them
is checked against the derivation, because the "five of the nine" in `AGENTS.md` was written by
hand on 2026-09-08, was true that day, and was stale the next morning.

---

## core — the Entity Core Protocol

| subject | track | files | engines with a green | n |
|---|---|---|---|---|
| `authority` | core | `spin/authority.pml` `tla/Authority.tla` `tla/AuthorityApalache.tla` | TLC · Apalache · Spin | 3 |
| `authority-select` | core | `tla/AuthoritySelect.tla` `tla/AuthoritySelectApalache.tla` | TLC · Apalache | 2 |
| `binding` | core | `tamarin/Binding.pv` `tamarin/Binding.spthy` `tamarin/BindingBug.pv` `tamarin/BindingBug.spthy` `tamarin/BindingReplay.pv` `tamarin/BindingReplayBug.pv` `tamarin/BindingReplayBug.spthy` | ProVerif · Tamarin | 2 |
| `bootstrap` | core | `spin/bootstrap.pml` `tla/Bootstrap.tla` `tla/BootstrapApalache.tla` | TLC · Apalache · Spin | 3 |
| `bounds` | core | `spin/bounds.pml` `tla/Bounds.tla` `tla/BoundsApalache.tla` | TLC · Apalache · Spin | 3 |
| `caveats` | core | `tamarin/Caveats.pv` `tamarin/Caveats.spthy` `tamarin/CaveatsBug.pv` `tamarin/CaveatsBug.spthy` | ProVerif · Tamarin | 2 |
| `chaintopology` | core | `tamarin/ChainTopology.pv` `tamarin/ChainTopology.spthy` `tamarin/ChainTopologyBug.pv` `tamarin/ChainTopologyBug.spthy` | ProVerif · Tamarin | 2 |
| `conn` | core | `spin/conn.pml` `tla/Conn.tla` `tla/ConnApalache.tla` | TLC · Apalache · Spin | 3 |
| `conncodes` | core | `spin/conncodes.pml` `tla/ConnCodes.tla` `tla/ConnCodesApalache.tla` | TLC · Apalache · Spin | 3 |
| `core` | core | `spin/core.pml` `tla/Core.tla` `tla/CoreApalache.tla` | TLC · Apalache · Spin | 3 |
| `core-refinement` | core | `tla/CoreMapFree.tla` `tla/RefMap.tla` | TLC | 1 |
| `deepchain` | core | `tamarin/DeepChain.pv` `tamarin/DeepChain.spthy` `tamarin/DeepChainBug.pv` `tamarin/DeepChainBug.spthy` | ProVerif · Tamarin | 2 |
| `deepchainn` | core | `tamarin/DeepChainN.pv` `tamarin/DeepChainN.spthy` `tamarin/DeepChainNBug.pv` `tamarin/DeepChainNBug.spthy` | ProVerif · Tamarin | 2 |
| `depthbound` | core | `tamarin/DepthBound.pv` `tamarin/DepthBound.spthy` `tamarin/DepthBoundBug.pv` `tamarin/DepthBoundBug.spthy` | ProVerif · Tamarin | 2 |
| `emit` | core | `spin/emit.pml` `tla/Emit.tla` `tla/EmitApalache.tla` | TLC · Apalache · Spin | 3 |
| `expiry` | core | `tamarin/Expiry.pv` `tamarin/Expiry.spthy` `tamarin/ExpiryBug.pv` `tamarin/ExpiryBug.spthy` | ProVerif · Tamarin | 2 |
| `malformed` | core | `tamarin/Malformed.pv` `tamarin/Malformed.spthy` `tamarin/MalformedBug.pv` `tamarin/MalformedBug.spthy` | ProVerif · Tamarin | 2 |
| `multisig` | core | `tamarin/Multisig.pv` `tamarin/Multisig.spthy` `tamarin/MultisigBug.pv` `tamarin/MultisigBug.spthy` | ProVerif · Tamarin | 2 |
| `multisigkn` | core | `tamarin/MultisigKN.pv` `tamarin/MultisigKN.spthy` `tamarin/MultisigKNBug.pv` `tamarin/MultisigKNBug.spthy` | ProVerif · Tamarin | 2 |
| `noescalation` | core | `tamarin/NoEscalation.pv` `tamarin/NoEscalation.spthy` `tamarin/NoEscalationBug.pv` `tamarin/NoEscalationBug.spthy` | ProVerif · Tamarin | 2 |
| `persistentrecheck` | core | `tamarin/PersistentRecheck.pv` `tamarin/PersistentRecheck.spthy` `tamarin/PersistentRecheckBug.pv` `tamarin/PersistentRecheckBug.spthy` | ProVerif · Tamarin | 2 |
| `reentry` | core | `spin/reentry.pml` `tla/Reentry.tla` `tla/ReentryApalache.tla` | TLC · Apalache · Spin | 3 |
| `register` | core | `spin/register.pml` `tla/Register.tla` `tla/RegisterApalache.tla` | TLC · Apalache · Spin | 3 |
| `resolution` | core | `tamarin/Resolution.pv` `tamarin/Resolution.spthy` `tamarin/ResolutionBug.pv` `tamarin/ResolutionBug.spthy` `tamarin/ResolutionDiscard.pv` `tamarin/ResolutionDiscard.spthy` `tamarin/ResolutionDiscardBug.pv` `tamarin/ResolutionDiscardBug.spthy` | ProVerif · Tamarin | 2 |
| `revoke` | core | `spin/revoke.pml` `tamarin/Revoke.pv` `tamarin/Revoke.spthy` `tamarin/RevokeBug.pv` `tamarin/RevokeBug.spthy` `tla/Revoke.tla` `tla/RevokeApalache.tla` | TLC · Apalache · Spin · ProVerif · Tamarin | 5 |
| `revokemech` | core | `tamarin/RevokeMech.spthy` |  | 0 |
| `store` | core | `spin/store.pml` `tla/Store.tla` `tla/StoreApalache.tla` | TLC · Apalache · Spin | 3 |
| `unforge` | core | `tamarin/Unforge.pv` `tamarin/Unforge.spthy` `tamarin/UnforgeBug.pv` `tamarin/UnforgeBug.spthy` | ProVerif · Tamarin | 2 |

## attestation — the signed-edge substrate

| subject | track | files | engines with a green | n |
|---|---|---|---|---|
| `attestindex` | attestation | `tla/AttestIndex.tla` `tla/AttestIndexApalache.tla` | TLC · Apalache | 2 |
| `attestlive` | attestation | `tla/AttestLive.tla` `tla/AttestLiveApalache.tla` | TLC · Apalache | 2 |
| `attestrevoke` | attestation | `tla/AttestRevoke.tla` `tla/AttestRevokeApalache.tla` | TLC · Apalache | 2 |

## quorum — K-of-N signer rosters

| subject | track | files | engines with a green | n |
|---|---|---|---|---|
| `quorumkofn` | quorum | `tla/QuorumKofN.tla` `tla/QuorumKofNApalache.tla` | TLC · Apalache | 2 |
| `quorumsignerset` | quorum | `tla/QuorumSignerSet.tla` `tla/QuorumSignerSetApalache.tla` | TLC · Apalache | 2 |
| `quorumtrust` | quorum | `tla/QuorumTrust.tla` `tla/QuorumTrustApalache.tla` | TLC · Apalache | 2 |

## identity — cert chains, rotation, recovery

| subject | track | files | engines with a green | n |
|---|---|---|---|---|
| `identitycertchain` | identity | `tla/IdentityCertChain.tla` `tla/IdentityCertChainApalache.tla` | TLC · Apalache | 2 |
| `identityprocess` | identity | `tla/IdentityProcess.tla` `tla/IdentityProcessApalache.tla` | TLC · Apalache | 2 |
| `identityrecovery` | identity | `tla/IdentityRecovery.tla` `tla/IdentityRecoveryApalache.tla` | TLC · Apalache | 2 |

---

## Single-engine subjects — every one of them, with the reason

Two as of 2026-09-09, and both are on `core`. The gate fails if this list and the tables above disagree in either direction. A
subject that gains a second engine and stays here reads as a gap it no longer is; a subject
that loses one and is not added here goes unnoticed, which is the failure this section exists
to prevent.

- **`revokemech`** — ZERO engines, and the only such row. `tamarin/RevokeMech.spthy` is genuinely non-terminating: it is excluded from `make matrix` by design, run standalone or skipped (`AGENTS.md` §Build). Nothing about the revocation *mechanism* theory is machine-checked, and the revocation *property* it was written beside is carried five ways by `revoke`. Naming it here is the disclosure; the alternative — leaving a file out of the ledger — is how a model nobody runs reads as a model that passes.
- **`core-refinement`** — TLC only. `tla/CoreMapFree.tla` is T4's classifier and `tla/RefMap.tla` is the refinement mapping it and `Core|CoreRefines` share; six of its seven rows are greens whose green IS a finding (a component invariant manufactured by the mapping rather than carried by the composition). Porting a *classifier* to a second engine would corroborate the classification, not the protocol, so this one is deliberately last in the queue rather than merely undone.

## The declared prose sites

Every file below states one of the two derived pairs, and `make enginecount` fails if any of
them drifts **or stops making the claim at all**. The list lives here, in the ledger, and
nowhere else — `runcount`'s shape, and for `runcount`'s reason: a site that quietly deletes its
claim is the failure mode a scattered marker cannot catch, because deleting the claim deletes
the marker with it.

*This list is also where the gate's first draft was wrong, which is why it is worth a paragraph.*
The markers were originally written **at each site**. The tool reads only this file, so six of
the seven were parsed by nothing and the gate went green while asserting one line of one
document. Reading the code did not show it; breaking all three of the newest claims and watching
the gate stay green did. **Sixth consecutive session in which a new gate's first draft was wrong
and only running it found out** — and this one is the D15 mechanism inside a D15 tool: the input
set was a claim, and nobody checked it.

<!-- enginecount-site: AGENTS.md :: extension subjects rest on two engines -->
<!-- enginecount-site: README.md :: subjects carry a green on two engines -->
<!-- enginecount-site: docs/COVERAGE-MATRIX.md :: have a second engine -->
<!-- enginecount-site: docs/ASSURANCE-MAP.md :: subjects carry even a second model checker -->
<!-- enginecount-site: docs/FINAL-ASSURANCE-SUMMARY.md :: subjects carry a green on two engines -->
<!-- enginecount-site: docs/CROSSCHECK-RESULTS.md :: subjects have a second engine -->
<!-- enginecount-site: docs/STATUS.md :: subjects overall and -->
<!-- enginecount-site: docs/PROPERTIES.md :: extension subjects have a second engine -->
<!-- enginecount-site: docs/status/FINDINGS-INDEX.md :: Extension MODULES with a second engine -->
<!-- enginecount-site: AGENTS.md :: subjects overall and -->
<!-- enginecount-site: docs/PROPERTIES.md :: subjects carry two or more -->
<!-- enginecount-site: CHANGELOG.md :: subjects on two or more -->

| Site | What it says there |
|---|---|
| `AGENTS.md` | the extension-track paragraph, beside the warning not to read "two engines" as "corroborated" |
| `README.md` | the extension-track preamble a public reader hits first |
| `docs/COVERAGE-MATRIX.md` §4 | the corroboration grid's live count — the sentence that carried a bare universal until it went false underneath someone |
| `docs/ASSURANCE-MAP.md` | the scope note explaining why no extension track owns a row |
| `docs/FINAL-ASSURANCE-SUMMARY.md` | the capstone's one-paragraph statement of reach |
| `docs/CROSSCHECK-RESULTS.md` | the scope qualifier on a historical blockquote |
| `docs/PROPERTIES.md` | the scorecard's scope note — **added 2026-09-09, and it had been stale since the day before.** It stated the count in WORDS ("five have a second engine … four are TLC-only"), so neither the gate nor a grep for the number reached it. Rewritten into the canonical `N of M` form specifically so a gate can read it |
| `docs/status/FINDINGS-INDEX.md` | the open-work table — **added 2026-09-09, and it had been stale for a day**, saying `5 of 9` while listing two modules that had gained a second engine the previous afternoon. Its own header says *"do not quote these from here"*, which is a disclaimer and not a gate; the site list had gone stale a second time, one day after the paragraph above recorded it going stale the first time |
| `docs/STATUS.md` | the rolling log's D16 entry — **added 2026-09-09, the day after the site list was written, because that entry stated both pairs and no gate read it.** The list is itself an input set (D15); it went stale within a day of being declared complete |
| `AGENTS.md` (second anchor) · `docs/PROPERTIES.md` (second anchor) | the OVERALL pair, **added 2026-09-16 after both had sat at `33 of 35` through a subject being added, with `make enginecount` green.** Both files were already on this list — anchored on the sentence stating the EXTENSION pair, which is a different sentence in a different section. **A site is an anchor, not a file: declaring a document does not declare its other statement of the same fact.** Two entries now point into each document, and the tool's `window_states_the_pair` learned to read a pair whose DENOMINATOR has moved, which is how all five stale sites went unseen |
| `CHANGELOG.md` | the `[Unreleased]` entry announcing this very standard — **added 2026-09-10, and it had been wrong in BOTH figures since 2026-09-09**, saying `31 of 35` and `7 of 9` while the gate derived `33 of 35` and `9 of 9`. **The fourth site missed by a list whose own three rows above record it going stale three times in one day** |

**Read those last four rows together, because they are one finding told four times.** This list
was declared complete, then extended on three consecutive occasions, each time by someone who had
just written a paragraph about it going stale. **The fourth miss is the sharpest**: `CHANGELOG.md`
is a **published** file — one of the four things a public reader actually gets — and the stale
sentence is *the announcement of the corroboration standard itself*, stating in the present tense
two numbers that the gate it announces derives differently. A feature's own release note is the
least likely place anyone re-reads for drift, and it is the most likely place to state a headline
figure.

**Why it stayed invisible to every other gate we have:** `enginecount` reads only this list, so an
undeclared site is outside its universe by construction; `retractcheck` matches *withdrawn
phrasings* and nothing here was retracted; `driftclaim` and `runcount` derive different numbers
entirely. Found by reading the `[Unreleased]` section for an unrelated reason. **The standing
lesson is the one D15 keeps restating and this repo keeps re-earning: a gate whose input set is a
hand-maintained list has moved the problem, not solved it** — the list is the claim. What is worth
having is that the cost is bounded and visible: four misses, all caught, all recorded here rather
than quietly appended.

## What is not in this file, and where it lives instead

- **No prover on any extension track.** That is not a single-engine row — it is a whole
  question no engine here asks. `docs/LEAN-SEAM.md` O5, O14 and O19 carry it, one per track,
  counted separately so the gap cannot shrink by being merged.
- **No Spin encoding on any extension track.** Same disposition: the extension subjects that
  read "2" above mean TLC + Apalache, and the core subjects that read "3" mean TLC + Apalache
  + Spin. The column is `n`, not a grade.
- **Which sections each subject covers** — `docs/COVERAGE-MATRIX.md`.
- **What each subject's greens actually claim** — `docs/PROPERTIES.md`.
