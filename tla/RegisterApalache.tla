---- MODULE RegisterApalache ----
\* Apalache (SMT) cross-check of the Register module (tla/Register.tla), cross-check #A per
\* docs/HANDOFF-CROSSCHECK.md Track A. A typed HAND-PORT of the §6.2 register/unregister lifecycle
\* data layer — the per-handler tree fullness (empty/partial/full, the five §6.2 writes abstracted)
\* and the lifecycle phase — proving the §6.2 NoUserAtSystem guard invariant INDUCTIVE.
\*
\* Scope (honest, handoff §6): Apalache here proves NoUserAtSystem — the §6.2 system-path guard —
\* which it handles cleanly. The relational coherence invariants (IndexMatchesTree / atomicity)
\* are *structural*: they are corroborated by the independent Spin encoding (spin/register.pml) and
\* remain TLC-checked; a native relational treatment (Alloy) is an optional Track-C follow-on.
\*
\* What this buys over TLC: TLC ENUMERATES at the bound; Apalache proves NoUserAtSystem INDUCTIVE
\* via Z3 (base Init=>Inv, step Inv/\Next=>Inv'), holding for EVERY reachable state. The proof needs
\* a strengthening — the user-at-system handler never enters an active lifecycle phase (so the
\* tree-writing transitions stay disabled for it). The neg control (GuardSystem=FALSE) is caught
\* symbolically exactly where TLC's RegisterSysGuardBug is.
EXTENDS Naturals

CONSTANTS
  \* @type: Bool;
  GuardSystem,   \* TRUE = §6.2 user register at system/* rejected; FALSE = neg control
  \* @type: Bool;
  Atomic,        \* TRUE = §6.2 writes + index update atomic; FALSE = incremental (Spin/TLC surface)
  \* @type: Bool;
  WedgeReg       \* FALSE = lifecycle settles; TRUE = liveness neg control (Spin/TLC surface)

Handlers == {"hLocal", "hSys"}
\* Who(h) = "user" for both; Where(h) = "system" only for hSys. So the §6.2 guard target is hSys.
IsUser(h)   == TRUE
IsSystem(h) == h = "hSys"

VARIABLES
  \* @type: Str -> Str;
  tree,      \* §6.1 source of truth: per-handler fullness "empty" | "partial" | "full"
  \* @type: Str -> Str;
  rphase     \* lifecycle: init | registering | live | unregistering | gone | rejected | wedged

\* @type: <<Str -> Str, Str -> Str>>;
vars == << tree, rphase >>

Fullness == {"empty", "partial", "full"}
Phases   == {"init", "registering", "live", "unregistering", "gone", "rejected", "wedged"}

\* ----- the safety invariant (transcribed from Register.tla's define block) -----
\* §6.2: no user-installed handler is ever present at a system/* path.
NoUserAtSystem == \A h \in Handlers : (tree[h] # "empty") => ~(IsUser(h) /\ IsSystem(h))

\* ----- type/domain + inductive strengthening -----
\* NoUserAtSystem alone is not inductive (an arbitrary state could have hSys mid-lifecycle with
\* tree=empty, then RFinish writes "full"). The strengthening: under the guard, hSys never leaves
\* {init, rejected}, so every tree-writing transition stays disabled for it and its tree stays empty.
SafeSys == /\ rphase["hSys"] \in {"init", "rejected"}
           /\ tree["hSys"] = "empty"

TypeOK ==
  /\ tree \in [Handlers -> Fullness]
  /\ rphase \in [Handlers -> Phases]

Inv == TypeOK /\ SafeSys /\ NoUserAtSystem

\* ----- transitions (data layer of Register.tla's RReg / RFinish / RUnreg / RUFinish) -----
\* DNF (one disjunct per outcome) so Apalache's assignment finder sees tree'/rphase' on each branch.
Init ==
  /\ tree = [h \in Handlers |-> "empty"]
  /\ rphase = [h \in Handlers |-> "init"]

\* §6.2 register: guard first (user MUST NOT register at system/*), then the writes.
RReg(h) ==
  /\ rphase[h] = "init"
  /\ \/ /\ GuardSystem /\ IsSystem(h)                          \* §6.2 rejected — no tree writes
        /\ rphase' = [rphase EXCEPT ![h] = "rejected"]
        /\ tree' = tree
     \/ /\ ~(GuardSystem /\ IsSystem(h)) /\ Atomic             \* atomic publish (five facets + index)
        /\ tree' = [tree EXCEPT ![h] = "full"]
        /\ rphase' = [rphase EXCEPT ![h] = "live"]
     \/ /\ ~(GuardSystem /\ IsSystem(h)) /\ ~Atomic            \* incremental: dispatch-visible partial
        /\ tree' = [tree EXCEPT ![h] = "partial"]
        /\ rphase' = [rphase EXCEPT ![h] = "registering"]

RFinish(h) ==
  /\ rphase[h] = "registering"
  /\ tree' = [tree EXCEPT ![h] = "full"]
  /\ rphase' = [rphase EXCEPT ![h] = "live"]

\* §6.2 unregister: reverses the writes; atomic w.r.t. dispatch (mirror of register).
RUnreg(h) ==
  /\ rphase[h] = "live"
  /\ \/ /\ WedgeReg                                            \* liveness neg ctrl: never settles
        /\ rphase' = [rphase EXCEPT ![h] = "wedged"]
        /\ tree' = tree
     \/ /\ ~WedgeReg /\ Atomic
        /\ tree' = [tree EXCEPT ![h] = "empty"]
        /\ rphase' = [rphase EXCEPT ![h] = "gone"]
     \/ /\ ~WedgeReg /\ ~Atomic
        /\ tree' = [tree EXCEPT ![h] = "partial"]
        /\ rphase' = [rphase EXCEPT ![h] = "unregistering"]

RUFinish(h) ==
  /\ rphase[h] = "unregistering"
  /\ tree' = [tree EXCEPT ![h] = "empty"]
  /\ rphase' = [rphase EXCEPT ![h] = "gone"]

Next ==
  \/ \E h \in Handlers : (RReg(h) \/ RFinish(h) \/ RUnreg(h) \/ RUFinish(h))
  \/ UNCHANGED vars

\* ----- inductive-step init: arbitrary typed state satisfying the (strengthened) invariant -----
IndInit == TypeOK /\ SafeSys /\ NoUserAtSystem

\* ----- constant inits (correct model + the negative control) -----
ConstInitOK  == GuardSystem = TRUE  /\ Atomic = TRUE /\ WedgeReg = FALSE   \* §6.2 guard honored
ConstInitBug == GuardSystem = FALSE /\ Atomic = TRUE /\ WedgeReg = FALSE   \* neg ctrl: guard removed
====
