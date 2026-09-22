# entity-core-formalization

Read **AGENTS-STANDARD.md** first. This file adds entity-core-formalization specifics.

## Overview

Formal design assurance for the Entity Core Protocol — machine-checked verification of
the V7 *protocol design* on the two layers Lean cannot structurally reach: **TLA+**
(distributed correctness under concurrency, safety + liveness — TLC, with **Apalache**
for inductive/unbounded invariants and **Spin** as an independent cross-check) and
**Tamarin / ProVerif** (active-attacker / Dolev-Yao security: capability unforgeability,
no escalation, no replay/reflection/confused-deputy). Models the current core; may
extend to extension protocols once they are vendored.

## How we work here — tier **AUTHORING**

This repo runs the entity-OS methodology at the **Authoring** tier — the framework is
`METHODOLOGY.md` (injected, identical everywhere; read it once). Formal methods are this
repo's primary gate, but they gate *the model*, not *the modelling process*: a proof is only
as good as the correspondence between the model and the system it claims to describe, and
nothing in TLA+ or Tamarin checks that correspondence.

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
  the `spec-data/` SHA-pin. Bind mounts use `:Z` (SELinux/Fedora host).
- `make` is the door: the root `Makefile` carries `smoke` / `check`
  (= `check-tla` + `check-spin` + `check-provers`) / `crosscheck` / `caps` / `clean`; each
  per-engine dir (`tla/`, `spin/`, `tamarin/`) has its own `image` (build the podman image)
  + `green` (green-sweep). Maude 3.4 — Tamarin's required rewriting backend — is pinned via
  a Tamarin-blessed prebuilt binary in `tamarin/Containerfile.tamarin` (apt's 3.2 is too old).
- Resource caps live in `caps.mk` (included by root + sub-Makefiles); `CAP_MEM=2g`,
  no swap (`CAP_SWAP == CAP_MEM` → the container is OOM-killed cleanly at the cap instead of
  dragging the host into swap-thrash). `caps.local.mk` is gitignored (per-host overrides).
- Run the three toolchains **serially** — concurrent `:Z` relabel races cause transient
  "file not found." `RevokeMech.spthy` is genuinely non-terminating (excluded from the
  matrix by design); run it standalone or skip it, and reclaim hung containers with
  `podman kill` (a `timeout podman run` only kills the client, not the detached container).

## Project structure

Read in order: `README.md` → `docs/ASSURANCE-MAP.md` → `docs/SCOPING-AND-SPIKE-PLAN.md`
→ your spike workspace README. Resuming? Start at `docs/FINAL-ASSURANCE-SUMMARY.md`
(capstone) → `docs/CROSSCHECK-RESULTS.md`. `docs/PRIOR-ART.md`
is the learning on-ramp; `docs/PROPERTIES.md` is the PROVEN/MODELED scorecard.

- `spec-data/` — vendored, SHA-pinned, byte-for-byte spec snapshots. Currently `v0.8.0/`
  and `v0.8.2/`; **`spec-data/MODELING-PIN` names the one the models actually transcribe**
  (`v0.8.0`) and therefore the one every published result is about. `make specdrift`
  reports the distance from that pin to the live spec.
- `tla/`, `spin/`, `tamarin/` — per-engine workspaces and reports.
- Per-spike deliverable: a `FORMALIZATION-REPORT`-style note (properties proved /
  counterexamples / scope boundaries / on-ramp pain / go-no-go).

**Status:** the spec has moved out from under the pin. `spec-data/v0.8.2/` is vendored
and hash-verified; the models still transcribe `v0.8.0` and the next substantive work is
modeling the new normative surface (§6.11 (a′) frame-write atomicity, §4.8 refcount
use-after-free, §5.6 malformed temporal ingest) — `docs/STATUS.md` §Next is the work-list.
Prior arc, all still green against the pin: Phase 0 spikes, Phase 1 (TLA+ all-Core concurrency +
Tamarin/ProVerif active-attacker), and Phase 2 (prover surface-closure) done; the full
76-run matrix re-verified and the TLA+ cross-check complete across every subsystem (Spin
re-encodes all 6 concurrency modules, reproducing the Class-G deadlock; Apalache proves
8 inductive invariants across 5 modules; Tamarin/ProVerif close 12 lemmas in lockstep).
Only optional leftovers remain — the capstone `docs/FINAL-ASSURANCE-SUMMARY.md` enumerates them.

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
  *(This rule previously said "the architecture repo re-vendors." That named
  `entity-core-architecture`, which no longer exists — the same stale reference corrected
  elsewhere in this file. There is no external owner to wait on.)*
- **`spec-data/MODELING-PIN` names the snapshot the models actually transcribe** — the one
  every published result is a statement about. Vendoring a newer snapshot does **not**
  move it. It moves only when the models have been re-validated against the new text, and
  moving it is the last step of that work, not the first. `make specdrift` reads it.
- **Ratified / superseded phase reports are historical record.** The phase outcomes are
  lineage; `docs/FINAL-ASSURANCE-SUMMARY.md` is the single live capstone pointer — don't
  rewrite closed reports to look current.
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
