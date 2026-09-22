# entity-core-formalization

Read **AGENTS-STANDARD.md** first — it is always loaded beside this file. This file adds
entity-core-formalization specifics. **Our addressable name, for a routing packet's `To:`
or `cc:` field, is `entity-core-formalization`.**

## Overview

Formal design assurance for the Entity Core Protocol — machine-checked verification of
the *protocol design at the pin* on the two layers Lean cannot structurally reach: **TLA+**
(distributed correctness under concurrency, safety + liveness — TLC, with **Apalache**
for inductive/unbounded invariants and **Spin** as an independent cross-check) and
**Tamarin / ProVerif** (active-attacker / Dolev-Yao security: capability unforgeability,
no escalation, no replay/reflection/confused-deputy). Models the current core; **all three extension
protocols — `attestation`, `quorum`, `identity` — are vendored, pinned and modeled too.**

## Public surface — what "breaking" is allowed to mean here

**Our public surface is what somebody needs in order to re-derive a published result: the
model files and their names, the `make` verbs, `TRACKS.toml`, the `spec-data/` pins, and the
documents declared in `CANONICAL-DOCS.toml`.** Everything that *produces* those — `tools/`,
the Containerfiles, `caps.mk`, `lean/_work/`, and every undeclared document — is ours to
change without notice.

| in | out |
|---|---|
| model **file paths and module names** (`tla/*.tla`, `tla/*.cfg`, `spin/*.pml`, `tamarin/*.pv`, `*.spthy`) | `tools/*.py` — their flags, their output text, their internals. They are reached through `make`, and only `make` is promised |
| the **`CONSTANTS` a module requires** and the **property / invariant / lemma names** it defines, plus which config asserts which | the podman images, `Containerfile*`, `caps.mk` values, `lean/_work/` |
| the **`make` verbs** in `make help` and what each asserts | which engine happens to carry a subject, and every intermediate artifact under `tla/`, `spin/`, `tamarin/` |
| **`TRACKS.toml`** — the track names and the field names a reader parses | anything under `docs/status/`, `docs/outbox/`, `docs/archive/` — undeclared, never published |
| **`spec-data/<pin>/` bytes and `spec-data/MODELING-PIN`** — frozen by contract, and the thing every result is quoted against | `spec-data/` snapshots **added** beside the existing ones — additive, never a break |
| the documents declared in **`CANONICAL-DOCS.toml`**, and the results stated in them | |

⛔ **A derived number moving is NOT a breaking change.** The run total, the coverage pair, the
ledger's row count, the drift figure — every one is a measurement re-derived at each cut by
the gate that owns it, and each is *promised to be derived*, not promised to hold. What is
breaking is a result being **withdrawn or weakened**: that goes in `docs/RETRACTIONS.toml`,
and `make retractcheck` is what stops a withdrawn phrasing from surviving in live prose.

## Proof tracks — know which protocol your claim is about

**`TRACKS.toml` is the registry and `make trackcheck` is its gate.** **4 proof tracks** —
**4 modeled** (`core`, `attestation`, `quorum`, `identity`), **0 scoped**. Every model file
belongs to exactly one; an unregistered file, a declared-but-missing file, or a file claimed
by two tracks fails the build. **Unless a statement names a track, it is about `core`.**
**Vendored is not pinned** — a track's `vendored` snapshot and its `pin_file` are separate
fields. All four are now both, and each track pins independently: core is held at `v0.8.2`
pending keystone, which has no bearing on the three extension pins.

Three rules before you write or move a model file. **A bare `§N.M` means a section of your
own track's `primary_spec`**; a cross-track reference writes the sigil first
(**`§CORE:6.2`** inside an attestation model) and is excluded from every track's coverage
set. **The model-file globs are not all recursive**, so moving models into `tla/<track>/`
can hide them from a gate that stays green. **A scoped track must have no models and no
pin**, so adding a model file fails until the track is promoted *with* a pin.

Each of those is a gate that once went green while asserting less than it said — the
evidence, and the `model_pins` override mechanism, are in
`docs/agents/memory/MODEL-CONVENTIONS.md`.

## How we work here — tier **AUTHORING**

This repo runs the entity-OS methodology at the **Authoring** tier — the framework is
`METHODOLOGY.md` (carried, not loaded; opened by trigger). **`docs/DISCIPLINE-CHARTER.md`
carries this repo's own disciplines, D13–D20** — read it once at cold start. Formal
methods are this repo's primary gate, but they gate *the model*, not *the modelling
process*: a proof is only as good as the correspondence between the model and the system
it claims to describe, and nothing in TLA+ or Tamarin checks that correspondence.

So what binds here is the honesty half of the framework:

