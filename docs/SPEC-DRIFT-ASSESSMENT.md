# Spec-drift assessment — the pin vs the live spec

> **RESOLVED — this document is now a historical record, not a live warning.** It measures
> the drift that existed while the models were pinned at 0.8.0 and the protocol had advanced
> to 0.8.2. That gap is closed: the models were re-validated against `spec-data/v0.8.2/`, the
> normative surface 0.8.1/0.8.2 added was modeled, and `MODELING-PIN` moved to `v0.8.2` as
> the last step. `make specdrift` now reports **no drift**.
>
> The measurement is kept because it is what scoped the re-target — and because the method
> (derive the dependency set from the `§`-citations the models carry, not from a prose
> summary) is the reusable part. See `docs/STATUS.md` for what was modeled and where.


**Measured 2026-08-27.** Reproduce with `make specdrift`.

Every result in this repository is a statement about the SHA-pinned snapshot in
`spec-data/`, not about the protocol as it stands today. That is the 5th wall
(`ASSURANCE-MAP.md`) restated as a practical matter: fidelity is to a *pinned text*, and
a pin ages. This document measures how far it has aged, by what method, and what that
does and does not mean.

It exists because the alternative — a reader assuming a formal-methods repository speaks
about the current protocol — is the exact overclaim this project was built not to make.

## Summary

| | |
|---|---|
| Modeling pin (`spec-data/MODELING-PIN`) | `spec-data/v0.8.2/` — Entity Core Protocol **0.8.2** *(moved 2026-08-28; this assessment records the drift that existed before the move)* |
| Vendored, not yet modeled | `spec-data/v0.8.2/` — hash-verified 2026-08-27 |
| Live (published `master`) | **0.8.2** |
| Core spec delta | 197 changed lines; 25 of 93 numbered sections |
| **Sections the models cite that moved** | **13 of 26** |
| Green matrix against the pin | still fully green (re-run 2026-08-27) |

Nothing previously published is falsified. The results remain reproducible statements
about the 0.8.0 design. What changed is that they are no longer *current*, and this
document is what makes the difference visible instead of implicit.

## Method

Deliberately dumb, because a subtle method is one we could be subtly wrong about.

A section counts as **unchanged** if and only if its pinned text — from its heading up to
the next heading of any level — occurs **verbatim** in the live file. No diff heuristics,
no fuzzy matching, no section-parsing applied to the live side at all. A section that
moved position but kept its bytes reads as unchanged, which is correct: models cite
content, not line numbers.

**The denominator is the models, not prose.** An early pass of this analysis took its
section list from `spec-data/v0.8.0/MANIFEST.md`, which names the sections the spikes
"care about." That list is a human summary and it undercounted: it gave 8 of 14 where the
models' own citations give 13 of 26. Every model in this repository is required to carry
the `§` it transcribes, so those citations are the dependency set the models *declare*.
That is the honest denominator, and it is the one used below.

### Negative controls

A drift detector that always reports drift is worthless, so the tool is controlled the
same way every model in this repo is:

| control | expected | observed |
|---|---|---|
| pin compared against itself | no drift, exit 0 | no drift, exit 0 |
| pin against itself, one 12-character edit injected inside §6.11 | exactly §6.11 flagged | exactly §6.11 flagged, 1 of 26, no false positives on the other 25 |

### What this method does not do

- It does not judge **significance**. A section flagged as moved may have changed by one
  word or been rewritten; the tool cannot tell you which. That is why the magnitude and
  classification below are done by hand — a section count on its own overstates the change,
  which is a mistake an earlier draft of this document made.
- It does not detect a change that is **semantically** relevant but lands in a section no
  model cites. Coverage is bounded by what the models chose to cite.
- It does not cover the extension protocols, which are not vendored at all.

## What moved

Of the 26 core-protocol sections cited by the models:

| § | model files citing it | |
|---|---|---|
| §5.1 verification | 11 | **moved** |
| §5.5a granter-frame canonicalization | 10 | **moved** |
| §5.6 attenuation | 10 | **moved** |
| §6.2 system handlers | 10 | **moved** |
| §4.8 store-safety | 7 | **moved** |
| §5.2 verification algorithm | 7 | **moved** |
| §5.10 verdict determinism | 6 | **moved** |
| §3.6 capability types | 4 | **moved** |
| §4.2 pre-authorization rules | 4 | **moved** |
| §4.6 authenticate signature | 3 | **moved** |
| §4.10 resource bounds | 3 | **moved** |
| §6.1 registration | 3 | **moved** |
| §6.11 transport reentry | 3 | **moved** |
| §5.5 chain verification | **33** | unchanged |
| §7.3 signatures | **22** | unchanged |
| §5.7 | 9 | unchanged |
| §6.8 handler-grant gate | 8 | unchanged |
| §4.9 resilience | 6 | unchanged |
| §5.4 pattern matching | 5 | unchanged |
| §4.1 · §6.5 · §6.10 · §1.7 · §6.6 · §6.9 · §4.7 | 1–4 each | unchanged |

