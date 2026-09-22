# entity-core-formalization

**Formal design assurance for the Entity Core Protocol.** Machine-checked verification of
the *protocol design* on the two layers Lean structurally cannot reach: **distributed
correctness + liveness under concurrency** (TLA+) and **active-attacker protocol
security** (Tamarin / ProVerif).

> **Which spec version is verified here is a property of the pin, not of this sentence.**
> The models are written against the SHA-pinned snapshot in `spec-data/`, and
> `spec-data/*/MANIFEST.md` is the single authoritative statement of which spec version,
> which files, and which SHA-256 each result is about. Restating a version number in prose
> is how a repo ends up publishing three different answers to one question.
>
> Today `spec-data/MODELING-PIN` reads `v0.8.2` — spec version **0.8.2**, the current
> published line. `make specdrift` reports **no drift**: the pin matches the live spec
> byte-for-byte across all three normative files. Results here are reproducible statements
> about the protocol as it stands today. The pin moves only as the last step of
> re-validating the models against a new snapshot, never on a file copy, so this sentence
> and the models cannot come apart silently — `make specdrift` is what keeps it honest.

This is a sibling project to `entity-core-protocol` (the spec authority — it publishes
the three specifications this repo models), `entity-core-keystone` (per-language peer
generation + conformance), and the reference implementations. It verifies the *design*
(the protocol itself), not any generated peer.

## Why this exists (the one-paragraph version)

The Lean proof-vector peer (in keystone) proved the authority **logic** is correct —
attenuation is monotone, deny-by-default, the verdict enforces the per-edge check
end-to-end. That closes the *implementation pure-core* layer. It leaves two formal
questions about the **design**, each owned by a different tool:

1. **Does the distributed protocol behave correctly under concurrency** — no
   deadlock/livelock, eventual progress, store-safety, bounded resources, across
   interleaved multi-peer sessions? → **TLA+** (safety **and liveness** — liveness is the
   property no other tool in the family reaches at all).
2. **Does the protocol resist an active network attacker** — capability
   unforgeability, no privilege escalation, no replay/reflection/confused-deputy? →
   **Tamarin / ProVerif** (Dolev-Yao symbolic model).

Together with what already exists, this rounds out the strongest assurance posture
available for a delegated-authority protocol:

> **Lean** (logic) + **TLA+** (concurrency/liveness) + **Tamarin** (active attacker)
> + **fuzzing** (hostile input) + **validate-peer** (impl conforms) — each tool on
> the wall it can actually reach, no double-ownership.

Full picture: **`docs/ASSURANCE-MAP.md`**.

## Status: current against protocol 0.8.2

The models are pinned at `spec-data/v0.8.2/` and `make specdrift` reports **no drift**
against the live spec — results here are statements about the protocol as it stands, not
about a previous release.

### What is verified, and by what

