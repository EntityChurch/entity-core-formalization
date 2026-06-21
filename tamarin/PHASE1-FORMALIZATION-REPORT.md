# PHASE1-FORMALIZATION-REPORT — Tamarin/ProVerif active-attacker model

**Status:** Phase 1 COMPLETE — all five scoped lemmas machine-closed in **both** ProVerif
and Tamarin, each with a negative control caught in both tools.
**Artifact type:** design-assurance formalization note. Models the **V7 design** under an
active Dolev-Yao attacker — not the code.
**Scope:** the 5-item Phase-1 plan from the Spike-B `FORMALIZATION-REPORT.md`, built
ProVerif + Tamarin **in lockstep** (every theory transcribed independently in both prover
families). Read with `PHASE1-SCOPE.md` (the plan) and `../docs/ASSURANCE-MAP.md` (walls).

---

## TL;DR — the headline result

Spike B proved 1-hop **structural** unforgeability (signatures + chain linkage, scope
opaque). Phase 1 gives `scope` real structure and adds the remaining attacker objectives.
**Five new security lemmas, each closed automatically in both tools, each with a negative
control that both tools catch** — the model rediscovers, in each case, the real V7 bug
class the check defends against:

| # | Theory | §refs | Lemma (proved) | Negative control (caught) |
|---|---|---|---|---|
| 0 | `Unforge` | §5.5/§7.3 | unforgeability (root + 1-hop deleg) | linkage dropped → forgery *(Spike B)* |
| 1 | `NoEscalation` | §5.6 | accepted leaf authority ≤ root authority (symbolic `isAttenuated_trans`) | per-link `is_attenuated` dropped → escalation |
| 2 | `DeepChain` | §5.5a Amd 1 | foreign-granted bare-`*` reaches the granter's namespace only, never the verifier's | canon against verifier frame → FOREIGN-GRANTER cross-peer admit |
| 3 | `Binding` | §5.2 step 3 | accepted EXECUTE ⇒ wielder holds the leaf grantee's key; **no-replay** (Tamarin) | drop `grantee==author` → confused-deputy; drop single-use → replay |
| 4a | `Revoke` | §5.1 | a revoked cap is never accepted afterwards | `is_revoked` consult dropped → silent fail-open |
| 4b | `Multisig` | §3.6 / §5.5 M3–M7 | K-of-N root accepted only with `threshold` distinct signers (incl. local peer) | threshold bypass (1 sig) → under-signed admit |

The negative controls are this phase's analog of Spike A's "Deadlock reached": each is
grounded in a **named, real** V7 bug class — the §5.5a FOREIGN-GRANTER cohort cycle
(v7.73), the §5.1 "writes the marker but never reads it" fail-open, the §5.6 attenuation
monotonicity that Lean's `isAttenuated_trans` proves on the logic side.

## Full verification matrix (reproduce: `make proverif THEORY=<T>` / `make tamarin THEORY=<T>`)

