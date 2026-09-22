# Findings, registers, and the denominator that was our own

**Symptom that brings you here:** you have a finding and do not know which of the four
registers it belongs in, or you are about to quote a count out of one of them.

`docs/status/FINDINGS-INDEX.md` is the single index — read it before any handoff.

**Where findings are tracked, 2026-09-08 — FOUR categories, and three of them had no home until
this date.** `docs/status/FINDINGS-INDEX.md` is the single index; read it before any handoff.
It covers: **spec defects** — 26 across the three **extension** protocols, 24 machine-checked, in five
routing notes — three per-track plus TWO that second engines added to a track already routed,
`ROUTING-2026-09-09-IDENTITY-HANDLE-CACHE-KEY.md` and
`ROUTING-2026-09-09-IDENTITY-ARRIVAL-PATH-STATE.md`); **validation-surface defects** (V1–V3, new, in
`ROUTING-2026-09-08-VALIDATION-SURFACE.md`); **CORE-track spec defects, which that sentence's
"three extension protocols" does not cover and did not used to exist** (`P-2`…`P-8` in
`docs/status/TRACKER-entity-core-protocol.md` — the `system/peer` `.data.peer_id` sites and the
§5.5a granter-frame set, 2026-09-16); **implementation divergences** (in
`docs/status/CONFORMANCE-DIVERGENCE-REGISTER.md` — **do not quote a count or an id range from
here; derive it**, `grep -cE '^\| D[0-9]+ \|'` for rows and the register's own `awk` one-liner for
the class table, both of which have been published wrong); and **our own open work** (the ledger's
OPEN rows and the one subject with no second engine).

**The divergence register is the one to understand, because the gap it closes was invisible.**
Every spec finding here was written with a census of what `entity-core-{go,rust,py}` do — this
repo's own rule is census before impact claim (`docs/PROPERTIES.md` §D.1). **Those censuses were
evidence for spec findings and were tracked nowhere as observations in their own right.** An
implementation divergence is not a bug report about an implementation; it is a **measurement of
where the specification failed to converge three independent authors**, and it belongs in the
packet. Classified C1–C5 — and the classes matter more than the rows: **C2 is where the cohort
follows the text faithfully and nothing protects the field**, and **C3 is where the three
disagree with each other**, which crosses a peer boundary. Writing the register is what surfaced
V1–V3; none of them is visible from any single finding.

**Neither the register nor the V-rows is gated, and that is stated in both files.** Their inputs
are three sibling repos, so they go stale with our tree untouched — the `driftclaim` class
exactly (D15). Re-read the source before quoting a row.

**A CAPABILITY FORGERY WAS CLOSED UPSTREAM, 2026-09-14, IN TEXT THAT WAS IN OUR PIN, AND NO
GATE HERE WAS RED.** `0.8.2.23` fixed this: every authority lookup resolved an entity by a
wire-supplied `envelope.included` key that **nothing verified**, so an observer of any capability
chain could mint a leaf off it up to the parent's scope **without the grantee's key**. Read three
facts together before anything else in this file. **(1) The enabling obligation was in our pin** —
`spec-data/v0.8.2` §3.1, *"The content_hash MUST match the map key"* — with **no enforcing
operation and no vector**, which is **D17's trigger verbatim**, and D17 had only ever been run on
the three extension tracks. **(2) No model here represents the indirection**: the prover theories
take capabilities and chain links as TERMS off `In(...)`, so there is no address to forge
(`content_hash`: **0** occurrences across the 60 files in `tamarin/`), and that abstraction was
declared **nowhere** until it became `docs/LEAN-SEAM.md` **O23**. **(3) `docs/PROPERTIES.md` and
`docs/FINAL-ASSURANCE-SUMMARY.md` both published that the pinned design admits no "forgery …
under an active attacker, at the modeled bound"** — true, and load-bearing on four words pointing
at a bound that never mentioned entity resolution. Both are corrected at the site; the form is
retracted as **R13**. **The cause is D19's subject and it is why that candidate exists: every
denominator in this repo was an artifact of ours.** `make obligations` supplies one from the pin
instead — **120 of 365 core obligations are UNEXAMINED**. Audit:
`docs/status/AUDIT-2026-09-14-THE-DENOMINATOR-WAS-OUR-OWN-CITATIONS.md`. **And the audit was
triggered from outside**, by a counterpart shipping the fix, which is recorded in its own process
review as the finding that outranks the rest.