Four engines in two families. **Every concurrency module is checked by all three engines of
its family, and both provers close every attacker lemma but two** — that redundancy is the
answer to the obvious objection, *"who formalizes the formalization?"* The two exceptions are
named, not glossed: `BindingReplay` is ProVerif-only (ProVerif's tables do not model single-use
atomically, so no-replay is Tamarin's) and `RevokeMech` does not terminate in Tamarin. The grid
above is per *module*; at *section* granularity one row still rests on one engine (§3.3, and
only as the *subject* of §6.11(a′) rather than as a property of its own). The two that used
to sit beside it, §4.7 and §6.9, turned out not to be single-tool results but **phantom
rows** — a section-range endpoint and an out-of-scope disclaimer, each counted as a citation.
Both are now genuinely modeled; `docs/COVERAGE-MATRIX.md` §3a-b has the story and the gate.

| Module | Protocol surface | TLC<br>*bounded* | Apalache<br>*unbounded* | Spin<br>*independent* |
|---|---|:---:|:---:|:---:|
| `Reentry` | §6.11 transport reentry + (a′) frame-write atomicity | ● | ● | ● |
| `Conn` | §4.1–4.6 connection establishment | ● | ● | ● |
| `Store` | §4.8–4.10 store safety, refcount, admission | ● | ● | ● |
| `Revoke` | §5.1/§5.10 revocation + verdict determinism | ● | ● | ● |
| `Emit` | §6.10 event emission | ● | ● | ● |
| `Register` | §6.1/§6.2 handler registration | ● | ● | ● |
| `Core` | **composition of all of the above** | ● | ● | ● |
| `Authority` | §5.2 three-valued dispatch authority | ● | ● | ● |
| `Bounds` | §5.9/§4.10(b) TTL vs chain-depth brakes | ● | ● | ● |
| `ConnCodes` | §4.7 connection error-code contract | ● | ● | ● |
| `Bootstrap` | §6.9 pre-loaded handler safety | ● | ● | ● |

| Active attacker (Dolev–Yao) | ProVerif | Tamarin |
|---|:---:|:---:|
| 14 lemmas — unforgeability, no-escalation, binding/no-replay, caveats, depth-bound, deep-chain integrity, expiry, malformed-temporal ingest, third-party chain topology, K-of-N multisig, revocation, persistent re-check | ● *(+`BindingReplay`)* | ● |

**Coverage: 28 of 85 numbered spec sections (33%)** — by area, the **§4 · §5 · §6** surfaces
this repo owns. The near-zero coverage of §2, §3, §7–§9 is deliberate scope (type system,
encoding, trusted crypto, conformance profiles belong to other layers), not neglect. That
figure is **derived from the models' own `§`-citations and checked by `make coverage`**,
which fails if the published grid and the models disagree in either direction — because for
one release it did. Which is which — and every limit and bound on every result — is in:

> ### ⇒ **[`docs/COVERAGE-MATRIX.md`](docs/COVERAGE-MATRIX.md)** — start here
> What each engine can and cannot do · protocol section × engine · what is *not* covered,
> split into out-of-scope / tool-limited / backlog · the exact bound on every claim.

The gate is `make matrix`, which asks three questions rather than one: do the properties
hold, **could they have failed** (every negative control must fail), and **does the model
reach an interesting state at all** (every non-vacuity witness must be violated). A green
control or a clean witness is a build failure.

**Capstone:** [`docs/FINAL-ASSURANCE-SUMMARY.md`](docs/FINAL-ASSURANCE-SUMMARY.md).
**Honesty scorecard:** [`docs/PROPERTIES.md`](docs/PROPERTIES.md).
The spike-first framing below is the history of how the project was gated.

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
make matrix   # THE GATE: green + negative controls + non-vacuity witnesses (258 runs)
make check    # the green-only slice — does NOT show the properties could have failed
make specdrift # has the spec moved out from under the pin?
make coverage  # does the coverage claim match what the models actually cite?
make lean      # the Lean seam tier: the cited Lean text has not moved (leanseam) AND
               # the cited proofs still hold (leanproof, + 5 controls). Needs the
               # entity-core-keystone sibling, so it is NOT part of `make matrix`.
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
Makefile                  ← the door: build / smoke / matrix / check / clean (make+podman only)
caps.mk                   ← shared podman resource caps (per-container ceilings)
VERSION                   ← 0.8.2
CANONICAL-DOCS.toml        ← declared canonical doc/spec surface (content ingest)
CLAUDE.md                 ← shim that loads the agent guidance (AGENTS-STANDARD.md + AGENTS.md)
AGENTS.md                 ← repo-specific agent guidance (build/test, layout, boundaries)
docs/
  PROPERTIES.md           ← PROVEN-vs-MODELED scorecard (the honesty surface)
  COVERAGE-MATRIX.md      ← section x engine, the limits, what is NOT covered (start here)
  FINAL-ASSURANCE-SUMMARY.md ← capstone: what was proved + the 258-run matrix
  STATUS.md               ← rolling status: where it is, what is next
  SPEC-DRIFT-ASSESSMENT.md ← how far the pin has aged behind the live spec
  ASSURANCE-MAP.md        ← the complete formal-assurance map + the limits walls
  LEAN-SEAM.md            ← the assumption ledger: what each model takes on faith, and
                            who discharges it (`make leanseam` + `make leanproof`)
  CROSSCHECK-RESULTS.md   ← Spin + Apalache independent corroboration
  SCOPING-AND-SPIKE-PLAN.md ← scope calls + Phase 0 gates + Phase 1 trigger
  PRIOR-ART.md            ← TLA+ & Tamarin learning resources + comparable models
spec-data/v0.8.2/          ← VENDORED specs (byte-for-byte) = the modeling ground truth
spec-data/MODELING-PIN     ← which snapshot the models transcribe (the answer to "verified what?")
tla/                      ← TLA+/PlusCal + TLC (concurrency + liveness) + Apalache (unbounded)
spin/                     ← Spin/Promela independent re-encoding (cross-check)
tamarin/                  ← Tamarin/ProVerif (active-attacker, Dolev-Yao)
lean/                     ← the Lean seam tier: NO Lean source, only the gate that builds
                            the keystone peer's proof track and grades its axiom sets
tools/spec-drift.py       ← the pin-vs-live-spec detector behind `make specdrift`
tools/lean-seam.py        ← the assumption-ledger drift check behind `make leanseam`
tools/lean-proof.py       ← the proof-still-holds gate behind `make leanproof`
tools/coverage-check.py   ← the coverage-claim check behind `make coverage`
```

## Where the spec lives

`spec-data/v0.8.2/` is a frozen byte-for-byte copy of the v0.8.2 (V8) normative specs,
with SHA-256 pins + provenance (`MANIFEST.md`). **Model against this, not against a live
checkout** — reproducibility per spec-version is the point. Prior snapshots (`v0.8.0/`)
stay in place as point-in-time pins and are never edited. This repo re-vendors itself when
the spec advances: the source is public and every step is hash-verifiable.

---

## Supporting the project

This project is developed in the open. If it's useful to you, the best support is
to use it, report issues, and contribute back — see
[CONTRIBUTING.md](CONTRIBUTING.md).

To support the work directly, see the project's funding page.
