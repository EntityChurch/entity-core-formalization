# CROSS-CHECK RESULTS — the TLA+ models, independently corroborated

**Status: complete across all modeled subsystems.** This retires the largest residual-risk
item in the Phase-1 TLA+ report ("no independent cross-check"). The TLA+ concurrency models were the only leg
in the assurance family without a parallel attestation; they now have two, on both the
dimensions that gap was about — **independent re-encoding** (Spin) and **unbounded proof**
(Apalache).

**Coverage now (was: priority surface only):** **all 11** modules have an
independent **Spin** re-encoding (`Reentry`, `Conn`, `Store`, `Revoke`, `Emit`, `Register`,
`Core`, `Authority`, `Bounds`, `ConnCodes`, `Bootstrap`), and **23 safety invariants across all 11** are proven
**inductive (unbounded in steps) in Apalache**. Both engines agree with TLC on every secure
result and every negative control, and **nothing is deferred** — the composed
*Core-conjunction* inductive invariant, carried as the one optional deferral since Phase 1,
was proved in the 0.8.2 audit. See Coverage for what that deferral's rationale got wrong.

Read with `tla/PHASE1-FORMALIZATION-REPORT.md` (the models being corroborated).

---

> **0.8.2 update.** The cross-check now spans the 0.8.2 surface AND is complete across every
> module. Spin re-encodes §6.11(a′) frame-write atomicity and §4.8's refcount use-after-free
> alongside the original modules, and gained three models it never had —`authority`, `bounds`
> and, most importantly, `core`: **the composed whole-protocol model previously had no
> independent encoding at all**, which the 0.8.2 audit identified as the worst-placed gap in
> the repo. **29 negative controls**, up from 6 wired into the gate.
>
> Apalache went from 9 invariants over 5 modules to **23 over all 11**, including the composed
> conjunction (`CoreApalache.InvComposed`) that had been carried as "consciously deferred"
> since Phase 1. Every module is now checked by all three engines; nothing is deferred.
>
> *(Scope, added 2026-09-07: that sentence is about the **`core` track**, which was the only
> track when it was written. The nine extension modules added later on `attestation`, `quorum`
> and `identity` are **TLC-only**. This blockquote is a historical snapshot and is left as
> written; the qualifier is the correction.)*
>
> One Apalache result is stronger than the others in kind: `BoundsApalache` proves §5.9's
> depth-brake property over **symbolic** constants constrained only by the ratio condition,
> so it covers every conforming deployment rather than the one triple TLC checks.
>
> The cross-check also did the thing it exists for — on the modeller rather than the
> protocol — **three times**. (1) Apalache's inductive step found a defect in `Reentry.tla`
> that TLC structurally could not: the client released the connection write lock even when
> that peer's own server held it mid-frame. TLC was right to miss it — at the 2-peer bound no
> third writer exists to exploit the stolen lock — but an inductive check starts from
> arbitrary states and caught it at once. Fixed in `Reentry.tla`, `Core.tla`, `reentry.pml`.
> (2) A Spin negative control compiled out both the defect and its detector, reporting
> `errors: 0`; caught only because a control that does not fail is itself a signal.
> (3) ProVerif and Tamarin **disagreed** on a negative control for the new §5.8
> `ChainTopology` theory. The cause was a hand-written Tamarin lemma whose `pkW` variable was never bound to
> the verifier it named, so it asserted far less than it appeared to. The disagreement was
> the signal; the lemma was fixed and both provers then agreed exactly. Recorded here and in
> `docs/PROPERTIES.md` §C.1 because "the two engines could share a misreading" is the
> standing caveat, and this is a case where they did not.

> **Follow-up: the fourth time, and it was the tool telling us directly.** A later pass found
> that **Tamarin had been reporting its own results as possibly wrong, and the gate read it as
> green.** `tamarin-prover --prove` exits 0 when every lemma verifies even if its
> wellformedness checks failed, printing `WARNING: N wellformedness check failed! The analysis
> results might be wrong!` as it goes. Four green theories carried that warning; the
> negative-control target captured prover output and echoed only a verdict line, so a warning
> from a *control* never reached scrollback at all.
>
> Two were substantive. `DeepChainN`'s `DelegateB` had a **free variable in its rule
> conclusion** — the delegatee `gC` appeared in the message, the action and the output, bound
> by no premise, so the backward search could instantiate it at will; the sibling rule
> `DelegateA` binds its own delegatee correctly, which is what makes the omission legible as
> an omission. `Malformed` used `Repr` at **two arities**, colliding an action label with the
> arity-1 fact that carries its entire §5.6 representability encoding. The other two were
> `!PkA(pk(~skA))` premises binding a secret key derivable from nothing.
>
> This is the same defect family as (3) above — a Tamarin rule quietly asserting something
> other than what it reads as — and it is the second time it has appeared. A wellformedness
> failure is now a **build failure** in both prover targets. The lesson generalizes past
> Tamarin: **when a tool says its answer might be wrong, that is not a green**, and the place
> to enforce that is the gate, not a reader's attention.


