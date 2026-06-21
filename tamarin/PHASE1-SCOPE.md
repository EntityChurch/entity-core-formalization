# Phase 1 — Tamarin/ProVerif active-attacker model: scope + build order

**Owner:** architecture (design assurance). **Status:** Phase-1 ACTIVE — Spike B
cleared GO/GO (`FORMALIZATION-REPORT.md`). **Off the 06-21 release critical path.**
**Lead workflow:** ProVerif + Tamarin **in lockstep** — every lemma is transcribed
independently in both prover families before it is called done. Agreement across two
tools is extra evidence against a single-tool modeling artifact (the Spike-B pattern).

Read first: `README.md` → `FORMALIZATION-REPORT.md` (Spike B) → this →
`../docs/ASSURANCE-MAP.md` (the walls). Model against `../spec-data/v0.8.0/`, cite the
V7 §ref on every modeled element.

## What Spike B already established (the baseline we extend)

`Unforge.{pv,spthy}` proves **structural unforgeability** for a 1-hop chain
(root P → A → B): signatures valid (§7.3) + chain linkage `parent.grantee ==
child.granter` (§5.5) + root-granter-local. Closed **automatically** in both tools;
the negative control `UnforgeBug` (linkage dropped) finds a forgery in both. `scope`
is **opaque** there — the chain structure is proved, the *authority arithmetic* is not.

Phase 1 gives `scope` real structure and adds the remaining attacker objectives.

## The discipline (every increment)

1. **Model against `../spec-data/v0.8.0/`**, cite the §ref on each modeled check.
2. **Abstract, never re-model, the verdict interior + crypto.** §5.4 pattern-match
   arithmetic is Lean's; sign/verify are symbolic (wall #1). We model the *chain
   acceptance structure* and the *order relation*, not the matcher internals.
3. **Each increment lands green in BOTH tools + a negative control that each tool
   catches** (the Spike-B "has teeth" pattern). State auto-vs-guided per tool.
4. **make + podman only.** `entity-proverif` + `entity-tamarin` images built.
   `make proverif THEORY=<T>` / `make tamarin THEORY=<T>`.
5. **5th wall in the report** — what is abstracted and who owns it.

## Build order (the 5 Phase-1 items from the Spike-B recommendation)

| # | Theory | §refs | Headline lemma | Negative control |
|---|---|---|---|---|
| ✅0 | `Unforge` | §5.5/§7.3 | unforgeability (root + 1-hop deleg) | linkage dropped → forgery (Spike B) |
| ▶1 | `NoEscalation` | §5.6 | accepted leaf authority ≤ root authority (symbolic `isAttenuated_trans`) | per-link `is_attenuated` dropped → escalation |
| 2 | `DeepChain` | §5.5a Amd 1 | N-hop, foreign granters: per-link granter-frame canon; no escalation deep | canon against verifier frame → FOREIGN-GRANTER-DEEP admit |
| 3 | `Binding` | §5.2 step 3 | accepted EXECUTE ⇒ wielder holds leaf grantee key; no cross-session replay | drop `grantee==author` → confused-deputy; replay old cap |
| 4 | `Revoke` / `Multisig` | §5.1, §3.6/§5.5 M3–M7 | revoked root never passes; K-of-N needs threshold valid sigs + local-peer-in-signers | honor-revocation off → revoked passes; threshold bypass |

Item 5 of the report (cross-check (1)–(3) in Tamarin) is **subsumed by the lockstep
workflow** — every theory above ships both `.pv` and `.spthy`. Plus: pin a
Tamarin-blessed Maude (3.2.1+) to clear the Spike-B warning wrinkle.

## Modeling strategy notes (how `scope` gets structure without re-modeling §5.4)

- **Order as an explicit finite relation.** Authority is a small finite lattice
  (e.g. `admin` ⊐ `read`). `is_attenuated(child,parent)` ⟺ `child ≤ parent` in that
  order. ProVerif: `leq` as a destructor that succeeds only on valid pairs. Tamarin:
  persistent `!Leq(a,b)` facts seeded at setup; the verify rule requires the fact.
  This is faithful to §5.6's "child MUST be ≤ parent" *as an order check* — the
  pattern-arithmetic that decides the order for real paths is Lean's/§5.4's, abstracted.
- **Granter-frame (§5.5a)** is modeled as: a peer-relative scope canonicalizes
  against *its own granter's* frame. The bug class = canonicalizing against the
  verifier frame, which silently widens a foreign-granted `*`.
- **Threat surface for attenuation:** the delegator re-signs whatever child scope the
  network supplies (a delegator MAY sign anything; V7 enforces attenuation at *verify*
  time per-link). The verifier's `is_attenuated` check is therefore the sole defense —
  exactly what the negative control removes.

## Go/no-go is already GO. Phase-1 success = the matrix above all-green

Each lemma machine-closed in both tools (auto or documented guidance) + each negative
control caught in both. Honest boundaries (deep-chain bound, opaque matcher, no TTL
arithmetic beyond the order) stated per theory in the report. Comprehensive async/
extension attacker flows (continuations, subscriptions, INSTALL) remain Phase 2.
