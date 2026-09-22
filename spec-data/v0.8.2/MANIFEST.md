# spec-data v0.8.2 — Snapshot Manifest

**Spec version:** Entity Core Protocol **0.8.2** (`ENTITY-CORE-PROTOCOL.md` `**Version**: 0.8.2`)
**Snapshot type:** verbatim copy of the authoritative normative spec files — **byte-for-byte, no paraphrase.**
**Purpose:** the modeling ground truth for the formal design-assurance project. TLA+ / Tamarin / Spin / Apalache / ProVerif models are written against a *pinned* version so a model and its result are reproducible per spec-version. When the spec moves, vendor a new snapshot and re-check.

> **This snapshot is vendored but NOT yet the modeling pin.** The models still transcribe
> `spec-data/v0.8.0/`, and `spec-data/MODELING-PIN` says so. Every published result in this
> repository remains a statement about 0.8.0 until the models have been re-validated against
> the text below and that file is moved. Vendoring is the first step of that work, not the last.

## Files (the three authoritative normative inputs)

| File | Spec version | Bytes | SHA-256 |
|---|---|---|---|
| `ENTITY-CORE-PROTOCOL.md` | 0.8.2 | 414 826 | `6e7e0ca1594099294f89853caef79d8a0a6e851cce70ac297216e125cdc8e4e9` |
| `ENTITY-CBOR-ENCODING.md` | 1.5 | 56 895 | `0826504a82ad4db96da1044c4e67a8103f870160862fb62955562ee5e74d25b9` |
| `ENTITY-NATIVE-TYPE-SYSTEM.md` | 4.2.1 | 120 317 | `64c526210a6908d0d248321178b7216816a24530c308d8aa47d08c9d40da70e5` |

Verify: `sha256sum spec-data/v0.8.2/*.md`.

## Provenance

| Field | Value |
|---|---|
| Source repo | `entity-core-protocol` (sibling; public source mirror) |
| Source path | `specs/` |
| Source ref | published `master` |
| Vendored | 2026-08-27, by this repo |
| Method | `git show master:specs/<file>` piped to the snapshot path; each output hashed and compared against the source blob's hash before acceptance. All three matched. |
| Supersedes | nothing — `spec-data/v0.8.0/` stays in place as a point-in-time pin |

**Cited by content, not by commit.** The prior snapshot recorded a source git commit
(`7381171296…`). That SHA no longer resolves in `entity-core-protocol`'s history, because
published commits are authored fresh at the release boundary — so the provenance record of
`v0.8.0` points at nothing a reader can check. The SHA-256 digests above are the durable
identifier and they are verifiable by anyone holding either tree.

## What changed since `v0.8.0` — the re-check record

Required by the re-vendor discipline: *note whether any modeled section moved, and if so
that the affected model needs a re-check.* Measured by `tools/spec-drift.py`
(`make specdrift`); the full analysis with method and negative controls is
`docs/SPEC-DRIFT-ASSESSMENT.md`.

### Structure: completely stable

| check | result |
|---|---|
| Sections added at 0.8.2 | **none** |
| Sections removed since 0.8.0 | **none** |
| Sections renumbered | **none** |
| Inline sub-labels the models cite (§4.9 a–e, §4.10 a–c, §6.11 a–c) | **all present** |
| Model `§`-citations that no longer resolve | **0 of 35** |

**Every `§`-citation in every model still resolves correctly against this snapshot.** The
one structural addition is a new sub-clause **§6.11 (a′)** (frame-write atomicity), which
is additive and breaks no existing reference.

### Content: additive refinement, not redefinition

`ENTITY-CORE-PROTOCOL.md` changes by 197 lines across 25 of 93 numbered sections. Of the
26 sections the models cite, 13 were touched — but that count overstates the change:

| | lines |
|---|---|
| pre-existing text removed or altered, across all 13 | **16** |
| new text added | **105** |

0–10% of any one section's existing text changed; 1–4% for most; **0% for §5.2, §5.10 and
§6.11**, which are pure additions. 0.8.1 and 0.8.2 are largely conformance findings
(`F32`, `F40`, `F48`, `CAP-1`…`CAP-7`, `RT-6`…`RT-14`, `W7`) being written down as
normative clarification.