## Why this phase existed (the gap it closes)

The Phase-1 TLA+ work was internally rigorous but **one encoding, by one author,
checked by one engine (TLC), at a finite bound.** Two things were unproven:

1. **Checked ≠ proved** — TLC enumerates all states *at a bound* (N=2), not a theorem
   for all N. → **Apalache** proves invariants *inductive* (`Init ⇒ Inv`,
   `Inv ∧ Next ⇒ Inv'`) symbolically via Z3, holding for all states at once.
2. **Fidelity (the 5th wall)** — nothing corroborated that the `.tla` faithfully
   encodes the spec except the author's §-citations. → **Spin** is a *different formalism*
   (Promela); an independent re-encoding *from the spec text* that reaches the same
   verdict makes a shared transcription error far less likely — the same logic as
   keystone's multi-language conformance peers and Spike B's Tamarin+ProVerif
   agreement.

**Honest caveat (unchanged):** even both engines agreeing does not *close* the 5th
wall — they could in principle share a misreading. Independent paradigms *narrow* it;
they don't eliminate it. And the cross-check covers the priority modules, not all
seven (see Coverage).

## Track B — Spin: independent Promela re-encodings (fidelity)

Each model was written **from the pinned spec's §-design in Promela** (channels / processes /
atomic guards), *not* translated from the `.tla` — that independence is the point.
Each has a fix variant and `#ifdef` defect variants mirroring the TLA+ negative
controls. Verified exhaustively in the `entity-spin` container. **Every variant
reaches the same verdict as the TLA+ model.**

| Module | Property (§) | Spin: fix | Spin: defect → caught |
|---|---|---|---|
| `reentry.pml` | **Class-G deadlock-freedom** (§6.11) + `EventuallyResolved` (§4.9a) | safety `errors: 0`; liveness `errors: 0` | `-DSERIALIZED` → **invalid end state (deadlock) @depth 9** *and* liveness **acceptance cycle** |
| `conn.pml` | NoEstablishWithoutNonce / DispatchedImpliesEstablished / TokenBounded (§4.1/4.2/4.6); AllAnswered (§4.1) | safety `errors: 0`; liveness `errors: 0` | `-DNOENFORCE` → safety **assertion violated**; `-DDROPFRAME` → liveness **acceptance cycle** |
| `store.pml` | StoreRaceFree (§4.8) / ResourceBounded (§4.9b/4.10); Responsive (§4.9a/c) | safety `errors: 0`; liveness `errors: 0` | `-DNOSERIALIZE` → `writers<=1` **violated**; `-DNOADMIT` → `pending<=MaxPending` **violated**; `-DSILENTDROP` → Responsive **acceptance cycle** |
| `revoke.pml` | RevokedNeverPasses (§5.1/6.8) / VerdictFnOfLayer1 (§5.10 determinism MUST); RevocationConverges (§5.10) | safety `errors: 0`; liveness `errors: 0` | `-DNOHONOR` → RevokedNeverPasses **assertion violated @depth 10**; `-DLEAKL1` → determinism **assertion violated @depth 8**; `-DNOCONVERGE` → RevocationConverges **acceptance cycle** |
| `emit.pml` | EventIffRealWork / NoEventOnNoop / EventTypeCorrect (§6.10 + v7.74 B2); EmitTerminates (§6.10) | safety `errors: 0`; liveness `errors: 0` | `-DEMITFIRE` → EventIffRealWork **assertion violated @depth 6**; `-DEMITMARKER` → EventTypeCorrect **assertion violated @depth 9**; `-DEMITSTALL` → EmitTerminates **acceptance cycle** |
| `register.pml` | NoPartialResidue / RegisterAllOrNothing / IndexMatchesTree / NoUserAtSystem (§6.1/6.2/6.6); RegisterSettles (§6.2) | safety `errors: 0`; liveness `errors: 0` | `-DNOATOMIC` → NoPartialResidue **assertion violated @depth 14**; `-DNOSYSGUARD` → NoUserAtSystem **assertion violated @depth 5**; `-DWEDGE` → RegisterSettles **acceptance cycle** |

