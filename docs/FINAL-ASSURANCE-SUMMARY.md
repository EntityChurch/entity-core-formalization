# FINAL ASSURANCE SUMMARY — entity-core-formalization

**Status: certifies protocol 0.8.2; the live spec is 0.8.2.11.** This is the capstone note over
everything this repo produced: the TLA+ concurrency/liveness model and the
Tamarin/ProVerif active-attacker model of the Entity Core Protocol design — each now
independently cross-checked. It is written so a future reader (or a returning agent) can
understand *what was proved, how far it goes, and what it deliberately does not say*
without re-reading the underlying reports.

> **Which protocol: the `core` track.** `TRACKS.toml` declares **4 proof tracks**
> (`make trackcheck`). **Everything capstoned here is about `core`** — the Entity Core
> Protocol — and nothing in this summary speaks for the others.
> `attestation` became **modeled** on 2026-09-07 (two TLC modules,
> `docs/COVERAGE-MATRIX.md` §3c) and is deliberately **not** capstoned here: it has one
> engine, no prover model, and two of its results are findings against the spec rather than
> assurance about it. A capstone is a claim that a body of work is settled, and that track's
> is not. `quorum` and `identity` are vendored, unpinned and unmodeled.
> There is deliberately no repo-wide assurance figure — averaging a verified protocol with
> three others at three different stages produces a number true of nothing.

> *On version names.* Live documents say **"the design"** or cite the pin
> (`spec-data/v0.8.2/`). The phase reports below say **"V7"** because they were written
> against the V7 line and are historical record; 0.8.0 was the de-versioned cutover of that
> line and is **wire-identical** to it (`spec-data/v0.8.0/README.md`), so the older reports'
> results carry forward unchanged. Restating a version in prose is how a repo ends up
> publishing several answers to one question — the pin is the answer.

**The one-paragraph version for the team.** We ran formal verification on the *design*
and did as much as the time allowed. **TLA+** covers all of Core Protocol's
concurrency + liveness, and is cross-checked with **two independent engines**: an independent
**Spin** (Promela) re-encoding of every concurrency module — written from the spec, not
translated — and **Apalache** SMT proofs that turn the key safety invariants from *checked at
a bound* into *proven inductive (unbounded)*. **Tamarin + ProVerif** (two provers, lockstep)
cover the active-attacker surface — **14 lemmas closed by both**, plus `BindingReplay` in
ProVerif only. **Every `core` concurrency module is checked by all three engines of its family**
(that is per *module* and per *track*; at *section* granularity one core row still rests on one
engine — §3.3, and only as the *subject* of §6.11(a′) rather than as a property of its own; and
of the
nine extension subjects across `attestation`, `quorum` and `identity`, **9 of 9 subjects carry a green on two engines** and none is TLC-only, and **none of the
nine has a third engine or a prover at all** — derived by `make enginecount`, named per subject
in `docs/CORROBORATION.md`) — see `docs/COVERAGE-MATRIX.md` for the grid,
what each engine can and cannot do, and the exact bound on every claim. Every property is §-cited to
`spec-data/v0.8.2/`,
every secure result has a negative control with teeth, and the scope boundaries — above all the
**5th wall (spec↔model fidelity)** — are stated, not hidden. This is a strong machine-checked
**demonstrator, not a closed proof** of the protocol: it now needs **human review against the
vendored spec** and the remaining follow-ons (fuzzing/adversarial-authz for the *code*; Phase 3
extension protocols — the async family `EXTENSION-CONTINUATION/-SUBSCRIPTION/-COMPUTE` is
still gated on vendoring; `attestation` is vendored, pinned and modeled since 2026-09-07).

If you are resuming work, read this capstone first — the optional leftovers are enumerated
in §5 (Findings and residual risk).

