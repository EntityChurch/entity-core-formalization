# PROPERTIES — what is PROVEN vs only MODELED (the honest scorecard)

**entity-core-formalization · v0.8.2**

This is the load-bearing honesty document for the release. A formal-methods repo
that overclaims is the worst kind of overclaim, so this states — per property,
exactly — the *strength* of each result and where it stops.

> **Which protocol: the `core` track, and only it.** `TRACKS.toml` declares **4 proof
> tracks** (`make trackcheck`); **all four are modeled** — `core`, `attestation`, `quorum` and
> `identity` — and every property below is a statement about **`core`**. The three extension
> tracks have their own grids in `docs/COVERAGE-MATRIX.md` §3c, §3d and §3e and are
> **deliberately not on this scorecard**: it is a PROVEN/MODELED scorecard, and **9 of 9**
> extension subjects have a second engine (every module on all three tracks, Apalache) while
> none has a third engine, none has a Spin encoding and none has a prover.
> *(This sentence said "five have a second engine … four are TLC-only" until 2026-09-09, in
> words rather than in the canonical `N of M` form. It went stale on 2026-09-08 and again on
> 2026-09-09, and neither `make enginecount` nor a grep for the number could see it — a
> paraphrase of a live claim is invisible to a search for the subject and to a search for the
> canonical words alike, which is exactly D15's fifth shape. It is a declared `enginecount`
> site now.)* Listing them here would
> put results of a different strength in the same table. Their findings are indexed in
> `docs/status/FINDINGS-INDEX.md`. **No track is `scoped` any more**, so the gate that refuses
> a model file on a scoped track has no subject in the live registry — which is worth knowing
> before anyone relies on it to keep an unpinned track off this page.
>
> *(This paragraph said "`core` is the only modeled one" and "nothing vendored" until
> 2026-09-07. Both were false when written — all three extension specs were already vendored
> — which is the ordinary way a preamble goes stale: nothing derives it and no gate reads it.
> `make trackcheck` checks the 4/3/1 inventory at four declared sites and this was not one of
> them.)*

> **Which spec version this scorecard is about.** Everything below is machine-checked
> against the SHA-pinned snapshot named by `spec-data/MODELING-PIN`, currently
> `spec-data/v0.8.2/` — the Entity Core Protocol at spec version **0.8.2**, which is the
> current published line. The models were re-validated against that text and extended to
> cover the normative surface it added; the pin moved as the last step of that work, not
> the first. `make specdrift` reports the distance from the pin to the live spec and is the
> check that keeps this sentence true.

> **Frame, once, plainly:** this project is **design assurance, off the release
> critical path.** It machine-checks **models of the V8 design**, not the prose
> and not the code. It is **not** a claim that "the Entity Core Protocol is proven
> correct." It is a strong **demonstrator** — a complementary third leg beside
> Lean (authority logic) and validate-peer (impl conformance) — whose deepest
> assumption (spec↔model fidelity, the *5th wall*) **no tool here closes**.

## The three strengths of result, defined

| Tier | Meaning | Tools |
|---|---|---|
| **PROVEN (unbounded)** | Holds for **all** states / all N — a machine-checked **inductive proof** (`Init ⇒ Inv` and `Inv ∧ Next ⇒ Inv'`). Not "no counterexample found up to a bound" — *no counterexample can exist*. | Apalache (SMT/Z3) |
| **MODELED — bounded-exhaustive** | **Every** behaviour enumerated, but only at a **tight finite bound** (2 peers, 3–4 requests, small key sets). Sound within the bound; says nothing beyond it. | TLC, Spin |
| **MODELED — symbolic (Dolev-Yao)** | Holds against an **unbounded** active network attacker, but over **perfect symbolic crypto** (sign/verify are ideal primitives; no bit-level cryptanalysis). | Tamarin, ProVerif |

Every result below is additionally relative to the **5th wall**: it is a property
of the *model*, true only insofar as the model faithfully transcribes
`spec-data/v0.8.2/`. Each modeled element carries a V8 §-citation, each secure
result has a negative control that reproduces a *named, real* bug class, and each
module has a **non-vacuity witness** proving it reaches an interesting state at all —
that is the mitigation, not a closure. Human review against the vendored spec owns it.

---

## A. Concurrency / distributed correctness (TLA+ track)

### A1 — PROVEN unbounded (Apalache inductive): 23 safety invariants / 11 modules

These are the key **safety** invariants of each concurrency module, proven
inductive — they hold in every reachable state, for any number of peers/requests,
not just the enumerated ones.

| Module | Invariant (operator) | V8 basis | What it proves |
|---|---|---|---|
| Revoke | `InvDet` (`VerdictFnOfLayer1`) | §5.10 | verdict is a function of Layer-1 only — no cross-peer/time leak |
| Revoke | `InvRev` (`RevokedNeverPasses`) | §5.1 | a revoked capability never produces a pass |
| Store | `InvRace` (`StoreRaceFree`) | §4.8 | concurrent admits cannot race the store past its gate |
| Store | `InvBound` (`ResourceBounded`) | §4.9(b) | the store stays within its admission bound |
| **Store** | **`InvUAF` (`NoUseAfterFree`)** | **§4.8 (0.8.1 RT-13a)** | **the content-store lifetime refcount never frees an entity under a live referrer** |
| Conn | `Inv` (`HelloImpliesNonce ∧ NoEstablishWithoutNonce`) | §4.6 | no connection established without the issued-nonce handshake |
| Emit | `InvIff` (`EventIffRealWork`) | §6.10 | an event fires **iff** real work happened (no phantom/no-op events) |
| Emit | `InvType` (`EventTypeCorrect`) | v7.74 B2 | the emitted event type matches the work done |
| Register | `Inv` (`SafeSys ∧ NoUserAtSystem`) | §6.2 | system-namespace guard holds; no user registers at a system path |
| **Reentry** | **`InvFrame` (`FramesNotInterleaved`)** | **§6.11(a′)** | **two frames' bytes never interleave on a pooled connection** |
| **Authority** | **`InvGrantless` / `InvEntry` / `InvResource` / `InvTarget`** | **§5.2** | **all four 0.8.2 dispatch-authority rules** |
| **Bounds** | **`InvBrake` / `InvCount` / `InvCodes`** | **§5.9 / §4.10(b)** | **depth brake before TTL; single decrement; distinct reason strings — over SYMBOLIC constants** |
| **Core** | **`InvComposed`** | **all of the above, together** | **the composed whole-protocol safety conjunction** |
| **ConnCodes** | **`ReasonCodesDistinct` / `StatusMatchesCode`** | **§4.7** | **distinct failures never share a reason code; each code carries the status the table fixes — over BOTH permitted readings of the contested §4.6/§4.7 cell** |
| **Bootstrap** | **`InvAllOrNothing` / `InvRegGate` / `InvConnect`** | **§6.9** | **nothing dispatch-visible before all its facets exist; registration only after all three bootstrap handlers do; connect pre-authorized** |