**The marquee result:** Spin independently reproduces the Class-G reentry deadlock that
the TLA+ `Reentry`/`Core` models found — from a from-scratch Promela encoding, the
serialized §6.11 defect both deadlocks (invalid end state) and violates liveness, while
the fix is clean on both. This is the strongest single corroboration in the project.

*Note (conn NOENFORCE):* the `Enforce=FALSE` defect violates several §4 safety
properties at once; Spin's DFS reports whichever it reaches first (`tokensIssued<=1`),
and the named `NoEstablishWithoutNonce` assertion is independently confirmed violated by
the same defect. Same outcome as the TLA+ control — the defect is caught.

*Note (register structural coherence):* `IndexMatchesTree` (§6.6 index↔tree-walk) is the
relational invariant the handoff flagged as awkward in Spin. With the dispatch index modeled
as a per-handler cache, the coherence reduces to the bi-implication `disp[h] ⇔ tree[h]==FULL`,
which Spin checks cleanly as a post-mutation state assertion (caught by `-DNOATOMIC`). A native
relational treatment (Alloy, Track C) would model the index↔tree-walk relation directly and
remains an optional follow-on; it is not required for this corroboration.

**Reproduce:** `cd spin && make verify MODEL=<m> [DEFS=-D<DEFECT>]` (safety) /
`make ltl MODEL=<m> [DEFS=-D<DEFECT>]` (liveness). The safety build compiles out any LTL
never-claim (`-DNOCLAIM`) so invalid-end/deadlock detection stays enabled; liveness uses
`pan -a -f` (weak fairness).

## Track A — Apalache: unbounded inductive proofs (checked → proved)

Each module's key safety invariant(s) are typed **hand-ports** of the corresponding `.tla`
data layer (`tla/<M>Apalache.tla` — the handoff's recommended approach over annotating
PlusCal output). Each was proven **inductive** via Z3 — base `Init ⇒ Inv` and step
`Inv ∧ Next ⇒ Inv'` both `EXITCODE: OK`, so the invariant holds for every reachable state
symbolically (unbounded in steps), not just the enumerated bound — and each negative control
is caught symbolically (`ERROR 12`), matching the TLC control.

| Module | Invariant (§) | base | step | negative control → caught |
|---|---|---|---|---|
| `Revoke` | `VerdictFnOfLayer1` — cross-peer verdict determinism (§5.10) | OK | OK | `LeakLayer1=TRUE` → `ERROR 12` — matches TLC `RevokeLeakBug` |
| `Revoke` | `RevokedNeverPasses` — revoked cap never passes (§5.1/6.8) | OK | OK | `HonorRevocation=FALSE` → `ERROR 12` — matches `RevokeIgnoreBug` |
| `Store` | `StoreRaceFree` — single-writer (§4.8) | OK | OK | `Serialize=FALSE` → `ERROR 12` — matches `StoreRaceBug` |
| `Store` | `ResourceBounded` — pending+store bounds (§4.9b/4.10) | OK | OK | `Admit=FALSE` → `ERROR 12` — matches `StoreAdmitBug` |
| `Conn` | `NoEstablishWithoutNonce` — §4.1/4.6 (via `HelloImpliesNonce` strengthening) | OK | OK | `Enforce=FALSE` → `ERROR 12` — matches `ConnBug` |
| `Emit` | `EventIffRealWork` — event iff real work (§6.10) | OK | OK | `Fire=FALSE` → `ERROR 12` — matches `EmitFireBug` |
| `Emit` | `EventTypeCorrect` — type derivation incl. v7.74 B2 (§6.10) | OK | OK | `MarkerDeletes=TRUE` → `ERROR 12` — matches `EmitMarkerBug` |
| `Register` | `NoUserAtSystem` — §6.2 guard (via `SafeSys` strengthening) | OK | OK | `GuardSystem=FALSE` → `ERROR 12` — matches `RegisterSysGuardBug` |

All invariants are **unbounded** (all states over the data domains, proven by SMT, not
enumeration), and Apalache **agrees with TLC** on every secure design and every defect.
`VerdictFnOfLayer1` was the handoff's highest-value unbounded target (the §5.10 determinism
MUST that nothing else proves for all states). The inductive-invariant hunt was needed only for
the two state-machine invariants — `Conn`'s `HelloImpliesNonce` (phase past `new` ⇒ nonce issued)
and `Register`'s `SafeSys` (the user-at-system handler never enters an active lifecycle phase);
`Store`'s linking invariant `pending = |InFlight|` ties the counter to the lifecycle so the gate
bounds it. The §4.8 race / §4.9 bound / §6.10 emit invariants were near-immediate given `TypeOK`.

