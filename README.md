# entity-core-formalization

**Formal design assurance for the Entity Core Protocol and its extensions.** Machine-checked
verification of the *protocol design* on the two layers Lean structurally cannot reach:
**distributed correctness + liveness under concurrency** (TLA+) and **active-attacker protocol
security** (Tamarin / ProVerif).

## Proof tracks — read this before any number on this page

This repo verifies **more than one protocol**, and a result is only meaningful once you know
which one it is about. Every model file, every coverage number and every spec pin belongs to
exactly one **track**, declared in [`TRACKS.toml`](TRACKS.toml) and gated by `make trackcheck`.

**4 proof tracks** — **4 modeled**, **0 scoped**:

| Track | Subject | Spec owner | Status |
|---|---|---|---|
| **core** | Entity Core Protocol — connection, store, revocation, dispatch, registration, reentry | `entity-core-protocol` | **modeled** — 105 model files, 380 runs, pinned at `spec-data/v0.8.2` (13 of them at `v0.8.2.25`) |
| **attestation** | The signed-edge substrate: `attesting → attested`, four mandatory indexes, the supersedes chain | `entity-system-architecture` | **modeled** — 3 modules (§5.7 index invariants; §4.3/§5.1–5.3 liveness and the chain walks; §4.3's revocation recursion), 68 runs, **TLC + Apalache on all three modules**, pinned at `spec-data/ext-attestation-v1.3` |
| **quorum** | K-of-N signer rosters; `quorum-update` / `quorum-publish`; `current_signer_set(as_of)` | `entity-system-architecture` | **modeled** — 3 modules (§4.2 the signer-set resolver and its clock; §4.2/§4.2.1 the arrival-time trust model; §4.1 K-of-N), 100 runs, **TLC and Apalache on all three**, pinned at `spec-data/ext-quorum-v1.2` |
| **identity** | Cert chains, rotation by handoff, rotation by recovery, retirement | `entity-system-architecture` | **modeled** — 3 modules (§6.3 the arrival convergence point; §9.4 compromise-recovery validation; §3.6 topology dispatch and §9.2 key confinement), 139 runs, **TLC and Apalache on all three** — no module on this track is left on a single engine, pinned at `spec-data/ext-identity-v3.10` |

**Everything else in this README is about the `core` track** unless it says otherwise. The
three extension tracks are days old.
**9 of 9 extension subjects carry a green on two engines** — every module
on `attestation`, `quorum` and `identity` carries TLC and Apalache; **none of the nine has a
third engine, none has a Spin encoding, and none has a prover.** That count is derived by `make enginecount` from the
green gate tables rather than stated by hand, and `docs/CORROBORATION.md` names every subject
that rests on one engine, with the reason. Their coverage is stated separately in `docs/COVERAGE-MATRIX.md` §3c, §3d and
§3e, where a substantial share of the rows are **findings against the spec** rather than coverage
of it. Read those three tracks as a defect report, not as assurance; the routed findings are
indexed in `docs/status/FINDINGS-INDEX.md`. `scoped` is a gated state rather than a label:
assigning a model file to a scoped track **fails the build** until the track is promoted with a
spec pin — which is the step where someone has to say which snapshot the results are about. It
forced that step twice, on `quorum` and on `identity`; with both promoted **no track is scoped
now**, so the gate has no subject left in this registry. **Vendored
is not pinned**, and the two are separate fields: all three extension specs are vendored as
frozen snapshots, and each names its own `MODELING-PIN-*` separately from that snapshot.

> **Why the tracks are declared before any extension model exists.** The coverage number here
> is derived from the `§`-citations the models carry, via a pattern that is *document-blind*:
> `EXTENSION-ATTESTATION §5.7` and core `§5.7` produce the same token, and core already has a
> `5.7` row. Without a track dimension, the first attestation model's citations would be
> silently absorbed into a **core** coverage claim, and the gate would report OK — a phantom
> row arriving *through* the gate that exists to prevent phantom rows. Scoping is declared
> first for the same reason the spec pin moves last: the honest order costs nothing up front
> and is unrecoverable afterwards.

> **Which spec version is verified here is a property of the pin, not of this sentence.**
> The models are written against the SHA-pinned snapshot in `spec-data/`, and
> `spec-data/*/MANIFEST.md` is the single authoritative statement of which spec version,
> which files, and which SHA-256 each result is about. Restating a version number in prose
> is how a repo ends up publishing three different answers to one question.
>
> Today `spec-data/MODELING-PIN` reads `v0.8.2` — spec version **0.8.2**. The live spec has
> since advanced to **0.8.2.32**, and `make specdrift` reports **15 of 29 cited sections moved**.
> Results here are reproducible statements about **0.8.2**, not about the protocol as it
> stands today. The pin moves only as the last step of re-validating the models against a new
> snapshot, never on a file copy — so a repo in this state is one doing the honest thing
> slowly, not one that has lost track. `docs/SPEC-DRIFT-ASSESSMENT.md` measures the distance
> section by section; `make driftclaim` is what stops this sentence and the measurement from
> coming apart, and it failed the day it was written.

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

## Status: verified against protocol 0.8.2; live spec is 0.8.2.32

The models are pinned at `spec-data/v0.8.2/` and `make specdrift` reports **15 of 29 cited
sections moved** — so results here are statements about **0.8.2**, and the pin is behind the
live spec by **23** point revisions (distinct `0.8.2.N` revision tags carried by the live text;
`0.8.2.12` and `0.8.2.15` were superseded and no longer appear in it). *That figure is
reproducible rather than recalled — `grep -o '0\.8\.2\.[0-9]\+' … | sort -u | wc -l` against
`entity-core-protocol/specs/ENTITY-CORE-PROTOCOL.md` — and no gate reads it. It said
**nineteen** until 2026-09-15, when counting it found the true number was already 23: a
hand-derived figure in a parenthetical, beside two gated ones, four revisions stale.*

What that does and does not mean, measured rather than asserted
(`docs/SPEC-DRIFT-ASSESSMENT.md`): **no section in the moved set contradicts a model** — the
movement is new normative clarification, in several cases text that adopts or converges with a
finding from this repo, and in one case (**§5.8**) a single backtick removed from a cross-reference
row. Nothing proved here is falsified, because every result is quoted against the pin — but a
reader wanting a statement about the *live* spec does not have one.

⛔ *This paragraph read **"eleven of the twelve moved sections contradict no model … the twelfth,
§4.7, is the one place the live text contradicts a model"** until 2026-09-17, and it was the
**fourth and oldest** copy of that claim. §4.7 stopped being an exception on **2026-09-15**, when
`tla/ConnCodes.tla`, its Apalache port and `spin/conncodes.pml` were retargeted to
`spec-data/v0.8.2.25/` — §4.7 is measured against its own snapshot now, so there is no §4.7 claim
here to contradict. **Every one of the four sites stated the count in its own words and at its own
vintage** — "eleven of the twelve", "fifteen of the sixteen", a table cell — which is why the gate
that anchors on the canonical phrasing `N of 29 cited sections moved` saw none of them, and why
three were found only after a fourth was. Each is repaired the same way: **the value is deleted and
the subject named.***

### What is verified, and by what

Four engines in two families. **Every `core` concurrency module is checked by all three engines
of its family, and both provers close every attacker lemma but two**  *(⛔ read
"concurrency module", not "core module": `AuthoritySelect` — §6.8's authority-selection rule,
2026-09-16 — is a core STRUCTURAL module on TLC + Apalache with no Spin encoding, and the
quantifier does not reach it. `docs/COVERAGE-MATRIX.md` §4 carries why that distinction is
written down rather than rounded off.)* — that redundancy is the
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

**Coverage: 27 of 91 numbered spec sections (30%)** — by area, the **§4 · §5 · §6** surfaces
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
make matrix   # THE GATE: green + negative controls + non-vacuity witnesses (687 runs)
make check    # the green-only slice — does NOT show the properties could have failed
make specdrift # has the spec moved out from under the pin?
make trackcheck # which proof track is each model file on? (TRACKS.toml)
make coverage  # does the coverage claim match what the models actually cite?
make lean      # the Lean seam tier: the cited Lean text has not moved (leanseam), the
               # cited proofs still hold (leanproof, + 5 controls), and our own results
               # about those definitions still hold (leanlemma, + 5 controls). Needs the
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
TRACKS.toml               ← THE PROOF TRACKS: which protocol each model file is about,
                            each track's spec pin and citation prefix (`make trackcheck`)
CLAUDE.md                 ← shim that loads the agent guidance (AGENTS-STANDARD.md + AGENTS.md)
AGENTS.md                 ← repo-specific agent guidance (build/test, layout, boundaries)
docs/
  PROPERTIES.md           ← PROVEN-vs-MODELED scorecard (the honesty surface)
  COVERAGE-MATRIX.md      ← section x engine, the limits, what is NOT covered (start here)
  FINAL-ASSURANCE-SUMMARY.md ← capstone: what was proved + the 687-run matrix
  STATUS.md               ← rolling status: where it is, what is next
  SPEC-DRIFT-ASSESSMENT.md ← how far the pin has aged behind the live spec
  ASSURANCE-MAP.md        ← the complete formal-assurance map + the limits walls
  LEAN-SEAM.md            ← the assumption ledger: what each model takes on faith, and
                            who discharges it (`make leanseam` + `make leanproof`)
  CORROBORATION.md        ← how many engines carry each subject, and every subject that
                            rests on one, by name (`make enginecount`)
  CROSSCHECK-RESULTS.md   ← Spin + Apalache independent corroboration
  DISCIPLINE-CHARTER.md   ← the rules this repo earned and the bug behind each one, with
                            the gate that enforces it (D13-D20; D1-D12 are ecosystem-wide)
  agents/memory/          ← durable notes, entered through INDEX.md and opened by SYMPTOM:
                            encoder limits, container failures that look like model
                            failures, what each extension track refuted, which published
                            sentences went stale and how
  SCOPING-AND-SPIKE-PLAN.md ← scope calls + Phase 0 gates + Phase 1 trigger
  PRIOR-ART.md            ← TLA+ & Tamarin learning resources + comparable models
spec-data/v0.8.2/          ← VENDORED specs (byte-for-byte) = the modeling ground truth
spec-data/MODELING-PIN     ← which snapshot the models transcribe (the answer to "verified what?")
tla/                      ← TLA+/PlusCal + TLC (concurrency + liveness) + Apalache (unbounded)
spin/                     ← Spin/Promela independent re-encoding (cross-check)
tamarin/                  ← Tamarin/ProVerif (active-attacker, Dolev-Yao)
lean/                     ← the Lean seam tier: NO Lean source, only the gate that builds
                            the keystone peer's proof track and grades its axiom sets
tools/spec-drift.py       ← the pin-vs-live-spec detector behind `make specdrift` / `driftclaim`
tools/lean-seam.py        ← the assumption-ledger drift check behind `make leanseam`
tools/lean-proof.py       ← the proof-still-holds gate behind `make leanproof`
tools/coverage-check.py   ← the coverage-claim check behind `make coverage`
tools/runcount.py         ← the matrix run-total check behind `make runcount`
tools/ledgercount.py      ← the assumption-ledger shape check behind `make ledgercount`
tools/trackcheck.py       ← the proof-track membership gate behind `make trackcheck`
```

`tla/`, `spin/` and `tamarin/` are organized **by engine**, not by track — a model file's
track is a property of `TRACKS.toml`, never of its directory, and `make trackcheck` is what
enforces that. Per-track subdirectories are a deliberate later step, safe to take only now
that a model file falling out of a gate's view is a build failure rather than a silent green.

*This paragraph read "today every model in them is on the `core` track" from the day it was
written until 2026-09-17, and it was false from the moment the first extension track was
promoted — a bare universal quantifier over our own artifacts, in the most-read file here,
with every gate green. No gate reads prose like that; the entry in `docs/DISCIPLINE-CHARTER.md`
(D14, sixth instance) is what it earned.*

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
