# PHASE2-FORMALIZATION-REPORT — Tamarin/ProVerif active-attacker model, Phase 2

**Status:** Phase 2 COMPLETE — seven new security results, each machine-closed in **both**
ProVerif and Tamarin with a negative control caught in both, plus one honest non-closure
documented.
**Artifact type:** design-assurance formalization note. Models the **V7 design** under an
active Dolev-Yao attacker — not the code.
**Scope:** the Phase-2 plan in `PHASE2-SCOPE.md` — closes the Phase-1 report's named "Does
NOT say" boundaries and cross-language asymmetries, and adds the delegation-caveat (§5.7),
temporal-validity (§5.5), and persistent-recheck (§6.8) surfaces. Read with
`PHASE1-FORMALIZATION-REPORT.md` (the baseline) and `../docs/ASSURANCE-MAP.md` (the walls).

---

## TL;DR — the headline result

Phase 1 proved the V7 capability design resists escalation, granter-frame confusion,
theft/confused-deputy, replay (Tamarin), revoked-cap use, and multi-sig bypass — at a
2-link / fixed-K / single-tool-per-asymmetry resolution. **Phase 2 extends the resolution
and closes the surface:** delegation caveats, real depth/TTL arithmetic, deep multi-foreign
chains, parametric K-of-N, no-replay now in *both* tools, and the per-use re-check that
underpins the async/extension flows. **Each new lemma is grounded in a named, real V7 check;
each negative control rediscovers the bug class the check defends against.**

| # | Theory | §refs | Lemma (proved, both tools) | Negative control (caught, both tools) |
|---|---|---|---|---|
| 6 | `Caveats` | §5.7 | a child of a `no_delegation` cap is never accepted | drop the consult → delegate-past-prohibition |
| 7 | `DepthBound` | §5.7 | accepted chain depth `<` `max_delegation_depth` (=1) | drop the per-link depth guard → over-deep admit |
| 8 | `Expiry` | §5.5/§5.10 | accepted ⇒ not expired at the single sampled `t` (A-LEAN-1) | drop the temporal check → stale-cap admit |
| 9 | `DeepChainN` | §5.5a | N=3, **two foreign mids**: no deep cross-peer escalation | canon vs verifier frame → deep FOREIGN-GRANTER admit |
| 10 | `MultisigKN` | §3.6/§5.5 | **K=2 of N=3**: local peer + a distinct co-signer | accept on one signature → threshold bypass |
| 11a | `BindingReplay` | §5.2 | **no-replay in ProVerif** (injective, challenge-response) | fixed challenge → captured execute replayed |
| 12 | `PersistentRecheck` | §6.8/§5.1 | persistent cap re-checked every async use; revoked-between denied | skip the later re-check → "trusted forever" fail-open |

Plus **11b** (`RevokeMech`): an attempt to bring ProVerif's mechanistic linear-token
revocation into Tamarin — **confirmed non-terminating**, so the Phase-1 tool split stands
(see Tool comparison).

## Full verification matrix (reproduce: `make proverif THEORY=<T>` / `make tamarin THEORY=<T>`)

| Theory | Property | ProVerif | Tamarin |
|---|---|---|---|
| `Caveats` | no_delegation honored | **true** | **verified** |
| `Caveats` | non-vacuity (delegable child accepted) | reachable | verified |
| `CaveatsBug` | no_delegation honored | **false + attack** | **falsified + trace** |
| `DepthBound` | depth < max_delegation_depth | **true** | **verified** |
| `DepthBound` | non-vacuity (within-bound leaf accepted) | reachable | verified |
| `DepthBoundBug` | depth bound honored | **false + attack** | **falsified + trace** |
| `Expiry` | expired-at-`t` never accepted | **true** | **verified** |
| `Expiry` | non-vacuity (live cap accepted) | reachable | verified |
| `ExpiryBug` | temporal validity | **false + attack** | **falsified + trace** |
| `DeepChainN` | no deep cross-peer escalation | **true** | **verified** |
| `DeepChainN` | non-vacuity (leaf-granter namespace authorized) | reachable | verified |
| `DeepChainNBug` | no deep cross-peer escalation | **false + attack** | **falsified + trace** |
| `MultisigKN` | K=2/N=3 threshold (local + distinct co-signer) | **true** | **verified** |
| `MultisigKN` | non-vacuity (quorum accepted) | reachable | verified |
| `MultisigKNBug` | threshold | **false + attack** | **falsified + trace** |
| `BindingReplay` | no-replay (injective) | **true** | *(Tamarin: Phase-1 Binding)* |
| `BindingReplay` | grantee-binding | **true** | verified (Phase 1) |
| `BindingReplayBug` | no-replay (injective) | **false + attack** | **falsified + trace** (Phase 1) |
| `PersistentRecheck` | revoked-between-uses denied | **true** | **verified** |
| `PersistentRecheck` | persistent re-use is real | reachable | verified (`reused_twice`) |
| `PersistentRecheckBug` | per-use re-check | **false + attack** | **falsified + trace** |

