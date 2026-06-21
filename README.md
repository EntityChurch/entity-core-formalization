# entity-core-formalization

**Formal design assurance for the Entity Core Protocol (v0.8.0 / V8).** Machine-checked
verification of the *protocol design* on the two layers Lean structurally cannot
reach: **distributed correctness + liveness under concurrency** (TLA+) and
**active-attacker protocol security** (Tamarin / ProVerif). v0.8.0 is the de-versioned
V8 release cutover of the V7 line this project proved — **wire-byte-identical**, so the
proofs carry forward unchanged.

This is a sibling project to `entity-core-architecture` (the spec authority),
`entity-core-keystone` (per-language peer generation + conformance), and the
reference implementations. It is **arch-owned**: it verifies the *design* (the
protocol itself), not any generated peer.

## Why this exists (the one-paragraph version)

The Lean proof-vector peer (in keystone) proved the authority **logic** is correct —
attenuation is monotone, deny-by-default, the verdict enforces the per-edge check
end-to-end. That closes the *implementation pure-core* layer. It leaves two formal
questions about the **design**, each owned by a different tool:

1. **Does the distributed protocol behave correctly under concurrency** — no
   deadlock/livelock, eventual progress, store-safety, bounded resources, across
   interleaved multi-peer sessions? → **TLA+** (safety **and liveness** — liveness
   is the property nothing we currently prove).
2. **Does the protocol resist an active network attacker** — capability
   unforgeability, no privilege escalation, no replay/reflection/confused-deputy? →
   **Tamarin / ProVerif** (Dolev-Yao symbolic model).

Together with what already exists, this rounds out the strongest assurance posture
available for a delegated-authority protocol:

> **Lean** (logic) + **TLA+** (concurrency/liveness) + **Tamarin** (active attacker)
> + **fuzzing** (hostile input) + **validate-peer** (impl conforms) — each tool on
> the wall it can actually reach, no double-ownership.

Full picture: **`docs/ASSURANCE-MAP.md`**.

## Status: paused (complete and bundled)

Phase 0 spikes, Phase 1 (TLA+ all-Core concurrency **and** Tamarin/ProVerif
active-attacker), and Phase 2 (prover surface-closure) are **complete**; the full
76-run matrix was independently re-verified, and the TLA+ cross-check
(Spin + Apalache) is now **complete across every modeled subsystem** — all 6 concurrency
modules independently re-encoded in Spin (incl. the Class-G deadlock), and every module's
key safety invariant proven inductive/unbounded in Apalache (8 invariants, 5 modules), both
engines agreeing with TLC on green and every negative control
([`docs/CROSSCHECK-RESULTS.md`](docs/CROSSCHECK-RESULTS.md)). The project is bundled and
paused. **Capstone:
[`docs/FINAL-ASSURANCE-SUMMARY.md`](docs/FINAL-ASSURANCE-SUMMARY.md)** — it records what
was proved and the only optional leftovers. The spike-first framing below is the
history of how it was gated.

### How it was gated — spike-first, demonstrator-altitude

We did NOT commit to a comprehensive model up front. Mirroring the Lean S1
throwaway-spike discipline, Phase 0 was **two go/no-go-gated spikes** before any full
model:

- **Spike A — TLA+** on one concurrency slice (the §6.11 reentry; the known §7b
  sustained-load runaway class). Lead spike: lowest setup friction, push-button TLC,
  highest near-term odds. → `tla/README.md`
- **Spike B — Tamarin/ProVerif** on one capability-unforgeability lemma. The
  de-risk gamble (proof-termination curve). → `tamarin/README.md`

This is additive assurance and a research demonstrator, separate from the
shipping reference implementations.

## Build — `make` is the door (make + podman only)

A bare host with **only `make` + `podman`** (no native TLA+/Spin/Apalache/Tamarin/
ProVerif toolchain) runs everything; the model checkers are all containerized.

```
make build    # build all 5 toolchain images (the only step that needs network)
make smoke    # prove every containerized toolchain runs end-to-end
make check    # run the GREEN verification matrix across all 4 engines (the gate)
make clean    # remove generated model-checker artifacts
make caps     # print the active per-container resource ceilings
```

Per-engine / single-spec work delegates to `make -C {tla,spin,tamarin} <target>`.
Every `podman` build/run carries a hard memory cap (`caps.mk`) so a runaway check
dies cleanly at the cap instead of thrashing the host — tune per machine via an
untracked `caps.local.mk` or env vars (see `caps.mk`). What is
**PROVEN vs only MODELED** is stated exactly in **`docs/PROPERTIES.md`**.

## Layout

```
README.md                 ← you are here
Makefile                  ← the door: build / smoke / check / clean (make+podman only)
caps.mk                   ← shared podman resource caps (per-container ceilings)
VERSION                   ← 0.8.0
CANONICAL-DOCS.toml        ← declared canonical doc/spec surface (content ingest)
CLAUDE.md                 ← shim that loads the agent guidance (AGENTS-STANDARD.md + AGENTS.md)
AGENTS.md                 ← repo-specific agent guidance (build/test, layout, boundaries)
docs/
  PROPERTIES.md           ← PROVEN-vs-MODELED scorecard (the honesty surface)
  FINAL-ASSURANCE-SUMMARY.md ← capstone: what was proved + the 76-run matrix
  ASSURANCE-MAP.md        ← the complete formal-assurance map + the limits walls
  CROSSCHECK-RESULTS.md   ← Spin + Apalache independent corroboration
  SCOPING-AND-SPIKE-PLAN.md ← arch's calls on scope + Phase 0 gates + Phase 1 trigger
  PRIOR-ART.md            ← TLA+ & Tamarin learning resources + comparable models
spec-data/v0.8.0/          ← VENDORED specs (byte-for-byte) = the modeling ground truth
tla/                      ← TLA+/PlusCal + TLC (concurrency + liveness) + Apalache (unbounded)
spin/                     ← Spin/Promela independent re-encoding (cross-check)
tamarin/                  ← Tamarin/ProVerif (active-attacker, Dolev-Yao)
```

## Where the spec lives

`spec-data/v0.8.0/` is a frozen byte-for-byte copy of the v0.8.0 (V8) normative specs,
with SHA-256 pins + provenance (`MANIFEST.md`). **Model against this, not against a live
checkout** — reproducibility per spec-version is the point. Architecture re-vendors
when the spec advances.

---

## Supporting the project

This project is developed in the open. If it's useful to you, the best support is
to use it, report issues, and contribute back — see
[CONTRIBUTING.md](CONTRIBUTING.md).

To support the work directly, see the project's funding page.