| Theory | Property | ProVerif | Tamarin |
|---|---|---|---|
| `NoEscalation` | no-escalation (admin never accepted under read root) | **true** | **verified** |
| `NoEscalation` | non-vacuity (read-level chain accepted) | reachable | verified |
| `NoEscalationBug` | no-escalation | **false + attack** | **falsified + trace** |
| `DeepChain` | no cross-peer escalation (V-namespace unreachable) | **true** | **verified** |
| `DeepChain` | non-vacuity (A's own namespace authorized) | reachable | verified |
| `DeepChainBug` | no cross-peer escalation | **false + attack** | **falsified + trace** |
| `Binding` | grantee-binding (`AcceptedExec(g) ⇒ Authored(g)`) | **true** | **verified** |
| `Binding` | no-replay (injective, single-use) | *(see note)* | **verified** |
| `BindingBug` | grantee-binding | **false + attack** | **falsified + trace** |
| `BindingReplayBug` | no-replay | *(n/a)* | **falsified + trace** |
| `Revoke` | revoked-never-passes | **true** | **verified** |
| `Revoke` | non-vacuity (live cap accepted) | reachable | verified |
| `RevokeBug` | revoked-never-passes | **false + attack** | **falsified + trace** |
| `Multisig` | threshold (both distinct signers signed) | **true** | **verified** |
| `Multisig` | non-vacuity (root accepted) | reachable | verified |
| `MultisigBug` | threshold | **false + attack** | **falsified + trace** |

All ProVerif lemmas closed in <1s with **no proof hand-holding** (no source/reuse lemmas,
no interactive guidance). All Tamarin lemmas closed automatically in seconds.

## What the lemmas mean — and what they do NOT say (honest boundaries)

**Lemma 1 — no-escalation (§5.6).** Authority is a finite order; `narrow(p)` is the strict
attenuation of `p`; a valid child scope is `p` or `narrow(p)`. The honest root grants the
narrow scope; the verifier's per-link `is_attenuated` check is the sole defense (the
delegator re-signs whatever child scope the network supplies — faithful to V7, which
constrains nothing at sign time and enforces attenuation at verify time). Proved: a chain
conferring the wide (`admin`) scope is unreachable under a read-only root — the symbolic
mirror of Lean's `isAttenuated_trans`.
*Does NOT say:* the §5.4 path-segment / wildcard arithmetic that decides the order for
real resources is Lean's / abstracted (verdict-interior wall) — we model the order
*relation* the verifier checks, not the matcher internals. Two scope levels modeled.