- **D8 and D12** (`METHODOLOGY.md` §4) verbatim — read the spec *against* the model, never as
  the model; cite canonical sources with `(symbol, path, commit)`; never paraphrase a spec
  claim from a summary into a modelling assumption. **A model that encodes a paraphrase proves
  a theorem about the paraphrase.**
- **D11 inventory-boundary declaration** — every proof states what is in the model **and what
  is abstracted away**. An unstated abstraction is how a green proof coexists with a live
  attack.
- **The Audit Doctrine A0–A12** (§7.2) — including for *"the model and the spec have drifted."*
- **The ratchet** (§2) and the **promotion ladder** (§3).

## Setup / environment · Build & test

- **make + podman only — no host installs.** Toolchains are baked into podman images
  (`tla/Containerfile` → `entity-tla`, `tamarin/Containerfile` → `entity-tamarin`) and
  invoked through `make`; never run `java`/`curl`/`opam`/`stack` on the host even though
  Java is present. This pins the toolchain into the reproducibility envelope alongside
  the `spec-data/` SHA-pin. **Bind-mount relabel flag: `:z` where a directory is shared by two
  images (`tla/` = TLC + Apalache, `tamarin/` = ProVerif + Tamarin), `:Z` only where one image
  owns it (`spin/`)** — a shared `:Z` makes Apalache die mid-sweep with a message that reads
  like a model failure (`docs/agents/memory/TOOLCHAIN-AND-CONTAINERS.md`).
- `make` is the door: the root `Makefile` carries `help` / `build` / `test` / `lint` / `fmt`
  / `smoke` / `check` (= `check-tla` + `check-spin` + `check-provers`) / `matrix` /
  `crosscheck` / `caps` / `clean`; each per-engine dir (`tla/`, `spin/`, `tamarin/`) has its
  own `image` (build the podman image) + `green` (green-sweep).
- **`lean/` is a fourth workspace with no models in it** — it holds the gate that builds the
  *sibling keystone peer's* Lean proof track (`entity-lean` image, `make lean-image`) and
  grades its axiom sets. `make lean` = `leanseam` + `leanproof` + `leanproof-neg` +
  `leanlemma` + `leanlemma-neg`. It needs the keystone checkout, so it is **excluded from
  `make matrix`** rather than skipped inside it, and its runs are counted separately from
  **`make matrix`'s total** — *no figure here, deliberately; state the subject and let the
  gate own the value.* **`leanproof` grades THEIR proofs; `leanlemma` grades OURS.**
