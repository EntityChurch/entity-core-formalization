# Memory index

**What this is.** Durable, topic-scoped notes on things that would otherwise be
rediscovered the hard way — a container flag that makes a tool failure look like a model
failure, an SMT encoding that OOMs at the cap, a gate that went green while asserting less
than it said. It is not a status log and not a changelog.

**How to use it.** Do not read this directory. Open **one** file when its symptom matches
what you are looking at. Each file opens with the symptom that should bring you to it.

**What belongs here vs. elsewhere.** The repo's root agent file answers *how do I work
here today?* — living, bounded, edited in place. **This directory** answers *what would I
otherwise rediscover the hard way?* — living, indexed. The discipline charter under `docs/`
answers *what rules did we earn, and on what evidence?* — governed by the promotion ladder.
The status directory answers *where are we this week?* — dated, written once, ages out.

> **An entry that could become a check SHOULD become one — and is then deleted from here.**
> Memory is where a finding waits **while it is still only prose.** It is not where
> findings retire. The maintenance pass is not "trim the file"; it is, per entry: *could a
> test, a lint rule, a build assertion or a gate make this impossible instead of merely
> documented?* This repo has an unusually good answer to that question — `make check` runs
> nine claim-checking gates — so expect entries to leave.

Entries are superseded in place, not appended to. Git holds the history. No dates in
prose, no session narration.

---

## The files

| file | the symptom that brings you here |
|---|---|
| [`MODEL-CONVENTIONS.md`](MODEL-CONVENTIONS.md) | You are writing, citing, moving or re-pinning a model file, or promoting a track — and want to know which of those silently changes a published number. |
| [`APALACHE-ENCODING.md`](APALACHE-ENCODING.md) | Apalache dies at the 2 GB cap, rejects `RECURSIVE`, prints *"v' is used before it is assigned"* or *"Trying to expand a set of functions"* — or you are porting a TLC module and want the shape that works. |
| [`TOOLCHAIN-AND-CONTAINERS.md`](TOOLCHAIN-AND-CONTAINERS.md) | A container, bind-mount, resource-cap or rewriting-backend failure — especially one that reads like a model failure and is not. |
| [`EXTENSION-TRACKS.md`](EXTENSION-TRACKS.md) | You are modelling or quoting a result on `attestation`, `quorum` or `identity`, or about to repeat a census or a hypothesis one of those tracks already took. |
| [`SPEC-PIN-AND-DRIFT.md`](SPEC-PIN-AND-DRIFT.md) | `make driftclaim` fired; a cited section moved underneath a model; or you are about to vendor a snapshot and need to know which repo owns which spec. |
| [`GATES-AND-DERIVED-NUMBERS.md`](GATES-AND-DERIVED-NUMBERS.md) | A claim gate is green and you want to know what it actually asserts, or a published figure went stale with every gate green. |
| [`FINDINGS-AND-REGISTERS.md`](FINDINGS-AND-REGISTERS.md) | You have a finding and do not know which of the four registers it belongs in, or you are about to quote a count out of one. |
| [`COUNTERPARTS-AND-ROUTING.md`](COUNTERPARTS-AND-ROUTING.md) | Session start; routing a packet; or you are about to make a claim about another seat's state. |

## Not here

- **The disciplines themselves** — `docs/DISCIPLINE-CHARTER.md` (D13–D20). Memory records
  what happened; the charter records the rule it earned and the enforcement point.
- **The published assurance claims** — `docs/PROPERTIES.md` (PROVEN vs MODELED),
  `docs/CORROBORATION.md` (engines per subject), `docs/COVERAGE-MATRIX.md`,
  `docs/LEAN-SEAM.md` (the assumption ledger). Those are the record; memory is the
  hard-won context around it.
- **Anything with a number in it you did not derive.** Every count in this repo is owned by
  a gate. Run it.
