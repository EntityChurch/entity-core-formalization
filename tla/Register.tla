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
\* (§6.9) bypass registration and are not modeled. Every element cites its V7 §ref.
EXTENDS Naturals, FiniteSets

CONSTANTS Atomic,       \* TRUE  = §6.2 five writes + index update are atomic w.r.t. dispatch;
                        \* FALSE = negative control: writes land incrementally, index published
                        \*         early -> a half-built handler is dispatch-visible.
          GuardSystem,  \* TRUE  = §6.2: user register at system/* rejected;
                        \* FALSE = negative control: guard removed -> user handler at system/*.
          WedgeReg      \* FALSE = §6.2: registration lifecycle always settles;
                        \* TRUE = LIVENESS negative control: a live handler wedges (never torn
                        \*        down / settled) -> RegisterSettles fails.

\* The five normative §6.2 `register` writes (content abstracted; presence/atomicity modeled).
FACETS  == {"manifest", "types", "grant", "sig", "iface"}
Live(s) == s = FACETS     \* §6.6: a handler is dispatchable iff all five facets are present.

\* Two user-installed handlers exercise the guard: one at a domain path (legitimate), one at a
\* system path (must be rejected, §6.2). System bootstrap handlers bypass registration (§6.9).
Handlers  == {"hLocal", "hSys"}
Who(h)    == "user"
Where(h)  == IF h = "hSys" THEN "system" ELSE "local"

(*--algorithm register
variables
  tree  = [h \in Handlers |-> {}],      \* §6.1 source of truth: facets present per handler path
  disp  = {},                           \* §6.6 in-memory dispatch index (cache of dispatchable handlers)
  rphase = [h \in Handlers |-> "init"]; \* lifecycle: init -> registering -> live -> unregistering -> gone | rejected

define
  \* §6.2 atomicity: a handler path is always either fully present (all five writes) or fully
  \* absent — dispatch never observes a partially-built (or partially-torn-down) handler.
  NoPartialResidue == \A h \in Handlers : tree[h] \in {{}, FACETS}

  \* §6.2 all-or-nothing at the dispatch boundary: nothing dispatch-visible is missing its
  \* grant+signature (the "manifest without grant" hazard — would run with no capability ceiling).
  RegisterAllOrNothing == \A h \in disp : Live(tree[h])

  \* §6.6 cache coherence: the dispatch index equals the tree-walk result at all times —
  \* no stale-positive (dispatch a gone handler) and no stale-negative (miss a live one).
  IndexMatchesTree == disp = {h \in Handlers : Live(tree[h])}

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
    elsif Atomic then
      \* Atomic w.r.t. dispatch: five facets + index publish in one visible transition.
      tree[self] := FACETS || disp := disp \cup {self} || rphase[self] := "live";
    else
      \* NEG CONTROL: publish to the dispatch index with only manifest+iface written; the
      \* grant/sig/types land in RFinish, so the handler is dispatch-visible without its grant.
      tree[self] := {"manifest", "iface"} || disp := disp \cup {self} ||
      rphase[self] := "registering";
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
      elsif Atomic then
        tree[self] := {} || disp := disp \ {self} || rphase[self] := "gone";
      else
        \* NEG CONTROL: drop grant/sig first but leave the handler dispatch-visible -> stale-positive.
        tree[self] := {"manifest", "iface"} || rphase[self] := "unregistering";
      end if;
    end if;
  RUFinish:
    if rphase[self] = "unregistering" then
      tree[self] := {} || disp := disp \ {self} || rphase[self] := "gone";
    end if;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "bf84eb70" /\ chksum(tla) = "2dde14c")
VARIABLES pc, tree, disp, rphase

(* define statement *)
NoPartialResidue == \A h \in Handlers : tree[h] \in {{}, FACETS}



RegisterAllOrNothing == \A h \in disp : Live(tree[h])



IndexMatchesTree == disp = {h \in Handlers : Live(tree[h])}


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
                    ELSE /\ IF Atomic
                               THEN /\ /\ disp' = (disp \cup {self})
                                       /\ rphase' = [rphase EXCEPT ![self] = "live"]
                                       /\ tree' = [tree EXCEPT ![self] = FACETS]
                               ELSE /\ /\ disp' = (disp \cup {self})
                                       /\ rphase' = [rphase EXCEPT ![self] = "registering"]
                                       /\ tree' = [tree EXCEPT ![self] = {"manifest", "iface"}]
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
                                 ELSE /\ IF Atomic
                                            THEN /\ /\ disp' = disp \ {self}
                                                    /\ rphase' = [rphase EXCEPT ![self] = "gone"]
                                                    /\ tree' = [tree EXCEPT ![self] = {}]
                                            ELSE /\ /\ rphase' = [rphase EXCEPT ![self] = "unregistering"]
                                                    /\ tree' = [tree EXCEPT ![self] = {"manifest", "iface"}]
                                                 /\ disp' = disp
                      ELSE /\ TRUE
                           /\ UNCHANGED << tree, disp, rphase >>
                /\ pc' = [pc EXCEPT ![self] = "RUFinish"]

RUFinish(self) == /\ pc[self] = "RUFinish"
                  /\ IF rphase[self] = "unregistering"
                        THEN /\ /\ disp' = disp \ {self}
                                /\ rphase' = [rphase EXCEPT ![self] = "gone"]
                                /\ tree' = [tree EXCEPT ![self] = {}]
                        ELSE /\ TRUE
                             /\ UNCHANGED << tree, disp, rphase >>
                  /\ pc' = [pc EXCEPT ![self] = "Done"]

reg(self) == RReg(self) \/ RFinish(self) \/ RUnreg(self) \/ RUFinish(self)

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
====
