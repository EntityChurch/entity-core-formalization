# spec-data v0.8.2.25 — Snapshot Manifest

**Spec version:** Entity Core Protocol **0.8.2.25** (`ENTITY-CORE-PROTOCOL.md` `**Version**: 0.8.2.25`)
**Snapshot type:** verbatim copy of the authoritative normative spec files — **byte-for-byte, no paraphrase.**
**Purpose:** the modeling ground truth for the formal design-assurance project. TLA+ / Tamarin / Spin / Apalache / ProVerif models are written against a *pinned* version so a model and its result are reproducible per spec-version. When the spec moves, vendor a new snapshot and re-check.

> ⚠ **THIS SNAPSHOT IS NOT THE MODELING PIN.** `spec-data/MODELING-PIN` still names **`v0.8.2`**,
> and **every published result in this repository remains a statement about `v0.8.2`.** The pin
> moves **last**, per step 5 of the re-vendor discipline — only once the models have been
> re-validated against this text. Vendoring alone changes no result.

> **Why this snapshot exists one day after `v0.8.2.24/`.** `0.8.2.25` added **§4.11
> Pre-admission refusals**, and its multiplexed arm is the largest tractable modelable surface
> this repo currently has — a concurrency claim on a shared connection that
> `entity-system-architecture` records (`KC-2`) as never having been driven by any instrument.
> Modeling it against a live checkout is exactly what the pin discipline forbids, so the
> snapshot comes first. See `docs/SPEC-DRIFT-ASSESSMENT.md` §1d.

## Files (the three authoritative normative inputs)

| File | Spec version | Bytes | SHA-256 |
|---|---|---|---|
| `ENTITY-CORE-PROTOCOL.md` | 0.8.2.25 | 536 963 | `589cc8f1905184931c4586babb103f2b25d2584e534671768ef6d5e730377710` |
| `ENTITY-CBOR-ENCODING.md` | 1.7 | 59 492 | `dd6aa47de343b335ececc3c7c654da019dc9e473eb4639af3dc9d7a202a8393f` |
| `ENTITY-NATIVE-TYPE-SYSTEM.md` | 4.2.1 | 120 642 | `043fc80d4fd21ff074082e1f3c76b779d73d9f172a90d3f2a986d68e0cde740d` |

Verify: `sha256sum spec-data/v0.8.2.25/*.md`, or `make specfreeze`, which checks every snapshot
in this tree against its own manifest.

⭐ **Two of the three files are BYTE-IDENTICAL to `v0.8.2.24/`** — same digests, not merely the
same version string. Only `ENTITY-CORE-PROTOCOL.md` moved. Stated because "the snapshot advanced"
reads as though three files changed, and a reader deciding what to re-check should not have to
diff to find out that two of them did not.

## Provenance

| Field | Value |
|---|---|
| Source repo | `entity-core-protocol` (sibling; public source mirror) |
| Source path | `specs/` |
| Source ref | `dev` @ the 0.8.2.25 fold |
| Vendored | 2026-09-15, by this repo |
| Method | `cp` from the source tree; each copy re-hashed and compared against the source file's SHA-256 **before acceptance**. All three matched. |
| Supersedes | nothing — `v0.8.0/`, `v0.8.2/` and `v0.8.2.24/` stay in place as point-in-time pins |

**Cited by content, not by commit.** The digests above are the durable identifier. The internal
source commit is recorded in `docs/status/` only; published history is re-authored at the release
boundary and an internal SHA resolves to nothing for a public reader.

## What changed since `v0.8.2.24` — the re-check record

Required by step 3 of the re-vendor discipline. Measured by `tools/spec-drift.py`
(`make specdrift`); the classification is `docs/SPEC-DRIFT-ASSESSMENT.md` **§1d**.

### Structure: one section added, nothing else moved

| check | result |
|---|---|
| Sections **added** | **one — §4.11 Pre-admission refusals** |
| Sections removed | **none** |
| Sections renumbered | **none** |
| Numbered `### N.M` sections | **92 → 93** |
| Model `§`-citations that no longer resolve | **0 of 31** |

⚠ **This is the first snapshot in this repo's history where a section was ADDED**, and it is
worth naming because the `v0.8.2.24` manifest's structure table could report *"Sections added:
none"* across twelve point revisions. A reader who learned to skim that row would miss this one.
**§4.11 is additive**, so no citation breaks and no model is invalidated — but *"structure is
stable"* is now a statement with an exception in it.