- Maude 3.4 — Tamarin's required rewriting backend — is pinned via a Tamarin-blessed
  prebuilt binary in `tamarin/Containerfile.tamarin` (apt's 3.2 is too old).
- Resource caps live in `caps.mk` (included by root + sub-Makefiles); `CAP_MEM=2g`,
  no swap (`CAP_SWAP == CAP_MEM` → the container is OOM-killed cleanly at the cap instead of
  dragging the host into swap-thrash). `caps.local.mk` is gitignored (per-host overrides).
- Run the three toolchains **serially** — for resource-cap reasons. `RevokeMech.spthy` is
  genuinely non-terminating (excluded from the matrix by design); run it standalone or skip
  it, and reclaim hung containers with `podman kill` (a `timeout podman run` only kills the
  client, not the detached container).

## Project structure

Read in order: `README.md` → `docs/ASSURANCE-MAP.md` → `docs/SCOPING-AND-SPIKE-PLAN.md`
→ your spike workspace README. Resuming? Start at `docs/FINAL-ASSURANCE-SUMMARY.md`
(capstone) → `docs/CROSSCHECK-RESULTS.md`. `docs/PRIOR-ART.md`
is the learning on-ramp; `docs/PROPERTIES.md` is the PROVEN/MODELED scorecard, and
**`docs/CORROBORATION.md` is the per-subject engine ledger** — read it before quoting any
single result, because it is the file that says which claims rest on one engine.

- `spec-data/` — vendored, SHA-pinned, byte-for-byte spec snapshots. Currently `v0.8.0/`
  and `v0.8.2/`; **`spec-data/MODELING-PIN` names the one the models actually transcribe**
  (`v0.8.2`) and therefore the one every published result is about. Do not restate it
  here — read the file. `make specdrift` reports the distance from that pin to the live spec.
- `tla/`, `spin/`, `tamarin/` — per-engine workspaces and reports.
- `lean/` — the keystone-seam gate. No models; the peer's tree is read-only input.
- `tools/` — the claim-checking gates. `docs/` — the published assurance documents.
- Per-spike deliverable: a `FORMALIZATION-REPORT`-style note (properties proved /
  counterexamples / scope boundaries / on-ramp pain / go-no-go).

## Status — and every number in it is derived, not recalled

⛔ **Do not quote a figure from this section without running the gate that owns it.** Five
of them have gone stale here with every gate green, each in a different way; the accounts
are in `docs/agents/memory/GATES-AND-DERIVED-NUMBERS.md` and the disciplines they earned
(D15, D20) are in `docs/DISCIPLINE-CHARTER.md`.

**Status:** pinned at `v0.8.2`; the live spec is **0.8.2.32** and `make specdrift` reports
**15 of 29 cited sections moved**, and **none of the moved set now contradicts a model**.
`docs/SPEC-DRIFT-ASSESSMENT.md` §1 is the per-section reading and
`docs/agents/memory/SPEC-PIN-AND-DRIFT.md` is what the distance has cost; **`make
driftclaim` must be run at a release boundary and on a schedule**, because its input is a
sibling tree and no diff of ours will trigger it.

⛔ **The off-pin group has a shelf life.** Two subjects are retargeted to `v0.8.2.25` via
`[track.core.model_pins]` (`conncodes`, `resolution`) and one more module rides that pin.
`make specdrift` reports ONE number for ALL files sharing a snapshot, so it moves for two
independent reasons — a new subject landing, or live advancing — and both have fired.
**Derive it every time; `0 of N` is a measurement, not a property of an override.**

Phase 0 spikes, Phase 1 (TLA+ all-Core concurrency +
Tamarin/ProVerif active-attacker) and Phase 2 (prover surface-closure) are done. The full
**687-run** `make matrix` is the gate: **11** concurrency/structural modules checked by all
three of TLC + Apalache + Spin, **plus `AuthoritySelect` on TLC + Apalache only** (§6.8's
authority-selection MUST, 2026-09-16, `model_pins`-targeted at `v0.8.2.25`), both provers
running every attacker theory (**17 ProVerif / 16 Tamarin** green theories), and a control and
witness set whose sizes `docs/STATUS.md`'s slice table states per target. No inductive
invariant is deferred; no control is known-weak. *`make runcount` declares this paragraph a
site and reads **the run total** and nothing else — the other three numbers in it are on
you.*

**`docs/LEAN-SEAM.md`** is the assumption ledger — per abstraction in the models, the
proposition relied on and the Lean theorem (or sibling engine, or nothing) that discharges
it, cited by content digest and gated by **two** targets: `make leanseam` (has the cited
*text* moved?) and `make leanproof` (do the cited *proofs* still hold? — needs the keystone
sibling). **Do not trust a count of the ledger's rows that you did not derive:** it is 43
rows / 13 Class L, **16 OPEN**, and a recalled figure has been published wrong here **five**
times. Run **`make ledgercount`** — it parses the ledger and fails when a declared prose
site disagrees.

**The claim gates, and what each one owns:** `make coverage` (the coverage pair against the
models' own `§`-citations) · `make runcount` (the matrix run total) · `make ledgercount`
(the ledger's rows, classes and verdicts) · `make enginecount` (how many engines carry each
subject) · `make obligations` (the denominator from the pin, not from us) · `make
trackcheck` (the registry) · `make retractcheck` (withdrawn phrasings) · `make specfreeze`
(the snapshots) · `make driftclaim` (release boundary only — its input is someone else's
tree).

**The failure mode this repo actually has is in the verification, not the protocol** —
every defect found by the last five audits was one, and they earned the disciplines in
`docs/DISCIPLINE-CHARTER.md`. The one exception is `docs/PROPERTIES.md` §D.1, a real
contradiction in the spec text, surfaced by modeling a section the coverage grid wrongly
claimed was covered.

## Memory — what is not in this file

`docs/agents/memory/INDEX.md` is the entry point; open a file when its symptom matches,
not speculatively.

| file | open it when |
|---|---|
| `MODEL-CONVENTIONS.md` | writing, citing, moving or re-pinning a model file |
| `APALACHE-ENCODING.md` | Apalache OOMs, rejects a form, or you are porting a TLC module |
| `TOOLCHAIN-AND-CONTAINERS.md` | a container, mount, cap or backend failure |
| `EXTENSION-TRACKS.md` | modelling or quoting attestation, quorum or identity |
| `SPEC-PIN-AND-DRIFT.md` | the drift gate fired, or a section moved under a model |
| `GATES-AND-DERIVED-NUMBERS.md` | a gate is green and you want to know what it asserts |
| `FINDINGS-AND-REGISTERS.md` | you have a finding and need the right register |

**An entry that could become a check SHOULD become one, and is then deleted from memory.**
Memory is where a finding waits while it is still only prose; it is not where findings
retire.

## Routing — where packets live

Packets we send are in **`docs/outbox/`**, named
`ROUTING-<date>-<letter>-<recipient>-<SLUG>.md`, each opening with `To:` / `From:` / `cc:`
/ `Re:` / `Tip:`. Acknowledged packets move to `docs/archive/outbox/`. **`docs/outbox/` is
never declared in `CANONICAL-DOCS.toml`** — routing is internal.

Per-counterpart state is `docs/status/TRACKER-<counterpart>.md`, each carrying a watermark
line for the last scan of that counterpart's outbox. `docs/status/INBOUND.md` is the
inbound register. **Fetch their tree before scanning, go by the date in the filename never
file mtime, and if you could not reach a tree write that down** — an omitted row reads as
a clean scan. The counterparts themselves — who they are, what each one's instrument can
and cannot decide — are in `docs/status/COUNTERPARTS-AND-ROUTING.md`, which is durable and
internal: it lives beside the trackers rather than in `docs/agents/memory/`, because that
directory publishes and every reference in this one points into somebody else's tree.

## Boundaries — do NOT modify

- **An existing `spec-data/vX/` snapshot is frozen** — vendored, SHA-pinned. Model against
  it, never against a live checkout, and **never edit a snapshot in place**: a pin whose
  bytes can change is not a pin, and every result here is quoted against one.
  **Adding a new snapshot is not editing one.** When the spec advances, vendor a new
  `spec-data/vX.Y.Z/` beside the old — this repo does that itself, because the source is
  the public `entity-core-protocol` `specs/` and the operation is mechanical and
  hash-verifiable (copy byte-for-byte, recompute SHA-256, record provenance and what
  moved). Prior snapshots stay in place as point-in-time pins. Procedure:
  `spec-data/<pin>/MANIFEST.md` §"Re-vendor discipline".
  **Vendor each spec from the repo that owns it.** `entity-core-protocol/specs/` owns the
  three core specs. **The extension specs are owned by `entity-system-architecture`**, in
  `../entity-system-architecture/specs/extensions/` — following a rule that names only the
  core repo finds nothing, and the absence reads as *"the spec is not written yet"* when it
  is written and landed.
- **`spec-data/MODELING-PIN` names the snapshot the models actually transcribe** — the one
  every published result is a statement about. Vendoring a newer snapshot does **not**
  move it. It moves only when the models have been re-validated against the new text, and
  moving it is the last step of that work, not the first. `make specdrift` reads it.
  **A single model may transcribe a newer snapshot**, via `[track.<name>.model_pins]` in
  `TRACKS.toml` plus a matching `MODELING-PIN-OVERRIDE:` marker in the file, both directions
  checked by `make trackcheck` §E. **This does NOT move `MODELING-PIN` and is not a step
  toward moving it.** Retarget a whole **subject**, never one file; expect the coverage
  number to fall and do not argue with it; and **when you add a field to `TRACKS.toml`, grep
  `tools/` for `["models"]` before you add the first row.**
  (`docs/agents/memory/MODEL-CONVENTIONS.md`.)
- **Ratified / superseded phase reports are historical record.** The phase outcomes are
  lineage; `docs/FINAL-ASSURANCE-SUMMARY.md` is the single live capstone pointer — don't
  rewrite closed reports to look current.
- **The keystone peer's Lean tree is read-only input — never vendored, never edited.**
  `lean/` builds it from a *copy* (`lean/_work/`, gitignored) with the sibling mounted
  read-only, and the negative controls mutate only that copy. A local fork would make the
  assumption ledger a claim about our copy, which nothing gates, rather than about the peer
  that ships and that the conformance suite runs — the whole value of the seam. Findings on
  the Lean side are **routed to `entity-core-keystone`**, like spec findings are routed to
  the protocol repo.
- **Don't change the spec here.** A model that surfaces a design defect is a **finding
  routed to the sibling `entity-core-protocol` repo** (a proposal in *their*
  `docs/proposals/`), never a spec edit here. Don't re-model what Lean proved —
  cap-chain-verify is an abstract predicate (TLA+) / function symbol (Tamarin); the
  attenuation logic is Lean's, done.

## Scope discipline

- **A model verifies a *model*, not the code and not the prose.** State the fidelity wall
  (the spec↔model 5th wall, `ASSURANCE-MAP.md`) in every report: the result is only as
  good as the model faithfully transcribing the spec. Cite spec section numbers in model
  comments so a reviewer can check the transcription. Never let scope hide.
- **This repo is additive assurance, off the release critical path** — a research
  demonstrator that must not pull effort off shipping work. A tag is a release cut at
  freeze, not on push.
- Model fidelity is checked against the pinned `spec-data/` plus the sibling repos
  (`entity-core-go` transport, `entity-core-keystone` Lean report + concurrency gate,
  `entity-core-protocol` live specs + `docs/proposals/`), present locally as siblings of
  this repo — read the source, not memory.
