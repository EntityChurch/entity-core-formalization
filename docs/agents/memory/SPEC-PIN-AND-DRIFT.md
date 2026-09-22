# The spec pin, and what the distance from it costs

**Symptom that brings you here:** `make driftclaim` fired, or you are about to quote a
drift figure, or you are wondering whether a section moving underneath a model changes a
published result.

**Derive every number here; do not recall one.** `make specdrift` is the measurement and
`make driftclaim` gates the prose sites that state it. `docs/SPEC-DRIFT-ASSESSMENT.md` §1
is the live per-section reading.

⛔ *That clause read **"none of the fourteen"** until 2026-09-16, with `make driftclaim` green over
the whole sentence the entire time.* The gate anchors on the canonical phrasing `N of 29 cited
sections moved` and on the live version; **a second, spelled-out copy of the same count sitting in
the next clause is invisible to it** — D15's fifth shape (*a stale number hides best in a sentence
that states it in different words*) inside the paragraph the gate does read. Repaired the way that
shape is always repaired here: **the value is deleted and the subject named**, so the clause cannot
go stale on the sixteenth section. **The fifteenth is §7.3** (0.8.2.26, the signature-message
consolidation), it is cited by **26** model files, and it does not contradict one — every citation
is the crypto wall, which is exactly what *"which bytes the message is"* abstracts away.
`docs/SPEC-DRIFT-ASSESSMENT.md` §1 carries the row and the one adjacency it does NOT wave past.
⭐ **§4.7 WAS the exception and is not any more, 2026-09-15.** `connection_sequence_error` moved
400 → 409 at 0.8.2.4 while `tla/ConnCodes.tla` transcribed 400; that module, its Apalache port
and `spin/conncodes.pml` are now **retargeted to `spec-data/v0.8.2.25`**. ⛔ **Do not quote a
figure for the off-pin group from memory: `make specdrift` reports ONE number for ALL files
sharing a snapshot, so it moves for TWO independent reasons and both have now fired.** It went
`0 of 11` → `0 of 21` the moment a SECOND subject retargeted to `.25` (the eight
`tamarin/Resolution*` files, 2026-09-16) — **the denominator moving because a different subject
landed**, with every gate green. Then it went to a non-zero numerator on 2026-09-17 without this
repo touching anything, because **live advanced past `.25`** and the off-pin group's own cited
set started moving underneath it — `.26` through `.32` changed §4.7 and §4.11 substantively
(a whole new `non_canonical_ecf` row, the close-is-forced-where-desynchronized split, the
in-flight bound). ⛔ **So `0 of N` is not a standing property of an override; it is a measurement
with a shelf life, and the shelf life of the `.25` group expired six revisions after it was
vendored.** It is not a declared `driftclaim` site and no gate will tell you — **derive it,
every time, and read `docs/SPEC-DRIFT-ASSESSMENT.md` §1 for which of the two reasons moved it.** ⛔ **They are therefore NOT statements about the pin, and the mechanism
for saying so is a gate rather than a sentence:** `[track.core.model_pins]` in `TRACKS.toml`,
a `MODELING-PIN-OVERRIDE:` marker in each file, both directions checked by `make trackcheck` §E,
their citations held out of the coverage pair by `make coverage` and measured against their own
snapshot by `make specdrift`. **The cost is visible on purpose: core's published coverage fell
29 → 27 of 91**, because no pin-targeting model cites §4.7 or §5.2a any more, so nothing here
verifies those two sections AS THE PIN STATES THEM. A header sentence would have left the 29
standing and made it false — D15's eleventh shape, *a disclaimer is not a gate*. The off-pin grid
is `docs/COVERAGE-MATRIX.md` §3f.
**§4.10 is the sixteenth, and 0.8.2.25 put the largest MODELABLE surface on the board in the
one place no other instrument can reach it.** New **§4.11** makes the pre-admission refusal a
single invariant — *a peer refusing a frame before admission MUST put a coded EXECUTE_RESPONSE
on the wire; the close is optional; a silent drop and a bare close are two distinct
non-conformances* — and §4.10(a)'s emission shape was strengthened SHOULD/MAY → MUST to point
at it. **Every model citing §4.10 cites (b) or the generic admission bound, and (b) is
byte-identical**, so this is the §6.8 shape again: movement around the clause we consume. What
is new is arm **(f)**, the multiplexed one: *a pre-admission refusal arriving while an admitted
request is in flight on the same connection MUST NOT cost that request its response.*
`entity-system-architecture` records (`KC-2`) that it **cannot be inferred from the other five
and has never been driven anywhere** — ⛔ *and the second half of that went stale on 2026-09-15,
the day after it was written: `entity-core-go` drove arm (f) 3-way
(`preadmission_multiplex_inflight_survives`), quoting the very sentence. **The warrant is better
now, not worse.** Their own comment says the obvious form of the arm is satisfied by a bare close
that drains, so they added a discriminator — a second request on the same connection — which
tests a property §4.11 explicitly leaves to the peer (*"whether it closes afterwards is its own
choice"*), and they have an OPEN ask to arch to split arm (a) so that it would not. **Arm (f)'s
decisive distinction is therefore not wire-decidable as the text stands**, which is `ECP-R24`'s
shape and the conformance seat's missing third disposition. Quote THAT, not the stale clause* —
it is a concurrency claim on a shared connection, which
is `tla/Reentry.tla`'s exact subject and a wire suite's blind spot. See
`docs/SPEC-DRIFT-ASSESSMENT.md` §1d.
**§5.4 and §6.8 moved on 2026-09-11/12 (spec 0.8.2.20/21) and BOTH were previously classified
`unchanged` IN AN ARGUMENT THAT LEANED ON THEIR STABILITY** — `SPEC-DRIFT-ASSESSMENT.md` §1a
said *"§5.4 itself is unchanged"* and §4's reading of the confused-deputy property said §6.8
*"did not move … the property was modeled against stable text."* Both sentences were true when
written and both are now false in their premise, with every gate in this repo green — the
`driftclaim` class again, and the first time it has landed on a **load-bearing clause of our own
argument** rather than on a count. Read `SPEC-DRIFT-ASSESSMENT.md` §1b, not the count: neither
contradicts a model, and the reasons are different in kind. **§5.4 is cited by 9 prover files and
every one of the 9 citations is an ABSTRACTION DISCLAIMER** (*"the §5.4 path matcher stays
abstract"*, *"is Lean's / abstracted here"*) — so the section moved in the one place nothing here
models, and the `§5.4` row of the coverage grid credits two engines for it (see §1b's finding).
**§6.8 moved by +3.8KB and the clause all ten citing models actually use — "a revoked capability
never passes a check" — is byte-identical**; what moved is new surface, and 0.8.2.21's new
authority-selection MUST lands squarely inside `tla/Authority.tla`'s own abstraction.
**§5.2 and §5.6 moved on 2026-09-09 (spec 0.8.2.16) and they are the two most-cited sections
in the repo (17 and 14 model files), so read the classification rather than the count.** What
changed in both is *pseudocode*, not prose: `matches_scope` and `scope_subset` now **dispatch
on the scope's type** — id-scope (`operations`, `peers`) matches literally, path-scope
(`handlers`, `resources`) canonicalizes. No model here contradicts it, because every model
abstracts the matcher and the one dimension any of them frames (`resources`, the §5.5a
granter-frame work in the Tamarin track) is path-scope in both texts. **It lands on the Lean
seam instead** — that is where it was routed, as K1. Re-vendoring is deliberately **not** the next move
(keystone has not upgraded yet); `docs/SPEC-DRIFT-ASSESSMENT.md` is the live measurement and
`make driftclaim` gates every prose site that states the status.
**All four pins are measured as of 2026-09-09, and until that date only one was.** `specdrift`
is per-track now: the track list is derived from `TRACKS.toml`, each track's pin comes from its
own `pin_file` and each track's live tree from its own `source_repo_path`, and a modeled track
no declared site states a status for is a build failure. The three extension files all **DIFFER**
from live and **no cited section moved** — one additive front-matter block each, before §1, zero
sections touched — so no finding changes. Read both halves: the file-level answer and the
section-level answer are different questions and this repo publishes the second one.

---

## Vendoring — who owns which spec, and the retracted answer

**This repo vendors its own snapshots.** The rule in `AGENTS.md` §Boundaries previously
said *"the architecture repo re-vendors"*, which named `entity-core-architecture` — a repo
that no longer exists. **There is no external owner to wait on.**

`entity-core-protocol/specs/` owns the three core specs. **The extension specs are owned by
`entity-system-architecture`** — all 26, including `EXTENSION-IDENTITY.md` and
`EXTENSION-ATTESTATION.md`, in `../entity-system-architecture/specs/extensions/`. That is
the ecosystem's ordinary layout, and vendoring from both is the ordinary thing to do.

**Why the stale sentence was expensive rather than merely wrong:** following a rule that
names only the core repo to vendor an extension finds nothing, and *the absence reads as
"the spec is not written yet"* when it is written and landed.

Procedure: `spec-data/<pin>/MANIFEST.md` §"Re-vendor discipline". `tools/vendor-spec.py` is
the mechanical half (copy byte-for-byte, recompute SHA-256, record provenance and what
moved); `make specfreeze` asserts afterwards that no snapshot has moved.
