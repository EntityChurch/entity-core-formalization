# spec-data v0.8.2.24 — Snapshot Manifest

**Spec version:** Entity Core Protocol **0.8.2.24** (`ENTITY-CORE-PROTOCOL.md` `**Version**: 0.8.2.24`)
**Snapshot type:** verbatim copy of the authoritative normative spec files — **byte-for-byte, no paraphrase.**
**Purpose:** the modeling ground truth for the formal design-assurance project. TLA+ / Tamarin / Spin / Apalache / ProVerif models are written against a *pinned* version so a model and its result are reproducible per spec-version. When the spec moves, vendor a new snapshot and re-check.

> ⚠ **THIS SNAPSHOT IS NOT THE MODELING PIN.** `spec-data/MODELING-PIN` still names **`v0.8.2`**,
> and **every published result in this repository remains a statement about `v0.8.2`.** This
> snapshot is vendored so that the drift measurement, the re-check work and the 0.8.2.22–.24
> authorization surface can be read against a frozen text rather than against a live checkout.
> The pin moves **last**, per step 5 of the re-vendor discipline — only once the models have
> been re-validated against this text. See *"What needs modeling work"* below for the list that
> gates that move.

## Files (the three authoritative normative inputs)

| File | Spec version | Bytes | SHA-256 |
|---|---|---|---|
| `ENTITY-CORE-PROTOCOL.md` | 0.8.2.24 | 522 911 | `827edf9b01e48301ea3fcc2d2365d9270cc85063dcbe49f0dba4c8d861cee0e9` |
| `ENTITY-CBOR-ENCODING.md` | 1.7 | 59 492 | `dd6aa47de343b335ececc3c7c654da019dc9e473eb4639af3dc9d7a202a8393f` |
| `ENTITY-NATIVE-TYPE-SYSTEM.md` | 4.2.1 | 120 642 | `043fc80d4fd21ff074082e1f3c76b779d73d9f172a90d3f2a986d68e0cde740d` |

Verify: `sha256sum spec-data/v0.8.2.24/*.md`.

## Provenance

| Field | Value |
|---|---|
| Source repo | `entity-core-protocol` (sibling; public source mirror) |
| Source path | `specs/` |
| Source ref | `dev` @ the 0.8.2.24 fold |
| Vendored | 2026-09-14, by this repo |
| Method | `cp` from the source tree; each copy re-hashed and compared against the source file's SHA-256 before acceptance. All three matched. |
| Supersedes | nothing — `v0.8.0/` and `v0.8.2/` stay in place as point-in-time pins |

**Cited by content, not by commit.** The digests above are the durable identifier. The internal
source commit is recorded in `docs/status/` only; published history is re-authored at the release
boundary and an internal SHA resolves to nothing for a public reader.

## What changed since `v0.8.2` — the re-check record

Required by the re-vendor discipline. Measured by `tools/spec-drift.py` (`make specdrift`); the
full classification is `docs/SPEC-DRIFT-ASSESSMENT.md`.

### Structure: completely stable

| check | result |
|---|---|
| Sections added | **none** |
| Sections removed | **none** |
| Sections renumbered | **none** |
| Numbered `### N.M` sections (the coverage denominator) | **91 → 91**, unchanged |
| Model `§`-citations that no longer resolve | **0 of 31** |

`ENTITY-CORE-PROTOCOL.md` grows by **558 lines** (+108 KB) with **no structural movement at all**.
Every `§`-citation in every model still resolves against this snapshot.

### Content: one arc, and it is entirely authorization

Twelve point revisions landed between the pin and this snapshot (`0.8.2.12`…`0.8.2.24`).
**15 of the 31 sections the models cite moved.** Ten of the fifteen moved *since this repo's last
drift assessment* (which was taken at `0.8.2.21`): §3.3, §3.6, §5.2, §5.2a, §5.4, **§5.5**, §5.6,
§6.8 — plus **§1.8** and **§3.1**, which no model cites and which are where the capability forgery
was closed.