### Content: `.25` is one idea

`ENTITY-CORE-PROTOCOL.md` grows by **+14 052 bytes**. Sections touched: **§3.3, §4.7, §4.10,
§5.2, §6.3, §6.4**, plus new **§4.11**. Of those, `make specdrift` reports **§4.10 as newly
moved** under a model citation; §3.3, §4.7 and §5.2 were already in the moved set.

**The whole revision is one invariant being stated once instead of five times.** From §4.11's own
"Why this section exists":

> "Four members of this class were specified independently, each as a local answer to a local
> incident, and **three of them gave the same reason in nearly the same words while reaching
> three different strengths** — §4.6 forbidding the bare close outright, §5.2a forbidding both
> failures, §4.10(a) permitting the close, and §3.3 *requiring* it with no frame at all. A fifth
> member — the framing arm — was specified nowhere, and three independent implementations
> produced three different caller-observable answers to one input."

That is **D17's own subject, written upstream by the specification about itself**: an obligation
with no single home, and a cohort diverging in exactly the gap.

### The obligation surface, and it is the number to carry

| snapshot | numbered sections | MUST / MUST NOT |
|---|---|---|
| `v0.8.2` — **the modeling pin** | 92 | **365** |
| `v0.8.2.24` | 92 | 506 |
| `v0.8.2.25` — **this snapshot** | 93 | **531** |

⛔ **The normative obligation surface has grown by 45% since the text every published result here
is about, with zero sections removed and one added.** Structural stability and normative
stability are different properties, and this repo has a gate for the first
(`make specdrift` resolves every citation) and a measurement for the second
(`make obligations`) that runs against the **pin**, not against this.

## What needs modeling work

**In priority order, and none of it is done.** Item 1 is the reason this snapshot exists.

1. ⭐ **§4.11 arm (f) — the multiplexed pre-admission refusal.** *"A pre-admission refusal
   arriving while an admitted request is in flight on the same connection MUST NOT cost that
   request its response."* It quantifies over **interleavings** and its failure is a **lost
   response**, so no wire suite separates it from slowness — `entity-system-architecture`
   records that it cannot be inferred from the other five arms and has never been driven
   anywhere. `tla/Reentry.tla` is the instrument: multiplexed connection, pooled dispatch,
   in-flight correlation, frame-write lock, §6.11(a)/(a′) already proved jointly satisfiable.
   ⚠ **It has no refusal path at all** (`Gate(p) == TRUE`, disclosed in `docs/PROPERTIES.md`),
   so **the D18 Class-O row naming what it cannot represent comes before the model does.**
2. **§4.11's cause → code table**, five rows. `tla/ConnCodes.tla`'s subject exactly, and it
   already checks this shape (`StatusMatchesCode`, `ReasonCodesDistinct`). ⚠ Retargeting
   `ConnCodes` here also collapses the one live **contradiction** between the pin and live
   (§4.7's `connection_sequence_error`, 400 → 409) — see `SPEC-DRIFT-ASSESSMENT.md` §1's §4.7
   note. The model gets *simpler*, and a control demotes from *"a conformant reading"* to an
   ordinary injected defect.
3. **§3.3's BROAD-RESULT / OPTIONAL-FILTER discriminator and the non-lossy-narrowing MUST**
   (`TE-1`/`TE-2`). *"Every seam that narrows is exempted alike, inbound-wire and in-process
   sub-dispatch, or one request receives two different answers according to which door it
   arrived through"* — which is the same shape as `tla/Authority.tla`'s already-modeled §5.2
   rule (2), *the condition is the field, not the door*.
4. **The `.22`–`.24` authorization arc**, unchanged from the `v0.8.2.24` manifest's list and
   still ahead of a pin move: §6.8's authority table as an **intersection**, §5.2's typed
   dispatch at **both** matchers, and §1.8/§3.1's resolution-integrity `[MUST]` — the last of
   which is `docs/LEAN-SEAM.md` **O23** and the top of `docs/STATUS.md` §Next.

**The pin does not move until these are done.** Step 5 is not a formality: moving it early would
make every published result a claim about text no model transcribes.
