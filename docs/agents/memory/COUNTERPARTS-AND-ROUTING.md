# Counterparts — who is out there, and how anything reaches them

**Symptom that brings you here:** you are starting a session and do not know what has
arrived; you are about to route a finding; or you are about to claim something about
another seat's state.

**Our addressable name is `entity-core-formalization`.** Packets we send live in
`docs/outbox/`; per-counterpart state lives in `docs/status/TRACKER-<counterpart>.md`,
each carrying a watermark line for the last outbox scan. `docs/status/INBOUND.md` is the
inbound register — a procedure, not a gate, because its inputs are sibling trees.

**The channel was one-directional and that cost measurably.** All three `TRACKER-*.md` are
*"what we are carrying TO them"*; there was no inbound direction, so arch's `ROUTING-2026-09-12-e`
— marked *"the priority item"* — sat unopened for two days, and keystone's **scope-algebra cell
census** (146 live cells, 37 with a vector, 109 unmeasured — an instrument enumerating our own
subject) was unknown here while three other seats worked from it. **`docs/status/INBOUND.md` is
the register; read it at session start.** It is a procedure, not a gate, and says so: its inputs
are seven sibling trees, the `driftclaim` class by construction.

**RUNNING IT ONCE FOUND A FIFTH COUNTERPART, AND IT IS THE ONE WITH THE LARGEST OVERLAP.**
**`entity-system-conformance`** — the independent conformance instrument, `requirements/`
(neutral, `ECP-R<n>`-keyed, **98 allocated / 50 authored**, pinned at `v0.8.2.24`) × `suites/`
(N independent implementations, built to disagree), never shipping a peer and never authoring
the spec. **There was no channel in either direction and they had no row for this repo at all.**
Tracker: `docs/status/TRACKER-entity-system-conformance.md`. Three things to internalize.

**(1) Their blind spot and ours are complements, and they have already NAMED theirs.** Their
format carries `surface = wire | host-seam | offline | cross-peer` plus `unreachable` as a
declared STATE, and `GUIDE-CONFORMANCE` §5.2a gives such a rule exactly two ways out — *a
pinned-input vector, or declared*. **There is no third, and the third is a machine-checked
model.** Their worked case says it outright: *"THIS IS A BINDING MUST AND IT IS NOT
WIRE-DECIDABLE."* **`ECP-R24` is the founding case**: a §9.1 FLOOR MUST whose defect §6.8
declares *"wire-invisible, because both readings produce a well-formed response and differ only
in which authority was consulted."* `tla/Authority.tla` is built for exactly that question and
**does not yet model that MUST** — it arrived at 0.8.2.21, inside the module's own abstraction.
Say those two facts in that order; the reverse is how a capability claim gets overstated.

**(2) Two denominators over one byte-identical snapshot.** **365/475** MUST + MUST NOT by our
regex, **98** ids by their positional §9 allocation. D15's own rule for that pair is *make them
disagree out loud or make them share the definition*, so **`make floorgap`** (`tools/floorgap.py`)
does both: it imports `obligations.py`'s regexes rather than re-typing them, and it cross-checks
its own §9.1 reading against their `ECP-INDEX.md`. **They AGREE exactly — the same 50 floor-cited
sections.** Result: **52 of 475 obligations, in 16 sections, have no §9.1 floor row**; 34 in 9
sections have no §9 row at all. That is their `CQ-36` generalized from a revision diff, which is
their own `AP-2` (*"the diff selects where to start reading; it must never select where to
stop"*). **Not a gate** — a sibling tree is its input. ⛔ **And it bounds itself: A FLOOR ROW IS
NOT A VECTOR.** §3.1 is FLOORED, by `ECP-R7`, with an authored requirement file — and it carries
the MUST that enabled the 0.8.2.23 forgery. *The tool would not have found the defect that caused
this repo to build it.*

**(3) A test vector is a grader, and so is a requirement file — read theirs before quoting a row.**
`ECP-R1.diag` carries a mandatory anti-vacuity negative control with its own `why`, a
non-conformant witness naming the peer shape the control separates, an explicit `NOT ASSERTED`
list, and bounded negatives. `UNEXECUTED-CEILING` is a ratchet on requirements no suite has run,
and **it may only go down**. This is our discipline family reached independently, which is the
argument for adjudicating disagreements rather than assuming ours wins.

*First-run defect worth keeping, because it is the register's own failure mode:* the sweep read
seven sibling trees and **did not read our own tracker**, so it reported four keystone asks as
having *"no row here"* when all four were answered — three of them nine days earlier — in
`TRACKER-entity-core-keystone.md`'s own `Inbound` section. **A new register has no memory, so
absence of a row in the NEW file reads as absence of the work.** The real state was a **receipt
gap, not a work gap**, which is cheaper to fix and invisible from inside either tree. Corrected
in place with the wrong sentence left standing.
