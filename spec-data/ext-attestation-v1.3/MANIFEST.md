# spec-data ext-attestation-v1.3 — Snapshot Manifest

**Spec:** `EXTENSION-ATTESTATION.md` **1.3**
**Snapshot type:** verbatim copy of the authoritative normative spec file(s) — **byte-for-byte, no paraphrase.**
**Purpose:** the modeling ground truth for the `attestation` proof track (`TRACKS.toml`). Models are
written against a *pinned* snapshot so a model and its result are reproducible per spec-version.
When the spec moves, vendor a new snapshot beside this one and re-check.

> **Vendored is not pinned.** This snapshot exists; whether the `attestation` models transcribe it is
> a separate fact, named by that track's `pin_file` in `TRACKS.toml`. Vendoring alone changes no
> result — the pin moves only as the LAST step of validating models against this text.
>
> **This snapshot is FROZEN.** Never edit a file in it. `make specfreeze`
> (`tools/vendor-spec.py verify`) re-hashes every snapshot against the digests below on every
> `make check` and `make matrix`; a pin whose bytes can change is not a pin.

## Files

| File | Spec version | Bytes | SHA-256 |
|---|---|---|---|
| `EXTENSION-ATTESTATION.md` | 1.3 | 53 432 | `855eba2f7eff5e862fca8083741d8d9f19bafe8ff5425086f4190481abc8963f` |

Verify: `make specfreeze` (or `sha256sum spec-data/ext-attestation-v1.3/*.md`).

## Provenance

| Field | Value |
|---|---|
| Source repo | `entity-system-architecture` (sibling) |
| Source path | `specs/extensions/` |
| Vendored | 2026-09-07, by this repo, via `tools/vendor-spec.py vendor --track attestation` |
| Method | byte-for-byte copy; each copy's SHA-256 recomputed and compared against the source file's own digest before acceptance. 1 of 1 matched. |
| Dependency floor | `ENTITY-CORE-PROTOCOL.md` (v7.40+) — met by `spec-data/v0.8.2`, which carries v7.62–v7.76 clause tags |
| Supersedes | nothing — prior snapshots stay in place as point-in-time pins |

**Cited by content, not by commit.** Published history is re-authored at the release boundary,
so a source commit SHA recorded here would resolve to nothing for a reader. The SHA-256 digests
above are the durable identifier and are verifiable by anyone holding either tree.

## Re-vendor discipline

1. Copy the file(s) byte-for-byte into a NEW `spec-data/<snapshot>/`, verifying each copy's
   SHA-256 against the source before accepting it. `tools/vendor-spec.py vendor` does this and
   refuses to write into an existing snapshot.
2. Record SHA-256, byte size and provenance here. Cite by content digest, not by commit SHA.
3. Record what changed and whether any *modeled* section moved, naming the models to re-check.
4. Keep prior snapshots in place as point-in-time pins. **Never edit a snapshot after it is
   written.**
5. The track's `pin_file` moves **last** — only once the models have been re-validated against
   the new text. Vendoring alone changes no result.