**Reproduce:** `cd tla` then (example — `Store` race step)
`podman run --rm -v "$PWD":/work:z -w /work entity-apalache check --cinit=ConstInitOK --init=IndInitRace --next=Next --inv=InvRace --length=1 StoreApalache.tla`
— each module's `ConstInit*` / `IndInit*` / `Inv*` operator names are in its header comment;
use `--init=Init --length=0` for the base case and `--cinit=ConstInitBug*` for the controls.

**The relabel flag is lowercase `:z` and that is load-bearing, not cosmetic.** `tla/` is
mounted by *two* images — `entity-tla` (TLC) and `entity-apalache` — and uppercase `:Z`
relabels a volume private to one container, so the second image's relabel invalidates the
first's and Apalache dies mid-run with `Could not find or create directory:
/work/_apalache-out/…`, which reads like a model failure and is not one. *(This command said
`:Z` until 2026-09-06, six days after the flag was fixed in `tla/Makefile` — a corrected
defect left standing in the one place a reader would copy it from.)*

## Coverage — what is and isn't cross-checked (honest scope)

- **Spin (fidelity): all 11 modules.** `Reentry`, `Conn`, `Store`, `Revoke`,
  `Emit`, `Register`, `Core` (the marquee deadlock, and the composed model — which had **no**
  independent encoding before the 0.8.2 audit), plus `Authority`, `Bounds`, `ConnCodes` and
  `Bootstrap` structurally. Each with a clean fix and every negative control caught the same
  way the matching TLC control fails.
- **Apalache (unbounded in steps): 23 safety invariants across all 11 modules** — `Revoke` (2),
  `Store` (3), `Conn` (1), `Emit` (2), `Register` (1), `Reentry` (1), `Authority` (4),
  `Bounds` (3), `Core` (1), `ConnCodes` (2), `Bootstrap` (3) — proven inductive, controls
  caught. `ConnCodesApalache` ranges `PreHelloAuthRow` over **both** readings of the
  contested §4.6-step-1-vs-§4.7-row-10 cell, so its result covers every row assignment the
  spec's two clauses permit rather than one chosen reading — the honest shape for a property
  whose input is a spec ambiguity (`docs/PROPERTIES.md` §D.1). Liveness is out of Apalache's
  scope by construction (left to TLC + Spin); `Conn`'s `TokenBounded` and `Register`'s
  relational `IndexMatchesTree` are deliberately left to TLC + Spin (the inductive port adds
  no fidelity over what Spin already corroborates — stated in each module header).
- **Nothing is deferred.** The composed **Core-conjunction** inductive invariant
  (`CoreApalache.InvComposed`) had been carried since Phase 1 as the one consciously-deferred
  optional item, on the reasoning that each invariant is already proven separately and Spin
  already reproduces the Class-G deadlock. The 0.8.2 audit rejected that reasoning and proved
  it: *"each invariant is proven separately"* is precisely what a **composition** invariant is
  not, and the deadlock it was said to corroborate is **liveness**, which Apalache cannot
  prove either way — so neither half of the rationale actually bore on the deferred item.
- **Unbounded in STEPS, not in PEERS.** Every Apalache result here fixes the peer set and
  proves the invariant for runs of any length over it. **`Reentry` and `Core` are checked at
  N = 2 *and* N = 3** on all three engines (`ReentryApalache` / `CoreApalache` prove
  `FramesNotInterleaved` and `InvComposed` inductive at 3); the other nine modules fix theirs
  at 2. A defect first appearing at 4 peers — or at 3 on a dispatch graph other than the
  directed ring — is outside every result on this page.
  *(This bullet read "fixes `Peers = {A,B}`" until 2026-09-06, false since the N=3 work landed
  on 2026-08-30. One of eleven live sites across six files carrying that stale bound; the
  count is derived from the diff, not recalled. See `CHANGELOG.md`.)*
- **The 5th wall is narrowed, not closed.** Two independent paradigms now agree across the
  whole modeled surface — but they could in principle share a misreading of the spec. Independent
  encoding + independent engine *narrow* the fidelity gap substantially; only human review
  against `spec-data/v0.8.2/` closes it.

## Bottom line

The Phase-1 TLA+ report's #1 residual risk — *"one encoding, one tool, one transcriber; the
least-independently-attested leg"* — is **closed across every modeled subsystem.** Every
concurrency module is now independently re-encoded in Spin (reaching TLC's verdict on the fix
and on every defect), and every module's key safety invariant is an unbounded (all-states) SMT
proof in Apalache, both engines agreeing with TLC throughout. The marquee Class-G deadlock and
the §5.10 cross-peer determinism MUST — the two highest-value results — are corroborated on both
dimensions. The TLA+ leg no longer stands alone on any module.