Five of these deserve a note:

- **`ConnCodes` and `Bootstrap` exist because the coverage grid was wrong about them.**
  §4.7 was listed as an Apalache-only result and §6.9 as a TLC-only one; in fact **neither was
  modeled at all** — §4.7's sole mention in the repo was the far end of a section range in one
  comment, and both of §6.9's were disclaimers saying bootstrap is not modeled
  (`docs/COVERAGE-MATRIX.md` §3a). Both are now on all three engines, and modeling §4.7
  surfaced the spec contradiction in §D.1.
- **`ConnCodes`'s two invariants are proven over a SYMBOLIC `PreHelloAuthRow`**, ranging over
  both readings the spec's two clauses permit rather than one chosen reading. The §4.6-step-1
  property itself is deliberately *not* in the inductive invariant: it is false under one of
  the two permitted assignments, and that is the finding.
- **`Core`'s `InvComposed` was the last deferred item in the repo.** It had been carried
  since Phase 1 as "consciously deferred, lowest value" on the reasoning that each invariant
  is proven separately and Spin corroborates the deadlock. That does not survive scrutiny:
  proving the conjuncts in separate modules is exactly what a *composition* invariant is
  not, and the deadlock in question is liveness, which Apalache cannot prove either way.
  **Nothing is deferred now.**
- **`Bounds` is proved over SYMBOLIC constants**, constrained only by §5.9's ratio condition
  rather than fixed at one triple. Since §5.9 makes the numbers explicitly non-normative and
  states the requirement as a property, this is the result shape the clause actually asks
  for: it holds for every conforming deployment, not for our chosen 16/4/2.
- The strengthening for the three `Store` invariants is `RefcountSound` — the counter equals
  the live-referrer set and a key is in the store exactly while it has one. `NoUseAfterFree`
  is an immediate corollary, which is precisely why the synchronized discipline is safe and
  the split read-modify-write is not.

**Unbounded in STEPS, not in PEERS.** Every Apalache result here fixes the peer/request set
and proves the invariant for runs of any length over it. "Unbounded" invites the wrong
reading and is worth stating plainly.

*This paragraph read "fixes the peer/request set (`Peers = {A,B}`)" until 2026-09-06, which
had been false since 2026-08-30.* `Reentry` and `Core` take `CONSTANT N` and dispatch on a
directed ring; `ReentryApalache` and `CoreApalache` prove `FramesNotInterleaved` and
`InvComposed` **inductive at N = 3** as well as N = 2 (`tla/CoreApalache.tla`), and Spin
re-encodes both at 3 via `-DNPEERS`. The remaining nine modules do fix their sets. The
correction understates nothing and overstates nothing now, but it is worth noticing which
direction it was wrong in: **the stale claim made this repo look weaker than it was**, which
is the direction nobody re-reads a document to catch.

Reproduce: `make -C tla apalache-green` (each: base case length 0 + inductive step length 1).

### A2 — MODELED, bounded-exhaustive (TLC + Spin): everything, incl. ALL liveness

At the tight bound (2 peers — the faithful worst case; the Class-G reentry deadlock
is deterministic at N=2), TLC enumerates every interleaving over **11 modules** and Spin
**independently re-encodes all 11** from the spec (a different formalism — explicit-state
Promela — agreeing corroborates the transcription). At v0.8.0 Spin covered 6 of them and the
composed `Core` model had no independent encoding at all; the 0.8.2 audit closed that. The
second gate audit added `ConnCodes` (§4.7) and `Bootstrap` (§6.9), both on all three engines
from the day they landed.

- **Safety** at the bound: all of A1 **plus** the composed 2-peer `Core` model
  (deadlock-free establish→request→revoke), plus the two modules added at 0.8.2:
  - **`Authority`** (§5.2) — the three-valued dispatch authority, the resource-check
    binding, and the no-resource-inheritance rule.
  - **`Bounds`** (§5.9/§4.10) — TTL versus continuation `chain_depth` as distinct
    magnitudes, single-decrement TTL accounting, and distinct reason strings.
- **Liveness — bounded only, by nature** (Apalache does safety/induction by
  construction, so liveness stays TLC+Spin at the bound): deadlock-freedom,
  stall-freedom, eventual settling, revocation convergence, emit progress. *These
  are MODELED, not PROVEN-unbounded.*
- **Negative controls with teeth:** **30 TLC** + **15 Apalache** + **29 Spin** defect variants, each of
  which **must** be caught (and is) — Class-G deadlock, **frame interleaving**,
  handshake-ordering, store race, **refcount use-after-free**, admission-bound breach,
  §5.1 revocation-ignored, **unbounded revocation propagation**, §5.10 determinism-leak,
  emit mis-fire, marker-type, registration partial-residue, system-guard removal,
  **both Option-collapse defaults for the dispatch authority**, **sub-dispatch gate skip**,
  **resource inheritance**, **equal TTL/depth magnitudes**, **TTL double-count**,
  **shared reason string**, and the liveness controls.
- **Non-vacuity witnesses (new at 0.8.2): 9, one per module.** Each is an invariant
  asserted *in order to be violated*; the violation exhibits the interesting state. See
  §C.4 — this closes a gap that stood open from Phase 1.

Reproduce: `make -C tla tlc-green`, `make -C spin green`; full gate `make matrix`.

---

## B. Active-attacker protocol security (Tamarin / ProVerif track)

### B1 — MODELED, symbolic Dolev-Yao (unbounded sessions, perfect crypto): 14 lemmas