All Phase-2 lemmas closed **automatically** in both tools — no source/reuse lemmas, no
interactive guidance. (`RevokeMech` is the single exception and does not close — below.)

## What the new lemmas mean — and what they do NOT say (honest boundaries)

**Lemma 6 — no_delegation (§5.7).** The `delegation_caveats.no_delegation` flag is enforced
at verify time, per link (V7 constrains nothing at sign time); the verifier's caveat consult
is the sole defense. Proved: a no-delegation root has no accepted delegated child.
*Does NOT say:* the `delegation_caveats` block is abstracted to its one load-bearing bit;
scope/order is opaque here (NoEscalation owns it).

**Lemma 7 — max_delegation_depth (§5.7).** depth is the verifier-computed, positional hop
count below the caveat-setting cap (anchored at the honest root — a malicious mid cannot
reset it); `belowok`/`!Below` computes `depth < bound`. Proved at the spec's worked instance
(`max_delegation_depth: 1`): a leaf two delegations deep is never accepted.
*Does NOT say:* one bound value modeled (the §5.7 example); larger bounds and multiple
caveat-setters along one chain are a structural generalization. Single caveat-setter modeled.

**Lemma 8 — temporal validity (§5.5/§5.10, A-LEAN-1).** `t` is the per-verdict evaluation
timestamp "sampled ONCE" (v7.76). Accept iff `t ≤ expires_at` (DENY when `expires_at < t`).
Time is a finite order {t0<t1<t2}, sampled `t = t1`. Proved: an expired cap is never accepted.
*Does NOT say:* the CROSS-PEER determinism question — two conformant peers at materially
different `t` near a TTL boundary legitimately diverging (§5.10) — is a distributed property
in **TLA+'s** lane (Spike A), not modeled here. `created_at`/ttl-subtraction abstracted.

