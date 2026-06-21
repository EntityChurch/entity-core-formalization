# FORMALIZATION-REPORT — Spike B (ProVerif / capability unforgeability)

**Status:** Spike B complete — ProVerif **and** Tamarin, both auto, agreeing.
**Recommendation: GO** to a scoped Phase 1.
**Artifact type:** design-assurance formalization note. Models the **V7 design** under an
active Dolev-Yao attacker — not the code.

---

## TL;DR — the headline result

A symbolic protocol model of **capability-chain unforgeability** (V7 §5.5 chain
verification + §5.6 attenuation linkage + §7.3 signatures) **closed automatically in BOTH
ProVerif and Tamarin** — no reuse/source lemmas, no interactive guidance. And a negative
control (the same model with the §5.5 chain-linkage check removed) **found a concrete
forgery attack in both tools**, proving the model has teeth and the two tools agree:

| Theory | Verifier | Lemma | ProVerif | Tamarin |
|---|---|---|---|---|
| `Unforge.{pv,spthy}` | §5.5-correct | root unforgeability `AcceptedRoot ⇒ IssuedRoot` | **true** (auto) | **verified** (auto) |
| `Unforge.{pv,spthy}` | §5.5-correct | delegation unforgeability `AcceptedDeleg ⇒ Delegated` | **true** (auto) | **verified** (auto) |
| `Unforge.spthy` | §5.5-correct | non-vacuity (accepted chain reachable) | — | **verified** (exists-trace) |
| `UnforgeBug.{pv,spthy}` | linkage check omitted | delegation unforgeability | **false** + attack | **falsified** + trace |

The negative control is Spike B's analog of Spike A's "Deadlock reached": **the model
rediscovers a real V7 bug class** — the §5.5 / §5.5a chain-linkage / granter-frame bug
that the v7.73 cohort cycle caught in Go, Rust and Python — the moment the check is
dropped, and **both provers independently find it.**

## Status as of Spike B

- **Toolchain:** containerized (make + podman), zero host installs. `entity-proverif` =
  `opam install proverif.2.05`; `entity-tamarin` = the pinned Tamarin 1.12.0 prebuilt
  linux64 binary + Maude (apt). Both `make smoke` green. Mirror the proven `entity-tla` shape.
- **Models:** `Unforge.pv` / `Unforge.spthy` (correct verifier) + `UnforgeBug.pv` /
  `UnforgeBug.spthy` (linkage-omitted negative control). ~80 lines each; symbolic
  sign/verify; built-in DY attacker. The ProVerif and Tamarin theories are independent
  transcriptions of the same fragment — agreement across two prover families is extra
  evidence against a single-tool modeling artifact.
- **The gate question — "auto or heavy hand-holding?" — answered: AUTO, in both tools.**
  Every lemma closed in well under a second with no proof guidance (ProVerif <1s; Tamarin
  ~0.4s). This is the de-risk result the spike existed to find; it materially lowers the
  Phase-1 cost estimate.

## What the model proves — and what it does NOT yet say

**Proved (unbounded sessions, symbolic crypto, active attacker):**
- The verifier accepts a **root** chain for `(g, s)` only if the honest root authority P
  actually issued it (`AcceptedRoot ⇒ IssuedRoot`). Rests on P's signature being
  unforgeable (§7.3) — exactly our crypto wall.
- The verifier accepts a **2-link delegated** chain conferring `s2` on `gB` only if the
  honest delegator A actually delegated it (`AcceptedDeleg ⇒ Delegated`). The attacker —
  holding its own keys and full network control — cannot manufacture a chain A never
  signed, *provided the verifier enforces the §5.5 linkage*.
- **Counter-fact:** drop the `parent.grantee == child.granter` linkage and unforgeability
  breaks immediately (attacker self-signs a child onto the public root) — the linkage
  check is load-bearing, and the model shows precisely why.

**Does NOT say (honest boundary):**
- *Only 1 delegation hop is modeled (root → A → B).* Deeper chains and the per-link
  granter-frame canonicalization across N foreign granters (§5.5a Amendment 1, the
  `AUTHZ-ATTENUATION-FOREIGN-GRANTER-DEEP` class) are Phase 1.