### Exposure by track

| track | model files | cited § | moved | files touching a moved § |
|---|---|---|---|---|
| TLA+ / Apalache | 13 | 21 | 11 (52%) | 11 / 13 |
| Spin | 7 | 17 | 10 (59%) | 5 / 7 |
| Tamarin / ProVerif | 52 | 13 | 7 (54%) | 35 / 52 |

**The drift is even across all three tracks.** An earlier draft of this assessment said it
"concentrates in the TLA+ track." That was wrong — 52%, 59% and 54% are the same number
for practical purposes — and it is corrected here rather than quietly dropped.

The real asymmetry is **depth, not breadth**: the two most-depended-on sections in the
repository, §5.5 chain verification (33 files) and §7.3 signatures (22 files), are both
unchanged, as are §5.4 pattern matching and §6.8. So the deepest and most widely shared
foundations are stable. What "moved" means in practice — and it is much less than the
count suggests — is measured in the next section.

## How much actually changed — magnitude, not just section count

**A section-touch count is not a semantic delta, and reporting it as one is misleading.**
An earlier draft of this document led with "roughly half the cited surface has moved,"
which is true of the section count and gives entirely the wrong impression of the change.
The measurement below is what that count is actually made of.

Across all 13 moved sections that the models cite:

| | lines |
|---|---|
| pre-existing text **removed or altered** | **16** |
| new text **added** | **105** |

Per section, the share of pre-existing text that changed is between 0% and 10%, and for
most sections it is 1–4%. §5.2, §5.10 and §6.11 — three of the sections that sound most
alarming — changed **0%** of their existing text; they are pure additions.

**The spec did not get different. It got more precise.** 0.8.1 and 0.8.2 are largely the
absorption of conformance findings — the `F32`, `F40`, `F48`, `CAP-1`…`CAP-7`, `RT-6`…`RT-14`
and `W7` tags running through the new text are implementation bugs and ambiguities being
written down as normative clarification. That is what a spec should look like two patch
revisions after a release.

### The 16 altered lines, classified

- **Status-code discrimination (§4.2, §5.1).** A blanket `403` became a discriminated
  `401` for authentication failure versus `403` for authorization failure. Before and
  after, **the request is rejected either way**. The models model accept/reject, not
  status codes.
- **Appended clarification (§4.6, §4.8, §4.10, §5.5a, §5.6, §6.2).** The original sentence
  is retained and extended — an added list item, an added ordering constraint, an added
  ceiling. Additive hardening, not reversal.
- **Two genuine semantic changes**, and both were checked against the models:

  | change | what it alters | do the models depend on it? |
  |---|---|---|
  | §3.6 `F40` — `id-scope` (`operations`, `peers`) is matched as a **literal string**, no longer via the §5.4 path `matches_pattern` | a real ALLOW bug class | **No.** The four models citing §3.6 (`Multisig*`) cite it for `system/capability/multi-granter` threshold structure. No model encodes id-scope matching at all, and §5.4 itself is unchanged. |
  | §6.1 `CAP-1` — a handler grant must be "present and **§6.8-valid**" rather than "present and **non-empty**" | empty `grants` is now a legitimate handler class | **No.** The models citing §6.1 (`Register*`, `register.pml`) cite it as the tree/index source of truth for handler facets. No model encodes grant emptiness. |

**No property this repository proved has been contradicted by 0.8.0 → 0.8.2.** Not one of
the 16 altered lines weakens a modeled invariant — not revocation-never-passes, not
no-escalation, not deadlock-freedom, not unforgeability.

### So what is the actual finding?

Not "the proofs are stale and possibly wrong." It is narrower and it is still worth acting
on:

1. **New normative surface exists that no model covers** — §6.11 frame-write atomicity,
   §4.8 the unsynchronized-refcount use-after-free, §5.6 malformed temporal-field ingest.
   These are new territory to model, not contradictions of old results.
2. **The pin is two revisions behind**, so nothing here can *speak* to the current spec
   regardless of whether anything broke — and that distinction was previously implicit.
3. **The `§`-citations should be re-validated** against the new text, which is cheap now
   that the moved list is known.

## Reading the changes that matter

Section-level flags are not severity. These are the ones worth a human's attention first,
with the reasoning stated so it can be argued with.

**§6.11 transport reentry** — the spike-A modeling target. 0.8.2 adds a new MUST: frame
writes on a shared/pooled connection must be atomic with respect to each other. The
existing models do not encode frame-level write atomicity at all; they model the mutex
discipline around send+recv. This is new modelable surface, not a contradiction.