> **Which spec version this capstone certifies.** Everything here certifies models written
> against the SHA-pinned `spec-data/v0.8.2/` — the protocol at spec version **0.8.2**. The
> live spec is **0.8.2.11** and `make specdrift` reports **9 of 30 cited sections moved**, so
> this capstone certifies 0.8.2 and nothing later. No result below is falsified by the
> movement — eight of the nine moved sections are additive, and §4.7's `connection_sequence_error`
> status change (400 → 409) contradicts `tla/ConnCodes.tla` only against text this capstone
> does not claim. `docs/SPEC-DRIFT-ASSESSMENT.md` has the section-by-section measurement.
>
> This was not always so, and the history is worth keeping: the models were pinned at 0.8.0
> while the protocol advanced to 0.8.2, and `docs/SPEC-DRIFT-ASSESSMENT.md` records how that
> gap was measured — from the `§`-citations the models themselves carry, not from a prose
> summary. That measurement is what scoped the re-target: the structure was completely
> stable (nothing added, removed or renumbered; 0 of 35 citations broken), so the work was
> **new normative surface to model**, not contradicted results. It is modeled, and the pin
> moved as the last step. §2a below is the record of what changed.

---

## 1. What this project was for (one paragraph)

The Lean proof-vector peer (in `entity-core-keystone`) already proved the
authority **logic** correct — attenuation monotone, deny-by-default, the verdict
enforces the per-edge check. That closes the implementation pure-core layer and is
**not** re-done here. Two formal questions about the **design** remained, each on a
layer Lean structurally cannot reach (`docs/ASSURANCE-MAP.md`, rows 4 & 5):

1. **Concurrency + liveness** — does the distributed protocol deadlock, livelock,
   race, leak, or stall under interleaved multi-peer execution? → **TLA+**.
2. **Active attacker** — can a Dolev-Yao network attacker forge a capability,
   escalate, replay, reflect, or run a confused deputy? → **Tamarin / ProVerif**.

This repo answered both at demonstrator altitude, against the SHA-pinned vendored
spec `spec-data/v0.8.2/`, with every model abstracting the Lean-owned verdict interior
away on purpose.

## 2. What was built — the three workstreams

| Phase | Workstream | Deliverable | Result |
|---|---|---|---|
| 0 (spike) | TLA+ (Spike A) | `tla/FORMALIZATION-REPORT.md` | GO — §6.11 reentry slice; **rediscovered the Class-G deadlock** as a counterexample, green after the fix |
| 0 (spike) | ProVerif + Tamarin (Spike B) | `tamarin/FORMALIZATION-REPORT.md` | GO — cap unforgeability proved **automatically** in both tools; linkage-bug control caught |
| 1 | TLA+ all-Core concurrency | `tla/PHASE1-FORMALIZATION-REPORT.md` | 7 subsystems, safety **+ liveness**, each with a teeth-proving negative control; composed 2-peer model deadlock-free |
| 1 | Tamarin/ProVerif active-attacker | `tamarin/PHASE1-FORMALIZATION-REPORT.md` | 5 lemmas (no-escalation, deep-chain frame, binding+no-replay, revocation, multi-sig), lockstep both tools |
| 2 | Tamarin/ProVerif surface-closure | `tamarin/PHASE2-FORMALIZATION-REPORT.md` | 7 more lemmas (caveats, depth, expiry, deep-N, K-of-N, no-replay-in-ProVerif, persistent re-check) + 1 documented non-closure |

| 2 (x-check) | Apalache + Spin cross-check of the TLA+ models | `docs/CROSSCHECK-RESULTS.md` | Concurrency modules independently re-encoded in Spin (incl. the Class-G deadlock) and their key safety invariants proven inductive (unbounded in steps) in Apalache; both engines agree with TLC on green and on every control. *At delivery: 6 Spin modules, 8 invariants over 5 modules. **Now 9 and 18 over 9** — the 0.8.2 coverage audit closed the rest.* |

