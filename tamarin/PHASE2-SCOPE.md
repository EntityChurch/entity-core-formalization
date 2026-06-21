# Phase 2 — Tamarin/ProVerif active-attacker model: scope + build order

**Owner:** architecture (design assurance). **Status:** Phase-2 COMPLETE.
**Off the 06-21 release critical path** — additive assurance, a separate explicit GO from
Phase 1. **Lead workflow:** ProVerif + Tamarin **in lockstep** — every lemma transcribed
independently in both prover families before it is called done (the Phase-1 pattern).

Read first: `PHASE1-FORMALIZATION-REPORT.md` (what Phase 1 established) → this →
`PHASE2-FORMALIZATION-REPORT.md` (results) → `../docs/ASSURANCE-MAP.md` (the walls). Model
against `../spec-data/v0.8.0/`, cite the V7 §ref on every modeled element.

## What Phase 1 established (the baseline Phase 2 extends)

Five lemmas — unforgeability (§5.5), no-escalation (§5.6), deep-chain granter-frame (§5.5a,
2-link), grantee-binding + no-replay (§5.2, no-replay Tamarin-only), revocation (§5.1,
mechanistic in ProVerif) + multi-sig K-of-N (§3.6, fixed K=2/N=2) — each green in both tools
with a negative control. Phase 2 closes the named "Does NOT say" boundaries and the
cross-language asymmetries, and adds the delegation-caveat + temporal + persistent-recheck
surfaces.

## Build order (each lands green in BOTH tools + a negative control)

| # | Theory | §refs | Headline lemma | Negative control | Closes |
|---|---|---|---|---|---|
| ✅6 | `Caveats` | §5.7 | `no_delegation` honored — a child of a no-delegation cap is never accepted | drop the consult → delegate-past-prohibition | new §5.7 surface |
| ✅7 | `DepthBound` | §5.7 | accepted chain depth < `max_delegation_depth` (worked instance =1) | drop the depth guard → over-deep admit | new §5.7 surface |
| ✅8 | `Expiry` | §5.5/§5.10 | accepted ⇒ not expired at the single sampled `t` (A-LEAN-1) | drop the temporal check → stale-cap admit | report's "no TTL arithmetic" gap |
| ✅9 | `DeepChainN` | §5.5a | N=3, TWO foreign mids: per-link granter-frame, no deep cross-peer escalation | canon vs verifier frame → deep FOREIGN-GRANTER | report's "2-link only" bound |
| ✅10 | `MultisigKN` | §3.6/§5.5 | parametric K=2 of N=3: S1(local) + a distinct co-signer | accept on 1 sig → threshold bypass | report's "fixed K=2/N=2" bound |
| ✅11a | `BindingReplay` | §5.2 | **no-replay in ProVerif** (injective, challenge-response) | fixed challenge → replay accepted | Tamarin-only no-replay asymmetry |
| ✅11b | `RevokeMech` | §5.1 | mechanistic linear-token revoke **in Tamarin** | — | **NOT closed** — confirmed non-terminating (see report) |
| ✅12 | `PersistentRecheck` | §6.8/§5.1/§1.7 | persistent cap re-checked at every async use; revoked-between-uses denied | skip the re-check on the later use → fail-open | the async/extension attacker surface (core property) |

## The discipline (every increment) — carried from Phase 1

1. **Model against `../spec-data/v0.8.0/`**, cite the §ref on each modeled check.
2. **Abstract, never re-model, the verdict interior + crypto.** §5.4 pattern-match
   arithmetic is Lean's; sign/verify are symbolic (wall #1). Orders/depths/times are
   modeled as the finite *relation* the verifier checks, not the matcher internals.
3. **Each increment green in BOTH tools + a negative control each tool catches.** State
   auto-vs-guided per tool. All Phase-2 lemmas closed automatically (no proof hand-holding).
4. **make + podman only.** `entity-proverif` + `entity-tamarin`. `make proverif THEORY=<T>`
   / `make tamarin THEORY=<T>`.
5. **5th wall in the report** — what is abstracted and who owns it, per theory.

## Explicit scope boundary — what Phase 2 does NOT model (and why)

The async/extension PROTOCOLS themselves — `EXTENSION-CONTINUATION`,
`EXTENSION-SUBSCRIPTION`, `EXTENSION-COMPUTE` (continuation dispatch, INSTALL/installation
grants, subscription notification mechanics) — are **not in the vendored `v7.76` snapshot**
(only CORE-PROTOCOL + CBOR + TYPE-SYSTEM are). Modeling their wire/dispatch mechanics would
violate the model-against-vendored-spec discipline. Inc 12 therefore models the **core-spec
property that governs those flows** — §6.8's per-use re-check ("a revoked capability never
passes a check, even if it passed earlier") — not the extension protocols. Full
continuation/subscription/INSTALL attacker models are a **Phase 3** item, gated on vendoring
the extension specs into `spec-data/`.

## Phase-2 success = the matrix above all-green in both tools

Achieved: increments 6-10, 11a, 12 each machine-closed in both tools + each negative control
caught in both. 11b is the one honest non-closure (a tool-capability split, documented).
Findings route to `entity-core-architecture` as proposals/review notes — no spec edits here.