- *Attenuation (§5.6) is structural, not yet semantic.* The model checks chain linkage +
  signatures; it treats `scope` as opaque and does **not** yet prove "child ⊆ parent" (the
  no-escalation property — the symbolic mirror of Lean's `isAttenuated_trans`). That is the
  highest-value Phase-1 lemma.
- *No revocation, no multi-sig, no expiry/TTL.* (§5.1 revocation, §3.6 multi-granter,
  §5.6 expiry-nil-vs-finite) — all Phase 1.
- *Grantee-binding (§5.2 step 3, grantee == author) and replay/reflection are not yet
  modeled* — the next lemmas after no-escalation.
- *This is the design, not the code.* Fuzzing + adversarial-authz tests own whether the
  code rejects hostile bytes (ASSURANCE-MAP row 6); ProVerif owns whether the design
  resists the attacker. Different objects.

## Scope boundaries — the walls

1. **5th wall — spec↔model fidelity (deepest).** The result is relative to `Unforge.pv`
   faithfully transcribing §5.5/§5.6/§7.3 from `spec-data/v0.8.0/`. Mitigation: events and
   checks cite §refs; the negative control is grounded in a *named, real* V7 bug class
   (v7.73 cohort). No tool closes this wall — review owns it.
2. **Crypto wall.** sign/verify are perfect symbolic functions (§7.3). This is the same
   trust boundary Lean takes as opaque axioms — assumptions line up, no fidelity loss.
3. **Verdict-interior wall.** We model the *chain-acceptance structure*, not the §5.4
   pattern-matching interior — Lean owns the attenuation arithmetic; here scope is opaque.
4. **Model-not-code.** ProVerif certifies the design; validate-peer + fuzzing own the code.

## On-ramp pain (for the Phase-1 estimate)

- **Lower than expected** — and notably lower than the handoff's "~2–4 weeks climbing
  curve" caution. The unforgeability fragment was ~hours including the negative control.
  ProVerif's applied-pi surface mapped cleanly onto issuance / delegation / verify.
- The one design subtlety that matters: the lemma is only meaningful if P issues a root
  **only to the honest A** (not as an open oracle) — otherwise the attacker roots its own
  legitimate chain and "unforgeability" becomes vacuous. Documented in the model.
- **No proof hand-holding was needed at all** — the headline de-risk finding.

## Toolchain note — Tamarin cross-check DONE; the two tools agree

The plan was "lead with ProVerif, cross-check with Tamarin on the same fragment." Both are
now done and **agree on every result** (table above). The `tamarinprover/tamarin-prover`
registry image was unavailable at every tag probed, so `entity-tamarin` is built from the
**pinned Tamarin 1.12.0 prebuilt linux64 binary** + Maude (apt) — far cheaper than the
from-source GHC/stack build. One honest wrinkle: Ubuntu 24.04 ships **Maude 3.2**, which
Tamarin flags as an unsupported point-release (it wants 3.2.1); Tamarin emitted a warning
but proved correctly regardless. Pinning a Tamarin-blessed Maude is a cheap Phase-1
hardening. ProVerif did not report any over-approximation/false-attack that Tamarin
resolved on this fragment — the two agreed exactly, in both the secure and the buggy model.

## Recommendation — GO, with a scoped Phase 1

The spike cleared its gate: the unforgeability lemma closed **automatically**, and the
model demonstrably catches a real linkage-bug class. The de-risk question ("is symbolic
verification of V7's cap chains tractable, or a months-long proof-engineering slog?") is
answered favorably for the unforgeability fragment.

**Phase 1 scope (estimate: ~1–3 weeks for the high-value lemmas, ProVerif-first):**
1. **No-escalation / attenuation (§5.6)** — model `scope` with an order and prove an
   accepted child never exceeds its parent. The symbolic mirror of Lean's
   `isAttenuated_trans`; the single highest-value security lemma. (~days–1wk)
2. **Deep chains + per-link granter-frame (§5.5a Amendment 1)** — N-hop, foreign granters;
   target the `AUTHZ-ATTENUATION-FOREIGN-GRANTER-DEEP` class symbolically. (~days)
3. **Grantee-binding + no-replay/reflection (§5.2 step 3)** — the wielder must hold the
   leaf grantee's key; old caps can't be replayed cross-session. (~days)
4. **Revocation (§5.1) and multi-sig roots (§3.6 / §5.5 M3–M7)** — convergent Layer-1
   inputs and K-of-N. (~1wk)
5. **Cross-check (1)–(3) in Tamarin** (toolchain already built this spike); report
   auto-vs-guided per tool and any ProVerif over-approximation Tamarin resolves. Pin a
   Tamarin-blessed Maude (3.2.1+) while doing so. (~days)

Phase 1 remains **post-06-21, off the critical path**, a separate explicit GO.
