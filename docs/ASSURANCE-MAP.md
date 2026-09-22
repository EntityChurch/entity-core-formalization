# The complete formal-assurance map

The point of this map: **nothing double-owned, nothing assumed without a named
owner.** Each formal question about the Entity Core Protocol is answered by exactly
one tool, on the layer it can actually reach.

> **Which protocol: the `core` track.** This repo declares **4 proof tracks** in
> `TRACKS.toml` (`make trackcheck`) — `core`, `attestation`, `quorum`, `identity`. **This map
> is about `core` and only `core`.** All four are modeled as of 2026-09-07 (nine TLC modules
> across the three extension tracks, `docs/COVERAGE-MATRIX.md` §3c–§3e) and **none of the three
> owns a row here yet**: this map's whole claim is that every formal question has exactly one
> named owner, and no extension track has that structure — **no prover on any of them**, which
> `docs/LEAN-SEAM.md` O5, O14 and O19 record one row per track, and while **9 of 9** extension
> subjects carry even a second model checker (`docs/CORROBORATION.md`, `make enginecount`).
> *(This sentence read "each has one engine and no prover" until 2026-09-09. The engine half
> went false on 2026-09-08, the day the first extension Apalache modules landed, and was missed
> by that session's own D14 sweep — which searched the subject and not the quantifier. The
> prover half is unchanged and is the part that matters.)* They get their own rows
> when they earn them rather than being folded into these. *(This paragraph said `quorum` and
> `identity` were "vendored, unpinned and unmodeled" until 2026-09-07; both were promoted the
> same day, hours apart.)*

> **Pinned at spec 0.8.2; the live spec is 0.8.2.19.** Rows 4 and 5 below — the two this
> repo owns — are answered against the SHA-pinned `spec-data/v0.8.2/` snapshot, and
> `make specdrift` reports **12 of 31 cited sections moved**. Eleven of the twelve contradict no model — one of them, §5.8, is a **single backtick** removed
> from a cross-reference row; §4.7 is the one that contradicts a model constant. Measured section by
> section in `docs/SPEC-DRIFT-ASSESSMENT.md` — which is also where the two newest movements
> (§5.2 and §5.6, 0.8.2.16) are classified: they contradict no model here, and they land on
> the **Lean seam** instead.
>
> Worth keeping in view: for part of the 0.8.x cycle this note read *"pinned at 0.8.0; the
> protocol is at 0.8.2"*, which was the 5th wall behaving exactly as this document warns it
> can — fidelity is to a pinned text, and a pin ages. The gap was measured
> (`docs/SPEC-DRIFT-ASSESSMENT.md`), the models were re-targeted, and the pin moved as the
> last step of that work. The mechanism that made it visible rather than silent is the
> separation between "which snapshots are vendored" and "which snapshot the models
> transcribe" — that is what `spec-data/MODELING-PIN` is for.

## The six questions

