---- MODULE RefMap ----
\* T4 — THE REFINEMENT MAPPING from the composed `Core` model onto the component modules
\* it is said to compose. `docs/LEAN-SEAM.md` Class T row T4, which was the ledger's one
\* OPEN row until this module closed it — by REFUTING it:
\*
\*   Assumed:       "the composed verdict is the conjunction the component modules check
\*                   separately."
\*   Discharged by: nothing — `Core` and the per-subsystem modules are checked
\*                   independently, and no refinement proof links them.
\*
\* This module is the mapping alone: pure operators over Core's state values, no variables
\* and no properties. It exists as its own module because TWO different checks must use
\* EXACTLY the same mapping text, and a mapping transcribed twice is a mapping that can
\* disagree with itself:
\*
\*   1. `Core.tla` INSTANCEs the component modules through it, so the components' OWN
\*      invariant definitions — not paraphrases of them — become invariants over Core's
\*      reachable states. (CoreRefines.cfg, plus CoreRefinesGateBug.cfg as its control)
\*   2. `CoreMapFree.tla` applies it to EVERY type-correct valuation instead of the
\*      reachable ones, which is what separates a component invariant Core actually CARRIES
\*      from one the mapping MANUFACTURES. (CoreMapFree*.cfg)
\*
\* WHY (2) EXISTS, and it is the whole methodological point of this module. A refinement or
\* invariant-implication check that passes tells you nothing on its own: a mapping that sends
\* a component variable to a constant makes that component's invariant a TAUTOLOGY, and TLC
\* reports the same green for "Core enforces this" as for "the mapping asserts it". That is
\* the `StoreBounded` failure — a conjunct that could not fail, disclosed as vacuous in two
\* releases — reproduced one level up, in the very check meant to close the composition gap.
\* So every mapped invariant is classified by a RUN:
\*
\*   CARRIED      — some type-correct valuation VIOLATES it, so the mapping does not force
\*                  it and Core's own reachability is what makes it true. Real content.
\*   MANUFACTURED — it holds in every type-correct valuation, so it is a theorem about this
\*                  mapping and says nothing whatever about Core.
\*
\* The classification is the deliverable. See docs/PROPERTIES.md §C item 10 and
\* docs/LEAN-SEAM.md row T4.
EXTENDS Naturals, FiniteSets

\* ============================================================================
\* Core -> Conn (subsystem A, §4.1-4.7)
\* ============================================================================
\* Core collapses the §4.6 handshake to a single `conn[p] : "new" -> "established"` step
\* (Core.tla process `link`). Conn runs the real two-phase machine, new -> hello_done ->
\* established, driven by a nondeterministic frame stream. So the mapping must invent
\* Conn's intermediate state, and everything it invents is a place a component invariant
\* can become manufactured. Each line below says which it is; the runs decide, not the
\* comments.

\* CARRIES CONTENT: Core's conn[p] is a real variable with both values reachable.
MapPhase(c)        == IF c = "established" THEN "established" ELSE "new"
MapEver(c)         == c = "established"

\* INVENTED: Core has no nonce. §4.6 step 1's echo check is Conn's and Tamarin's (T1);
\* Core's `link` process establishes without one. Any value here is a choice, and this one
\* is chosen to be the FAITHFUL one — an established Core connection is one whose handshake
\* succeeded, which under Conn means the issued nonce was echoed.
MapIssuedNonce(c)  == IF c = "established" THEN "N1" ELSE "none"

\* INVENTED: Core does not model token issuance at all. Same faithful-choice reasoning:
\* one established connection minted one token.
MapTokens(c)       == IF c = "established" THEN 1 ELSE 0

\* CARRIES CONTENT: Core's client lifecycle is a real variable, and "a non-connect EXECUTE
\* was admitted to dispatch" is exactly what cstate leaving "init" means in Core.
MapDispatched(cs)  == cs \in {"sent", "done"}

\* Conn's remaining variables are its frame plumbing, which Core has no counterpart for at
\* all. No invariant of Conn mentions them, so these exist only to satisfy INSTANCE's
\* requirement that every variable be substituted.
MapInbox           == << >>
MapSubmitted       == 0
MapAnswered        == 0
MapRespHalted      == FALSE
MapConnPc          == [x \in {"env", "resp"} |-> "Done"]

\* ============================================================================
\* Core -> Store (subsystem C, §4.8-4.10)
\* ============================================================================
\* Read the substitutions below before reading the result, because the result is visible in
\* them: Core represents the entire store subsystem as `store[p] \subseteq {"k"}` — one
\* peer-local set, one literal key, written once. Store's invariants are about a refcount
\* (`rc`), the ground-truth referrer set (`holders`), write-critical-section occupancy
\* (`writers`), admission (`pending`), and per-request admission state (`rstate`, `payload`,
\* `depth`, `wrote`). Core has NO counterpart for any of them, so every one is mapped to a
\* constant. An invariant over constants cannot fail.
\*
\* This is not a defect in Core and it is not news to Core: the module's own header removed
\* `StoreBounded` for being vacuous and names §4.8's refcount use-after-free as a STRUCTURAL
\* exclusion — "neither property is expressible against this module's abstractions." What is
\* new is that T4's claim is measured against that, rather than being left to read as though
\* the composition covered it.

\* The one Store variable with a real Core counterpart. Core's single key becomes one of
\* Store's three; the mapping is injective, so a Core store write is a Store store write.
MapStoreSet(st)    == IF "k" \in st THEN {"k1"} ELSE {}

\* CONSTANT — Core has no write critical section. Its handler write and verdict gate are one
\* atomic step by construction (Core.tla, the note at SFrame1), so "how many writers are
\* inside the section" is not a question this model can ask.
MapWriters         == 0

\* CONSTANT — Core has no refcount and no referrer set. §4.8's use-after-free predicate
\* (`k \notin store /\ holders[k] # {}`) is therefore unstatable against Core's state.
MapRc              == [k \in {"k1", "k2", "k3"} |-> 0]
MapHolders         == [k \in {"k1", "k2", "k3"} |-> {}]

\* CONSTANT — Core has no admission gate and no per-request state. Core's servers are not
\* requests in Store's sense; they serve once, unconditionally, with no §4.10 limits.
MapPending         == 0
MapRstate          == [r \in {1} |-> "new"]
MapPayload         == [r \in {1} |-> "ok"]
MapDepth           == [r \in {1} |-> "ok"]
MapWrote           == [r \in {1} |-> FALSE]
MapStorePc         == [x \in {"adm"} |-> "Done"]
====
