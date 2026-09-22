---- MODULE RegisterApalache ----
\* Apalache (SMT) cross-check of the Register module (tla/Register.tla), cross-check #A per
\* docs/HANDOFF-CROSSCHECK.md Track A. A typed HAND-PORT of the §6.2 register/unregister lifecycle
\* data layer — the per-handler tree fullness (empty/partial/full, the five §6.2 writes abstracted)
\* and the lifecycle phase — proving the §6.2 NoUserAtSystem guard invariant INDUCTIVE.
\*
\* Scope (honest, handoff section 6): Apalache proves NoUserAtSystem — the §6.2 system-path guard —
\* and, since 0.8.3-dev, RegisterAllOrNothing: nothing in the §6.6 dispatch index is missing a
\* facet. The full relational coherence invariant (IndexMatchesTree, an EQUALITY between the
\* index and the tree-walk) remains TLC/Spin's, corroborated by the independent Spin encoding;
\* a native relational treatment (Alloy) is still the optional Track-C follow-on.
\*
\* WHY RegisterAllOrNothing IS HERE NOW, and was not before. Under the pre-0.8.3 collapsed-write
\* model the five §6.2 writes and the index publish were ONE assignment, so the property was
\* near-tautological (../docs/PROPERTIES.md §C.4) — there was no state in which a handler could
\* be indexed and incomplete, so proving it inductive would have proved nothing. Sequenced writes
\* make the incomplete state REACHABLE, which is what turns the invariant into a claim about a
\* DISCIPLINE — the final write and the index publish are one atomic commit — and therefore into
\* something worth proving unbounded.
\*
\* What this buys over TLC: TLC ENUMERATES at the bound; Apalache proves NoUserAtSystem INDUCTIVE
\* via Z3 (base Init=>Inv, step Inv/\Next=>Inv'), holding for EVERY reachable state. The proof needs
\* a strengthening — the user-at-system handler never enters an active lifecycle phase (so the
\* tree-writing transitions stay disabled for it). The neg control (GuardSystem=FALSE) is caught
\* symbolically exactly where TLC's RegisterSysGuardBug is.
EXTENDS Naturals

CONSTANTS
  \* @type: Bool;
  SequencedWrites,
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
  \* @type: Set(Str);
  disp,      \* §6.6 in-memory dispatch index — the set of dispatchable handler paths
  \* @type: Str -> Str;
  tree,      \* §6.1 source of truth: per-handler fullness "empty" | "partial" | "full"
  \* @type: Str -> Str;
  rphase     \* lifecycle: init | registering | live | unregistering | gone | rejected | wedged

\* @type: <<Set(Str), Str -> Str, Str -> Str>>;
vars == << disp, tree, rphase >>

Fullness == {"empty", "partial", "full"}
Phases   == {"init", "registering", "writing", "live", "unregistering", "unwriting", "gone",
             "rejected", "wedged"}

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
  /\ disp \in SUBSET Handlers   \* `\in SUBSET`, not `\subseteq`: Apalache's assignment finder
                                \* needs an assignment form here, since TypeOK is also the IndInit

\* §6.2 all-or-nothing at the dispatch boundary — the property sequenced writes make real.
RegisterAllOrNothing == \A h \in Handlers : h \in disp => tree[h] = "full"

\* The strengthening RegisterAllOrNothing needs to be inductive. Without it an arbitrary typed
\* state could put a handler in `disp` while its phase is mid-write, and the next write step
\* would drop it to "partial" while still indexed — a spurious counterexample about a state no
\* run reaches. Stated as: only a LIVE (or wedged-while-live) handler is ever indexed.
IndexedOnlyWhenLive == \A h \in Handlers :
  h \in disp => rphase[h] \in {"live", "wedged"}

Inv    == TypeOK /\ SafeSys /\ NoUserAtSystem
InvAoN == TypeOK /\ IndexedOnlyWhenLive /\ RegisterAllOrNothing

\* ----- transitions (data layer of Register.tla's RReg / RFinish / RUnreg / RUFinish) -----
\* DNF (one disjunct per outcome) so Apalache's assignment finder sees tree'/rphase' on each branch.
Init ==
  /\ disp = {}
  /\ tree = [h \in Handlers |-> "empty"]
  /\ rphase = [h \in Handlers |-> "init"]

\* §6.2 register: guard first (user MUST NOT register at system/*), then the writes.
RReg(h) ==
  /\ rphase[h] = "init"
  /\ \/ /\ GuardSystem /\ IsSystem(h)                          \* §6.2 rejected — no tree writes
        /\ rphase' = [rphase EXCEPT ![h] = "rejected"]
        /\ tree' = tree /\ disp' = disp
     \/ /\ ~(GuardSystem /\ IsSystem(h)) /\ Atomic /\ SequencedWrites
        \* §6.2 sequenced: enter the write phase. NOT indexed yet — the publish is the commit.
        /\ rphase' = [rphase EXCEPT ![h] = "writing"]
        /\ tree' = tree /\ disp' = disp
     \/ /\ ~(GuardSystem /\ IsSystem(h)) /\ Atomic /\ ~SequencedWrites
        /\ tree' = [tree EXCEPT ![h] = "full"]     \* collapsed publish (five facets + index)
        /\ rphase' = [rphase EXCEPT ![h] = "live"]
        /\ disp' = disp \cup {h}
     \/ /\ ~(GuardSystem /\ IsSystem(h)) /\ ~Atomic            \* NEG CTRL: indexed while partial
        /\ tree' = [tree EXCEPT ![h] = "partial"]
        /\ rphase' = [rphase EXCEPT ![h] = "registering"]
        /\ disp' = disp \cup {h}

\* §6.2 the sequenced write steps: the tree becomes PARTIAL, and stays out of the index.
RWriteSeq(h) ==
  /\ rphase[h] = "writing"
  /\ tree' = [tree EXCEPT ![h] = "partial"]
  /\ rphase' = rphase /\ disp' = disp

\* §6.2/§6.6 THE COMMIT POINT — final write + index publish, atomic. This one step is what
\* makes RegisterAllOrNothing true; splitting it is exactly the ~Atomic branch above.
RCommit(h) ==
  /\ rphase[h] = "writing"
  /\ tree' = [tree EXCEPT ![h] = "full"]
  /\ rphase' = [rphase EXCEPT ![h] = "live"]
  /\ disp' = disp \cup {h}

RFinish(h) ==
  /\ rphase[h] = "registering"
  /\ tree' = [tree EXCEPT ![h] = "full"]
  /\ rphase' = [rphase EXCEPT ![h] = "live"]
  /\ disp' = disp

\* §6.2 unregister: reverses the writes; atomic w.r.t. dispatch (mirror of register).
RUnreg(h) ==
  /\ rphase[h] = "live"
  /\ \/ /\ WedgeReg                                            \* liveness neg ctrl: never settles
        /\ rphase' = [rphase EXCEPT ![h] = "wedged"]
        /\ tree' = tree /\ disp' = disp
     \/ /\ ~WedgeReg /\ Atomic /\ SequencedWrites          \* DECOMMIT: leave index + drop facet
        /\ tree' = [tree EXCEPT ![h] = "partial"]
        /\ rphase' = [rphase EXCEPT ![h] = "unwriting"]
        /\ disp' = disp \ {h}
     \/ /\ ~WedgeReg /\ Atomic /\ ~SequencedWrites
        /\ tree' = [tree EXCEPT ![h] = "empty"]
        /\ rphase' = [rphase EXCEPT ![h] = "gone"]
        /\ disp' = disp \ {h}
     \/ /\ ~WedgeReg /\ ~Atomic                           \* NEG CTRL: stale-positive in the index
        /\ tree' = [tree EXCEPT ![h] = "partial"]
        /\ rphase' = [rphase EXCEPT ![h] = "unregistering"]
        /\ disp' = disp

RUFinish(h) ==
  /\ rphase[h] = "unregistering"
  /\ tree' = [tree EXCEPT ![h] = "empty"]
  /\ rphase' = [rphase EXCEPT ![h] = "gone"]
  /\ disp' = disp \ {h}

\* the sequenced teardown: already out of the index, drop the rest and settle.
RSettle(h) ==
  /\ rphase[h] = "unwriting"
  /\ tree' = [tree EXCEPT ![h] = "empty"]
  /\ rphase' = [rphase EXCEPT ![h] = "gone"]
  /\ disp' = disp

Next ==
  \/ \E h \in Handlers : (RReg(h) \/ RWriteSeq(h) \/ RCommit(h) \/ RFinish(h)
                          \/ RUnreg(h) \/ RSettle(h) \/ RUFinish(h))
  \/ UNCHANGED vars

\* ----- inductive-step init: arbitrary typed state satisfying the (strengthened) invariant -----
IndInit    == TypeOK /\ SafeSys /\ NoUserAtSystem
IndInitAoN == TypeOK /\ IndexedOnlyWhenLive /\ RegisterAllOrNothing

\* ----- constant inits (correct model + the negative control) -----
ConstInitOK  == GuardSystem = TRUE  /\ Atomic = TRUE  /\ WedgeReg = FALSE /\ SequencedWrites = TRUE
ConstInitBug == GuardSystem = FALSE /\ Atomic = TRUE  /\ WedgeReg = FALSE /\ SequencedWrites = TRUE
\* NEG CTRL for RegisterAllOrNothing: split the commit — publish to the index with the tree
\* still partial. MUST produce a counterexample; if it does not, the invariant is vacuous.
ConstInitBugAoN == GuardSystem = TRUE /\ Atomic = FALSE /\ WedgeReg = FALSE /\ SequencedWrites = TRUE
====
