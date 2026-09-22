# spec-data/v0.8.2/

**Verbatim snapshot of the authoritative normative specs** — byte-for-byte copies of
`entity-core-protocol/specs/{ENTITY-CORE-PROTOCOL,ENTITY-CBOR-ENCODING,ENTITY-NATIVE-TYPE-SYSTEM}.md`
taken from that repo's published `master`.

- **Vendored, not authored.** This repo copies; it does not write spec text. Every file
  here was hash-checked against its source before acceptance (`MANIFEST.md`).
- **No paraphrase:** this is the literal spec. Paraphrase would be a fidelity bug.
- **Integrity + provenance:** `MANIFEST.md` — SHA-256 and byte size per file, cited by
  content digest rather than by commit SHA, because published history is re-authored at
  the release boundary and internal SHAs do not resolve.
- **Frozen once written.** Never edit a snapshot in place; a pin whose bytes can change is
  not a pin. To follow a spec that has moved, add a new `vX.Y.Z/` beside this one.

## This is vendored but is NOT yet the modeling pin

`spec-data/MODELING-PIN` names the snapshot the models actually transcribe. It currently
says **`v0.8.0`**, and it stays there until the models have been re-validated against the
text in this directory. Until then every published result in this repository is a
statement about 0.8.0, not about 0.8.2.

## What is different from `v0.8.0`

Structurally, nothing: **no section added, removed or renumbered**, all inline sub-labels
intact, and **all 35 model `§`-citations still resolve**. The one structural addition is
§6.11 (a′), which is additive.

By content, 197 lines across 25 sections — but overwhelmingly *additive*: across the 13
cited sections that moved, 16 lines of pre-existing text changed against 105 added. No
property this project proved is contradicted.

What genuinely needs modeling work is the new normative surface — §6.11 (a′) frame-write
atomicity, §4.8 refcount use-after-free, §5.6 malformed temporal-field ingest — enumerated
with affected models in `MANIFEST.md` §"What DOES need modeling work", and analysed in full
in `docs/SPEC-DRIFT-ASSESSMENT.md`.

See `MANIFEST.md` §"the sections the spikes care about" for the reading guide — and note
its caveat that the models' own citations, not that prose list, are the real dependency set.