**§4.8 store-safety** — 0.8.2 names an unsynchronized reference-count decrement under
concurrent dispatch as a use-after-free and therefore a §4.9 no-crash violation. The store
model abstracts refcounts away. Again new surface, and squarely in the class this track exists for.

**§5.6 attenuation** — the `MIN_DEFINED` portability rules and, more sharply, a named
fail-open: a capability whose temporal field is unrepresentable is *malformed*, and a
verifier must not read it as absent, because absent means no expiry. `Expiry.pv` /
`Expiry.spthy` model expiry validity but not malformed-field ingest.

**§5.2 verification algorithm — and an honest correction.** 0.8.2 adds two normative
rules absent from the pin (verified: the strings `THREE-VALUED`, `is_sub_dispatch` and
`THE CONDITION IS THE FIELD` occur zero times in the pin and are present at 0.8.2). The
first requires the dispatch authority to be three-valued — SELF, GRANT, and an ABSENT case
that must deny — and states that collapsing it to a two-valued optional has no correct
default.

An earlier draft of this assessment claimed that `tla/Reentry.tla`'s `Gate(p) == TRUE` is
"the spelling the spec now names as the defect." **That overstated it and is withdrawn.**
Three things temper it:

1. §5.2's rule is addressed to *implementations* representing an authority value. A
   declared modeling abstraction is a different kind of object; `Reentry.tla` says
   plainly that the verdict is Lean's and is not modeled.
2. The underlying security property — gate on the handler's own grant, never on the
   propagated caller capability, which is the confused-deputy door — lives in **§6.8,
   which did not move** and is cited by 8 model files. 0.8.2's new §5.2 text explicitly
   defers to §6.8 for it. The property was modeled against stable text.
3. `tla/Core.tla` does model gate denials (`GateEstablished`, `GateRevocation` are
   controls that can be false), so the track is not uniformly blind to a denying gate.

What survives, and is worth acting on: `Reentry.tla`'s gate is a **constant**, so
`NoDispatchWithoutGate` cannot fail there and the denial case is inexpressible in that
module. That was already a known backlog item ("model gate denials so the dispatch gate is
load-bearing"). 0.8.2 does not create the gap; it raises its value, because the denial
case now carries an explicit normative rule with a named ALLOW-bug lineage behind it.

## What this does not change

The green matrix was re-run against the pin during this assessment and is unchanged:

| engine | result |
|---|---|
| TLC | 7 modules, "No error has been found" ×7, zero violations |
| Apalache | 8 invariants × {base, step} = 16 runs, checker-clean |
| Spin | 6 modules × {safety, liveness} = 12 runs, `errors: 0` |
| Tamarin | 12 theories, 26 lemma verdicts, all `verified`, 0 falsified |
| ProVerif | 13 secure theories; security lemmas true with non-vacuity reachable |

That the matrix is green says the models still hold **against the pin**. It says nothing
about 0.8.2, and no re-run of the current models can, because they transcribe 0.8.0 text.
Only a re-vendor and a re-transcription can speak to the current spec. Keeping those two
statements apart is the whole point of this document.

## What happens next

**The snapshot is vendored.** `spec-data/v0.8.2/` is in the tree, copied byte-for-byte from
`entity-core-protocol`'s published `master` and hash-verified per file. An earlier version
of this section said the re-vendor was owned by that repo and this one could not do it;
that was wrong, and it traced to an `AGENTS.md` rule naming "the architecture repo" —
`entity-core-architecture`, which no longer exists. The rule is corrected. The source is
public, the copy is mechanical, and every byte is checkable by digest.

**The pin has not moved, and that is the point.** `spec-data/MODELING-PIN` still reads
`v0.8.0` because that is the text the models transcribe. Vendoring changes no result. If
the pin advanced on a file copy it would silently convert *"we vendored the new spec"* into
*"we verified the new spec"* — two claims separated by roughly the entire cost of this
project. `make specdrift` reads that file, so it keeps reporting the full distance and
notes that a newer snapshot exists but is unmodeled.

**The citation structure re-validated cleanly** against the new snapshot: no section added,
removed or renumbered, all inline sub-labels intact, and **0 of 35 model `§`-citations
broken**. The one structural addition is §6.11 (a′). So the new text is a clean target —
the work is modeling, not repair.

What remains is enumerated in `spec-data/v0.8.2/MANIFEST.md` §"What DOES need modeling
work" and sequenced in `STATUS.md` §Next: model the three genuinely new normative
requirements (§6.11 (a′) frame-write atomicity, §4.8 refcount use-after-free, §5.6
malformed temporal ingest), re-read the 13 moved sections against their transcriptions,
promote the gate-denial backlog item — and only then move the pin.