| § | model files | pin → .21 | .21 → .24 | what the new movement is |
|---|---|---|---|---|
| **§5.5** | **39** | 0 | **+738** | **NEW.** The resolution-integrity precondition on `verify_capability_chain` (0.8.2.23), plus the note that the `included` arm and the content-store arm *differ in trust*. The most-cited section in this repo, and it had never moved before |
| §6.8 | 10 | +3 793 | +2 799 | the authority table becomes an **intersection** (.22); row 1's ceiling ruled to be the executing handler's own grant (.24 N5) |
| §5.2 | 17 | +5 493 | +2 746 | scope type is a property of the **dimension**, supplied by the call site (.22); the `check_resource_scope` pattern arm takes the sentinel **first**; the two-empties rule (.24 N6) |
| §5.4 | 9 | +10 183 | +1 828 | `NEVER_MATCH` scoped to **path-scope only** (.24 N2); the consumer table gains `check_resource_scope`; *"a sentinel arm is a control-flow obligation, not a line"* (.22) |
| §5.2a | 1 | +1 424 | +3 749 | three resolution-integrity disposition rows (.23); `400 hash_mismatch` pinned in the imperative and a decode-boundary refusal ruled a **refusal, not silence** (.24 N3/N4) |
| §3.6 | 4 | +488 | +2 123 | the id-scope/path-scope dimension mapping restated as `[MUST]`, and the `scope.type` admission MAY (.24 N1) |
| §3.3 | 1 | +8 733 | +961 | decode-boundary status codes |
| §5.6 | 14 | +1 092 | +186 | `scope_subset` takes the scope type as a parameter (.22) |
| §1.8 | **0** | +626 | **+1 389** | **the resolution-integrity `[MUST]` itself** — never resolve an entity used for an authority decision through an address not verified against its content. **Cited by no model in this repo** |
| §3.1 | **0** (core) | 0 | **+1 060** | **the `included` map keying, made normative in both directions.** At the pin it was a `MUST` in the indicative with no enforcing operation and no vector. **Cited by no core model in this repo** |
| §4.2 · §4.6 · §4.7 · §5.8 · §5.9 · §6.2 · §6.5 | 3–12 | moved | **0** | unchanged since the last assessment; classification in `docs/SPEC-DRIFT-ASSESSMENT.md` stands |

### What needs modeling work — the list that gates the pin move

| # | Subject | Why it is owed | Where |
|---|---|---|---|
| 1 | **§1.8 / §3.1 / §5.5 resolution integrity** | A capability/identity forgery closed in shipped text, whose enabling indirection — *resolve an entity by a wire-supplied address* — exists in **zero** models here, in the track whose stated subject is capability unforgeability under an active attacker | `tamarin/` — new theory + `*Bug` control |
| 2 | **§6.8 authority selection, as an intersection** | `tla/Authority.tla` declares its subject as *"WHICH authority is consulted and WHETHER it is consulted"* and makes SELF/GRANT coverage deliberately disjoint. The falsifier is built; the rule is new and is now a conjunction, not a three-row exclusive table | `tla/Authority.tla` |
| 3 | **§5.2 / §5.6 typed dispatch at `scope_subset`** | The type is now `[MUST]` supplied by the call site at **both** matchers. This is the routed K1 finding landing in normative text | Lean seam (`docs/LEAN-SEAM.md` L5, L6) |
| 4 | **§5.4 sentinel, scoped to path-scope** | The `NEVER_MATCH` rule no longer ranges over `operations`/`peers`. `lean/lemmas/` measures the matcher; the scoping is new | `lean/lemmas/` |
| 5 | **§5.2a decode-boundary dispositions** | New status-code surface with a *refusal, not silence* `[MUST]`; `tla/ConnCodes.tla` and `spin/conncodes.pml` transcribe the §4.7 table and already carry one known contradiction | `tla/ConnCodes.tla`, `spin/conncodes.pml` |

**Item 1 is the one that changes how this snapshot should be read.** It is not new surface that
happens to be unmodeled; it is surface that was **in the pin**, carried a `MUST`, and was outside
every model's domain without that abstraction being declared anywhere. The audit is
`docs/status/AUDIT-2026-09-14-THE-DENOMINATOR-WAS-OUR-OWN-CITATIONS.md`.

## Boundary

**This snapshot is frozen from the moment it is committed.** Model against it, never against a
live checkout, and never edit it in place — a pin whose bytes can change is not a pin. Only this
manifest is repo-authored provenance; it is excluded from the hashed set by `tools/spec-drift.py`
and the three normative `.md` files above are byte-frozen.