Two independent provers in lockstep (ProVerif proves all 15 incl. `BindingReplay`;
Tamarin proves 14). Unbounded in sessions/attacker behaviour; crypto is ideal.

> **What the 15-vs-14 actually is, since the count invites the wrong reading.** It is a
> *packaging* difference, not a coverage gap. **Both provers prove no-replay.** Tamarin proves
> it inside `Binding.spthy` as the `no_replay` lemma, using a linear consumed-nonce fact that
> models single-use precisely. ProVerif cannot use that idiom — its `get/else insert` tables
> are not atomic under replication — so it proves the same property in a separate theory,
> `BindingReplay.pv`, as an **injective correspondence** over a challenge-response handshake.
> Same obligation, two idioms, one extra file on the ProVerif side. The one *genuine* tool
> asymmetry in this repo is `RevokeMech` (§C.5).
>
> This is also where the second gate audit found a real hole: `BindingReplayBug.spthy` — the
> negative control for Tamarin's `no_replay` — was **on disk but in no gate list**, so
> `no_replay` was a green lemma the reports quote with **no control running anywhere in the
> matrix**. The control was fine when run (wellformedness clean; `binding` still verified, so
> the defect is replay-specific; `no_replay` falsified; reachability intact). It is now in
> `TM_NEG`, which took the matrix to **204 runs** at the time (258 now — see the inventory
> below and `docs/STATUS.md`).

| Lemma | Property | V8 basis |
|---|---|---|
| Unforge | capability unforgeability | §5.4/§5.6 |
| NoEscalation | no privilege escalation via attenuation | §5.4 |
| Binding / BindingReplay | request-binding; no replay/reflection | §5.6 |
| Caveats | caveat enforcement under an attacker | §5.5 |
| DepthBound / DeepChain / DeepChainN | delegation-depth bound; deep cross-peer frame integrity | §5.4 |
| Expiry | expiry honored against an attacker | §5.5 |
| **Malformed** | **an unrepresentable temporal field is refused, never read as absent** | **§5.6 (0.8.1 CAP-6a)** |
| **ChainTopology** | **cross-peer provenance holds at a NON-ISSUING third-party verifier** | **§5.8** |
| Multisig / MultisigKN | K-of-N threshold cannot be bypassed | §5.7 |
| Revoke | revocation under an active attacker | §5.1 |
| PersistentRecheck | no "trusted-forever" fail-open; re-check persists | §6.8 |

**On `ChainTopology` and what it says about `DeepChain`.** `DeepChain`/`DeepChainN`
prove the §5.5a granter-frame property with the verifier seated as the **root issuer**.
Those results are sound for the property they claim, but in that topology the root frame
and the verifier frame are the same peer, so a defect that canonicalizes against the root
is indistinguishable from correct behaviour — the local identity-collapse §5.8 names.
`ChainTopology` separates root / granter / grantee / verifier into four distinct peers and
adds the lemma `DeepChain` structurally cannot state. Its negative control confirms the
asymmetry: canonicalizing against the root frame leaves the verifier-namespace lemma
**still true** while falsifying the root-namespace one. `DeepChain` is not retracted; it is
**not sufficient on its own**, and that is now recorded rather than assumed.

Reproduce: `make -C tamarin green`; 15 ProVerif + 14 Tamarin bug controls each falsified.

---

## C. What is NOT proven here (the walls — stated, not hidden)

1. **Spec↔model fidelity — the 5th wall (deepest).** Every result above is a
   property of a *model*. No tool closes this; the two-paradigm agreement (Spin
   independent encoding + Apalache unbounded, both matching TLC; ProVerif+Tamarin
   lockstep) **narrows** it substantially but they could share a misreading of the spec.
   **Human review against `spec-data/v0.8.2/` owns this.**
   *This is not hypothetical:* during the 0.8.2 work the ProVerif/Tamarin lockstep caught
   a real defect in a hand-written Tamarin lemma (a `pkW` variable never bound to the
   verifier, so the lemma said far less than it appeared to). The cross-check earned its
   keep on the modeller, which is the failure mode it exists for.
2. **Verdict interior + crypto.** §5.4 attenuation arithmetic is **Lean's** (abstract
   predicate / function symbol here); sign/verify are perfect symbolic primitives.
   Same trust boundaries Lean takes as axioms — not re-proven here.
3. **Liveness is bounded-only** (see A2). Safety is lifted to unbounded by Apalache;
   liveness is not.