| # | Question | Tool | Layer | Status |
|---|---|---|---|---|
| 1 | Is the authority **logic** correct? (attenuation monotone, deny-by-default, verdict enforces the per-edge check) | **Lean** | implementation (pure core) | **DONE** (keystone Track B) |
| 2 | Do **implementations conform** to the spec? | **validate-peer** | implementation (live, per-peer) | **DONE / ongoing** (keystone) |
| 3 | Is the **crypto** sound? | audited library + FIPS KATs (EverCrypt-class) | primitive | **trusted boundary** (out of scope — we consume, don't design crypto) |
| 4 | Does the **distributed protocol** behave under concurrency — safety **+ liveness**? | **TLA+** | **protocol design** | **THIS PROJECT — Spike A** |
| 5 | Does the protocol resist an **active attacker** — unforgeability / no-escalation? | **Tamarin / ProVerif** | **protocol design** | **THIS PROJECT — Spike B** |
| 6 | Does the impl **reject hostile inputs**? (malformed CBOR, oversized, protocol confusion) | coverage-guided **fuzzing** + adversarial-authz tests | implementation (boundary) | **gap, flagged** (separate security-suite follow-on, not this project) |

Rows 4 and 5 are this project. The tell that they belong to architecture (not to
per-language peer generation): **both sit at the "protocol design" layer.** They
validate the protocol design itself.

## Complementarity (why there's no overlap or redo)

- **Lean** owns the authority-logic interior (row 1, DONE). TLA+ and Tamarin
  *abstract that away* — they treat cap-chain-verify as an abstract predicate /
  function symbol — precisely so they can focus on concurrency and the adversary.
  No re-modeling of the Lean-proven algorithm.

  > **The seam between row 1 and rows 4–5 is now written down: `docs/LEAN-SEAM.md`.**
  > "Lean owns the interior, we abstract it away" is a *division of labour*, and a division
  > of labour is only sound if the property each model **assumes** of the abstraction is the
  > property Lean **proves**. That correspondence used to live nowhere. The ledger states it
  > per abstraction — the proposition relied on, the discharging theorem cited by
  > `(name, file, sha256)`, any residual hypothesis, and a verdict of CLOSED /
  > CLOSED-MODULO-H / OPEN / BY-DESIGN — and `make leanseam` fails when the cited Lean text
  > moves. Writing it produced two results a spot-check could not: `verifyChain` takes
  > `localPeer` as an argument, so the structural verdict is **not** peer-independent and
  > `Revoke.tla`'s cross-peer abstraction is closed only modulo a frame assumption it does
  > not state (L1); and §5.5a namespace isolation is "covered" by ProVerif/Tamarin *and* by
  > Lean while the two **cover different parts of it** — §5.5a admits three pattern forms,
  > our symbolic models carry all three as three `canon` equations, and Lean's isolation
  > theorem holds only for the peer-relative one, scoped there by its hypothesis `hframed`.
  > The **absolute named form** — the one §5.5a *requires* for cross-peer authority — has no
  > Lean theorem (L7, §4.1). Coverage counted by engine cannot see that, which is the
  > argument for counting by assumption instead.
  >
  > *(This paragraph said until 2026-08-30 that the two engines rest on the **same** unproved
  > proposition, ProVerif asserting `hframed` as a rewrite rule. Both halves were wrong —
  > there are three `canon` equations and the second is `hframed`'s negation — and the error
  > is recorded rather than quietly deleted in `LEAN-SEAM.md` §4.1. Nothing is wrong on the
  > ProVerif/Tamarin side and there is no ask there.)*
  >
  > **The ledger does not machine-check any correspondence** — every verdict in it is a
  > human reading of two texts, and `make leanseam` only detects that one of the texts
  > changed. What `make leanproof` adds (2026-08-30) is the other half of the Lean side: the
  > cited theorems are actually **proved**, from Lean's three standard axioms and nothing
  > else, by the compiler the peer pins. That check did not exist anywhere — the keystone
  > peer documents `lake build EntityCoreProofs` as its proof gate and invokes it from
  > nothing, and a `sorry` would not have failed it anyway (Lean reports one as a *warning*;
  > lake exits 0). Still unchecked by any machine: whether the theorem proved is the
  > proposition the model assumes. Differential trace checking (replaying Apalache
  > `.itf.json` counterexamples through the Lean executable model) is what would reach that;
  > it is on the work-list, not done.
- **validate-peer** owns "implementations match the spec" (row 2).
- **Fuzzing + adversarial-authz** own hostile-input rejection in the real code (row
  6). Tamarin proves the *design* resists an attacker; fuzzing checks the *code*
  does. Different objects.

## The walls — where each tool stops and another takes over

Carried and extended from the Lean limits map. A proof/model is only as strong as
its honest boundary.

1. **Crypto wall (`@[extern]` / symbolic).** Ed25519 / SHA / Ed448 are trusted
   primitives. Lean treats them as opaque axioms; Tamarin treats them as perfect
   symbolic functions. **Same trust boundary — the assumptions line up.** Owned by
   the audited library + FIPS KATs + the FFI-vs-native byte-equality cross-check.
   Not us.
2. **IO-shell wall (transport / store / concurrency).** Effects + interleavings.
   Core Lean can't reason about them. **This is exactly TLA+'s wall (row 4)** —
   TLA+ is built to model the interleavings and prove safety + liveness over them.
3. **Adversarial-input wall (the parser).** The hostile byte space. Neither Lean
   nor TLA+ explores it; Tamarin reasons about *protocol-level* attacker messages
   but not malformed-byte rejection. Owned by **fuzzing** (row 6).
4. **Resolve-layer / shell↔model seam.** Models assume the shell feeds correct
   inputs (resolved the right granter frame, verified the sig, collected the full
   chain). If the shell resolves *wrong*, the model's guarantee is vacuous for that
   input. Owned by **live adversarial-authz tests** + the Tamarin attacker model
   (which asks whether the attacker can *cause* a wrong resolution).
5. **The 5th wall — spec↔model fidelity (the deepest assumption).** Every model
   here certifies a *model of the design at the pin*, not the spec's prose and not the
   code. The whole effort
   is relative to the model being a faithful transcription of `spec-data/v0.8.2/`.
   There is no tool that closes this — it is owned by **careful modeling + review
   against the vendored spec**, and by keeping models at spec altitude. State it in
   every report; never let it hide. Chain of trust:
   `spec prose ─(faithful modeling)─ formal model ─(TLC/Tamarin)─ proved property`.

## What a "done" looks like for this project (demonstrator scope)

Not "the protocol is proven." Honestly: **two headline machine-checked properties,
each with its scope boundary stated** —

- TLA+: one safety invariant + one liveness property on the §6.11 reentry slice,
  TLC-checked at a small bound (ideally rediscovering the known runaway/deadlock
  class as a counterexample first, then green after the fix is modeled).
- Tamarin/ProVerif: one capability-unforgeability lemma on a minimal cap-chain
  fragment, machine-closed (auto or with documented guidance).

Comprehensive design assurance (full async/extension flows; full attacker model
with replay/reflection/escalation lemmas) is **Phase 1 — months, post-release, a
separate explicit GO.** See `SCOPING-AND-SPIKE-PLAN.md`.