**Lemma 9 — deep granter-frame (§5.5a).** Generalizes Phase-1 DeepChain from one foreign mid
to a chain V→A→B→C with **two** foreign mids, leaf granted by the deeper mid B. Proved: B's
bare-`*` reaches B's namespace only, never the verifier V's, two hops deep — the §5.5a
per-link frame (A-LEAN-3) holds at depth. The control (canon vs V) reproduces the deep
FOREIGN-GRANTER cross-peer admit; the legit case also breaks (the mis-frame redirects B's
authority to V — an honest consequence, as in Phase-1 DeepChainBug).
*Does NOT say:* N=3 modeled; arbitrary N with mixed honest/foreign mids is a further
structural generalization (the bug is per-link and frame-local — N=3 with two foreign mids
is representative). Path-segment matching abstracted (Lean's). Honest foreign mids pinned to
their registered identities (the theorem is about honest foreign granters).

**Lemma 10 — parametric K-of-N (§3.6/§5.5).** K=2 of N=3 with the local peer S1 in the set
and signing (M6). With N>K the set genuinely exceeds the threshold; acceptance is any
distinct pair including S1 — so the property is `S1 signed ∧ (S2 ∨ S3 signed)`. Distinctness
is structural (two different keys). Proved: ≥2 distinct signers incl. the local peer. The
control accepts on one signature → bypass.
*Does NOT say:* K=2/N=3 modeled; general K/N is a structural generalization. The
multi-granter content (signer list / threshold field) abstracted to a signed constant.

**Lemma 11a — no-replay in ProVerif (§5.2).** Phase 1 proved no-replay in Tamarin only
(ProVerif's non-atomic table `get/else`). Closed here with a **challenge-response**: the
verifier samples a fresh challenge `c`, the grantee signs it into the execute, and no-replay
is an **injective** correspondence (`inj-event`). A captured execute (old `c`) cannot be
re-accepted by a later verdict (fresh `c'`). The control fixes `c` → replay accepted; binding
still holds (replay ⊥ binding), mirroring Tamarin's BindingReplayBug.

**Lemma 12 — persistent per-use re-check (§6.8/§5.1/§1.7).** The core-spec property under the
async flows: §6.8 — "a revoked capability never passes a check, even if the same capability
passed a check earlier in the same operation"; §5.5/§1.7 — installation grants / continuation
dispatch_capabilities / subscription tokens are checked on *every* sub-dispatch / advance /
notification. Proved: a persistent cap re-used across async uses (Tamarin `reused_twice`
witnesses genuine re-use) is denied once revoked, even after an earlier use succeeded. The
control skips the later re-check → the "checked once at install, trusted forever" fail-open.
*Does NOT say:* this models the §6.8/§5.1 **core property**, NOT the EXTENSION-CONTINUATION /
-SUBSCRIPTION / -COMPUTE protocols (not in vendored `v7.76` — a Phase-3 item). The
transferred-closure confused-deputy slot-assignment (§5.8 three-slot model) is named but not
separately modeled.

**Across all — the design, not the code.** Fuzzing + adversarial-authz tests own whether the
code rejects hostile bytes (ASSURANCE-MAP row 6); these provers own whether the *design*
resists the attacker.

## Scope boundaries — the walls (carried from ASSURANCE-MAP)

1. **5th wall — spec↔model fidelity (deepest).** Each result is relative to the theory
   faithfully transcribing §5.7/§5.5/§5.5a/§3.6/§6.8 from `../spec-data/v0.8.0/`. Every modeled
   check cites its §ref; every negative control is grounded in a named, real V7 bug class. No
   tool closes this wall — review owns it. **Notably, the async/extension PROTOCOLS are out of
   vendored scope** (Phase 3); Inc 12 models only the governing core property.
2. **Crypto wall.** sign/verify are perfect symbolic functions (§7.3) — same trust boundary
   Lean takes as opaque axioms.
3. **Verdict-interior wall.** Orders / depths / times are modeled as the finite *relation* the
   verifier checks; the §5.4 pattern-match arithmetic that computes them for real paths is
   Lean's. Depth/bound/time are small finite instances (the §5.7 worked example, {t0,t1,t2}).
4. **Distributed-time wall.** Cross-peer verdict determinism under different `t` (§5.10) is
   TLA+'s lane, not these provers'.
5. **Model-not-code.** These prove the design; validate-peer + fuzzing own the code.

## Tool comparison (the Spike-B gate question, extended)

- **Both tools agree on every secure and every buggy Phase-2 result** — strong evidence
  against a single-tool modeling artifact, now across 7 more theory pairs.
- **No-replay asymmetry CLOSED (Inc 11a).** ProVerif proves injective no-replay via the
  challenge-response idiom it is good at — the Phase-1 "Tamarin-only" caveat is retired.
- **Mechanistic revocation asymmetry CONFIRMED IRREDUCIBLE (Inc 11b).** The mechanistic
  regenerating linear token (`RevokeMech.spthy`) does **not** terminate in Tamarin
  (`--prove` ran >130s; the regenerated `Valid(cid)` fact loops the backward search — the
  exact documented failure mode). So the split stands: mechanistic-token revocation is
  **ProVerif's lane** (Revoke.pv), Tamarin uses the terminating trace-restriction idiom
  (Revoke.spthy / PersistentRecheck.spthy). This is a genuine tool-capability finding, not a
  modeling gap — kept as a recorded artifact, excluded from the auto-verified matrix.
- **Modeling-idiom notes worth keeping:** ProVerif destructors cannot recurse (depth `<`
  bound is modeled at the worked instance, not by recursion); ProVerif reserves `time`
  (renamed `tstamp`); ProVerif phases do not persist a private-channel "cache" across phases
  the way the live token does (the Inc 12 bug is the cleaner "drop the re-check"). Tamarin
  needs the foreign mids pinned to registered identities to avoid a leaf-granter aliasing
  artifact (DeepChainN) — ProVerif pins them via process parameters for free.

## Recommendation

Phase 2's scoped attacker model is **complete and green in both tools.** The V7 capability
design holds, under an active Dolev-Yao attacker, against: delegation-caveat bypass
(no_delegation, depth), stale-cap (expired) use, deep multi-foreign-granter cross-peer
escalation, parametric K-of-N threshold bypass, execute replay (now both tools), and
persistent-capability "trusted-forever" fail-open — each with the load-bearing check
demonstrated by a negative control. **Phase 3** (post-release, separate explicit GO) is the
async/extension PROTOCOLS proper — continuation dispatch, INSTALL/installation-grant chains
(§5.8 three-slot + transferred-closure confused-deputy), subscription notification flows —
**gated on vendoring `EXTENSION-CONTINUATION/-SUBSCRIPTION/-COMPUTE` into `spec-data/`** so
they can be modeled faithfully rather than from changelog mentions. Findings route to
`entity-core-architecture` as proposals/review notes — no spec edits here.