Of the 16 altered lines: status-code discrimination in §4.2/§5.1 (a blanket `403` split
into `401` auth-class vs `403` authz-class — rejected either way, and the models model
accept/reject rather than status codes); appended clarification in §4.6, §4.8, §4.10,
§5.5a, §5.6 and §6.2; and exactly two genuine semantic changes, both checked against the
models rather than assumed:

| change | do the models depend on it? |
|---|---|
| §3.6 `F40` — `id-scope` (`operations`, `peers`) matched as a literal string, no longer via the §5.4 path matcher | **No.** The models citing §3.6 (`Multisig*`) cite it for `multi-granter` threshold structure; no model encodes id-scope matching, and §5.4 is unchanged. |
| §6.1 `CAP-1` — handler grant "present and §6.8-valid" replaces "present and non-empty" | **No.** The models citing §6.1 (`Register*`, `register.pml`) cite it as the tree/index source of truth for handler facets; no model encodes grant emptiness. |

**No property this project proved is contradicted by 0.8.0 → 0.8.2.**

### What DOES need modeling work

New normative surface with no model coverage — new territory, not broken results:

| § | new requirement | affected models |
|---|---|---|
| **§6.11 (a′)** | frame writes on a shared/pooled connection MUST be atomic with respect to each other; two frames' bytes MUST NOT interleave | `Reentry.tla`, `reentry.pml`, `Core.tla` — model the mutex discipline around send+recv, not byte-level write atomicity |
| **§4.8** | an unsynchronized reference-count decrement under concurrent dispatch is a use-after-free, hence a §4.9 no-crash violation | `Store.tla`, `store.pml`, `StoreApalache.tla` — refcounts are abstracted away |
| **§5.6 `CAP-6a`** | a capability whose temporal field is unrepresentable is **malformed**; a verifier MUST NOT read it as absent (absent means no expiry — the fail-open) | `Expiry.pv` / `Expiry.spthy` — model expiry validity, not malformed-field ingest |
| §5.9 / §4.10 | TTL and continuation `chain_depth` are distinct magnitudes; `400 chain_depth_exceeded` is distinct from the continuation brake's `429` | resource-bound models |
| §5.10 | deployment-declared `revocation_propagation_bound`; cross-clock skew tolerance δ becomes a Layer-1 input alongside `t` | `Revoke*`, determinism invariants |

Secondary: §5.2 gains a normative three-valued dispatch-authority rule (SELF / GRANT /
ABSENT-must-deny). The underlying confused-deputy property is §6.8, which did **not** move
and is modeled; what this raises is the pre-existing backlog item *"model gate denials so
the dispatch gate is load-bearing"* — `tla/Reentry.tla`'s `Gate(p) == TRUE` is a constant,
so the denial case is inexpressible there.

## The sections the spikes care about (reading guide)

Unchanged from `v0.8.0`, since the numbering is identical:

- **TLA+ (concurrency/liveness):** §4 (connection, dispatch, §4.8 store-safety, §4.9 resilience, §4.10 resource bounds), **§6.11 reentry / handler-initiated outbound** (the spike-A modeling target), §5.10 (Layer-1 determinism — time is a sampled input, and at 0.8.2 so is skew tolerance δ).
- **Tamarin/ProVerif (active attacker):** §1.5 (peer-id), §5 (capability: §5.4 pattern matching, §5.5 chain verification + root-granter-local, §5.5a granter-frame canonicalization, §5.6 attenuation), §7.3/§7.4 (signatures). The cap-chain-verify *result* is the abstract predicate; the attacker model is about whether acceptance can be manufactured.

**Do not treat this list as the dependency set.** It is a human summary and it undercounts —
the models' own `§`-citations are authoritative, and `make specdrift` reads those.

## Re-vendor discipline

When the spec advances:

1. Copy the three files byte-for-byte into a new `vX.Y.Z/` from the **published** spec ref,
   and verify each copy's SHA-256 against the source blob before accepting it.
2. Record SHA-256, byte size and provenance here. **Cite by content digest, not by commit
   SHA** — published history is re-authored at the release boundary and internal SHAs do
   not resolve.
3. Record what changed and whether any *modeled* section moved (`make specdrift`), naming
   the models that need a re-check.
4. Keep prior snapshots in place as point-in-time pins. **Never edit a snapshot after it is
   written.**
5. `spec-data/MODELING-PIN` moves **last** — only once the models have actually been
   re-validated against the new text. Vendoring alone changes no result.

This repo performs the vendoring itself: the source is public and every step is
hash-verifiable. There is no external owner to wait on.
