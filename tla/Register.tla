---- MODULE Register ----
\* Phase 1 — increment 3: Handler registration + index↔tree coherence (V7 §6.1, §6.2, §6.6),
\* per PHASE1-SCOPE.md subsystem E. Registrars install/remove handlers via the §6.2 five-write
\* `register`/`unregister` lifecycle, concurrently, while the dispatch index (§6.6 cache) must
\* stay coherent with the tree (the source of truth) at every observable state.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the five §6.2 writes are modeled as five
\* opaque tree facets (manifest / types / grant / sig / iface) — their byte content, the
\* grant attenuation chain (Lean), and the grant-signature crypto (Tamarin) are abstracted;
\* what is modeled is their *presence/atomicity* w.r.t. dispatch. The §6.6 dispatch index is a
\* cache (`disp`); the tree-walk it must equal is captured by Live(tree[h]). Bootstrap handlers
\* bypass registration entirely and are modeled separately, in tla/Bootstrap.tla. Every
\* element cites its V7 §ref — and ONLY where it makes a claim about that section. The two
\* sentences about bootstrap here deliberately carry no sigil: a scope DISCLAIMER that cites
\* a section was being counted as coverage of it (../docs/COVERAGE-MATRIX.md section 3b).
EXTENDS Naturals, FiniteSets

