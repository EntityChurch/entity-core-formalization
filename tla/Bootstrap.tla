---- MODULE Bootstrap ----
\* §6.9 Bootstrap — pre-loaded handler safety, added at 0.8.2's second gate audit.
\*
\* WHY THIS EXISTS. §6.9 was listed in COVERAGE-MATRIX.md as a real single-tool result
\* ("TLC only, via Register.tla"). It was not covered at all: both §6.9 citations in the repo
\* were in Register.tla's header and BOTH were DISCLAIMERS — two sentences saying bootstrap
\* handlers bypass registration and are NOT modeled. The citation-derived coverage grid
\* counted an out-of-scope declaration as a claim.
\* See COVERAGE-MATRIX.md section 3a for the class and its tripwire.
\*
\* WHAT §6.9 SAYS, and what is checkable in it:
\*   "Three handlers MUST exist from system initialization, BEFORE ANY HANDLER REGISTRATION
\*    CAN OCCUR" — system/tree, system/handler, system/protocol/connect.
\*   "The spec describes the observable state after initialization: bootstrap handler
\*    manifests exist at their pattern paths, their types exist ..., their grants exist ...,
\*    interface entities exist ..., AND DISPATCH RESOLVES THEM."
\*   "Steps 1-7 are implementation-internal. The observable state after initialization is
\*    normative."
\*
\* So the normative content is a PRECONDITION (all three exist before registration is
\* possible) plus a POST-STATE (all facets present AND dispatchable). The bootstrap sequence
\* itself is informative — which is exactly why the interesting question is what an
\* implementation may be observed doing while it runs, and that is what this module models.
\*
\* THE HAZARD. §6.9's informative sequence puts "6. Create capability grants" before
\* "7. Build dispatch index". An implementation that publishes the index first — a natural
\* optimization, since the manifests are already installed at step 4 — makes a bootstrap
\* handler dispatchable BEFORE its grant exists. That is the §6.2 "manifest without grant"
\* hazard (Register.tla's RegisterAllOrNothing) at the one place §6.2's register lifecycle
\* does not run, because bootstrap bypasses it. Nothing else in this repo covers that gap.
\*
\* THE SECOND HAZARD, and the sharper property. §6.9's precondition is about ALL THREE
\* handlers, not about the one serving the request. An implementation that admits a
\* registration as soon as `system/handler` is dispatchable — the obvious reading, since
\* that is the handler doing the work — can admit it while `system/tree` is still
\* installing, and registration writes to the tree. GateAll = FALSE is that control.
\*
\* MODEL SHAPE (D11 — what is and is not here). Facet vocabulary is shared with Register.tla
\* deliberately: the point is that the SAME all-or-nothing property must hold on the path
\* that bypasses §6.2's lifecycle. ABSTRACTED AWAY: facet byte content, the type/grant
\* entities' structure, the tree walk (Live(s) stands for it, as in Register.tla), and all
\* crypto. §6.9's "types handler SHOULD be bootstrapped" is a SHOULD over an optional fourth
\* handler, gated on the type-system spec's Level 2+, and is not modeled — the MUST is about
\* the three. (That gating section carries no sigil here for the same reason: a section a
\* model makes no claim about must not be cited. COVERAGE-MATRIX.md section 3b.)
EXTENDS Naturals, FiniteSets

CONSTANTS
  AtomicPublish,  \* TRUE  = §6.9 post-state: a bootstrap handler becomes dispatchable only
                  \*         once all its facets exist (grants at step 6 before index at 7).
                  \* FALSE = neg control: the index is built from the step-4 manifests, so a
                  \*         bootstrap handler is dispatchable without its grant.
  GateAll,        \* TRUE  = §6.9: registration is possible only after ALL THREE bootstrap
                  \*         handlers exist. CORRECT.
                  \* FALSE = neg control: registration is admitted as soon as system/handler
                  \*         is dispatchable, while system/tree may still be installing.
  GateConnect     \* TRUE  = §6.9: system/protocol/connect is "pre-authorized" — it exists
                  \*         from initialization, so no connection can establish before it.
                  \* FALSE = neg control: connections are served before connect is installed.

\* The five §6.2 facets, same abstraction as Register.tla (manifest / types / grant / sig /
\* iface). §6.9 installs them at initialization instead of through the register lifecycle.
FACETS  == {"manifest", "types", "grant", "sig", "iface"}
Live(s) == s = FACETS

\* §6.9's three MUST-exist handlers.
Boot == {"tree", "handler", "connect"}

\* What the index is built from when the publish is not atomic with the grant write: §6.9
\* step 4 installs manifests and step 5 the interface entities, so those two are what a
\* too-early index build has to work with.
EARLY == {"manifest", "iface"}

VARIABLES
  facets,       \* Boot -> SUBSET FACETS: which facets exist at each bootstrap path
  disp,         \* SUBSET Boot: the §6.6 dispatch index
  registered,   \* a non-bootstrap handler has been registered through system/handler
  established   \* a connection has been established through system/protocol/connect

vars == << facets, disp, registered, established >>

\* ===== transitions =====
Init ==
  /\ facets      = [h \in Boot |-> {}]
  /\ disp        = {}
  /\ registered  = FALSE
  /\ established = FALSE

\* System initialization installs one bootstrap handler. Correct: facets and index publish
\* land together, so the handler is never dispatch-visible incomplete. Control: the index is
\* published from the manifests alone and the remaining facets land later (InstallFinish).
InstallBoot(h) ==
  /\ facets[h] = {}
  /\ IF AtomicPublish
       THEN /\ facets' = [facets EXCEPT ![h] = FACETS]
            /\ disp'   = disp \cup {h}
       ELSE /\ facets' = [facets EXCEPT ![h] = EARLY]
            /\ disp'   = disp \cup {h}
  /\ UNCHANGED << registered, established >>

\* The late grant/sig/types writes, in the non-atomic variant.
InstallFinish(h) ==
  /\ facets[h] = EARLY
  /\ facets' = [facets EXCEPT ![h] = FACETS]
  /\ UNCHANGED << disp, registered, established >>

\* §6.9: "before any handler registration can occur". Correct: every bootstrap handler must
\* exist. Control: only the handler doing the work is checked.
RegReady ==
  IF GateAll THEN \A h \in Boot : h \in disp
             ELSE "handler" \in disp

Register ==
  /\ ~registered
  /\ RegReady
  /\ registered' = TRUE
  /\ UNCHANGED << facets, disp, established >>

\* §6.9: system/protocol/connect is pre-authorized — present from initialization.
Establish ==
  /\ ~established
  /\ (GateConnect => "connect" \in disp)
  /\ established' = TRUE
  /\ UNCHANGED << facets, disp, registered >>

Next ==
  \/ \E h \in Boot : (InstallBoot(h) \/ InstallFinish(h))
  \/ Register
  \/ Establish
  \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

\* ===== Properties =====

TypeOK ==
  /\ facets \in [Boot -> SUBSET FACETS]
  /\ disp \subseteq Boot
  /\ registered \in BOOLEAN
  /\ established \in BOOLEAN

\* SAFETY — §6.9's normative post-state carried to every observable state: nothing is
\* dispatch-visible before all of its facets exist. This is Register.tla's
\* RegisterAllOrNothing on the path that BYPASSES §6.2's register lifecycle, which is the
\* whole reason §6.9 needs its own model. Violated by AtomicPublish = FALSE.
BootAllOrNothing == \A h \in disp : Live(facets[h])

\* SAFETY — §6.9: "Three handlers MUST exist from system initialization, before any handler
\* registration can occur." Note this quantifies over ALL THREE, not over the handler serving
\* the request. Violated by GateAll = FALSE.
NoRegistrationBeforeBootstrap ==
  registered => (\A h \in Boot : Live(facets[h]))

\* SAFETY — §6.9: system/protocol/connect is bootstrapped and "pre-authorized", so a
\* connection can never be served by a handler that does not yet exist. Violated by
\* GateConnect = FALSE.
ConnectPreAuthorized == established => Live(facets["connect"])

\* NON-VACUITY WITNESS (PROPERTIES.md §C.4 / BootstrapWitness.cfg). Asserted as an invariant
\* that MUST FAIL: a violation exhibits a reachable state in which initialization completed,
\* a handler actually registered AND a connection actually established — so the three
\* properties above are not vacuously true of a system that never finishes booting.
\* Expected verdict: VIOLATION.
WitnessBootComplete ==
  ~(registered /\ established /\ \A h \in Boot : Live(facets[h]))
====
