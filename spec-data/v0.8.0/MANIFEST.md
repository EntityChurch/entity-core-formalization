# spec-data v0.8.0 — Snapshot Manifest

**Spec version:** Entity Core Protocol **0.8.0** (V8) (`ENTITY-CORE-PROTOCOL.md` `**Version**: 0.8.0`)
**Snapshot type:** verbatim copy of the authoritative normative spec files — **byte-for-byte, no paraphrase.**
**Purpose:** the modeling ground truth for the formal design-assurance project. TLA+ / Tamarin / Spin / Apalache / ProVerif models are written against *this* pinned version so a model and its result are reproducible per spec-version. When the spec moves, re-vendor a new snapshot and re-check.

## Wire-identical to the prior V7 line (read first)

This snapshot is **wire-byte-identical** to the V7 line this project already proved
(the `v7.76`/v7.75 spec data). The protocol was **de-versioned at the V8 release
cutover**:

- The core protocol spec is now **`ENTITY-CORE-PROTOCOL.md`** — de-versioned. The
  prior snapshot carried it as `ENTITY-CORE-PROTOCOL-V7.md`; the "V7" was an artifact
  of the source revision folder, not part of the published identity. The spec is
  identified by its `**Version**` field, now stamped **0.8.0**.
- **No wire-format change. No new error/status code.** The substantive deltas that
  closed the V7 line — 0.7.76 (capability-verdict timestamp sampled once per verdict,
  §5.10 Layer-1 input) and 0.7.77 (identifier-naming normalization, mostly
  extension-side type-paths) — left the **core wire contract byte-unchanged**. CBOR
  (1.5) and the native type-system (4.2.1) are normatively unchanged; their bytes
  differ from the V7 snapshot only by release-prep (cross-refs re-pointed to the
  renamed core spec, dev-process dates / unpublished-doc citations stripped).

Because the design under verification is unchanged, the existing invariant-based
proofs carry forward; re-running the matrix against this snapshot **is** the
verification.

## What this snapshot is for

Unlike the keystone snapshots (which feed per-language *peer generation*), this snapshot feeds **protocol-design verification**. The models abstract the implementation away and reason about the *design* — so the spec text here IS the subject under verification, not a generation input. Fidelity of model→spec is the deepest assumption of the whole effort (see `docs/ASSURANCE-MAP.md` §"the 5th wall").

## Files (the three authoritative normative inputs)

| File | Spec version | SHA-256 |
|---|---|---|
| `ENTITY-CORE-PROTOCOL.md` | 0.8.0 | `ff8e76660fd1e64677a9f26495bc73a337bb70a2378ee79b37fe2b1a6861c1a5` |
| `ENTITY-CBOR-ENCODING.md` | 1.5 | `fc57a85cfca759e75cf54795cb36af5cb5b60e1c289440a2db54a123007711cb` |
| `ENTITY-NATIVE-TYPE-SYSTEM.md` | 4.2.1 | `de86fa7ef92a8d0f4794bdc23a497e1ad5016d7e78db3f3b948055c0f745bad3` |

All three SHA-256 differ from the prior `v7.76` snapshot **only by release-prep**
(file rename + cross-reference normalization + date/citation stripping). The
modeled design — the §4 / §5 / §6 surface the models transcribe — is unchanged.

## The sections the spikes care about (reading guide)

- **TLA+ (concurrency/liveness):** §4 (connection, dispatch, §4.8 store-safety, §4.9 resilience, §4.10 resource bounds), **§6.11 reentry / handler-initiated outbound** (the spike-A modeling target), §5.10 (Layer-1 determinism — time is one sampled input).
- **Tamarin/ProVerif (active attacker):** §1.5 (peer-id), §5 (capability: §5.4 pattern matching, §5.5 chain verification + root-granter-local, §5.5a granter-frame canonicalization, §5.6 attenuation), §7.3/§7.4 (signatures). The cap-chain-verify *result* is the abstract predicate; the attacker model is about whether acceptance can be manufactured.

The section numbering is **unchanged** from the V7 line, so the in-model `§`-citations
remain valid against this snapshot.

## Provenance

| Field | Value |
|---|---|
| Source repo | `entity-core-protocol` (sibling, public source mirror) |
| Source path | `specs/` |
| Source git commit | `738117129698908e6d54ef9675a0c9804ccac4a4` (HEAD) |
| Vendored-file cleanliness | the 3 spec files are byte-identical to their committed state at this commit (SHA-verified above). |
| Supersedes | `spec-data/v7.76/` (the prior vendored V7 snapshot — same design, removed at this migration) |

## Re-vendor discipline

Architecture authors spec-data; the formal team does NOT edit it. When the spec advances:
1. Re-copy the three files byte-for-byte into a new `vX.Y.Z/`.
2. Recompute SHA-256, update the table + provenance.
3. Note in a new MANIFEST §"what changed" whether any spiked/modeled section moved (if so, the affected model needs a re-check). Keep prior snapshots in place as point-in-time pins.