CONSTANTS Atomic,       \* TRUE  = §6.2 five writes + index update are atomic w.r.t. dispatch;
                        \* FALSE = negative control: writes land incrementally, index published
                        \*         early -> a half-built handler is dispatch-visible.
          GuardSystem,  \* TRUE  = §6.2: user register at system/* rejected;
                        \* FALSE = negative control: guard removed -> user handler at system/*.
          SequencedWrites, \* TRUE  = §6.2's five writes land ONE AT A TIME, in any order, each
                        \*         its own dispatch-visible transition, with the FINAL write and
                        \*         the §6.6 index publish as the single atomic commit point.
                        \* FALSE = the pre-0.8.3 shape: all five writes collapse into one
                        \*         assignment. See the RETIRING VACUITY note below.
          WedgeReg      \* FALSE = §6.2: registration lifecycle always settles;
                        \* TRUE = LIVENESS negative control: a live handler wedges (never torn
                        \*        down / settled) -> RegisterSettles fails.

\* The five normative §6.2 `register` writes (content abstracted; presence/atomicity modeled).
FACETS  == {"manifest", "types", "grant", "sig", "iface"}
Live(s) == s = FACETS     \* §6.6: a handler is dispatchable iff all five facets are present.

\* RETIRING A VACUITY (docs/PROPERTIES.md §C.4, STATUS §Next item 13).
\*
\* Until 0.8.3-dev this module wrote all five facets in ONE assignment, and the correct-model
\* invariants were near-tautological because of it: `tree[h] \in {{}, FACETS}` cannot fail in a
\* model where `tree[h]` is only ever assigned `{}` or `FACETS`. The positive restated the
\* assignment. All the teeth were on the control side.
\*
\* Under SequencedWrites the four non-committing facets land INDIVIDUALLY and in ANY ORDER,
\* each in its own transition that a concurrent registrar can interleave with, so the tree
\* genuinely passes through partial states. What makes the §6.2/§6.6 invariants TRUE is then a
\* discipline rather than an assignment: the fifth write and the index publish are the atomic
\* commit point. `RegisterAllOrNothing` and `IndexMatchesTree` become statements that could
\* fail and do not — and `RegisterSeqWitness` proves the partial states are actually reached,
\* because a "sequenced" model whose sequence is never observed is the same vacuity again.
COMMIT_FACET == "iface"              \* the write that publishes; §6.6's dispatch interface
PRECOMMIT    == FACETS \ {COMMIT_FACET}

\* Two user-installed handlers exercise the guard: one at a domain path (legitimate), one at a
\* system path (must be rejected, §6.2). System bootstrap handlers bypass registration
\* entirely; their own safety properties live in tla/Bootstrap.tla.
Handlers  == {"hLocal", "hSys"}
Who(h)    == "user"
Where(h)  == IF h = "hSys" THEN "system" ELSE "local"

(*--algorithm register
variables
  tree  = [h \in Handlers |-> {}],      \* §6.1 source of truth: facets present per handler path
  disp  = {},                           \* §6.6 in-memory dispatch index (cache of dispatchable handlers)
  rphase = [h \in Handlers |-> "init"]; \* lifecycle: init -> registering -> live -> unregistering -> gone | rejected

define
  \* §6.2 no partial RESIDUE. The property is about what a handler SETTLES in, not about what
  \* is momentarily in flight: under SequencedWrites the tree passes through partial states by
  \* construction (that is the point), and what §6.2 forbids is a handler coming to rest in one
  \* — a permanently half-built or half-torn-down path. In the collapsed-write mode no
  \* in-flight phase exists, so this reduces to the pre-0.8.3 `tree[h] \in {{}, FACETS}`
  \* character for character.
  Settled(h)       == rphase[h] \in {"init", "live", "gone", "rejected", "wedged"}
  NoPartialResidue == \A h \in Handlers : Settled(h) => tree[h] \in {{}, FACETS}

  \* §6.2 all-or-nothing at the dispatch boundary: nothing dispatch-visible is missing its
  \* grant+signature (the "manifest without grant" hazard — would run with no capability ceiling).
  RegisterAllOrNothing == \A h \in disp : Live(tree[h])

  \* §6.6 cache coherence: the dispatch index equals the tree-walk result at all times —
  \* no stale-positive (dispatch a gone handler) and no stale-negative (miss a live one).
  IndexMatchesTree == disp = {h \in Handlers : Live(tree[h])}

  \* NON-VACUITY WITNESS for the sequencing itself. Asserted to be VIOLATED: the violation
  \* exhibits a handler whose tree is genuinely PARTIAL — some facets written, not yet
  \* committed — which is the state the collapsed-write model could not reach at all. Without
  \* it, "the writes are sequenced" is a claim about the source text rather than about the
  \* state space, and a sequencing that is never exercised restores the vacuity it was added
  \* to retire.
  WitnessTreePartial == \A h \in Handlers : tree[h] \in {{}, FACETS}

  \* §6.2: no user-installed handler is ever present at a system/* path.
  NoUserAtSystem == \A h \in Handlers :
                       (tree[h] # {}) => ~(Who(h) = "user" /\ Where(h) = "system")
end define;

\* Each handler's registrar runs its register -> unregister lifecycle concurrently with the others.
fair process reg \in Handlers
begin
  RReg:
    \* §6.2 register. Guard first (§6.2: user MUST NOT register at a system path), then the writes.
    if GuardSystem /\ Who(self) = "user" /\ Where(self) = "system" then
      rphase[self] := "rejected";                 \* §6.2 rejected — no tree writes
    elsif Atomic /\ SequencedWrites then
      \* §6.2 sequenced: enter the write loop. Nothing is dispatch-visible yet — the index
      \* publish is the commit below, not this step.
      rphase[self] := "writing";
    elsif Atomic then
      \* Collapsed-write mode: five facets + index publish in one visible transition.
      tree[self] := FACETS || disp := disp \cup {self} || rphase[self] := "live";
    else
      \* NEG CONTROL: publish to the dispatch index with only manifest+iface written; the
      \* grant/sig/types land in RFinish, so the handler is dispatch-visible without its grant.
      tree[self] := {"manifest", "iface"} || disp := disp \cup {self} ||
      rphase[self] := "registering";
    end if;
  RWriteSeq:
    \* The four non-committing facets, ONE PER TRANSITION and in ANY ORDER — the nondeterministic
    \* `with` is what makes this a real interleaving rather than a fixed sequence. The handler is
    \* NOT in `disp` throughout, which is the discipline the invariants rest on.
    while rphase[self] = "writing" /\ tree[self] # PRECOMMIT do
      with f \in PRECOMMIT \ tree[self] do
        tree[self] := tree[self] \cup {f};
      end with;
    end while;
  RCommit:
    \* §6.2/§6.6 THE COMMIT POINT: the final write and the index publish are atomic w.r.t.
    \* dispatch. This single step is what makes RegisterAllOrNothing and IndexMatchesTree true;
    \* split it and both fail, which is the RegisterAtomicBug control one branch up.
    if rphase[self] = "writing" then
      tree[self] := FACETS || disp := disp \cup {self} || rphase[self] := "live";
    end if;
  RFinish:
    if rphase[self] = "registering" then
      tree[self] := FACETS || rphase[self] := "live";   \* the late grant/sig/types writes land
    end if;
  RUnreg:
    \* §6.2 unregister reverses all five; atomic w.r.t. dispatch (mirror of register).
    if rphase[self] = "live" then
      if WedgeReg then
        rphase[self] := "wedged";   \* LIVENESS NEG CONTROL: stuck live, never settles (still coherent)
      elsif Atomic /\ SequencedWrites then
        \* §6.2 DECOMMIT — the exact mirror of RCommit. Leaving the dispatch index and dropping
        \* the commit facet are one atomic step; only after that do the remaining facets go, one
        \* per transition. Teardown is where the stale-POSITIVE hazard lives (dispatch a handler
        \* whose grant is already gone), so the order is the opposite of registration's.
        tree[self] := PRECOMMIT || disp := disp \ {self} || rphase[self] := "unwriting";
      elsif Atomic then
        tree[self] := {} || disp := disp \ {self} || rphase[self] := "gone";
      else
        \* NEG CONTROL: drop grant/sig first but leave the handler dispatch-visible -> stale-positive.
        tree[self] := {"manifest", "iface"} || rphase[self] := "unregistering";
      end if;
    end if;
  RUnwriteSeq:
    \* Drop the remaining facets one per transition, any order — already out of the index.
    while rphase[self] = "unwriting" /\ tree[self] # {} do
      with f \in tree[self] do
        tree[self] := tree[self] \ {f};
      end with;
    end while;
  RSettle:
    if rphase[self] = "unwriting" then
      rphase[self] := "gone";
    end if;
  RUFinish:
    if rphase[self] = "unregistering" then
      tree[self] := {} || disp := disp \ {self} || rphase[self] := "gone";
    end if;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "bf2f611d" /\ chksum(tla) = "d6b88744")
VARIABLES pc, tree, disp, rphase

(* define statement *)
Settled(h)       == rphase[h] \in {"init", "live", "gone", "rejected", "wedged"}
NoPartialResidue == \A h \in Handlers : Settled(h) => tree[h] \in {{}, FACETS}



RegisterAllOrNothing == \A h \in disp : Live(tree[h])



IndexMatchesTree == disp = {h \in Handlers : Live(tree[h])}







WitnessTreePartial == \A h \in Handlers : tree[h] \in {{}, FACETS}


NoUserAtSystem == \A h \in Handlers :
                     (tree[h] # {}) => ~(Who(h) = "user" /\ Where(h) = "system")


vars == << pc, tree, disp, rphase >>

ProcSet == (Handlers)

Init == (* Global variables *)
        /\ tree = [h \in Handlers |-> {}]
        /\ disp = {}
        /\ rphase = [h \in Handlers |-> "init"]
        /\ pc = [self \in ProcSet |-> "RReg"]

RReg(self) == /\ pc[self] = "RReg"
              /\ IF GuardSystem /\ Who(self) = "user" /\ Where(self) = "system"
                    THEN /\ rphase' = [rphase EXCEPT ![self] = "rejected"]
                         /\ UNCHANGED << tree, disp >>
                    ELSE /\ IF Atomic /\ SequencedWrites
                               THEN /\ rphase' = [rphase EXCEPT ![self] = "writing"]
                                    /\ UNCHANGED << tree, disp >>
                               ELSE /\ IF Atomic
                                          THEN /\ /\ disp' = (disp \cup {self})
                                                  /\ rphase' = [rphase EXCEPT ![self] = "live"]
                                                  /\ tree' = [tree EXCEPT ![self] = FACETS]
                                          ELSE /\ /\ disp' = (disp \cup {self})
                                                  /\ rphase' = [rphase EXCEPT ![self] = "registering"]
                                                  /\ tree' = [tree EXCEPT ![self] = {"manifest", "iface"}]
              /\ pc' = [pc EXCEPT ![self] = "RWriteSeq"]

RWriteSeq(self) == /\ pc[self] = "RWriteSeq"
                   /\ IF rphase[self] = "writing" /\ tree[self] # PRECOMMIT
                         THEN /\ \E f \in PRECOMMIT \ tree[self]:
                                   tree' = [tree EXCEPT ![self] = tree[self] \cup {f}]
                              /\ pc' = [pc EXCEPT ![self] = "RWriteSeq"]
                         ELSE /\ pc' = [pc EXCEPT ![self] = "RCommit"]
                              /\ tree' = tree
                   /\ UNCHANGED << disp, rphase >>

RCommit(self) == /\ pc[self] = "RCommit"
                 /\ IF rphase[self] = "writing"
                       THEN /\ /\ disp' = (disp \cup {self})
                               /\ rphase' = [rphase EXCEPT ![self] = "live"]
                               /\ tree' = [tree EXCEPT ![self] = FACETS]
                       ELSE /\ TRUE
                            /\ UNCHANGED << tree, disp, rphase >>
                 /\ pc' = [pc EXCEPT ![self] = "RFinish"]

RFinish(self) == /\ pc[self] = "RFinish"
                 /\ IF rphase[self] = "registering"
                       THEN /\ /\ rphase' = [rphase EXCEPT ![self] = "live"]
                               /\ tree' = [tree EXCEPT ![self] = FACETS]
                       ELSE /\ TRUE
                            /\ UNCHANGED << tree, rphase >>
                 /\ pc' = [pc EXCEPT ![self] = "RUnreg"]
                 /\ disp' = disp

RUnreg(self) == /\ pc[self] = "RUnreg"
                /\ IF rphase[self] = "live"
                      THEN /\ IF WedgeReg
                                 THEN /\ rphase' = [rphase EXCEPT ![self] = "wedged"]
                                      /\ UNCHANGED << tree, disp >>
                                 ELSE /\ IF Atomic /\ SequencedWrites
                                            THEN /\ /\ disp' = disp \ {self}
                                                    /\ rphase' = [rphase EXCEPT ![self] = "unwriting"]
                                                    /\ tree' = [tree EXCEPT ![self] = PRECOMMIT]
                                            ELSE /\ IF Atomic
                                                       THEN /\ /\ disp' = disp \ {self}
                                                               /\ rphase' = [rphase EXCEPT ![self] = "gone"]
                                                               /\ tree' = [tree EXCEPT ![self] = {}]
                                                       ELSE /\ /\ rphase' = [rphase EXCEPT ![self] = "unregistering"]
                                                               /\ tree' = [tree EXCEPT ![self] = {"manifest", "iface"}]
                                                            /\ disp' = disp
                      ELSE /\ TRUE
                           /\ UNCHANGED << tree, disp, rphase >>
                /\ pc' = [pc EXCEPT ![self] = "RUnwriteSeq"]

RUnwriteSeq(self) == /\ pc[self] = "RUnwriteSeq"
                     /\ IF rphase[self] = "unwriting" /\ tree[self] # {}
                           THEN /\ \E f \in tree[self]:
                                     tree' = [tree EXCEPT ![self] = tree[self] \ {f}]
                                /\ pc' = [pc EXCEPT ![self] = "RUnwriteSeq"]
                           ELSE /\ pc' = [pc EXCEPT ![self] = "RSettle"]
                                /\ tree' = tree
                     /\ UNCHANGED << disp, rphase >>

RSettle(self) == /\ pc[self] = "RSettle"
                 /\ IF rphase[self] = "unwriting"
                       THEN /\ rphase' = [rphase EXCEPT ![self] = "gone"]
                       ELSE /\ TRUE
                            /\ UNCHANGED rphase
                 /\ pc' = [pc EXCEPT ![self] = "RUFinish"]
                 /\ UNCHANGED << tree, disp >>

RUFinish(self) == /\ pc[self] = "RUFinish"
                  /\ IF rphase[self] = "unregistering"
                        THEN /\ /\ disp' = disp \ {self}
                                /\ rphase' = [rphase EXCEPT ![self] = "gone"]
                                /\ tree' = [tree EXCEPT ![self] = {}]
                        ELSE /\ TRUE
                             /\ UNCHANGED << tree, disp, rphase >>
                  /\ pc' = [pc EXCEPT ![self] = "Done"]

reg(self) == RReg(self) \/ RWriteSeq(self) \/ RCommit(self)
                \/ RFinish(self) \/ RUnreg(self) \/ RUnwriteSeq(self)
                \/ RSettle(self) \/ RUFinish(self)

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == (\E self \in Handlers: reg(self))
           \/ Terminating

Spec == /\ Init /\ [][Next]_vars
        /\ \A self \in Handlers : WF_vars(reg(self))

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION

\* ===== Liveness (checked as PROPERTY; needs the WF supplied by `fair process`) =====

\* §6.2: every registration settles — concurrent register/unregister-vs-dispatch makes
\* progress; no registrar wedges. Each handler reaches a terminal outcome (torn down, or
\* rejected by the system-path guard) rather than hanging mid-lifecycle.
RegisterSettles == \A h \in Handlers : <>(rphase[h] \in {"gone", "rejected"})

\* NON-VACUITY WITNESS (PROPERTIES.md §C.4 / RegisterWitness.cfg). TLC has no ProVerif-style
\* reachability query, so a witness is expressed as an invariant that MUST BE VIOLATED. A
\* violation is the PASS condition: it exhibits a reachable state in which
\* a handler was actually REGISTERED and is live in the tree — so the §6.1 atomicity and
\* index-coherence results are not vacuously true of a peer with no handlers.
\* Checking it GREEN would mean the interesting state is unreachable — i.e. the results above
\* hold of an inert model. Expected verdict: VIOLATION.
WitnessHandlerLive == ~(\E h \in Handlers : Live(tree[h]))
====