3a. **Four subjects rest on ONE engine, and they are named rather than inferred.**
   `docs/CORROBORATION.md` is the ledger and `make enginecount` is its gate (D16, added
   2026-09-09): per subject, which engines have a **green** on it, derived from the gate tables
   rather than from which files exist. **33 of 35** subjects carry two or more; the two that do
   not are both on `core` — `revokemech` (zero — genuinely non-terminating, excluded from the
   matrix by design) and `core-refinement` (TLC, T4's classifier, deliberately last).
   **No extension subject is single-engine as of 2026-09-09.**
   **`identityprocess` was the fourth until 2026-09-09**, when the port that closed it produced
   two findings (N3, N4) by lifting its single-arrival domain rather than by re-checking its
   invariants — the fourth consecutive time that has happened (`docs/LEAN-SEAM.md` O22).
   **`identityrecovery` was the fifth until 2026-09-09**, and it was ranked first to fix because
   the §9.4 compromise-recovery result is a *negative-reachability* claim — the shape with the
   highest vacuity risk this repo publishes. `tla/IdentityRecoveryApalache.tla` now carries it,
   inductively; `identityprocess` is next and `docs/LEAN-SEAM.md` O22 says where to point it.
   Read any one-engine result as a hypothesis with a machine behind it.
   *And read the counterpart from wall 1 above:* a second engine narrows the search, not the
   transcription. Two model checkers over one `.tla` file share its reading of the spec.
4. **Vacuity — all three thin positives now retired, and the gap instrumented.**
   - *Retired at 0.8.2:* `Store`'s store-cardinality conjunct was **vacuous** — the model
     held a single key while asserting a bound of 2, so `Cardinality(store) ≤ MaxStore`
     could not fail, and the Apalache port made it explicit as `store ⊆ {"k"}`. The store
     is now multi-key (3 keys against a bound of 2) and the bound is discharged by
     refcount correctness, so it is a real obligation with a control that breaks it.
   - *Retired after 0.8.2:* `Reentry`'s and `Core`'s `StoreBounded` were inherited **vacuous
     conjuncts** — one literal key written once against a bound ≥ 1, so no behaviour of
     either model could violate them — and `Core`'s was carried into the composed
     `CoreApalache.ComposedSafety`, making that conjunction look one term stronger than it
     was. The Spin counterpart was worse: `core.pml` wrote the store through a **saturating**
     increment that clamped at `MAXKEYS` and then asserted `store[q] <= MAXKEYS`, so the
     assertion was enforced by the statement three lines above it. They are **removed**, not
     given teeth: the bound only has content under repeated dispatch or multi-key writes,
     which these models structurally do not do, so making it falsifiable would mean importing
     `Store`'s machinery and duplicating an owner. `Store`'s `ResourceBounded` is the real
     §4.8/§4.9(b) obligation. Declared as a structural exclusion in each model's header —
     this had been disclosed as vacuous twice without being fixed.
   - *~~Still standing:~~ **RETIRED 2026-09-06**, and the retirement is a run rather than a
     rewrite.* `Register`'s correct-model atomicity was **near-tautological**: the five §6.2
     writes landed in one assignment, so `tree[h] \in {{}, FACETS}` restated the assignment and
     could not fail. All the teeth were on the control side.

     The four non-committing facets now land **one per transition, in any order**, with the
     fifth write and the §6.6 index publish as a single atomic **commit point** — and the
     teardown mirrors it. So `RegisterAllOrNothing` and `IndexMatchesTree` hold because of a
     *discipline*, not because no other state exists.

     **`RegisterSeqWitness` is the proof that this is real, and it is the sharpest form the
     evidence could take: it asserts the PRE-0.8.3 invariant, and requires it to be VIOLATED.**
     The old positive is now false — the tree does reach `{"manifest"}` — while the properties
     that matter still hold. A "sequenced" model whose sequence is never reached would be the
     same vacuity in new source code, and only a violated reachability assertion rules that out.

     Two consequences worth stating rather than absorbing:
     - **`NoPartialResidue` is now scoped to *settled* handlers.** A partial tree in flight is
       the model working; a partial tree at rest is the defect. §6.2's claim is about what a
       handler comes to rest in.
     - **`RegisterAtomicBug` now fails on `RegisterAllOrNothing`, not `NoPartialResidue`** — in
       TLC *and* in Spin, which is the cross-check agreeing. That is the defect the control's
       own header names ("a half-built handler is dispatch-visible without its grant"); the old
       verdict was an incidental side effect of the collapsed-write shape. A control failing
       for its stated reason rather than a neighbouring one is D13's whole point.

     **And the property got stronger, not just honest.** `RegisterAllOrNothing` is now proven
     **inductive (unbounded in steps)** by Apalache — which was not worth doing before, because
     proving a tautology unbounded proves nothing. It carries its own negative control
     (`ConstInitBugAoN`), since an inductive invariant with no control is the same trap one
     level up. **No thin positive remains.**
   - *A trap in the tooling, recorded:* a bounded Apalache negative control that is too
     SHORT to reach its defect reports `NoError` — textually identical to "the invariant
     holds". One control was observed passing at length 4 and failing at 5. Lengths in
     `tla/Makefile` now carry margin.
   - *The gate believed a tool that said otherwise.* **Tamarin exits 0 when every lemma
     verifies even if its own wellformedness checks failed** — printing `WARNING: N
     wellformedness check failed! The analysis results might be wrong!` and returning
     success. Four green theories were shipping that warning, unread, and the negative-control
     target captured prover output and echoed only a verdict line, so a warning from a
     *control* was invisible even in scrollback. Two were real: `DeepChainN`'s `DelegateB`
     had a **free variable in its rule conclusion** (the delegatee `gC`, never bound by any
     premise — the sibling rule `DelegateA` binds its own correctly), and `Malformed` used
     `Repr` at **two arities** (an arity-0 action label colliding with the arity-1 fact
     `!Repr(x)` that carries the whole §5.6 representability encoding). Both fixed; the other
     two were `!PkA(pk(~skA))` premises binding a secret key derivable from nothing. A
     wellformedness failure is now a **build failure** in both `tamarin-green` and
     `tamarin-neg`. This is the same family as the two entries above: *a tool telling us the
     result might be wrong, reported as a green.*
   - *Negative controls now assert WHY they fail, not just that they do.* `tlc-neg` graded on
     TLC's exit status with output discarded — and TLC exits non-zero for a parse or semantic
     error exactly as it does for a caught defect, so a control broken by a typo, or one that
     had drifted onto a *different* property than the one it targets, scored `ok (failed as
     required)`. Every row of `TLC_NEG` now carries the exact verdict line it must produce
     (30 of them) and a mismatch is a build failure. `spin/Makefile` likewise now requires a
     positive `errors: N` count from a control (absence of `errors: 0` is not evidence a
     defect was caught — a compile failure produces neither) and an explicit `errors: 0` from
     a green run.
   - *…and the same fix then had to be applied to the four graders that pass had not touched.*
     Fixing three of five graders left **62 of the 203 runs** still graded by a criterion that
     cannot distinguish the outcome it claims to check. Found by asking of each target, not
     just `tlc-neg`, *"what exactly does this assert, and what else satisfies it?"*:
     - **`proverif-green` asserted nothing** (15 runs). It graded on ProVerif's exit status —
       and **ProVerif exits 0 with a false query**, a fact written in the comment on the
       target directly below it and never applied here. Confirmed: `UnforgeBug.pv` reports
       `RESULT … is false.` and exits `0`. An attack found against any of the 15 secure
       theories would have reported green.
     - **`proverif-neg`'s criterion was met by the secure theory** (15 runs). It required "at
       least one `RESULT … is false`". But ProVerif reports a **reachable** event as a
       *falsified* `not event(…)` query — which is how a non-vacuity witness passes — and 13
       of the 15 secure theories carry one. Secure `Revoke.pv` satisfies the criterion its own
       negative control was graded by, so for 13 of 15 rows "ok (query falsified)" said
       nothing about the security query.
     - **`apalache-neg` and `tlc-witness` graded on exit status with output discarded** (15 +
       9 runs) — verbatim the `tlc-neg` defect, in the two targets the earlier pass did not
       open. Apalache exits `255` on a configuration error and `12` on a counterexample; TLC
       exits `151` on an undefined invariant. Both were scored as "the control caught its
       defect". Confirmed by pointing one of each at a nonexistent operator: both passed.
       That `tlc-witness` was among them is the sharpest form of the problem — the witnesses
       exist *to rule out vacuity*, and were themselves graded by a criterion a broken config
       satisfies.

     Both provers are now graded against **declared verdict tables** (`PV_EXPECT`,
     `PV_NEG_EXPECT`, `TM_EXPECT`, `TM_NEG_EXPECT`): every query and every lemma of every
     theory states the verdict it must produce, and the run must produce **exactly that set —
     no more, no less**, so a query silently added or dropped fails the build. The
     green-versus-control distinction now lives entirely in the declared verdicts, which is
     what makes "a control that failed for the wrong reason" detectable at all.
     `apalache-neg` must see `EXITCODE: ERROR (12)`, not merely a non-zero exit;
     `tlc-witness` must see its own witness invariant named in the violation.
     **None of the underlying verdicts moved** — all 203 were re-derived by hand and match
     what these reports claim. What was wrong was the gate's ability to notice if they ever
     stopped matching.

     *The full grader inventory, so the class is closed rather than sampled* (AGENTS.md D14 —
     the finding is what made that discipline necessary). Seventeen targets decide the 609 runs.

     **This table carries no run counts, deliberately — corrected 2026-09-07.** It used to,
     and they were stale: `tlc-neg` sat at 40 against a real 45, `tlc-green` at 15 against 24,
     through several matrix growths. The header even claimed they were "re-derived from the
     gate tables, not carried forward", which is how a duplicated number reads right up until
     someone checks it. The per-target counts have exactly one canonical home — the slice
     table in `docs/STATUS.md`, which **`make runcount` checks row by row** against the gate
     tables. A second copy here could only ever be a hand-maintained shadow of a gated number,
     which is the failure this very item is about. What this table owns is the last column.

     | Target | Grades on |
     |---|---|
     | `tlc-green` | TLC's **completion line** *and* a cfg that declares at least one `INVARIANT`/`PROPERTY` — exit status alone is satisfied by a cfg that checks nothing, which TLC reports with the same success text |
     | `tlc-neg` | declared verdict line per row |
     | `tlc-witness` | declared violation line per row |
     | `tlc-finding` | declared violation line per row, on a model with **nothing weakened** — added 2026-09-07. Grades identically to `tlc-neg` and means the opposite: a green is not a toothless control but a spec defect fixed upstream, and the row must then be *retired* rather than repaired. The target says so in its own failure message |
     | `apalache-green` | Apalache exit status (26 rows × base + inductive step) — fail-safe: a green slice wants success, so a tool error correctly fails the build |
     | `apalache-neg` | `EXITCODE: ERROR (12)`, not merely non-zero |
     | `spin green` | explicit `errors: 0` |
     | `spin neg` | the declared pan failure signature, matched against the `pan:N:` error line — a positive `errors: N` alone cannot tell a caught assertion from a deadlock |
     | `proverif-green` | `PV_EXPECT`, per query |
     | `proverif-neg` | `PV_NEG_EXPECT`, per query |
     | `tamarin-green` / `-neg` | `TM_EXPECT` / `TM_NEG_EXPECT`, per lemma, + wellformedness |

     Several further targets grade a **number or a claim** rather than a run, and are counted
     in no matrix total because they verify no model: `make coverage` (the coverage claim
     against the models' own `§`-citations, and since 2026-09-07 the coverage pair at every
     declared prose site); **`make runcount`** (this table's own totals, derived from the gate
     tables, failing when a declared site disagrees); `make ledgercount`; `make trackcheck`;
     `make specfreeze`; and `make leanseam`. `make driftclaim` is deliberately in neither
     `check` nor `matrix` — its input is a sibling repo's tree, so a gate that runs on our
     diffs cannot see it go stale.

     *A twelfth through fifteenth target, in a tier of their own* — `make lean`, **12 runs**,
     excluded from the 277 because they need an `entity-core-keystone` checkout that a bare
     clone does not have (`docs/LEAN-SEAM.md` §7):

     | Target | Runs | Grades on |
     |---|---|---|
     | `leanproof` | 1 | the **axiom set** of all 40 `#print axioms` gates against `lean/proof-gate.expect`, in both directions, + every ledger-pinned theorem present + no undeclared warning + the image's Lean == keystone's `lean-toolchain` pin |
     | `leanproof-neg` | 5 | the declared reason codes per control **and the declarations each names** — `SORRY_AX`, `UNTRUSTED_AXIOM`, `MISSING_GATE` (declaration-level and file-level), `BUILD_ERROR` pinned to its error kind. Graded on counts alone in its first draft; that is below the standard `TM_NEG_EXPECT` set, and the session audit corrected it |
     | `leanlemma` | 1 | **our own** Lean results about the peer's definitions (`lean/lemmas/`, the A-31 star-free theorem and the K2 differential): the axiom set of every gate under our namespace, the `#eval` output **one-to-one** against `lean/lemma-gate.expect`, and every declared prose site still stating a figure the sweep produces |
     | `leanlemma-neg` | 5 | `sorry`, broken proof, deleted gate line, a **narrowed differential input set** (`neg-eval`, which reports a perfectly clean sweep about a smaller question), and `neg-site`, which perturbs the declared prose sites in memory three ways |

     **Why `leanlemma` is a separate target from `leanproof` and not extra rows in it.** They are
     two different claims about two different trees. `leanproof`'s subject is *keystone's* proofs;
     folding ours in would mean a typo of ours turns red the one gate whose whole job is reporting
     movement in a tree we do not control. The number above (**12**) is **not derived by
     `make runcount`** — the lean tier is outside its `DERIVATION` by construction, because its
     input is a sibling checkout — so it is a hand-maintained figure in a repo that has been wrong
     about hand-maintained figures four times. Stated here rather than left implicit.

     Why not `lake build`'s exit status, which is what keystone's own documentation calls the
     proof check: **it exits 0 with a `sorry` in the proof** (a `sorry` is a warning in Lean,
     and lake still prints `Build completed successfully`), and exits 0 with a hand-written
     `axiom` substituted for a proof, with no warning at all. Only a proof that fails to
     type-check exits non-zero. All three were built and observed.

     The two "fail-safe" rows are the ones where grading on exit status is *sound*: a green
     slice wants the run to succeed, so any failure — verification or tool — correctly fails
     the build. The direction matters. Exit-status grading is unsound only where a **failure**
     is the expected outcome, which is precisely where all four defects were. `spin -a`'s
     `>/dev/null` in `spin neg` was checked and is in the sound direction too (exit 1 on a
     parse error, no `pan.c` emitted, `|| exit 1` catches it).
   - *Three negative controls break the honest path as well as the property — now declared.*
     Pinning Tamarin's verdicts per lemma surfaced something `grep -q falsified` had been
     absorbing: `ChainTopologyBug`, `DeepChainBug` and `DeepChainNBug` each report
     `falsified - no trace found` on their own `exists-trace` reachability lemma. The
     security lemma is genuinely falsified in all three, so they do have teeth — but in a
     variant where the legitimate protocol run no longer exists. For `ChainTopologyBug` that
     is the *expected* consequence of the injected defect (canonicalizing against the root
     frame moves which namespace is authorized, so the grantee's own namespace stops being
     reachable — the same flip its ProVerif twin shows, and the asymmetry §B1 describes). For
     `DeepChainBug`/`DeepChainNBug` the honest chain dies at **2 steps**, which makes those
     two the weakest controls in the prover matrix: a defect that breaks the model is a
     weaker demonstration than a defect that breaks only the property. Declared in
     `TM_NEG_EXPECT` so it is a stated property of those controls rather than something the
     gate silently absorbs. Narrowing them is on the work-list; it is not done.
   - *Two ProVerif theories had no non-vacuity query at all* — `Unforge.pv` and `Binding.pv`,
     whose Tamarin twins both carry an `accepted_reachable` `exists-trace` lemma. Both are
     pure correspondence lemmas ("accepted ⇒ issued"), which a model that can never accept
     satisfies **vacuously**. The flagship unforgeability result was the un-witnessed one.
     Queries added; both fire (`is false` = the honest path is reachable), so the lockstep is
     now symmetric on non-vacuity as well as on the security property.
   - *The general gap, now closed:* the TLA+ track had **no non-vacuity assertions at
     all**, unlike ProVerif's reachability queries — a trivially-inert model would have
     reported the same green as a working one. Every TLC module now carries a **witness
     config** asserting an invariant that MUST be violated; `make -C tla tlc-witness`
     fails loudly if any witnessed state becomes unreachable.
5. **One irreducible tool asymmetry:** mechanistic linear-token revocation
   (`RevokeMech`) does **not terminate** in Tamarin — it stays ProVerif's lane; Tamarin
   uses the terminating trace-restriction idiom. Documented tool-capability finding,
   not a modeling gap. (`RevokeMech` is excluded from `make check`; run by hand with a
   kill switch.)
6. **Code, not modeled.** Hostile-byte rejection (malformed/oversized CBOR, protocol
   confusion) is the **fuzzing + adversarial-authz follow-on**, not this project.
   validate-peer (keystone) owns "impl conforms." Note the boundary carefully for
   §5.6 CAP-6a: `Malformed` proves the *verifier's disposition* of an unrepresentable
   temporal field; the CBOR decode that produces it is not modeled.
7. **The async extension protocols are not modeled.** `EXTENSION-CONTINUATION/
   -SUBSCRIPTION/-COMPUTE` are not vendored; only the core properties governing them are
   modeled (§6.8 re-check, and now §5.8's conformance topology and §5.9's continuation
   depth brake). Those three are **Phase 3, gated on vendoring**. Not a claim about
   extensions generally: `attestation`, `quorum` and `identity` are all modeled tracks of
   their own since 2026-09-07.
8. **§6.11(a′) is proved per-connection *and* composed — the receiver's decode is the
   wall.** Frame-write atomicity is modeled in `Reentry` (TLC + Apalache) and `reentry.pml`
   (Spin), **and** in the composed `Core` model, where it is checked against interleavings
   involving §5.1 revocation and the §4.2 connection lifecycle that `Reentry` structurally
   lacks. The composed result is a **corroboration** — same verdict, no new violation path,
   and the `CoreFrameBug` counterexample is the same client-vs-own-server frame race — but
   that is a measured outcome, not a predicted one. *An earlier revision of this entry said
   `Core` deliberately did not carry (a′) because doing so "would duplicate `Reentry`
   without producing an interleaving `Reentry` cannot already exhibit." That was a claim
   about what a model would do, asserted without running it; it is retracted.* What remains
   genuinely outside every (a′) result is **the receiver's decode**: the models prove the
   writes do not interleave, not the decoder that would fail if they did.
9. **Peers are fixed — at 2 for nine modules, at 2 *and* 3 for `Reentry` and `Core`.**
   The Apalache results are unbounded in *steps*, never in *peers*. `Reentry` and `Core`
   take `CONSTANT N` on a directed ring and are checked at both bounds on all three engines,
   which is what reaches the 3-cycle deadlock class two peers cannot form; the ring is still
   **one topology**, so a peer with several counterparties or several concurrent outbound
   requests is not modeled anywhere. A defect that first appears at 4 peers, or at 3 on a
   non-ring graph, is outside every result in this document.
   *(This item said "Every model — TLC, Spin and Apalache alike — fixes the peer set at 2"
   until 2026-09-06. It had been false since the N=3 work landed on 2026-08-30 — a stale
   claim in the load-bearing honesty document, found while adding item 10 rather than by any
   gate. `make coverage` and `make runcount` check the section set and the run total; **no
   gate reads a prose sentence about a bound**, and this is what that hole looks like.)*

10. **The composition is checked, and it carries one component property.** `Core` is the
    composed whole-protocol model; `Conn`, `Store`, `Reentry`, `Revoke` are the components.
    Until 2026-09-06 nothing related them and the ledger recorded that as row T4. It is now
    related by an explicit mapping (`tla/RefMap.tla`), and the measured answer is narrow:
    **`Core` is not a refinement of `Conn` or `Store`** — it performs §4.6's two-step
    handshake in one step, and it has no counterpart for `Store`'s refcount, referrer set,
    write critical section or admission state — and of the six component invariants checked
    under the mapping, **one is carried and five are manufactured by the mapping itself**
    (`tla/CoreMapFree.tla`, one graded run per verdict). The one carried is §4.2's
    dispatch gate.

    So: "the composed model is checked and the components are checked" does **not** mean the
    composition is verified, and this is the wall that says by how much. `Core`'s own
    invariants are unaffected — they hold, with controls and a witness, exactly as before.
    Full statement and the per-invariant table: `docs/LEAN-SEAM.md` row T4.

---

## D. Findings routed to `entity-core-protocol`

Per repo discipline any defect is a proposal/review-note in the sibling protocol repo,
**never a spec edit here.**

1. **§4.7's error-code table contradicts itself — and §4.6 step 1 — on the same input.**
   *This is the first finding here that is a genuine defect in the spec text rather than a
   boundary worth stating, and it is the only one machine-exhibited by all three TLA+-track
   engines.* An `authenticate` frame arriving before any hello nonce has been issued is named
   explicitly by **eight** normative sites across two published documents, which disagree on
   the code **and** the status class. The four we found and modeled:

   | Site | Says | Code | Status |
   |---|---|---|---|
   | §4.6 step 1 (Nonce-echo, normative) | "A mismatch — **or an `authenticate` received before any hello nonce was issued** — MUST be rejected with status 401 `invalid_nonce`." | `invalid_nonce` | **401** |
   | §4.7 table **row 6** | "Nonce mismatch / absent / **pre-hello** (§4.6 step 1)" | `invalid_nonce` | **401** |
   | §4.7 table **row 10** | "Out-of-order operation (**e.g., authenticate before hello**)" | `connection_sequence_error` | **400** |
   | §5.2a verdict-to-status enumeration | "Connect-time (§4.6) \| Nonce mismatch" — **drops "absent / pre-hello" entirely** | `invalid_nonce` | **401** |

   **Review in the sibling repo found four more, and one of them changes the remedy.** §6.12
   names §4.7 as the code-namespace home for connection errors — it delegates to the site that
   answers twice. §9.1 lists §4.2's ordering enforcement and §4.7's code contract as separate
   conformance MUSTs without reconciling them. `ENTITY-CORE-MACHINE-SPEC` §6.4 carries a second,
   **stale** copy of the §4.7 table with no `invalid_nonce` row at all — published, and
   contradicting row 6 by omission. And **§4.2** says *"the connection handler MUST enforce
   ordering: `hello` before `authenticate`"* — a normative MUST naming this exact input, with
   no status and no code.

   The two conflicting rows are **in the same table**, so "follow §4.7" is not a well-defined
   position: an implementer reading it top-to-bottom hits row 6, then row 10 four rows later.
   *(This entry previously framed the defect as §4.6 vs §4.7 row 10. That is true but weaker,
   and it points at the wrong fix — row 6 already defers to §4.6 by citation and the
   contradiction survives anyway. The defect is row 10's parenthetical in isolation, which
   makes the remedy four words rather than a two-section reconciliation.)*

   All are MUSTs. §4.7's preamble then forbids the divergence it creates: the table is "a
   normative MUST-emit contract ... an impl that collapses several of these to one code, **or
   returns a different status**, is non-conformant". So whichever row an implementation
   follows, the other one calls it non-conformant — and the disagreement lands on
   `result.data.code`, the exact field §4.7 says "clients key error handling off". 401 and
   400 are also different *classes*: one is the authentication boundary (§4.6), the other is
   a client-correctable structural error. A client that retries on 400 and re-authenticates
   on 401 behaves differently against two conformant peers.

   **This is not hypothetical — the divergence is shipped, and it is wider than we first
   reported.** Our contribution was a **source read** of the 46-peer keystone cohort plus the
   three ground-up implementations (2026-08-30), which found four distinct behaviours. Both
   siblings then went further, and the current count is **six**:

   | Behaviour | Where | n | Source |
   |---|---|---|---|
   | `401 invalid_nonce` — row 6 / §4.6, conformant under the ruling | keystone cohort | **38** | measured |
   | `400 connection_sequence_error` — row 10 | keystone cohort | **6** | measured |
   | `401 authentication_failed` | keystone cohort (`prolog`) | 1 | measured |
   | `409 connection_sequence_error` — a status in no clause | `entity-core-go` | 1 | source read |
   | `400 handshake_failed` — a code absent from the whole corpus | `entity-core-rust` | 1 | source read |
   | `400 bad_request` — a code in no §4.7 row | `entity-core-py` | 1 | source read, **corrected** |

   Two corrections to what this document previously published, both from the sibling repos and
   both recorded rather than silently absorbed:

   - **`entity-core-py` is not conformant.** We reported it emitting `401 invalid_nonce` by
     fall-through. There *is* a pre-hello branch — `handle_connect_authenticate` raises before
     any nonce comparison — and that raise carries no `code`, so `ConnectError`'s own
     `"bad_request"` default reaches the wire. A fifth behaviour, found in review of our draft.
   - **The cohort split is measured now, not read.** `entity-core-keystone` built the probe our
     packet said did not exist and ran it against 45 of 46 peers (`csharp` is unbuildable
     offline). Our source read was **upheld** — zero disagreements across the 34 peers we
     committed to — and all 11 we could not resolve from source are now resolved, which is
     where the 29 becomes 38 and where `prolog`'s sixth behaviour appears.

   **And the measurement produced a finding a source read could not, which weakens an argument
   we made.** Every peer was also asked the same `authenticate` *after* a valid hello. Only the
   6 in the 400 column answer differently. The other 39 give the same answer either way: they
   never model the pre-hello case at all, they reach the nonce check and find nothing to match.
   So the 38–6 split is **not 38 implementations endorsing row 6** — it is 6 that decided
   something and 38 that got row 6's answer for free because it is the cheaper path. Cohort
   weight is much weaker than it looks, and this repo cited that census as impact. *(The general
   form is worth carrying: when a census counts implementations agreeing, check whether the
   agreeing ones **decided**. An answer reached by fall-through is not a vote.)*

   Nothing caught any of it because `validate-peer` has **no probe that sends `authenticate`
   before `hello`**, and cites §4.7 nowhere in `connectivity`: §4.7 declares ten MUST-emit rows
   and roughly one is gated. Per-peer attribution and the hand-off checklist are carried in an
   internal routing packet; the finding, the evidence and the disposition are stated in full here.

   Two conformant readings, so the models check **both** rather than picking one: the row
   assignment for a pre-hello `authenticate` is a constant (`PreHelloAuthRow` /
   `PREHELLO_ROW`), and the §4.7 reading violates §4.6 step 1 transcribed as an invariant.
   Reproduce — the only control in this repo whose "defect" is a conformant reading of the
   spec rather than something injected:
   `tla/ConnCodesSeqReadingBug.cfg` (TLC) · `ConstInitSeqReading` (Apalache) ·
   `make verify MODEL=conncodes DEFS=-DSEQREADING` (Spin).

   **Disposition: adopted and ruled — the direction we proposed, by a larger edit than we
   proposed.** The finding is now a live proposal in `entity-core-protocol`
   (`PROPOSAL-CONNECT-ERROR-CODE-RECONCILIATION`), which adopts our draft and **rules 401
   `invalid_nonce`**: §4.6 step 1 is the more specific and more recently hardened clause, §4.7
   row 6 already cites it, and the 401 classification matches the other two step-failures
   (`authentication_failed`, `identity_mismatch`).

   **Our suggested remedy — "narrow row 10's parenthetical alone, four words" — was right about
   row 10 and incomplete about the spec, and the reason is §4.2**, one of the four sites we did
   not carry. An implementer reads §4.2's *"MUST enforce ordering: `hello` before
   `authenticate`"*, goes to §4.7 for a code, and finds row 10's *"out-of-order operation"* — a
   near-verbatim lexical match for the words §4.2 just used. That is a clean derivation from two
   normative sentences, and it lands on 400. **The six peers in the 400 column did not skip row
   6; they followed §4.2 into row 10.** So narrowing row 10 alone breaks the chain without
   repairing it: §4.2's ordering MUST would then point at no §4.7 row at all, leaving a
   normative MUST with no wire consequence a peer can emit. The adopted proposal therefore
   carries five items, two of them required and new, and also repairs the stale MACHINE-SPEC
   §6.4 copy. §5.2a's half-copy and the §3.3/§4.7/§5.2a precedence question, which we flagged
   rather than proposed, are carried there too.

   *This is the useful shape of the outcome, and it is worth keeping: the models exhibited a
   real contradiction and got the direction right; the sibling that owns the text found the
   mechanism, and the sibling that owns the cohort measured what we had only read. Neither
   correction was available from inside this repo.*

2. **§5.9 recommended TTL/`chain_depth` ratio has zero margin at worst-case fan-out.**
   §5.9 requires the ratio be "chosen so the deterministic depth brake engages before the
   TTL backstop **under the peer's worst-case sub-dispatch fan-out**", and recommends 8×
   (seed 512 at ceiling 64). `Bounds` shows the property needs
   `ceiling × worst_case_fanout` **strictly less than** the seed: at exact equality the
   final causal level spends the last of the TTL and the backstop fires on the step the
   brake would have. A deployment that takes the recommended 8× seed *and* has a
   worst-case fan-out of 8 therefore has no margin. This is **not** a claim the default
   is wrong — §5.9 explicitly puts the choice on the deployment — but the boundary is
   worth stating where operators will read it. Reproduce: `BoundsRatioBug.cfg`.
3. **§5.8's topology rule is load-bearing for this repo's own prior results.** See §B1:
   the pre-0.8.2 `DeepChain` models sit in exactly the same-peer topology §5.8 says cannot
   witness a cross-peer seam. Recorded as a note on modeling practice for anyone building
   cross-peer chain-construction tests, not as a spec defect.

Otherwise **none new**: the models re-derived the known Class-G reentry deadlock (already
fixed) and otherwise found the 0.8.2 design admits no deadlock, frame interleaving, store
race, refcount use-after-free, resource leak, registration partial-residue, emit mis-fire,
Layer-1 verdict leak, grantless-sub-dispatch authorization, or — under an active attacker —
forgery, escalation, replay, deep frame confusion, threshold bypass, temporal fail-open, or
trusted-forever fail-open, at the modeled bound.

> ⛔ **AND "AT THE MODELED BOUND" IS DOING MORE WORK IN THAT SENTENCE THAN A READER CAN SEE —
> corrected 2026-09-14, and the correction is kept beside the claim rather than replacing it.**
> On 2026-09-14 `entity-core-protocol` `0.8.2.23` closed a **capability and identity forgery**
> in the pinned design: every authority lookup resolved an entity through a wire-supplied
> `envelope.included` map key that nothing verified, so an observer of any capability chain
> could mint a leaf off it, up to the parent's scope, **without the grantee's key**. The
> enabling obligation — §3.1's *"The content_hash MUST match the map key"* — is in
> `spec-data/v0.8.2`, with no enforcing operation and no vector.
>
> **The sentence above is true and it is not the sentence a reader takes from it.** The bound
> it points at never mentioned entity resolution, because **no model here represents the
> address→entity indirection at all**: the prover theories take capabilities and chain links
> as terms, so there is no address to forge (`content_hash` occurs **0** times across the 60
> files in `tamarin/`). That is not a limit that was disclosed and accepted; it was undisclosed
> until this date. It is booked as `docs/LEAN-SEAM.md` **O23**, measured as part of
> **120 of 365 core obligations are UNEXAMINED** (`make obligations`), and audited in
> `docs/status/AUDIT-2026-09-14-THE-DENOMINATOR-WAS-OUR-OWN-CITATIONS.md`.
>
> **Read every "admits no X" in this document as "no model here exhibits X", and read the
> model's domain before believing the second form covers the first.**

*Section-by-section coverage, what each engine can and cannot do, and every bound:
`docs/COVERAGE-MATRIX.md` — the best starting point for a new reader.
Full narrative + the re-verification matrix: `docs/FINAL-ASSURANCE-SUMMARY.md`.
Cross-check detail: `docs/CROSSCHECK-RESULTS.md`. Per-property commands: the
`tla/` and `tamarin/` FORMALIZATION-REPORTs.*