The cross-check (the TLA+ track's independent corroboration) is **complete across every
modeled subsystem** — see §3 and `docs/CROSSCHECK-RESULTS.md`. **Nothing is deferred.** The
composed *Core-conjunction* inductive invariant in Apalache was carried from Phase 1 to the
0.8.2 audit as the one optional deferral, justified on the grounds that each invariant is
proven separately and Spin already reproduces the deadlock. The audit rejected both halves —
proving the conjuncts separately is exactly what a composition invariant is *not*, and the
deadlock is liveness, which Apalache cannot prove either way — and proved it instead.

## 3. Independent re-verification of every claim

Rather than trust the reports, the **entire model matrix was re-run from the pinned
container images** and each result graded against its expected verdict. All three
matrices reproduce exactly what the reports claim.

As of the 0.8.2 re-target this is a **single command** — `make matrix` — and it asks three
questions rather than one: do the properties hold (**green**), could they have failed
(**negative controls**), and does the model reach an interesting state at all
(**non-vacuity witnesses**). The third is new at 0.8.2 and closes a real gap: the TLA+ track
previously had no reachability assertions, so a trivially-inert model would have reported the
same green as a working one. `make check` remains the green-only slice and now says so.

Two follow-up passes hardened *how* each of the three questions is graded, after finding that
all three could be answered "yes" by a run that had not verified anything.

The **first pass** fixed three of the five graders. Every TLC negative control now declares the
exact verdict line it must produce, so a control broken by a typo (TLC exits non-zero for a
parse error exactly as for a caught defect) or one that has drifted onto a different property
fails the build. Spin controls must report a positive `errors: N`, not merely the absence of
`errors: 0`, which a compile failure also produces. Tamarin runs must be **wellformed** — the
prover exits 0 when lemmas verify even if its own checks failed, printing "the analysis results
might be wrong" on the way out, and four theories were shipping that warning unread.

The **second pass** found the same defect still standing in the graders the first pass had not
touched, and one worse than any of them:

- **`proverif-green` had no verdict gate at all** (15 runs). It ran `proverif $t.pv || exit 1`
  and graded on the exit status — while **ProVerif exits 0 even when a query is false**, a fact
  already written in the comment on the target immediately below it. A genuine attack found
  against any of the 15 secure theories would have reported green.
- **`proverif-neg`'s criterion was satisfied by the secure theory** (15 runs). It required "at
  least one `RESULT ... is false`" — but ProVerif reports a *reachable* event as a falsified
  `not event(...)` query, so the **non-vacuity witness** that 13 of the 15 secure theories carry
  also prints `is false`. Secure `Revoke.pv` passes the criterion its own control was graded by.
- **`apalache-neg` and `tlc-witness` graded on exit status with output discarded** (15 + 9 runs)
  — verbatim the defect the first pass fixed in `tlc-neg`. Apalache exits `255` for a
  configuration error and `12` for a counterexample; TLC exits `151` for an undefined invariant.
  Both scored as "the control caught its defect". Confirmed by pointing one of each at a
  nonexistent operator: both passed.

Both provers are now graded by **declared verdict tables** — every query and every lemma of
every theory states the verdict it must produce, and the run must produce exactly that set, no
more and no less. The green/control distinction lives entirely in the declared verdicts, which
is what makes "a control that failed for the wrong reason" a build failure. `apalache-neg` must
see `EXITCODE: ERROR (12)`; `tlc-witness` must see its own witness invariant named in the
violation. **Absence of a pass is not evidence of a catch**, and all five graders now encode it.

*The results themselves did not move.* Every verdict in the matrix was re-derived by hand
during this pass and matches what the reports claim; what was wrong was the gate's ability to
notice if they ever stopped matching.

| Matrix | Runs | Outcome |
|---|---|---|
| **TLA+** (TLC) | 59 | 11 base configs green + `Store`'s liveness slice; **36 negative controls each caught their defect** (invariant violation / deadlock / temporal-property violation); **11 non-vacuity witnesses each violated as required**. Clean sweep. Two modules new at the second gate audit — `ConnCodes` (§4.7) and `Bootstrap` (§6.9), for sections the coverage grid claimed were covered when nothing modeled them. |
| **ProVerif** | 30 | 15 secure theories — security query `is true` + non-vacuity query reachable; **15 bug controls each falsified** (`is false` + attack). Every query of every theory declares the verdict it must produce (`PV_EXPECT` / `PV_NEG_EXPECT`). |
| **Tamarin** | 29 | 14 secure theories `verified`, including each theory's `exists-trace` non-vacuity lemma; **15 bug controls each `falsified` + trace**. Graded per lemma against `TM_EXPECT` / `TM_NEG_EXPECT`. The 15th is `BindingReplayBug`, which was on disk but in no gate list — so `Binding.spthy`'s `no_replay` lemma had no control running at all. |
| **Tamarin `RevokeMech`** | 1 | **Expected non-termination confirmed empirically** — the backward search loops the regenerated `Valid` fact; the run was observed still executing after **2–8 hours** across two sessions (vs. the report's conservative ">130s"). The documented irreducible tool split, excluded from the matrix. NB: `timeout` wraps the `podman run` client, not the detached container — kill the container directly (`podman kill`) to reclaim it. |
| **Spin cross-check** | 53 | **All 11 modules** (reentry/conn/store/revoke/emit/register/core/authority/bounds/**conncodes**/**bootstrap**) × fix + defect variants. Every fix clean (safety + liveness); every defect caught the same way the matching TLC control fails (Class-G deadlock, handshake-ordering, store race, admission-bound, §5.1 revocation-ignored, §5.10 determinism-leak, emit mis-fire, marker-type, registration partial-residue, system-guard, and all liveness controls). |
| **Apalache cross-check** | 67 | **ALL 11 modules, 23 safety invariants** × {base, step} proven **inductive (unbounded in steps)** + 21 negative controls caught symbolically (`ERROR 12`), matching TLC. Added at 0.8.2: `InvUAF` (§4.8 refcount use-after-free) and ports for `Reentry`, `Authority`, `Bounds` and `Core` — four modules that previously had TLC coverage only. `CoreApalache`'s `InvComposed` is the **composed whole-protocol conjunction deferred since Phase 1**. |

The Spin/Apalache cross-check (details in `docs/CROSSCHECK-RESULTS.md`) is the
corroboration the TLA+ track had been missing — an independent re-encoding (Spin) *and* an
unbounded proof (Apalache) for every modeled subsystem, not a re-run of an existing result.

**609 runs in one `make matrix`, zero failures; all behave exactly as designed.**
(The v0.8.0 line was 76 model runs + 50 cross-check runs. The growth is the 0.8.2 normative
surface, the non-vacuity witnesses, the Apalache ports and Spin re-encodings the coverage
audit added, controls for all of it, and — in the second gate audit — `BindingReplayBug`, a
control that existed on disk but was in no gate list, leaving `Binding.spthy`'s `no_replay`
lemma with none, plus two whole new modules. `ConnCodes` (§4.7 connection error codes) and
`Bootstrap` (§6.9 pre-loaded handler safety) exist because the coverage grid listed both
sections as covered when **nothing modeled either**: §4.7's only mention in the repo was the
far end of a section range in one comment, and both of §6.9's were disclaimers saying
bootstrap is not modeled. Modeling §4.7 then surfaced a **normative contradiction in the
spec** — see §5. `docs/COVERAGE-MATRIX.md` §3a-b has the class and the `make coverage` gate
that now checks the claim against the models' own citations.)
Method note: the first
automated pass ran all three matrices concurrently, which produced four spurious
failures from an SELinux `:Z` bind-mount relabel race (three concurrent containers on
overlapping trees → transient "file not found" / empty output). Re-running those four
theories serially (ProVerif `MultisigKN`; Tamarin `BindingBug`, `Caveats`,
`CaveatsBug`) confirmed every one passes. No real regressions.
**That race was diagnosed and fixed on 2026-08-30, and this paragraph is kept as the
record of when it bit rather than as live guidance.** It was not a platform quirk but a
defect here: `tla/` and `tamarin/` are each bind-mounted by two images, and uppercase `:Z`
relabels a volume *private to one container*, so the second image's relabel invalidated the
first's. Both are lowercase `:z` now; `spin/`, owned by a single image, correctly keeps `:Z`.
Running the engines serially is still the rule, for the `caps.mk` memory ceiling.

## 4. What is proved — and the walls (honest scope)

Each result certifies a **model of the design at the pin**, not the prose and not the code.
The boundaries are stated in full in each report and `docs/ASSURANCE-MAP.md`; the
load-bearing ones:

- **5th wall — spec↔model fidelity (deepest).** Every guarantee is relative to the
  model faithfully transcribing `spec-data/v0.8.2/`. Mitigation: every modeled element
  cites its §ref; every negative control reproduces a *named, real* bug class from the
  protocol's own history.
  No tool closes this wall — review against the vendored spec owns it.
- **Verdict-interior + crypto walls.** §5.4 attenuation arithmetic is Lean's
  (abstract predicate / function symbol here); sign/verify are perfect symbolic
  primitives. Same trust boundaries Lean takes as axioms.
- **Bounded in TLC — but the key safety invariants are now proven unbounded.** TLC is
  exhaustive only at a tight bound (2 peers — 2 *and* 3 for `Reentry`/`Core` — 1–3 requests,
  small key sets) — the faithful
  worst case for the concurrency bugs (Class-G is deterministic at N=2). That bound is no
  longer the whole story: **Apalache proves each module's key safety invariant *inductive*
  (`Init⇒Inv`, `Inv∧Next⇒Inv'`), i.e. for all states, not just the enumerated ones**
  (**23 invariants across all 11 modules**, including the composed whole-protocol conjunction).
  What remains bounded-only is **liveness** (deadlock-/stall-freedom, settling, convergence) —
  Apalache does safety/inductive by construction, so liveness stays TLC + Spin at the modeled
  bound. Note also that "unbounded" here means unbounded in *steps*: the peer set is fixed at
  2 in every model.
- **Distributed-time wall.** Cross-peer verdict determinism under different `t`
  (§5.10) is TLA+'s lane; the provers abstract it. Conversely the active-attacker
  surface is the provers'; TLA+ abstracts the adversary.
- **Model, not code.** Hostile-byte rejection (malformed CBOR, oversized, protocol
  confusion) is the fuzzing + adversarial-authz follow-on (ASSURANCE-MAP row 6), not
  this project. validate-peer owns "impl conforms."

## 5. Findings and residual risk

**One finding routed to `entity-core-protocol` — since adopted there, and ruled: §4.7's
error-code table gives contradictory normative answers for the same input, and so does §4.6
step 1 against one of them.** An `authenticate` frame arriving before any hello nonce was
issued is named explicitly by **eight** normative sites across two published documents, four of
which we found and modeled; they disagree on the reason code *and* the status class. §4.6 step 1 says
**401 `invalid_nonce`**; §4.7 **row 6** restates that verbatim ("Nonce mismatch / absent /
pre-hello (§4.6 step 1)"); §4.7 **row 10** — four rows later, in the same table — says **400
`connection_sequence_error`**; §5.2a re-lists the connect-time rows and drops the case
entirely. All are MUSTs, and §4.7's own preamble ("an impl that collapses several of these to
one code, **or returns a different status**, is non-conformant") makes each reading
non-conformant by the other's lights — so *"follow §4.7"* is not a well-defined position. The
disagreement lands on `result.data.code`, the field §4.7 says clients key error handling off,
so two conformant peers can give a client different instructions for the same failure.

Exhibited independently by **all three TLA+-track engines** (`ConnCodesSeqReadingBug.cfg` /
`ConstInitSeqReading` / `DEFS=-DSEQREADING`) — the only control in this repo whose "defect"
is a conformant reading of the spec rather than something injected. **And it is not
hypothetical:** the 46-peer keystone cohort plus the three ground-up implementations show
**six** distinct wire behaviours for that one frame, four of them outside the spec's own answer
set, none of them caught — the conformance oracle has no probe that sends `authenticate` before
`hello`.

**The outcome is the more interesting part, and it cuts both ways.** The proposal was adopted
in the sibling protocol repo and **ruled 401 `invalid_nonce`** — the direction this repo argued
for. It was also corrected twice on the way there, by the two repos that own what we could only
read: review found four further normative sites and showed that our minimal remedy would have
left §4.2's ordering MUST pointing at no error row at all, and the keystone peer **built the
probe we said did not exist** and measured the cohort instead of reading it. That measurement
upheld our source census exactly, resolved the eleven peers we could not, and then showed that
39 of them answer identically whether or not a hello preceded — they never model the case, so
the majority we cited as impact is largely fall-through rather than agreement. Both corrections
are absorbed in `docs/PROPERTIES.md` §D.1, which is the full statement. The per-peer census and
hand-off checklist are an internal working document, not part of this publication. Per repo
discipline it was a proposal in the sibling protocol repo, never a spec edit here.

**Otherwise none new.** The models *re-derived* the known Class-G reentry deadlock (already
fixed upstream) and otherwise confirmed the pinned design admits no deadlock, store race,
resource leak, registration partial-residue, emit mis-fire, Layer-1 verdict leak,
bootstrap-ordering hazard, or — under an active attacker — forgery, escalation, replay, deep
cross-peer frame confusion, threshold bypass, or "trusted-forever" fail-open, at the modeled
bound.

**Residual risk, ranked (carried verbatim from the reports — not papered over):**

1. **TLA+ cross-check: complete across every modeled subsystem (was the highest risk;
   now retired).** The TLA+ track is no longer singly attested on any module: Spin
   independently re-encodes all **11** modules (reproducing the Class-G deadlock and
   reaching TLC's verdict on every defect), and Apalache proves **23 safety invariants across
   all 11** **inductive (unbounded in steps)** — both engines agreeing with TLC on green and
   every negative control (`docs/CROSSCHECK-RESULTS.md`). **Nothing is deferred**, including
   the composed Core-conjunction. The 5th wall is now **substantially narrowed** — two
   independent paradigms agree across the whole surface — but **not closed**: they could in
   principle share a misreading of the spec, so human review against `spec-data/v0.8.2/`
   still owns it. Note "unbounded" means unbounded in *steps*, never in *peers*: the peer set
   is fixed in every model — at 2 for nine of them, at 2 **and** 3 for `Reentry` and `Core`.
2. **Liveness is bounded; safety is now unbounded (TLA+).** As §4 — the inductive Apalache
   proofs lift the key *safety* invariants to all-N; *liveness* (deadlock-/stall-freedom,
   settling, convergence) remains small-scope exhaustive in TLC + Spin.
3. **~~One thin positive left.~~ None left — retired 2026-09-06.** `Register`'s correct-model
   atomicity was near-tautological, with teeth on the control side only, because the five §6.2
   writes landed in one assignment. They are now sequenced — four facets one per transition,
   the fifth plus the §6.6 index publish as a single atomic commit — so the invariants hold by
   a discipline rather than by the absence of any other state. The evidence is a run, not a
   rewrite: `RegisterSeqWitness` asserts the **pre-0.8.3** invariant and requires it to be
   violated, which is what rules out a sequencing that is never reached. `RegisterAllOrNothing`
   is now also proven **inductive** in Apalache — worth doing only once it stopped being a
   tautology. The other two were retired earlier: `Store`'s store-cardinality conjunct was de-vacuumed at 0.8.2 (multi-key,
   discharged by refcount correctness), and `Reentry`/`Core`'s inherited `StoreBounded` was
   **removed** in the follow-up pass — one literal key written once against a bound ≥ 1 could
   not fail, and `core.pml`'s Spin counterpart clamped the write at the bound it then asserted.
   It is now a declared structural exclusion pointing at `Store`, which owns the real
   §4.8/§4.9(b) obligation.
4. **One tool asymmetry is irreducible.** Mechanistic linear-token revocation does
   not terminate in Tamarin (`RevokeMech`); it stays ProVerif's lane while Tamarin
   uses the terminating trace-restriction idiom. This is a genuine tool-capability
   finding, documented, not a modeling gap.
5. **The ASYNC extension protocols are not modeled.** `EXTENSION-CONTINUATION/
   -SUBSCRIPTION/-COMPUTE` are not vendored; Phase 2 modeled only the §6.8 core
   property that governs them. Those three remain Phase 3, gated on vendoring.
   **Read this as narrower than it used to be:** it is a statement about the async
   family, not about extensions generally. `EXTENSION-ATTESTATION` is vendored,
   pinned and modeled as its own proof track (`docs/COVERAGE-MATRIX.md` §3c), and
   `EXTENSION-QUORUM` / `EXTENSION-IDENTITY` are vendored and scoped.
6. **The peer set is fixed — at 2 for nine modules, at 2 *and* 3 for `Reentry` and `Core`,
   and the remaining structural limit is the TOPOLOGY rather than the number.** TLC, Spin
   and Apalache all check `Reentry` and `Core` at both bounds; Apalache's results are
   unbounded in *steps*, never in *peers*. Three is what reaches the 3-cycle deadlock class
   two peers cannot form — but it is **one topology**: a directed ring, one outbound request
   per peer, one predecessor. A peer with several counterparties, or several concurrent
   outbound requests, is modeled nowhere. A defect first appearing at 4 peers, or at 3 on a
   non-ring dispatch graph, is outside every result in this document. Not attacked: the named
   technique is parameterized verification (Ivy's decidable EPR fragment, `mypyvy`, or
   TLAPS), which proves an inductive invariant for all N. `docs/STATUS.md` §Next item 5.

   *(This item read "Every model fixes the peer set at 2 — this is the largest structural
   limit" until 2026-09-06, and had been false since the N=3 work landed on 2026-08-30. It
   was one of **eleven** live sites carrying the stale bound across **six** files; the N=3 work
   reached `docs/STATUS.md` and nowhere else. Worth noticing the direction — the
   stale claim made this repo look **weaker** than it was, which is the direction nobody
   re-reads a document to catch, and no gate here reads a prose sentence about a bound.)*

6a. **The composition is checked and carries one component property.** `Core` is not a
   refinement of `Conn` or `Store`; under an explicit mapping, **1 of 6** component
   invariants is carried and 5 are manufactured by the mapping (`tla/RefMap.tla`,
   `tla/CoreMapFree.tla`, ledger row T4). "The composed model is checked and the components
   are checked" does not mean the composition is verified. `Core`'s own invariants are
   unaffected.
7. **The Lean↔model seam is written down, the Lean side is now gated, and the
   correspondence itself is still a human reading.**
   `docs/ASSURANCE-MAP.md` divides labour: Lean owns the authority-logic interior, TLA+ and
   Tamarin abstract it to a predicate / function symbol. That division is sound only if the
   property each model **assumes** of the abstraction is the property Lean **proves**, and
   that correspondence now lives in **`docs/LEAN-SEAM.md`** — 21 Lean theorems cited by
   `(name, file, sha256)`, one rejected correspondence pinned as such, each row carrying a
   verdict and any residual hypothesis. `make leanseam` fails when the cited Lean text moves.

   Two rows are **not** closed, and writing the ledger is what surfaced both. **L1:**
   `verifyChain` takes `localPeer` as an argument and §5.5a's granter frame threads it through
   the walk, so the structural verdict is not peer-independent and `Revoke.tla`'s cross-peer
   abstraction holds only where the two peers' frames agree — a restriction the model does not
   state. **L7:** §5.5a namespace isolation is covered by ProVerif/Tamarin *and* by Lean, and
   the two cover **different parts** of it. §5.5a admits three pattern forms; our symbolic
   models carry all three, and Lean's isolation theorem is scoped by its hypothesis `hframed`
   to the *peer-relative* one. The **absolute named form**, which §5.5a makes the required way
   to express cross-peer authority, has no Lean theorem at all. Coverage counted by *engine*
   cannot see that. *(Until 2026-08-30 this item read "both rest on the same unproved
   proposition… ProVerif asserts it as a rewrite rule". Both halves were wrong; the error and
   its shape are kept on the record in `docs/LEAN-SEAM.md` §4.1 rather than deleted.)*

   **The Lean side is now gated; the correspondence is not.** `make leanproof` (2026-08-30)
   builds the peer's proof track and asserts the axiom set of all 40 `#print axioms` gates,
   so a cited theorem cannot quietly acquire a `sorry` or an extra axiom. It had to be built
   here because nothing ran the proofs anywhere: the keystone peer documents
   `lake build EntityCoreProofs` as its proof check in four places and invokes it from none —
   and a `sorry` would not have failed it in any case, since Lean reports one as a *warning*
   and lake exits 0. **What remains a human reading is whether the theorem proved is the
   proposition the model assumes** — the gate detects that a text moved, not that a reading
   was right, and §4.1 is the record of one that was not. Replaying Apalache `.itf.json`
   counterexamples through the Lean executable model is the only proposed closure that puts a
   machine on that half of the wall. `docs/STATUS.md` §Next item 4.
8. **~~Two weak controls and two single-engine section rows.~~ Both closed, and neither was
   what it looked like.** All *three* controls that falsified their own reachability lemma —
   `ChainTopologyBug` as well as `DeepChainBug`/`DeepChainNBug` — now carry a §5.5a
   absolute-form leaf, which is frame-independent and so beyond reach of a
   canonicalization-frame defect; the honest path survives and each falsifies its target
   alone. §4.7 and §6.9 were not single-engine results but **phantom rows** — a section-range
   endpoint and an out-of-scope disclaimer, each counted as a citation — and are now real
   modules on all three engines. `make coverage` makes that class of mistake a build failure
   (`docs/COVERAGE-MATRIX.md` §3a-b). What remains single-engine is §3.3, and only as the
   *subject* of §6.11(a′) rather than as a property in its own right.

## 6. Bottom line

As a **design-assurance demonstrator**, the project met its objective: the design
holds — under concurrency (safety + liveness) and under an active Dolev-Yao attacker —
across every property modeled, each grounded in a §-cited check and demonstrated
falsifiable by a negative control. **Both tracks are now doubly-attested:** the prover track
by ProVerif + Tamarin agreeing in lockstep, and the TLA+ track by an independent Spin
re-encoding of every concurrency module *plus* unbounded Apalache SMT proofs of every module's
key safety invariant — both engines agreeing with TLC throughout. The two highest-value results
(the Class-G deadlock and the §5.10 cross-peer determinism MUST) are corroborated on both
dimensions. **Nothing is deferred** — the composed Core-conjunction inductive invariant, carried
as optional since Phase 1, was proved in the 0.8.2 audit (§2, §3). What remains is the follow-ons
that are out of this project's scope by design.

This is a strong machine-checked **demonstrator, not a closed proof.** It is a complementary
third leg beside Lean (logic) and validate-peer (conformance) — not a replacement, and not a
claim that "the protocol is proven." The honest next step is **human review of the models
against `spec-data/v0.8.2/`** (the 5th wall no tool can close), then the code-level follow-ons
(fuzzing + adversarial-authz) and Phase 3 extension protocols. State plainly, to anyone who
asks: we verified *models of the design*, as far as the time allowed, and said exactly where
the boundaries are.

---

*Underlying reports: `tla/{FORMALIZATION-REPORT,PHASE1-FORMALIZATION-REPORT,PHASE1-PROGRESS}.md`,
`tamarin/{FORMALIZATION-REPORT,PHASE1-FORMALIZATION-REPORT,PHASE2-FORMALIZATION-REPORT}.md`,
scope: `tamarin/PHASE{1,2}-SCOPE.md`, `tla/PHASE1-SCOPE.md`. Reproduce any run with the
per-row commands in those reports (`make tlc` / `make proverif` / `make tamarin`).*