**Lemma 2 — granter-frame (§5.5a Amendment 1).** A peer-relative resource pattern
canonicalizes against ITS OWN granter's frame. Chain V→A→B with the leaf granted by foreign
peer A; the verifier authorizes a request only if the leaf, canonicalized against A,
covers it. Proved: A's bare-`*` leaf reaches A's namespace only — V's namespace is
unreachable. The control (canon against V) reproduces the `captok_form_dispatch_minted_pl_
presented_xpeer` / `AUTHZ-ATTENUATION-FOREIGN-GRANTER` cross-peer admit.
*Does NOT say:* a 2-link instance models the foreign-granter frame; N-deep chains with
multiple foreign mids are a structural generalization (the bug is per-link and frame-local,
so the 2-link instance is representative — but deeper instances are not separately checked
here). Path-segment matching abstracted (Lean's). In the buggy model the legit case also
breaks (mis-framing redirects A's authority to V) — an honest consequence, not a separate
property.

**Lemma 3 — grantee-binding + no-replay (§5.2 step 3).** The EXECUTE is signed by its
author; the cap's grantee must equal the author. Proved (both tools): an accepted execute
wielding a cap with grantee `g` implies `g` authored it — an intercepted cap cannot be
wielded by a non-grantee (no confused-deputy / theft). **No-replay** (each accepted execute
maps to a distinct authoring; old executes can't be replayed) is proved in **Tamarin** via
a single-use restriction over a fresh nonce — see the tool-comparison note below.
*Does NOT say:* the chain interior is abstracted to "cap signed by root P" (Lemmas 1-2 own
it). Reflection beyond duplicate-acceptance is not separately modeled.

**Lemma 4a — revocation (§5.1).** Full verification = chain-verify AND NOT is_revoked. A
revocation marker makes a cryptographically-valid cap fail. Proved (both tools): a revoked
cap is never accepted afterwards. The control drops the is_revoked consult → the §5.1
"writes the marker but never reads it" silent fail-open.
*Does NOT say:* the marker mechanism is abstracted (ProVerif: a private-channel validity
token; Tamarin: a trace restriction encoding the consult). Path-binding vs explicit-marker
(the two §5.1 mechanisms) are unified to one "revoked" predicate.

**Lemma 4b — multi-sig root (§3.6 / §5.5 M3-M7).** K-of-N root (modeled K=2, N=2, with
signer S1 = the local peer per M6). Proved (both tools): acceptance requires `threshold`
**distinct** signers to have signed; distinctness is structural (two signatures must verify
under two different keys, so one signer's sig replayed into both slots cannot reach
threshold — the M3 dedupe). The control accepts on one signature → threshold bypass.
*Does NOT say:* fixed K=2/N=2; larger thresholds are a structural generalization. The
multi-granter content (signer list / threshold field) is abstracted to a signed constant.

**Across all five — the design, not the code.** Fuzzing + adversarial-authz tests own
whether the code rejects hostile bytes (ASSURANCE-MAP row 6); these provers own whether the
*design* resists the attacker. Different objects.

## Scope boundaries — the walls (carried from ASSURANCE-MAP)

1. **5th wall — spec↔model fidelity (deepest).** Each result is relative to the theory
   faithfully transcribing §5.6/§5.5a/§5.2/§5.1/§3.6 from `../spec-data/v0.8.0/`. Mitigation:
   every modeled check cites its §ref; every negative control is grounded in a *named, real*
   V7 bug class. No tool closes this wall — review owns it.
2. **Crypto wall.** sign/verify are perfect symbolic functions (§7.3) — the same trust
   boundary Lean takes as opaque axioms. Assumptions line up; no fidelity loss.
3. **Verdict-interior wall.** We model the chain-acceptance *structure* + the authority
   *order relation* + the canonicalization *frame*; the §5.4 pattern-match arithmetic that
   computes the order/coverage for real paths is Lean's. Scope is an order, not a path set.
4. **Model-not-code.** These prove the design; validate-peer + fuzzing own the code.

## Tool comparison (the Spike-B gate question, extended)

- **Both tools agree on every secure and every buggy result** (matrix above) — strong
  evidence against a single-tool modeling artifact.
- **ProVerif cleaner for revocation timing.** A private-channel linear validity token
  models is_revoked precisely and ProVerif closed both directions. (ProVerif's *table*
  `get/else` is non-atomic under replication and could not close the positive direction —
  the private-channel token is the right ProVerif idiom for this.)
- **Tamarin cleaner for no-replay.** Tamarin's linear-fact / single-use restriction models
  exactly-once acceptance and proves the injective no-replay lemma. ProVerif's table
  `get/else insert` is not atomic, so the injective property does not close there without a
  challenge-response reformulation — we keep the ProVerif `Binding` theory to the binding
  correspondence and prove no-replay in Tamarin.
- **Tamarin revocation idiom.** A mechanistic regenerating linear token does not terminate
  in Tamarin; revocation there uses the standard terminating trace-restriction idiom, with
  the negative control providing the teeth. (ProVerif carries the mechanistic version.)
- **No proof hand-holding in either tool** on any lemma — the favorable de-risk finding
  from Spike B holds across the full Phase-1 surface.

## Toolchain — Maude pin DONE

`entity-tamarin` now pins the **Tamarin-blessed Maude 3.4** prebuilt binary
(`maude-lang/Maude` release, `MAUDE_LIB=/opt/maude/Linux64`) instead of Ubuntu's apt Maude
3.2 — clearing the Spike-B "unsupported point-release" warning. `entity-proverif` =
opam ProVerif 2.05. Both `make smoke` green; all theories re-verified on the pinned image.

## Recommendation

Phase 1's scoped attacker model is **complete and green in both tools**. The V7 capability
design holds, under an active Dolev-Yao attacker, against escalation, cross-peer
granter-frame confusion, capability theft/confused-deputy, replay (Tamarin), use of revoked
caps, and multi-sig threshold bypass — each with the load-bearing check demonstrated by a
negative control. **Phase 2** (comprehensive async/extension attacker flows —
continuations / INSTALL / subscriptions, N-deep foreign-granter chains, full multi-granter
K-of-N parametric, expiry/TTL arithmetic) remains post-release, off the critical path, a
separate explicit GO. Findings route to `entity-core-architecture` as proposals/review
notes — no spec edits here.
