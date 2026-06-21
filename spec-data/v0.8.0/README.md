# spec-data/v0.8.0/

**Verbatim snapshot of the authoritative normative specs** — byte-for-byte copies of
`entity-core-protocol/specs/{ENTITY-CORE-PROTOCOL,ENTITY-CBOR-ENCODING,ENTITY-NATIVE-TYPE-SYSTEM}.md`.

- **Authoring authority:** architecture only. The formal team does NOT write spec-data — it *models against* it.
- **No paraphrase:** this is the literal spec. Paraphrase would be a fidelity bug.
- **Integrity + provenance:** see `MANIFEST.md` (SHA-256 per file + source commit).
- **This is the subject under verification.** The models reason about the design these files describe; their faithfulness to this text is the foundational assumption (`docs/ASSURANCE-MAP.md`).
- **Wire-identical to the prior V7 line.** Entity Core Protocol **0.8.0** (V8) is the
  de-versioned release cutover of the V7 line this project already proved: **no
  wire-format change, no new error/status code, identical section structure.** The
  core spec was renamed `ENTITY-CORE-PROTOCOL-V7.md` → `ENTITY-CORE-PROTOCOL.md` and
  stamped `**Version**: 0.8.0`; CBOR (1.5) and the type-system (4.2.1) are normatively
  unchanged. Because the modeled design is unchanged, the invariant-based proofs carry
  forward and re-running them against this snapshot is the verification. See
  `MANIFEST.md` for the full delta.

See `MANIFEST.md` §"the sections the spikes care about" for the reading guide.
